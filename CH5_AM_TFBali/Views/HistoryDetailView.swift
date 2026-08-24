//
//  HistoryDetailView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation

/// One finished trip: when it ran, which buses it used, the landmarks it went past, and the
/// clips the rider recorded along the way.
struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: NavigationSession

    /// This trip's markings. A recording still belongs to its landmark and outlives the trip
    /// (see `LandmarkVideo.sessionID`), so these are filtered in rather than owned.
    @State private var moments: [LandmarkVideo] = []
    @State private var playback: ClipPlayback?
    @State private var isRenaming = false
    @State private var draftTitle = ""

    private var displayTitle: String {
        if let custom = session.customTitle, !custom.isEmpty { return custom }
        return session.startedAt.formatted(.dateTime.day().month(.wide).year())
    }

    /// The landmarks this trip passed, resolved to their POI records for artwork and category.
    /// Names that no longer match a POI are dropped rather than drawn as blanks.
    private var passedPlaces: [LandmarkPOI] {
        session.passedLandmarkNames.compactMap { name in
            landmarkPOIs.first { $0.name == name }
        }
    }

    /// "Visited" means the rider actually recorded something there — a subset of the
    /// landmarks passed, which is why the two numbers differ.
    private var placesVisitedCount: Int {
        Set(moments.map(\.landmarkName)).count
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    summaryCard

                    if !passedPlaces.isEmpty {
                        section("Places You Passed") {
                            PassedPlacesTrail(places: passedPlaces)
                        }
                    }

                    if !moments.isEmpty {
                        section("Your Moments") {
                            MomentsPager(moments: moments, onPlay: playAll)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { loadMoments() }
        .fullScreenCover(item: $playback) { playback in
            ClipPlayerView(title: playback.title, clips: playback.clips)
        }
        .alert("Rename trip", isPresented: $isRenaming) {
            TextField("Trip name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                // Clearing the name is how the rider gets the date back, so empty means nil
                // rather than an empty title.
                session.customTitle = trimmed.isEmpty ? nil : trimmed
                try? modelContext.save()
            }
        } message: {
            Text("Leave it empty to go back to showing the date.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                circleButton("chevron.left") { dismiss() }
                Spacer()
                circleButton("pencil") {
                    draftTitle = session.customTitle ?? ""
                    isRenaming = true
                }
            }
            .padding(.top, 8)

            Text(displayTitle)
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            metaRow
        }
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Label {
                Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day().year()))
            } icon: {
                Image(systemName: "calendar")
            }

            dot

            if let duration = session.duration {
                Label {
                    Text(Self.durationText(duration))
                } icon: {
                    Image(systemName: "clock")
                }
                dot
            }

            Image(systemName: "bus")
            ForEach(Array(session.corridorBadges.enumerated()), id: \.offset) { index, badge in
                Text(badge)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Self.badgeColor(for: badge, fallbackIndex: index), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(Color.textMuted)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var dot: some View {
        Text("•").foregroundStyle(Color.textMuted.opacity(0.6))
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            statTile("Places Visited", "figure.walk", "\(placesVisitedCount)")
            statDivider
            statTile("Moments", "video.fill", "\(moments.count)")
            statDivider
            statTile(
                "Distance",
                "point.topleft.down.to.point.bottomright.curvepath",
                Self.distanceText(session.distanceMeters)
            )
        }
        .padding(.vertical, 14)
        .background(Color.primaryPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private func statTile(_ title: String, _ icon: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.primaryPurple)
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(value)
                    .fontWeight(.semibold)
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primaryPurple.opacity(0.2))
            .frame(width: 1, height: 34)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            content()
        }
    }

    // MARK: - Data

    private func loadMoments() {
        let id = session.id
        let descriptor = FetchDescriptor<LandmarkVideo>(
            predicate: #Predicate { $0.sessionID == id },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        moments = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func playAll() {
        let clips = moments.compactMap { moment -> TripClip? in
            guard let url = Self.fileURL(for: moment),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return TripClip(name: moment.landmarkName, url: url)
        }
        guard !clips.isEmpty else { return }
        playback = ClipPlayback(title: displayTitle, clips: clips)
    }

    static func fileURL(for moment: LandmarkVideo) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LandmarkVideos", isDirectory: true)
            .appendingPathComponent(
                LandmarkVideo.storageFolder(landmarkIndex: moment.landmarkIndex, placeKey: moment.placeKey),
                isDirectory: true
            )
            .appendingPathComponent(moment.fileName)
    }

    // MARK: - Formatting

    static func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int((duration / 60).rounded())
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func distanceText(_ meters: CLLocationDistance) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    /// Corridors carry their own colour in the network data, so a badge matches the line as
    /// drawn on the map. The trailing direction letter is stripped to find it.
    static func badgeColor(for badge: String, fallbackIndex: Int) -> Color {
        let palette: [Color] = [.primaryOrange, .primaryPurple, .secondaryPurple]
        let corridorID = badge.hasSuffix(where: \.isLetter) ? String(badge.dropLast()) : badge
        return corridors.first { $0.id == corridorID }?.color
            ?? palette[fallbackIndex % palette.count]
    }
}

