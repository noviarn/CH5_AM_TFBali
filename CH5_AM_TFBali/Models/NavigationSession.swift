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

    @Relationship(deleteRule: .cascade, inverse: \LandmarkVideo.session)
    var videos: [LandmarkVideo]

    init(
        id: UUID = UUID(),
        routeName: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        totalSteps: Int = 0,
        completedSteps: Int = 0,
        videos: [LandmarkVideo] = []
    ) {
        self.id = id
        self.routeName = routeName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.videos = videos
    }
}
