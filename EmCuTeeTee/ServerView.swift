//
//  ServerView.swift
//  MQTTClient
//
//  Created by Adam Fowler on 27/06/2021.
//

import Logging
import MQTTNIO
import NIO
import NIOTransportServices
import SwiftUI

struct ServerView: View {
    static let maxPayloadLength = 256
    static let maxNumMessages = 50

    let serverDetails: ServerDetails
    @State var client: MQTTClientConnection?

    var connected: Bool = false
    @State var receivedMessages = CircularBuffer<String>()
    @State var messages = CircularBuffer<Message>()
    @State var currentId: Int = 0

    // subscribe sheet variables
    @State var showSubscribe = false
    @State var subscribeTopic: String = ""
    // unsubscribe sheet variables
    @State var showUnsubscribe = false
    @State var unsubscribeTopic: String = ""
    // publish sheet variables
    @State var showPublish = false
    @State var publishTopic: String = ""
    @State var publishPayload: String = ""
    @State var publishQoS: Int = 1
    @State var publishRetain: Bool = false

    //@State var timer: Timer? = nil

    var body: some View {
        NavigationView {
            ScrollViewReader { scrollView in
                List {
                    ForEach(messages) {
                        Text($0.text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay (
                                RoundedRectangle(cornerRadius: 16.0)
                                    .stroke(Color.secondary, lineWidth: 2)
                            )
                    }
                }
                .onChange(of: messages) { target in
                    withAnimation {
                        scrollView.scrollTo(target.last?.id, anchor: .bottom)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) { subscribeButton }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) { unsubscribeButton }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) { publishButton }
            }
        }
        .navigationBarTitle(Text(self.serverDetails.hostname))
        .onAppear {
            Task {
                let client = MQTTClientConnection(view: self)
                Task {
                    self.client = client
                    await client.connect()
                }
            }
        }
        .task {
            var cancelled = false
            while !cancelled {
                do  {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    cancelled = true
                }
                self.updateList()
            }
        }
        .onDisappear {
            Task {
                await self.client?.shutdown()
                self.client = nil
            }
        }
    }

    var subscribeButton: some View {
        Button("Subscribe") {
            showSubscribe = true
        }
        .sheet(isPresented: $showSubscribe) {
            SubscribeView(showView: $showSubscribe, topicName: $subscribeTopic) {
                Task {
                    await self.client?.subscribe(topic: subscribeTopic)
                }
            }
        }
    }

    var unsubscribeButton: some View {
        Button("Unsubscribe") {
            showUnsubscribe = true
        }
        .sheet(isPresented: $showUnsubscribe) {
            UnsubscribeView(showView: $showUnsubscribe, topicName: $unsubscribeTopic) {
                Task {
                    await self.client?.unsubscribe(topic: unsubscribeTopic)
                }
            }
        }
    }

    var publishButton: some View {
        Button("Publish") {
            showPublish = true
        }
        .sheet(isPresented: $showPublish) {
            PublishView(
                showView: $showPublish,
                topicName: $publishTopic,
                payload: $publishPayload,
                qos: $publishQoS,
                retain: $publishRetain
            ) {
                Task {
                    await self.client?.publish(topic: publishTopic, payload: publishPayload, qos: publishQoS, retain: publishRetain)
                }
            }
        }
    }

    /// Update list of messages. Call this every at a set interval instead of updating messages
    /// every time a new message comes in.
    func updateList() {
        guard showPublish == false, showSubscribe == false, showUnsubscribe == false else { return }
        while let message = receivedMessages.popFirst() {
            addMessage(message)
        }
    }

    func addReceivedMessage(_ text: String) {
        receivedMessages.append(text)
        if receivedMessages.count > Self.maxNumMessages {
            receivedMessages.removeFirst()
        }
    }

    func addMessage(_ text: String) {
        self.currentId += 1
        messages.append(.init(text: text, id: self.currentId))
        if messages.count > Self.maxNumMessages {
            messages.removeFirst()
        }
    }

