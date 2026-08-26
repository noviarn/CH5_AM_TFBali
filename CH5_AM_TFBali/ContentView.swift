//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import SwiftData

/// A trip the app was killed in the middle of, on its way back onto the navigation stack.
///
/// The place is rebuilt from the session rather than looked up, so a destination found
/// through general search — which never becomes a stored `Place` — can still be resumed.
struct ResumeTarget: Hashable {
    let place: Place
    let session: NavigationSession

    /// `nil` when the session predates the stored destination coordinates and its name
    /// matches nothing in the store, which is the one case with genuinely nothing to reopen.
    init?(session: NavigationSession, places: [Place]) {
        self.session = session
        if let match = places.first(where: { $0.name == session.routeName }) {
            place = match
        } else if let latitude = session.destinationLatitude,
                  let longitude = session.destinationLongitude {
            place = Place(
                name: session.routeName,
                desc: session.destinationSummary ?? "Trip destination",
                images: ["placeholder-default"],
                category: Category(name: "Other", image: "placeholder-default"),
                latitude: latitude,
                longitude: longitude
            )
        } else {
            return nil
        }
    }
}

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

    /// Checked once, from `@Query`'s state at cold launch, and never revisited — see the
    /// original note on why re-deriving this on every change breaks an in-progress trip.
    @State private var didCheckForResume = false
    /// The single navigation stack for the app — a resumed trip is pushed onto it rather than
    /// replacing `MainPageView` as the root, so it has a real "back to home" to pop to once
    /// the trip stops, same as a trip started normally from within the app.
    @State private var path = NavigationPath()
    @State private var networkMonitor = NetworkMonitor()
    /// Bumped to rebuild the stack, which is how a finished trip returns home in one move —
    /// see the original note on why `NavigationLink`-based pushes need this instead of
    /// popping the path directly.
    @State private var stackID = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack(path: $path) {
                MainTabView()
                    .navigationDestination(for: ResumeTarget.self) { target in
                        RouteMapView(
                            destinationPlace: target.place,
                            resumeSession: target.session,
                            isDirectToPlace: true
                        )
                    }
            }
            .id(stackID)
            .onAppear {
                guard !didCheckForResume else { return }
                didCheckForResume = true
                if let session = activeSessions.first,
                   let target = ResumeTarget(session: session, places: places) {
                    path.append(target)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .tripEndedGoHome)) { _ in
                path = NavigationPath()
                stackID = UUID()
            }

            if !networkMonitor.isConnected {
                NoInternetBanner()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: networkMonitor.isConnected)
    }
}

#Preview {
    ContentView()
}
