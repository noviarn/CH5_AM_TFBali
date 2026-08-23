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
    init() {
#if DEBUG
        RoutePolylineBuilder.runSelfCheck()
        CorridorDataCheck.run()
        NearestStopFinder.runSelfCheck()
        RoutePlanner.runSelfCheck()
        SearchLocationManager.runSelfCheck()
        Task {
            await RoutePolylineBuilder.runAsyncSelfCheck()
            await NearestStopFinder.runAsyncSelfCheck()
        }
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Category.self, Place.self, NavigationSession.self, LandmarkVideo.self, UserProfile.self, HistoryItem.self  ])
        //        .modelContainer(for: [NavigationSession.self, LandmarkVideo.self])
    }
}
