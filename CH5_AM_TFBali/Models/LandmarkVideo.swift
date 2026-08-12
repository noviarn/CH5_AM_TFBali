import Foundation
import SwiftData

@Model
final class LandmarkVideo {
    @Attribute(.unique) var landmarkName: String
    var fileName: String
    var recordedAt: Date

    init(landmarkName: String, fileName: String, recordedAt: Date = .now) {
        self.landmarkName = landmarkName
        self.fileName = fileName
        self.recordedAt = recordedAt
    }
}
