import Foundation
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
        routeCoordinates: [RouteCoordinate] = []
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
    }
}
