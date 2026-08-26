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

        // If the app was killed mid-trip, this actor's `activity` handle was lost but
        // ActivityKit kept the Live Activity itself running on the system side — resuming
        // the trip would otherwise start a second one alongside it, and "Stop" would only
        // ever end the new handle, leaving the orphaned one stuck on the lock screen.
        for stale in Activity<RoutingActivityAttributes>.activities {
            await stale.end(stale.content, dismissalPolicy: .immediate)
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
            transferSummary: Optional<String>.none,
            // The first leg is always the walk to the boarding stop; the real numbers land on
            // the first update, once there's a GPS fix to measure from.
            phase: .walking,
            placeName: routeName,
            minutesRemaining: 0,
            metersRemaining: 0,
            stopsRemaining: nil
        )

        do {
            activity = try Activity<RoutingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialContentState, staleDate: nil),
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
        transferSummary: String?,
        phase: RoutingActivityAttributes.ContentState.Phase,
        placeName: String,
        minutesRemaining: Int,
        metersRemaining: CLLocationDistance,
        stopsRemaining: Int?
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
            transferSummary: transferSummary,
            phase: phase,
            placeName: placeName,
            minutesRemaining: minutesRemaining,
            metersRemaining: metersRemaining,
            stopsRemaining: stopsRemaining
        )

        // Re-pushing an identical state wakes the widget for nothing, and at 1 Hz that is
        // most ticks.
        guard contentState != activity.content.state else { return }

        await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }

    func endActivity() async {
        guard let activity = activity else { return }
        await activity.end(ActivityContent(state: RoutingActivityAttributes.ContentState(
            currentInstruction: "Navigation ended",
            currentDistance: "—",
            nextInstruction: Optional<String>.none,
            nearbyLandmarkName: Optional<String>.none,
            landmarkDistance: Optional<String>.none,
            landmarkSide: Optional<String>.none,
            nextStopName: Optional<String>.none,
            transferSummary: Optional<String>.none,
            phase: .arrived,
            placeName: "Trip ended",
            minutesRemaining: 0,
            metersRemaining: 0,
            stopsRemaining: nil
        ), staleDate: nil), dismissalPolicy: .immediate)
        self.activity = nil
    }
}