private extension String {
    func hasSuffix(where predicate: (Character) -> Bool) -> Bool {
        last.map(predicate) ?? false
    }
}

/// The landmarks passed, laid out as a walked trail: three to a row, every other row running
/// right to left, joined by a dashed line that bulges out at the turns.
///
/// The snake ordering is the point — it keeps consecutive landmarks next to each other, so
/// the dashed line reads as one continuous path rather than jumping back across the row.
struct PassedPlacesTrail: View {
    let places: [LandmarkPOI]

    private let columns = 3
    private let diameter: CGFloat = 78
    private let labelHeight: CGFloat = 40
    private let rowGap: CGFloat = 20

    private var rowCount: Int {
        Int((Double(places.count) / Double(columns)).rounded(.up))
    }

    private var rowHeight: CGFloat { diameter + labelHeight + rowGap }

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = proxy.size.width / CGFloat(columns)

            ZStack(alignment: .topLeading) {
                trail(columnWidth: columnWidth)
                    .stroke(
                        Color.textMuted.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
                    )

                ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                    let point = center(index, columnWidth: columnWidth)
                    badge(place, columnWidth: columnWidth)
                        .frame(width: columnWidth)
                        .position(x: point.x, y: point.y - diameter / 2 + (diameter + labelHeight) / 2)
                }
            }
        }
        .frame(height: CGFloat(rowCount) * rowHeight - rowGap)
    }

    private func badge(_ place: LandmarkPOI, columnWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(place.images.first ?? "landmark-placeholder")
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().stroke(ringColor(for: place), lineWidth: 4))

            Text(place.name)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                // Held narrower than the column so the turn arc, which passes just outside
                // the circle, has a lane of its own instead of striking through the name.
                .frame(width: max(columnWidth - 34, diameter), height: labelHeight, alignment: .top)
        }
    }

    /// Centre of the circle at `index`, snaked: even rows run left to right, odd rows right
    /// to left.
    private func center(_ index: Int, columnWidth: CGFloat) -> CGPoint {
        let row = index / columns
        let seat = index % columns
        let column = row.isMultiple(of: 2) ? seat : (columns - 1 - seat)
        return CGPoint(
            x: columnWidth * (CGFloat(column) + 0.5),
            y: CGFloat(row) * rowHeight + diameter / 2
        )
    }

    private func trail(columnWidth: CGFloat) -> Path {
        var path = Path()
        guard places.count > 1 else { return path }

        let radius = diameter / 2
        let clearance: CGFloat = 7

        for index in 0..<(places.count - 1) {
            let from = center(index, columnWidth: columnWidth)
            let to = center(index + 1, columnWidth: columnWidth)

            if from.y == to.y {
                let direction: CGFloat = to.x > from.x ? 1 : -1
                path.move(to: CGPoint(x: from.x + direction * (radius + clearance), y: from.y))
                path.addLine(to: CGPoint(x: to.x - direction * (radius + clearance), y: to.y))
            } else {
                // Dropping a row happens within one column, so the turn leaves and re-enters
                // from the circles' sides rather than their bottoms — going out the bottom
                // would take the line straight down through the landmark's name.
                let outward: CGFloat = from.x > columnWidth * 1.5 ? 1 : -1
                let offset = outward * (radius + clearance)
                let start = CGPoint(x: from.x + offset, y: from.y)
                let end = CGPoint(x: to.x + offset, y: to.y)
                let waist = (start.y + end.y) / 2

                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x + outward * 12, y: waist),
                    control2: CGPoint(x: end.x + outward * 12, y: waist)
                )
            }
        }
        return path
    }

    private func ringColor(for place: LandmarkPOI) -> Color {
        switch place.category.split(separator: "/").first.map(String.init) ?? place.category {
        case "Temple": Color.primaryPurple
        case "Beach": Color.secondaryPurple
        case "Market": Color.primaryOrange
        case "Park": Color.tertiaryOrange
        default: Color.primaryPurple
        }
    }
}

/// The clips recorded on this trip, one card at a time.
struct MomentsPager: View {
    let moments: [LandmarkVideo]
    let onPlay: () -> Void

    var body: some View {
        TabView {
            ForEach(moments) { moment in
                MomentCard(moment: moment, onPlay: onPlay)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: moments.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 430)
    }
}

private struct MomentCard: View {
    let moment: LandmarkVideo
    let onPlay: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    // A still hasn't been pulled from the clip yet — hold the card's shape
                    // rather than collapsing it and shoving the pager around.
                    Color.primaryPurple.opacity(0.15)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Button {
                Haptics.tap()
                onPlay()
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.9), in: Circle())
            }
            .padding(14)

            Label(moment.landmarkName, systemImage: "figure.walk.motion")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 28)
        .task(id: moment.id) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard thumbnail == nil, let url = HistoryDetailView.fileURL(for: moment),
              FileManager.default.fileExists(atPath: url.path) else { return }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        // A hair in rather than at zero: the first frame of these clips is regularly still
        // the camera warming up, which comes out black.
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        if let image = try? await generator.image(at: time).image {
            thumbnail = UIImage(cgImage: image)
        }
    }
}
