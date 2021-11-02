//
//  ContentView.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 27/06/2021.
//

import MQTTNIO
import SwiftUI

struct EnterDetailsView: View {
    @State var clientIdentifier: String = ""
    @State var serverName: String = "test.mosquitto.org"
    @State var port: Int = 1883
    @State var webSocket: Bool = false
    @State var webSocketUrl: String = "/mqtt"
    @State var tls: Bool = false
    @State var version: MQTTClient.Version = .v3_1_1
    @State var cleanSession: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter server details")) {
                    HStack {
                        Text("Identifier")
                        TextField(
                            "Enter client identifier",
                            text: $clientIdentifier
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }
                    HStack {
                        Text("Host")
                        TextField("Enter server name", text: $serverName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    let portBinding = Binding<String>(
                        get: { String(self.$port.wrappedValue) },
                        set: {
                            if let value = NumberFormatter().number(from: $0) {
                                self.$port.wrappedValue = value.intValue
                            }
                        }
                    )
                    HStack {
                        Text("Port")
                        TextField("Port", text: portBinding)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    }
                    let versionBinding = Binding<Int>(
                        get: {
                            switch self.version {
                            case .v3_1_1:
                                return 0
                            case .v5_0:
                                return 1
                            }
                        },
                        set: {
                            switch $0 {
                            case 0:
                                self.version = .v3_1_1
                            case 1:
                                self.version = .v5_0
                            default:
                                break
                            }
                        }
                    )
                    Picker(
                        selection: versionBinding,
                        label: Text("Version"),
                        content: {
                            Text("3.1.1").tag(0)
                            Text("5.0").tag(1)
                        }
                    ).pickerStyle(SegmentedPickerStyle())
                    Toggle("TLS", isOn: $tls)
                    Toggle("WebSocket", isOn: $webSocket)
                    if webSocket {
                        HStack {
                            Text("WebSocket URL")
                            TextField("Enter URL", text: $webSocketUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                }
                Section {
                    Toggle("Clean Session", isOn: $cleanSession)
                    NavigationLink (
                        destination: ServerView(
                            serverDetails: .init(
                                identifier: clientIdentifier,
                                hostname: serverName,
                                port: port,
                                version: version,
                                cleanSession: cleanSession,
                                useTLS: tls,
                                useWebSocket: webSocket,
                                webSocketUrl: webSocketUrl
                            )
                        )
                    ) {
                        Text("Connect")
                    }
                    .disabled(serverName.count == 0)
                }
            }
        }
    }

    struct TextFieldPreferenceKey: PreferenceKey {
        static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
            value = nextValue()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EnterDetailsView()
    }
}
