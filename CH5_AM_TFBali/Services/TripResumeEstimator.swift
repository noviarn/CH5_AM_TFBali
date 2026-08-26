import CoreLocation

/// Works out where an interrupted trip stands *now*, from the route the session already
/// stored and a fresh location fix.
///
/// The alternative was replanning the whole trip on the home screen — `RoutePlanner` plus a
/// directions fetch — for numbers the rider glances at once before tapping through. The route
/// hasn't changed while the app was dead; only the rider's position along it has, and that is
/// plain geometry over data already on disk.
enum TripResumeEstimator {
    struct Estimate {
        let minutesRemaining: Double?
        let stopsRemaining: Int?
        let nextStopName: String?
    }

    /// Blended bus-and-walk pace, matching what `RouteMapView` shows mid-trip so the card and
    /// the map don't quote different numbers for the same journey.
    private static let averageSpeedKmh = 20.0

    /// `nil` when there is nothing better than the stored snapshot — no fix yet, or a session
    /// saved before routes were persisted.
    static func estimate(
        for session: NavigationSession,
        from location: CLLocationCoordinate2D
    ) -> Estimate? {
        let path = session.routeCoordinates.map(\.coordinate)
        guard path.count > 1,
              let progress = RouteGeometry.progress(of: location, along: path, from: 0)
        else { return nil }

        let ahead = RouteGeometry.remaining(
            path,
            fromSegment: progress.index,
            projected: progress.projected
        )
        let minutes = ahead.count > 1
            ? (RouteGeometry.length(of: ahead) / 1000 / averageSpeedKmh) * 60
            : 0

        // Only stops the bus has yet to reach. A rider who carried on while the app was shut
        // will see the count drop accordingly rather than the figure they left behind.
        let upcoming = session.plannedStops.filter { $0.pathIndex > progress.index }

        return Estimate(
            minutesRemaining: minutes,
            stopsRemaining: session.plannedStops.isEmpty ? nil : upcoming.count,
            nextStopName: upcoming.first?.name
        )
    }
}
