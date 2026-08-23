import SwiftUI

/// Detail sheet for a standalone corridor point of interest — see the note on `LandmarkPOI`.
struct LandmarkPOIDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let poi: LandmarkPOI

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
//                    Image(poi.image)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(height: 220)
//                        .frame(maxWidth: .infinity)
//                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(poi.category)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondaryPurple)
                                .clipShape(RoundedRectangle(cornerRadius: 5))

                            ForEach(poi.corridorIDs, id: \.self) { id in
                                Text(id)
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.primaryOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }

                        Text(poi.name)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                    }

                    Text(poi.summary)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)

                    if !poi.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What to do")
                                .font(.system(.headline, design: .rounded))
                            ForEach(poi.activities, id: \.self) { activity in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.primaryOrange)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)
//                                    Text(activity)
//                                        .font(.system(.subheadline, design: .rounded))
                                }
                            }
                        }
                    }

                    if let funFact = poi.funFact {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Color.primaryOrange)
                                if let title = poi.funFactTitle {
                                    Text(title)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                }
                            }
                            Text(funFact)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primaryOrange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle(poi.name)
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
    LandmarkPOIDetailView(poi: landmarkPOIs[0])
}
