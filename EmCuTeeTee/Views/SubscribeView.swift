//
//  SubscribeView.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 27/06/2021.
//

import SwiftUI

struct SubscribeView: View {
    @Binding var showView: Bool
    @Binding var topicName: String
    let onOk: () -> ()

    var body: some View {
        Form {
            Text("Subscribe")
                .font(.title)
            HStack {
                Text("Topic filter")
                TextField("Enter topic filter", text: $topicName)
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
