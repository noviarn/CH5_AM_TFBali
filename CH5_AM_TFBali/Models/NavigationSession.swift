import Foundation
import CoreLocation
import SwiftData

/// One stop on a saved trip, tied to where it sits along the route's stored path.
struct ResumeStop: Codable, Hashable {
    let name: String
    /// Index into `NavigationSession.routeCoordinates`.
    let pathIndex: Int
}

@Model
final class NavigationSession {
    @Attribute(.unique) var id: UUID
    var routeName: String
    var startedAt: Date
    var endedAt: Date?
    var totalSteps: Int
    var completedSteps: Int
    var totalCheckpoints: Int
    var checkpointsReached: Int
    var isCompleted: Bool
    var routeCoordinates: [RouteCoordinate] = []

    /// What the rider renamed this trip to. The history screen falls back to the date when
    /// this is unset, which is how every trip starts out.
    var customTitle: String?
    /// The buses ridden, as shown on the badges — corridor ID plus the direction's letter
    /// ("K5B"). Stored rather than recomputed: the corridor data can be re-cut later, and a
    /// past trip should keep saying which bus it actually took.
    var corridorBadges: [String] = []
    /// Names of the landmarks the route went past, in the order it reached them. Names only —
    /// the image and category are looked up from `landmarkPOIs` at display time, so refreshed
    /// artwork reaches old trips.
    var passedLandmarkNames: [String] = []

    /// Where the trip was headed, kept as coordinates rather than only as `routeName`.
    /// Resuming used to look the destination up by matching that name against the seeded
    /// `Place` rows, so a trip to somewhere found through general search — which deliberately
    /// never becomes a stored `Place` — could not be resumed at all, and simply vanished.
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var destinationSummary: String?

    /// The stops this trip passes, positioned along `routeCoordinates`. Stored so the home
    /// screen can work out what is still ahead from the rider's current position, rather than
    /// only repeating whatever was true when the app was killed.
    var plannedStops: [ResumeStop] = []

    /// What the trip looked like the last time it reported in. Used as the fallback for the
    /// "continue your trip" card when there is no location fix to measure against.
    var nextStopName: String?
    var stopsRemaining: Int?
    var minutesRemaining: Double?

    init(
        id: UUID = UUID(),
        routeName: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        totalSteps: Int = 0,
        completedSteps: Int = 0,
        totalCheckpoints: Int = 0,
        checkpointsReached: Int = 0,
        isCompleted: Bool = false,
        routeCoordinates: [RouteCoordinate] = [],
        customTitle: String? = nil,
        corridorBadges: [String] = [],
        passedLandmarkNames: [String] = [],
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil,
        destinationSummary: String? = nil
    ) {
        self.id = id
        self.routeName = routeName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.totalCheckpoints = totalCheckpoints
        self.checkpointsReached = checkpointsReached
        self.isCompleted = isCompleted
        self.routeCoordinates = routeCoordinates
        self.customTitle = customTitle
        self.corridorBadges = corridorBadges
        self.passedLandmarkNames = passedLandmarkNames
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.destinationSummary = destinationSummary
    }

    /// How far the trip ran, measured along the route as it was saved. Derived rather than
    /// stored — `routeCoordinates` is already trimmed to the journey the rider actually made.
    var distanceMeters: CLLocationDistance {
        RouteGeometry.length(of: routeCoordinates.map(\.coordinate))
    }

    var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}
