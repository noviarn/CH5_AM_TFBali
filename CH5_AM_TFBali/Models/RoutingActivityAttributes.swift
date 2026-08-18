import ActivityKit
import MapKit

struct RoutingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let currentInstruction: String
        let currentDistance: String
        let nextInstruction: String?
        let nearbyLandmarkName: String?
        let landmarkDistance: String?
        let landmarkSide: String?
        let nextStopName: String?
        let transferSummary: String?
    }

    let routeName: String
}
