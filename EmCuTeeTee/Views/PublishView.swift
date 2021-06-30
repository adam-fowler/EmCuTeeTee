//
//  PublishView.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 27/06/2021.
//

import SwiftUI

struct PublishView: View {
    @Binding var showView: Bool
    @Binding var topicName: String
    @Binding var payload: String
    @Binding var qos: Int
    @Binding var retain: Bool
    let onOk: () -> ()

    var body: some View {
        Form {
            Text("Publish")
                .font(.title)
            HStack {
                Text("Topic name")
                TextField("Enter topic name", text: $topicName)
            }
            Text("Payload")
            TextEditor(text: $payload)
                .border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/, width: 1)
            Picker(
                selection: $qos,
                label: Text("QoS"),
                content: {
                    Text("At most once").tag(0)
                    Text("At least once").tag(1)
                    Text("Exactly once").tag(2)
                }
            ).pickerStyle(SegmentedPickerStyle())
            Toggle(isOn: $retain) {
                Text("Retain")
            }
            HStack {
                Button("Cancel") {
                    self.showView = false
                }
                .buttonStyle(BorderlessButtonStyle())
                Spacer()
                Button("OK") {
                    onOk()
                    self.showView = false
                }
                .disabled(topicName.count == 0)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
        }
    }
}
