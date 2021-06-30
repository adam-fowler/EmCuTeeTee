//
//  BasicTextFieldModifier.swift
//  EmCuteetee
//
//  Created by Adam Fowler on 30/06/2021.
//

import SwiftUI

struct BasicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .disableAutocorrection(true)
    }
}
