//
//  SuggestionList.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 28/06/2021.
//

import SwiftUI

struct TextFieldSuggestionList: View {
    let suggestions: [String]
    let label: String

    @Binding var text: String

    init(_ label: String, text: Binding<String>, suggestions: [String]) {
        self.label = label
        self._text = text
        self.suggestions = suggestions
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextField(label, text: $text)
            let suggestionList = getSuggestionList(text)
            if suggestionList.count > 0 {
                VStack {
                    ForEach(suggestionList, id: \.self) { text in
                        Button(action: {
                            self.text = text
                        }) {
                            Text(text)
                            Spacer()
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .border(Color.gray)
            }
        }
    }

    func getSuggestionList(_ prefix: String) -> [String] {
        guard prefix.count > 0 else { return [] }
        var list: [String] = []
        for s in suggestions {
            if s.hasPrefix(prefix) {
                list.append(s)
                if list.count == 5 {
                    return list
                }
            }
        }
        if list.count == 1,
           list[0] == prefix {
            return []
        }
        return list
    }
}
