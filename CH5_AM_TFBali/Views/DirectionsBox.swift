import SwiftUI
import MapKit

struct DirectionsBox: View {
    let currentInstruction: DirectionStep?
    let nextInstruction: DirectionStep?
    let nearbyLandmark: (distance: CLLocationDistance, side: String, name: String)?

    var body: some View {
        if let current = currentInstruction {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "location.north.line")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.displayText)
                            .font(.headline)
                            .lineLimit(2)

                        if let landmark = nearbyLandmark {
                            Text("There is \(landmark.name) on your \(landmark.side)")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        } else if let next = nextInstruction {
                            Text("Then: \(next.instruction)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                ProgressView(value: 0.3)
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
        nextInstruction: DirectionStep(
            instruction: "Turn right",
            distance: 500,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        ),
        nearbyLandmark: (distance: 50, side: "left", name: "Landmark 1")
    )
}
