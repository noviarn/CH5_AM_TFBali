import SwiftUI

struct LandmarkDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let landmarkName: String
    let info: LandmarkInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.12))
                        Image(systemName: info?.icon ?? "mappin.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 140)

                    if let info {
                        Text(info.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.red, in: Capsule())

                        Text(info.summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("No information available for this landmark yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(info?.title ?? landmarkName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LandmarkDetailView(
        landmarkName: "Landmark 1",
        info: LandmarkInfo(
            title: "Beachfront Bend",
            category: "Scenic Stop",
            summary: "The stretch of the loop closest to the Kuta beachfront, where the road curves in from the coast.",
            icon: "beach.umbrella.fill"
        )
    )
}
