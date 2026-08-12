import Foundation
import SwiftData

@Model
final class LandmarkVideo {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var landmarkName: String
    var recordedAt: Date
    var session: NavigationSession?

    init(
        id: UUID = UUID(),
        landmarkName: String,
        fileName: String,
        recordedAt: Date = .now,
        session: NavigationSession? = nil
    ) {
        self.id = id
        self.landmarkName = landmarkName
        self.fileName = fileName
        self.recordedAt = recordedAt
        self.session = session
    }
}
