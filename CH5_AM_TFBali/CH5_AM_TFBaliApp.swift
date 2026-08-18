//
//  CH5_AM_TFBaliApp.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI

@main
struct CH5_AM_TFBaliApp: App {
    init() {
        #if DEBUG
        RouteGeometry.runSelfCheck()
        CorridorDataCheck.run()
        NearestStopFinder.runSelfCheck()
        Task {
            await RouteGeometry.runAsyncSelfCheck()
            await NearestStopFinder.runAsyncSelfCheck()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
