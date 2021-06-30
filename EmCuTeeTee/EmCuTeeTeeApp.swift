//
//  EmCuTeeTeeApp.swift
//  EmCuTeeTee
//
//  Created by Adam Fowler on 27/06/2021.
//

import SwiftUI

@main
struct EmCuTeeTeeApp: App {
    @StateObject var settings = UserSettings()
    
    var body: some Scene {
        WindowGroup {
            EnterDetailsView()
                .environmentObject(settings)
        }
    }
}
