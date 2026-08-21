//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // A session's `endedAt` is only set when a trip stops normally (`RouteMapView.endNavigationSession`)
    // — one still nil means the app got killed mid-trip, so relaunch should reattach to it
    // instead of showing the home screen.
    @Query(
        filter: #Predicate<NavigationSession> { $0.endedAt == nil },
        sort: \NavigationSession.startedAt,
        order: .reverse
    )
    private var activeSessions: [NavigationSession]
    // `routeName` is set to the destination place's name at trip start — matching back on it
    // avoids a schema change just to remember which place a session belongs to.
    @Query private var places: [Place]

    /// Checked once, from `@Query`'s state at cold launch, and never revisited. `@Query` is
    /// live — any trip starting or ending anywhere in the app (not just at launch) touches
    /// `activeSessions`, and re-deriving whether to resume on every change kept swapping the
    /// whole view hierarchy out from under an in-progress trip: starting one tore down the
    /// pushed `RouteMapView` and rebuilt a fresh root copy (resetting the map's camera), and
    /// stopping one dropped straight to `MainPageView` instead of leaving the rider on the
    /// route-preview screen.
    @State private var didCheckForResume = false
    /// The single navigation stack for the app — a resumed trip is pushed onto it rather than
    /// replacing `MainPageView` as the root, so it has a real "back to home" to pop to once
    /// the trip stops, same as a trip started normally from within the app.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            MainPageView()
                .navigationDestination(for: ResumeTarget.self) { target in
                    RouteMapView(destinationPlace: target.place, resumeSession: target.session, isDirectToPlace: true)
                }
        }
        .onAppear {
            guard !didCheckForResume else { return }
            didCheckForResume = true
            if let session = activeSessions.first,
               let place = places.first(where: { $0.name == session.routeName }) {
                path.append(ResumeTarget(place: place, session: session))
            }
        }
    }
}

private struct ResumeTarget: Hashable {
    let place: Place
    let session: NavigationSession
}

#Preview {
    ContentView()
}