    /// Message displayed in list
    struct Message: Identifiable, Equatable {
        let text: String
        let id: Int
    }

    struct ServerDetails {
        let identifier: String
        let hostname: String
        let port: Int
        let version: MQTTClient.Version
        let cleanSession: Bool
        let useTLS: Bool
        let useWebSocket: Bool
        let webSocketUrl: String
    }
}

/// Object MQTTClient and passing messages back to View
class MQTTClientConnection {
    static let eventLoopGroup = NIOTSEventLoopGroup()
    let view: ServerView
    let client: MQTTClient
    var shuttingDown: Bool

    init(view: ServerView) {
        let details = view.serverDetails
        let config = MQTTClient.Configuration(
            version: details.version,
            useSSL: details.useTLS,
            useWebSockets: details.useWebSocket,
            webSocketURLPath: details.webSocketUrl
        )
        var logger = Logger(label: "EmCuteetee")
        #if DEBUG
        logger.logLevel = .trace
        #else
        logger.logLevel = .critical
        #endif
        self.client = .init(
            host: details.hostname,
            port: details.port,
            identifier: details.identifier,
            eventLoopGroupProvider: .shared(Self.eventLoopGroup),
            logger: logger,
            configuration: config
        )
        self.view = view
        self.shuttingDown = false

        self.client.addPublishListener(named: "MQTTClient") { result in
            switch result {
            case .success(let value):
                let string = String(buffer: value.payload)
                Task {
                    var output: String
                    if string.count > ServerView.maxPayloadLength {
                        output = string.prefix(ServerView.maxPayloadLength) + "..."
                    } else {
                        output = string
                    }
                    await view.addReceivedMessage("\(value.topicName):\n\(output)")
                }
            case .failure:
                break
            }
        }
    }

    func connect() async {
        do {
            _ = try await self.client.connect(cleanSession: view.serverDetails.cleanSession)
            self.client.addCloseListener(named: "EmCuTeeTee") { result in
                guard !self.shuttingDown else { return }
                Task {
                    await self.view.addMessage("Connection closed")
                    await self.view.addMessage("Reconnecting...")
                    await self.connect()
                }
            }
            await self.view.addMessage("Connection successful")
        } catch {
            await self.view.addMessage("Failed to connect\n\(error)")
        }
    }

    func shutdown() async {
        self.shuttingDown = true
        try? await self.client.disconnect()
        try? await self.client.shutdown()
    }

    func publish(topic: String, payload: String, qos: Int, retain: Bool) async {
        do {
            _ = try await self.client.publish(
                to: topic,
                payload: ByteBufferAllocator().buffer(string: payload),
                qos: .init(rawValue: UInt8(qos))!,
                retain: retain
            )
            await self.view.addMessage("Published to \(topic)")
        } catch {
            await self.view.addMessage("Failed to publish to \(topic)\nError: \(error)")
        }
    }

    func subscribe(topic: String) async {
        do {
            _ = try await self.client.subscribe(to: [MQTTSubscribeInfo(topicFilter: topic, qos: MQTTQoS.exactlyOnce)])
            await self.view.addMessage("Subscribed to \(topic)")
        } catch {
            await self.view.addMessage("Failed to subscribe to \(topic)\nError: \(error)")
        }
    }

    func unsubscribe(topic: String) async {
        do {
            _ = try await self.client.unsubscribe(from: [topic])
            await self.view.addMessage("Unsubscribed to \(topic)")
        } catch {
            await self.view.addMessage("Failed to unsubscribe from \(topic)\nError: \(error)")
        }
    }
}

struct ServerView_Previews: PreviewProvider {
    static var previews: some View {
        ServerView(
            serverDetails: .init(
                identifier: "Test Client",
                hostname: "localhost",
                port: 1883,
                version: .v3_1_1,
                cleanSession: true,
                useTLS: false,
                useWebSocket: false,
                webSocketUrl: "/mqtt"
            )
        )
    }
}

