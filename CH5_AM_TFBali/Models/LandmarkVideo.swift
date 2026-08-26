import Foundation
import SwiftData

/// A marking recorded at a landmark. Owned by the landmark itself (`landmarkIndex`), not by
/// whichever navigation session the rider happened to be on — the same landmark can be
/// re-marked across many trips, and every recording is kept.
@Model
final class LandmarkVideo {
    @Attribute(.unique) var id: UUID
    var landmarkIndex: Int = 0
    /// Set only for a marking captured while exploring a `Place` (e.g. "Sanur Beach") rather
    /// than the fixed Kuta-loop landmarks. `landmarkIndex` alone isn't unique across places —
    /// every place's single destination-landmark is index 0 — so this disambiguates storage
    /// and lookup without renumbering the legacy 0-3 range.
    var placeKey: String?
    var landmarkName: String
    var fileName: String
    var recordedAt: Date
    /// Which trip this marking was made on, for the per-trip "Moments" list in history.
    ///
    /// Deliberately a loose id and not a relationship: a marking still belongs to its
    /// landmark and outlives any trip, so deleting a session must not take the recording with
    /// it. Nil for markings made before trips were tracked.
    var sessionID: UUID?
    /// Rider-written caption, set from the moment viewer's "Edit Caption" action. Nil until
    /// the rider bothers to add one.
    var caption: String?

    /// What belongs over this clip: the rider's own words when they wrote any, the landmark's
    /// name otherwise. Shared by the viewer's on-screen label and the caption burned into an
    /// export so the two can't drift apart.
    var displayCaption: String { caption ?? landmarkName }

    init(
        id: UUID = UUID(),
        landmarkIndex: Int,
        placeKey: String? = nil,
        landmarkName: String,
        fileName: String,
        recordedAt: Date = .now,
        sessionID: UUID? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.landmarkIndex = landmarkIndex
        self.placeKey = placeKey
        self.landmarkName = landmarkName
        self.fileName = fileName
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.caption = caption
    }

    /// Where a landmark's recordings live under `Documents/LandmarkVideos/` — one folder per
    /// fixed Kuta-loop landmark, or one per explored place when `placeKey` is set.
    static func storageFolder(landmarkIndex: Int, placeKey: String?) -> String {
        guard let placeKey else { return "landmark-\(landmarkIndex)" }
        let slug = placeKey
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return "place-\(slug)"
    }
}
