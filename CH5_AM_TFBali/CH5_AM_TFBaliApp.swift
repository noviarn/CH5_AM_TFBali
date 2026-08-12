//
//  CH5_AM_TFBaliApp.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import SwiftData

@main
struct CH5_AM_TFBaliApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [NavigationSession.self, LandmarkVideo.self])
    }
}
