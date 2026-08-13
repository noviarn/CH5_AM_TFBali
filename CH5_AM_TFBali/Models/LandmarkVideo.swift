import Foundation
import SwiftData

/// A marking recorded at a landmark. Owned by the landmark itself (`landmarkIndex`), not by
/// whichever navigation session the rider happened to be on — the same landmark can be
/// re-marked across many trips, and every recording is kept.
@Model
final class LandmarkVideo {
    @Attribute(.unique) var id: UUID
    var landmarkIndex: Int = 0
    var landmarkName: String
    var fileName: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        landmarkIndex: Int,
        landmarkName: String,
        fileName: String,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.landmarkIndex = landmarkIndex
        self.landmarkName = landmarkName
        self.fileName = fileName
        self.recordedAt = recordedAt
    }
}
