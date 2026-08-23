import MapKit
import SwiftUI

/// One painted stretch of a route's path: which slice it covers, and how that slice should
/// read to the rider. The path itself stays a single flat array — progress, maneuver
/// positions and checkpoint ordering are all indexed against it — so this describes the
/// colouring alongside it rather than splitting it up.
struct RouteSegment: Identifiable {
    let id = UUID()
    /// Half-open range into `MapRoute.combinedWaypoints`.
    let range: Range<Int>
    let kind: Kind

    enum Kind {
        /// Riding one bus, drawn in that corridor's own colour and labelled with its line.
        case ride(line: String, color: Color)
        /// On foot: the approach to the first stop, a change between buses, or the last mile.
        case walk
    }

    var isRide: Bool {
        if case .ride = kind { return true }
        return false
    }

    /// Moves the range into `combinedWaypoints` space once the approach leg is known, the
    /// same shift `DirectionStep` gets.
    func shifted(by offset: Int) -> RouteSegment {
        RouteSegment(range: (range.lowerBound + offset)..<(range.upperBound + offset), kind: kind)
    }
}

struct MapRoute: Identifiable {
    let id = UUID()
    let name: String
    let waypoints: [CLLocationCoordinate2D]
    let approachWaypoints: [CLLocationCoordinate2D]
    /// How `combinedWaypoints` is coloured, in that array's own index space. Empty when the
    /// route is a plain point-to-point fallback with no legs to tell apart, in which case
    /// the map falls back to drawing one undifferentiated line.
    let segments: [RouteSegment]

    init(
        name: String,
        waypoints: [CLLocationCoordinate2D],
        approachWaypoints: [CLLocationCoordinate2D] = [],
        segments: [RouteSegment] = []
    ) {
        self.name = name
        self.waypoints = waypoints
        self.approachWaypoints = approachWaypoints
        self.segments = segments
    }

    /// Approach leg followed by the loop, as one continuous path. Progress, maneuver
    /// positions and checkpoint ordering are all measured against this so there is a single
    /// monotonic index for the whole trip.
    var combinedWaypoints: [CLLocationCoordinate2D] {
        approachWaypoints + waypoints
    }

    var polyline: MKPolyline {
        MKPolyline(coordinates: waypoints, count: waypoints.count)
    }

    var approachPolyline: MKPolyline? {
        guard approachWaypoints.count >= 2 else { return nil }
        return MKPolyline(coordinates: approachWaypoints, count: approachWaypoints.count)
    }
}
