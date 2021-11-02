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

    var client = Client()

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
            self.createClient()
            Task {
                await self.connect()
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
            //self.timer?.invalidate()
            //self.timer = nil
            self.client.destroy()
        }
    }

    var subscribeButton: some View {
        Button("Subscribe") {
            showSubscribe = true
        }
        .sheet(isPresented: $showSubscribe) {
            SubscribeView(showView: $showSubscribe, topicName: $subscribeTopic) {
                Task {
                    do {
                        _ = try await self.client.client?.subscribe(to: [MQTTSubscribeInfo(topicFilter: subscribeTopic, qos: MQTTQoS.exactlyOnce)])
                        self.addReceivedMessage("Subscribed to \(subscribeTopic)")
                    } catch {
                        self.addReceivedMessage("Failed to subscribe to \(subscribeTopic)\nError: \(error)")
                    }
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
                    do {
                        _ = try await self.client.client?.unsubscribe(from: [unsubscribeTopic])
                        self.addReceivedMessage("Unsubscribed from \(unsubscribeTopic)")
                    } catch {
                        self.addReceivedMessage("Failed to unsubscribe from \(unsubscribeTopic)\nError: \(error)")
                    }
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
                    do {
                        _ = try await self.client.client?.publish(
                            to: publishTopic,
                            payload: ByteBufferAllocator().buffer(string: publishPayload),
                            qos: .init(rawValue: UInt8(publishQoS))!,
                            retain: publishRetain
                        )
                        self.addReceivedMessage("Published to \(publishTopic)")
                    } catch {
                        self.addReceivedMessage("Failed to publish to \(publishTopic)\nError: \(error)")
                    }
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

    /// create MQTT client
    func createClient() {
        client.create(details: self.serverDetails) { result in
            switch result {
            case .success(let value):
                let string = String(buffer: value.payload)
                var output: String
                if string.count > Self.maxPayloadLength {
                    output = string.prefix(Self.maxPayloadLength) + "..."
                } else {
                    output = string
                }
                addReceivedMessage("\(value.topicName):\n\(output)")
            case .failure:
                break
            }
        }
    }
    
    /// connect to MQTT server
    func connect() async {
        do {
            _ = try await self.client.client?.connect(cleanSession: serverDetails.cleanSession)
            self.client.client?.addCloseListener(named: "EmCuTeeTee") { result in
                addMessage("Connection closed")
                addMessage("Reconnecting...")
                Task {
                    await self.connect()
                }
            }
            addMessage("Connection successful")
        } catch {
            addMessage("Failed to connect\n\(error)")
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

    class Client {
        static let eventLoopGroup = NIOTSEventLoopGroup()

        var client: MQTTClient?
        var logger: Logger = {
            var logger = Logger(label: "EmCuteetee")
            #if DEBUG
            logger.logLevel = .trace
            #else
            logger.logLevel = .critical
            #endif
            return logger
        } ()

        func create(
            details: ServerDetails,
            onPublish: @escaping (Result<MQTTPublishInfo, Error>)->()
        ) {
            let config = MQTTClient.Configuration(
                version: details.version,
                useSSL: details.useTLS,
                useWebSockets: details.useWebSocket,
                webSocketURLPath: details.webSocketUrl
            )
            self.client = .init(
                host: details.hostname,
                port: details.port,
                identifier: details.identifier,
                eventLoopGroupProvider: .shared(Self.eventLoopGroup),
                logger: self.logger,
                configuration: config
            )
            self.client?.addPublishListener(named: "MQTTClient") { result in
                onPublish(result)
            }
        }

        func destroy() {
            Task {
                try? await self.client?.disconnect()
                try? await self.client?.shutdown()
                self.client = nil
            }
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

