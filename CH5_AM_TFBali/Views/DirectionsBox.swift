import SwiftUI
import MapKit

struct DirectionsBox: View {
    let currentInstruction: DirectionStep?
    /// Live distance from the rider to the maneuver. `DirectionStep.distance` is the fixed
    /// length MapKit assigned the step, which is why the box used to sit on one number.
    var distanceToCurrent: CLLocationDistance?
    let nextInstruction: DirectionStep?
    let nearbyLandmark: NearbyLandmark?
    var checkpointIndex: Int = 0
    var totalCheckpoints: Int = 0
    var currentCheckpoint: RouteCheckpoint?
    var onOpenCamera: () -> Void = {}

    private var checkpointKindLabel: String {
        switch currentCheckpoint?.kind {
        case .landmark: "Landmark"
        case .busStop: "Bus Stop"
        case .none: ""
        }
    }

    private var checkpointProgress: Double {
        guard totalCheckpoints > 0 else { return 0 }
        return Double(checkpointIndex) / Double(totalCheckpoints)
    }

    var body: some View {
        if let current = currentInstruction {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "location.north.line")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.displayText(remaining: distanceToCurrent))
                            .font(.headline)
                            .lineLimit(2)

                        if let landmark = nearbyLandmark {
                            Text("There is \(landmark.name) \(landmark.sideDescription) · \(landmark.formattedDistance)")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        } else if let next = nextInstruction {
                            Text("Then: \(next.instruction)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }

                        if totalCheckpoints > 0 {
                            Text("Checkpoint \(min(checkpointIndex + 1, totalCheckpoints)) of \(totalCheckpoints) · \(checkpointKindLabel): \(currentCheckpoint?.name ?? "")")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }

                    Spacer()

                    if nearbyLandmark != nil {
                        Button(action: onOpenCamera) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.red)
                                .clipShape(Circle())
                        }
                    }
                }

                ProgressView(value: checkpointProgress)
                    .tint(.blue)
            }
            .padding()
            .background(.white)
            .cornerRadius(12)
            .shadow(radius: 4)
            .padding()
        }
    }
}

#Preview {
    DirectionsBox(
        currentInstruction: DirectionStep(
            instruction: "Turn left",
            distance: 200,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        ),
        distanceToCurrent: 85,
        nextInstruction: DirectionStep(
            instruction: "Turn right",
            distance: 500,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        ),
        nearbyLandmark: NearbyLandmark(index: 0, distance: 50, side: .left, name: "Landmark 1"),
        checkpointIndex: 1,
        totalCheckpoints: 4,
        currentCheckpoint: RouteCheckpoint(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            name: "Landmark 2",
            kind: .landmark
        )
    )
}
