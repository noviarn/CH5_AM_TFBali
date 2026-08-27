import SwiftUI
import MapKit

/// What the search sheet shows before anyone types: places worth going, arranged so a visitor
/// who doesn't know a single name in Bali still has somewhere to start.
///
/// A flat list ordered by distance answered "what is closest", which is only useful to someone
/// who already knows what they're looking for. These sections answer "what is there".
struct SearchRecommendations: View {
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (LandmarkPOI) -> Void

    @State private var selectedCategory: String?

    /// Free-text categories in the source data ("Park/Statue") reduced to their first term,
    /// which is what the chips are built from.
    private var categories: [String] {
        var seen: [String] = []
        for poi in sortedByDistance where !seen.contains(poi.primaryCategory) {
            seen.append(poi.primaryCategory)
        }
        return seen
    }

    private var sortedByDistance: [LandmarkPOI] {
        guard let userLocation else { return landmarkPOIs }
        return landmarkPOIs.sorted {
            userLocation.distance(to: $0.coordinate) < userLocation.distance(to: $1.coordinate)
        }
    }

    /// Places the curated data actually says something to do at, rather than just name.
    ///
    /// Note this is not a local endorsement — nothing in `LandmarkPOI` records one. If real
    /// local picks are wanted, a flag on the model would drive this section instead.
    private var worthAStop: [LandmarkPOI] {
        sortedByDistance.filter { !$0.activities.isEmpty }
    }

    private var listed: [LandmarkPOI] {
        guard let selectedCategory else { return worthAStop }
        return sortedByDistance.filter { $0.primaryCategory == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Nearby landmarks") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sortedByDistance.prefix(6)) { poi in
                                nearbyCard(poi)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                section("Browse by category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                categoryChip(category)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                section(selectedCategory ?? "Things to do") {
                    VStack(spacing: 0) {
                        ForEach(listed) { poi in
                            row(poi)
                            if poi.id != listed.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryPurple)
                .padding(.horizontal, 16)
            content()
        }
    }

    private func nearbyCard(_ poi: LandmarkPOI) -> some View {
        Button {
            Haptics.selection()
            onSelect(poi)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(poi.primaryImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 126, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(poi.name)
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryPurple)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if let distance = distanceText(to: poi.coordinate) {
                    Text(distance)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: 150, height: 186, alignment: .topLeading)
            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            Haptics.selection()
            // Tapping the active chip clears it, so there's a way back to the default list.
            selectedCategory = isSelected ? nil : category
        } label: {
            Text(category)
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : Color.primaryPurple)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.primaryPurple : Color.gray.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func row(_ poi: LandmarkPOI) -> some View {
        Button {
            Haptics.selection()
            onSelect(poi)
        } label: {
            HStack(spacing: 12) {
                Image(poi.primaryImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text(poi.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(poi.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let distance = distanceText(to: poi.coordinate) {
                    Text(distance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func distanceText(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let userLocation else { return nil }
        let metres = userLocation.distance(to: coordinate)
        return metres < 1000
            ? String(format: "%.0f m", metres)
            : String(format: "%.1f km", metres / 1000)
    }
}
