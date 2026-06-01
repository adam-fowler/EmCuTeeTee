//
//  ServerView.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 27/06/2021.
//

import AsyncAlgorithms
import Logging
@preconcurrency import MQTTNIO
import NIO
import NIOTransportServices
import SwiftUI
import Synchronization

private let maxPayloadLength = 256
private let maxNumMessages = 50

@MainActor
struct ServerView: View {
    struct Server {
        enum SubscribeEvent {
            case subscribe(String)
            case unsubscribe(String)
        }
        let configuration: ServerConfiguration
        let messageContinuation: AsyncStream<String>.Continuation
        let subscribeStream: AsyncStream<SubscribeEvent>
    }

    struct ServerConfiguration: Sendable {
        let identifier: String
        let hostname: String
        let port: Int
        let version: MQTTConnectionConfiguration.Version
        let useTLS: Bool
        let useWebSocket: Bool
        let webSocketUrl: String
        let username: String?
        let password: String?
        
        var connectionConfiguration: MQTTConnectionConfiguration {
            // Server configuration
            let version = switch self.version {
            case .v3_1_1:
                MQTTConnectionConfiguration.VersionConfiguration.v3_1_1()
            case .v5_0:
                MQTTConnectionConfiguration.VersionConfiguration.v5_0(
                    connectProperties: [.sessionExpiryInterval(60*60)]
                )
            }
            let tls = if self.useTLS {
                MQTTConnectionConfiguration.TLS.enable(.ts(.init()), tlsServerName: self.hostname)
            } else {
                MQTTConnectionConfiguration.TLS.disable
            }
            let ws:MQTTConnectionConfiguration.WebSocketConfiguration? = if self.useWebSocket {
                .init(urlPath: self.webSocketUrl)
            } else {
                nil
            }
            return .init(
                versionConfiguration: version,
                pingConfiguration: .pingInterval(.seconds(30)),
                connectTimeout: .seconds(30),
                tls: tls,
                webSocketConfiguration: ws
            )
        }
    }

    struct PublishInfo {
        let topic: String
        let payload: String
        let qos: MQTTQoS
        let retain: Bool
    }
    let serverConfiguration: ServerConfiguration
    
    @State var publishContinuation: AsyncStream<PublishInfo>.Continuation?
    @State var subscribeContinuation: AsyncStream<Server.SubscribeEvent>.Continuation?

    @State var messages = CircularBuffer<Message>()

    @State var connected = false
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

