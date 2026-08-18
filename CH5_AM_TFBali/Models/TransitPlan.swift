import MapKit

/// One physical bus stop the rider's route actually passes, in the order the road reaches
/// it. The outbound/inbound pair at a two-way stop collapses to a single visit — see
/// `TransitPlanner`.
struct TransitStopVisit: Identifiable {
    let id = UUID()
    let stop: BusStop
    /// Position along the route's combined coordinate path.
    let pathIndex: Int
}

/// What happens between two consecutive stop visits.
enum TransitLegKind {
    /// Same corridor, ride straight through.
    case ride(corridor: Int)
    /// Corridor changes but the two stops are effectively the same spot — step off one bus,
    /// onto the other, no walking involved.
    case sameStopTransfer(from: Int, to: Int)
    /// Corridor changes and the stops are physically apart — the rider has to walk the gap.
    case walkingTransfer(from: Int, to: Int, distance: CLLocationDistance)

    /// Rider-facing description of the transfer, or `nil` for a plain ride — nil is the
    /// signal callers use to decide whether a transfer banner should show at all.
    var transferSummary: String? {
        switch self {
        case .ride:
            return nil
        case .sameStopTransfer(let from, let to):
            return "Change here: Corridor \(from) → Corridor \(to)"
        case .walkingTransfer(let from, let to, let distance):
            return "Walk \(DirectionStep.formatted(distance)): Corridor \(from) → Corridor \(to)"
        }
    }
}

struct TransitLeg: Identifiable {
    let id = UUID()
    let from: TransitStopVisit
    let to: TransitStopVisit
    let kind: TransitLegKind

    var isTransfer: Bool { kind.transferSummary != nil }
}
