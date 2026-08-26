import Foundation

/// Rider-facing description for one point in `Landmark.coordinates`, indexed the same way
/// ("Landmark 1" -> index 0). Kept separate from `Landmark` itself since the geometry
/// (coordinates, polygon) and the descriptive content change independently.
struct LandmarkInfo: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let summary: String
    let icon: String
}