    @State var timer: Timer? = nil
    
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
                            .id($0.id)
                    }
                }
                .onChange(of: messages) { oldValue, newValue in
                    withAnimation {
                        scrollView.scrollTo(newValue.last?.id, anchor: .bottom)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) { subscribeButton }
                ToolbarItem(placement: .bottomBar) { unsubscribeButton }
                ToolbarItem(placement: .bottomBar) { publishButton }
            }
        }
        .navigationBarTitle(Text(self.serverConfiguration.hostname))
        .task {
            let (messageStream, messageCont) = AsyncStream.makeStream(of: String.self)
            let (subscribeStream, subscribeCont) = AsyncStream.makeStream(of: Server.SubscribeEvent.self)
            self.subscribeContinuation = subscribeCont
            defer {
                self.publishContinuation = nil
                self.subscribeContinuation = nil
            }
            let server = Server(
                configuration: self.serverConfiguration,
                messageContinuation: messageCont,
                subscribeStream: subscribeStream
            )
            
            await withTaskGroup { group in
                group.addTask {
                    await runServer(server)
                }
                group.addTask {
                    var currentID = 0
                    for await message in messageStream {
                        currentID += 1
                        await self.addMessage(message, id: currentID)
                    }
                }
            }
        }
    }

    var subscribeButton: some View {
        Button("Subscribe") {
            showSubscribe = true
        }
        .sheet(isPresented: $showSubscribe) {
            SubscribeView(showView: $showSubscribe, topicName: $subscribeTopic) {
                subscribeContinuation?.yield(.subscribe($0))
            }
        }
    }

    var unsubscribeButton: some View {
        Button("Unsubscribe") {
            showUnsubscribe = true
        }
        .sheet(isPresented: $showUnsubscribe) {
            UnsubscribeView(showView: $showUnsubscribe, topicName: $unsubscribeTopic) {
               subscribeContinuation?.yield(.unsubscribe($0))
            }
        }
    }

    var publishButton: some View {
        Button("Publish") {
            showPublish = true
        }
        .disabled(!connected)
        .sheet(isPresented: $showPublish) {
            PublishView(
                showView: $showPublish,
                topicName: $publishTopic,
                payload: $publishPayload,
                qos: $publishQoS,
                retain: $publishRetain
            ) {
                guard let qos = MQTTQoS(rawValue: UInt8(publishQoS)) else { return }
                publishContinuation?.yield(.init(topic: publishTopic, payload: publishPayload, qos: qos, retain: publishRetain))
            }
        }
    }

    func setConnected(_ cont: AsyncStream<PublishInfo>.Continuation?) {
        self.publishContinuation = cont
        self.connected = true
    }

    func setDisconnected() {
        self.publishContinuation = nil
        self.connected = false
    }

    @concurrent func runServer(_ server: Server) async {
        let logger = {
            var logger = Logger(label: "EmCuTeeTee")
            logger.logLevel = .trace
            return logger
        }()
        do {
            try await withThrowingTaskGroup { group in
                let session = MQTTSession(clientID: server.configuration.identifier, logger: logger)
                group.addTask {
                    while !Task.isCancelled {
                        server.messageContinuation.yield("Connecting...")
                        do {
                            // Run connection
                            try await MQTTConnection.withConnection(
                                address: .hostname(server.configuration.hostname, port: server.configuration.port),
                                configuration: server.configuration.connectionConfiguration,
                                session: session,
                                eventLoop: NIOTSEventLoopGroup.singleton.next(),
                                logger: logger
                            ) { connection, sessionPresent in
                                server.messageContinuation.yield("Connected (\(sessionPresent ? "found session": "new session" ))")
                                
                                // publish messages
                                try await withThrowingTaskGroup { group in
                                    group.addTask {
                                        let (publishStream, publishCont) = AsyncStream.makeStream(of: PublishInfo.self)
                                        await self.setConnected(publishCont)
                                        for await publish in publishStream {
                                            do {
                                                try await connection.publish(
                                                    to: publish.topic,
                                                    payload: .init(string: publish.payload),
                                                    qos: publish.qos,
                                                    retain: publish.retain
                                                )
                                                server.messageContinuation.yield("Published to \(publish.topic)")
                                            } catch {
                                                server.messageContinuation.yield("Failed to publish to \(publish.topic)")
                                            }
                                        }
                                        await self.setDisconnected()
                                        logger.info("Finished publish stream")
                                    }
                                    group.addTask {
                                        await connection.waitOnClose()
                                        throw MQTTError.connectionClosed
                                    }
                                    try await group.next()!
                                    connection.close()
                                }
                            }
                        } catch {
                            server.messageContinuation.yield("Connection error: \(error)")
                        }
                    }
                }
                let subscriptions = Subscriptions()
                // for each subscription add a new child task
                for try await event in server.subscribeStream {
                    switch event {
                    case .subscribe(let topic):
                        let (cancelStream, cancelContinuation) = AsyncStream.makeStream(of: Void.self)
                        // verify we aren't already running this subscription
                        guard subscriptions.addNewSubscription(topic, cancelContinuation: cancelContinuation) else { continue }
                        group.addTask {
                            defer {
                                server.messageContinuation.yield("Subscription ended: \(topic)")
                                subscriptions.removeSubscription(topic)
                            }
                            try await session.subscribe(to: [.init(topicFilter: topic, qos: .exactlyOnce)]) { subscription in
                                // Merge subscription async sequence with cancellation sequence
                                enum MergedStreamType {
                                    case publish(MQTTSubscription.Element)
                                    case cancel
                                }
                                let mergedStream = merge(
                                    subscription.map { MergedStreamType.publish($0)},
                                    cancelStream.map {MergedStreamType.cancel }
                                )
                                server.messageContinuation.yield("Subscribe to: \(topic)")
                                for try await message in mergedStream {
                                    switch message {
                                    case .publish(let message):
                                        let subscriptionOutput = "\(message.topicName): \(String(buffer :message.payload))"
                                        var output: String
                                        if subscriptionOutput.count > maxPayloadLength {
                                            output = subscriptionOutput.prefix(maxPayloadLength) + "..."
                                        } else {
                                            output = subscriptionOutput
                                        }
                                        server.messageContinuation.yield(output)
                                    case .cancel:
                                        return
                                    }
                                }
                            }
                        }
                    case .unsubscribe(let topic):
                        subscriptions.cancelSubscription(topic)
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            server.messageContinuation.yield("Error: \(error)")
        }
    }

    func addMessage(_ message: String, id: Int) {
        messages.append(.init(text: message, id: id))
        if messages.count > maxNumMessages {
            messages.removeFirst()
        }
    }
    
    /// Message displayed in list
    struct Message: Identifiable, Equatable {
        let text: String
        let id: Int
    }
}

struct ServerView_Previews: PreviewProvider {
    static var previews: some View {
        ServerView(
            serverConfiguration: .init(
                identifier: "Test Client",
                hostname: "localhost",
                port: 1883,
                version: .v3_1_1,
                useTLS: false,
                useWebSocket: false,
                webSocketUrl: "/mqtt",
                username: nil,
                password: nil
            )
        )
    }
}

