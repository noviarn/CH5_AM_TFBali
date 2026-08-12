import ActivityKit
import MapKit

actor RoutingActivityManager {
    static let shared = RoutingActivityManager()
    private var activity: Activity<RoutingActivityAttributes>?

    func startActivity(routeName: String) async {
        let attributes = RoutingActivityAttributes(routeName: routeName)
        let initialContentState = RoutingActivityAttributes.ContentState(
            currentInstruction: "Starting navigation",
            currentDistance: "—",
            nextInstruction: Optional<String>.none,
            nearbyLandmarkName: Optional<String>.none,
            landmarkDistance: Optional<String>.none,
            landmarkSide: Optional<String>.none
        )

        do {
            activity = try Activity<RoutingActivityAttributes>.request(
                attributes: attributes,
                contentState: initialContentState,
                pushType: .none
            )
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    func updateActivity(
        currentStep: DirectionStep?,
        nextStep: DirectionStep?,
        nearbyLandmark: (distance: CLLocationDistance, side: String, name: String)?
    ) async {
        guard let activity = activity else { return }

        let contentState = RoutingActivityAttributes.ContentState(
            currentInstruction: currentStep?.instruction ?? "Navigation active",
            currentDistance: currentStep?.formattedDistance ?? "—",
            nextInstruction: nextStep?.displayText,
            nearbyLandmarkName: nearbyLandmark?.name,
            landmarkDistance: nearbyLandmark.map { String(format: "%.0f m", $0.distance) },
            landmarkSide: nearbyLandmark?.side
        )

        await activity.update(using: contentState)
    }

    func endActivity() async {
        guard let activity = activity else { return }
        await activity.end(using: RoutingActivityAttributes.ContentState(
            currentInstruction: "Navigation ended",
            currentDistance: "—",
            nextInstruction: Optional<String>.none,
            nearbyLandmarkName: Optional<String>.none,
            landmarkDistance: Optional<String>.none,
            landmarkSide: Optional<String>.none
        ), dismissalPolicy: .immediate)
        self.activity = nil
    }
}
