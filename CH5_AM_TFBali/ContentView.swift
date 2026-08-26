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
    /// The single navigation stack for the app — a resumed trip is pushed onto it rather than
    /// replacing `MainPageView` as the root, so it has a real "back to home" to pop to once
    /// the trip stops, same as a trip started normally from within the app.
    ///
    /// Relaunching no longer pushes a trip on its own. It used to, which meant a rider who
    /// force-quit was dropped back onto a live map with no way to say "I'm done with that" —
    /// and when the destination lookup failed the trip silently disappeared instead. The
    /// unfinished trip is now offered on the home screen (see `ContinueTripCard`), and this
    /// stack is only what carries them there when they accept.
    @State private var path = NavigationPath()

    /// Bumped to rebuild the stack, which is how a finished trip returns home in one move.
    ///
    /// Most of the app pushes with `NavigationLink(destination:)`, and SwiftUI does not record
    /// those in `path` — so there is no path to clear and no way to pop several screens at
    /// once. Each screen used to dismiss itself in turn instead, which visibly stepped back
    /// through every page between the map and home. Rebuilding the stack drops all of them at
    /// the same instant.
    @State private var stackID = UUID()

    var body: some View {
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
        .onReceive(NotificationCenter.default.publisher(for: .tripEndedGoHome)) { _ in
            path = NavigationPath()
            stackID = UUID()
        }
    }
}

#Preview {
    ContentView()
}
