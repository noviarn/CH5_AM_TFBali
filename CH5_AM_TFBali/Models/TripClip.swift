import Foundation

/// One recorded landmark clip, ready to play.
struct TripClip: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}

/// Payload for the trip summary cover.
///
/// Presenting by item rather than by a bare `Bool` is deliberate: setting the clips and
/// flipping an `isPresented` flag in the same update let SwiftUI build the cover before the
/// clips landed, which is why the first play showed an empty player and every later one
/// worked.
struct TripSummary: Identifiable {
    let id = UUID()
    let clips: [TripClip]
}
