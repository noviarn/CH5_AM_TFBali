import Foundation
import CoreLocation
import SwiftData

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
        passedLandmarkNames: [String] = []
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
