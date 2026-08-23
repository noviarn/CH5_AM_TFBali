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

        // What the lock-screen card shows: the leg in progress, rather than the next turn.
        // A rider glancing at a locked phone wants "how much longer on this bit", not a
        // maneuver they can't see the road for.

        /// Which card the rider gets. The two states the design also called for — waiting at
        /// the stop for a named bus, and that bus arriving — are deliberately absent: both
        /// need live vehicle positions, which no feed provides here, and a countdown invented
        /// from a timetable would have riders watching an empty road.
        enum Phase: String, Codable, Hashable {
            /// On foot to a bus stop — the first one, or the far side of a transfer.
            case walking
            /// On foot on the last stretch, with no more buses to catch. Split from `walking`
            /// because the Dynamic Island names the two differently: a stop is announced by
            /// its own name, the final walk as "Walk to <place>".
            case walkingToDestination
            /// On the bus with the alighting stop still some way off.
            case riding
            /// On the bus, alighting stop next — the rider needs to be at the door.
            case gettingOff
            /// A landmark is alongside right now. Transient, and outranks the others.
            case landmark
            /// Destination reached.
            case arrived
        }

        let phase: Phase
        /// The one name the card is about: the stop being walked to, the stop being ridden
        /// to, the landmark alongside, or the destination. Phrasing lives in the widget.
        let placeName: String
        /// Left to run on the current leg. Numbers rather than formatted strings, so the card
        /// can size a value and its unit separately.
        let minutesRemaining: Int
        let metersRemaining: Double
        /// Stops still to be ridden before the rider's own stop. `nil` off the bus.
        let stopsRemaining: Int?
    }

    let routeName: String
}
