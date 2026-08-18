import ActivityKit
import MapKit

actor RoutingActivityManager {
    static let shared = RoutingActivityManager()
    private var activity: Activity<RoutingActivityAttributes>?

    func startActivity(routeName: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities disabled — enable in Settings > CH5_AM_TFBali > Live Activities")
            return
        }

        let attributes = RoutingActivityAttributes(routeName: routeName)
        let initialContentState = RoutingActivityAttributes.ContentState(
            currentInstruction: "Starting navigation",
            currentDistance: "—",
            nextInstruction: Optional<String>.none,
            nearbyLandmarkName: Optional<String>.none,
            landmarkDistance: Optional<String>.none,
            landmarkSide: Optional<String>.none,
            nextStopName: Optional<String>.none,
            transferSummary: Optional<String>.none
        )

        do {
            activity = try Activity<RoutingActivityAttributes>.request(
                attributes: attributes,
                contentState: initialContentState,
                pushType: .none
            )
            print("Live Activity started: \(activity?.id ?? "?")")
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    func updateActivity(
        currentStep: DirectionStep?,
        distanceToCurrentStep: CLLocationDistance?,
        nextStep: DirectionStep?,
        nearbyLandmark: NearbyLandmark?,
        nextStopName: String?,
        transferSummary: String?
    ) async {
        guard let activity = activity else { return }

        let currentDistance = distanceToCurrentStep.map(DirectionStep.formatted)
            ?? currentStep?.formattedDistance

        let contentState = RoutingActivityAttributes.ContentState(
            currentInstruction: currentStep?.instruction ?? "Navigation active",
            currentDistance: currentDistance ?? "—",
            nextInstruction: nextStep?.displayText(),
            nearbyLandmarkName: nearbyLandmark?.name,
            landmarkDistance: nearbyLandmark?.formattedDistance,
            landmarkSide: nearbyLandmark?.side.rawValue,
            nextStopName: nextStopName,
            transferSummary: transferSummary
        )

        // Re-pushing an identical state wakes the widget for nothing, and at 1 Hz that is
        // most ticks.
        guard contentState != activity.content.state else { return }

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
            landmarkSide: Optional<String>.none,
            nextStopName: Optional<String>.none,
            transferSummary: Optional<String>.none
        ), dismissalPolicy: .immediate)
        self.activity = nil
    }
}
