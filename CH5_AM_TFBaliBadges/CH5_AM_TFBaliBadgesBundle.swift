//
//  CH5_AM_TFBaliBadgesBundle.swift
//  CH5_AM_TFBaliBadges
//
//  Created by Nurkahfi Rahmada on 12/08/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CH5_AM_TFBaliBadgesBundle: WidgetBundle {
    var body: some Widget {
        RoutingActivityWidget()
    }
}

/// The palette the card is drawn from. The widget extension can't reach the main app's
/// asset catalog, so these mirror `primaryPurple` and `creamText` by value.
private extension Color {
    static let activityAccent = Color(red: 0x9A / 255, green: 0x6C / 255, blue: 1)
    static let activityGlyph = Color(red: 1, green: 0xE1 / 255, blue: 0xCD / 255)
    /// Stands in for the background image while it decodes, and behind its transparent
    /// edges — sampled from the artwork so the seam never shows.
    static let activityBackdrop = Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x4B / 255)
}

/// Everything the phase decides, in one place, so the lock-screen card and the Dynamic
/// Island can't drift apart as either design changes.
struct ActivityStyle {
    let state: RoutingActivityAttributes.ContentState

    var isAnnouncement: Bool {
        state.phase == .landmark || state.phase == .arrived
    }

    var glyph: String {
        switch state.phase {
        case .walking, .walkingToDestination: "figure.walk"
        case .riding, .gettingOff: "bell.fill"
        case .landmark: "building.columns.fill"
        case .arrived: "mappin"
        }
    }

    /// The landmark alert flips the badge — cream disc, purple glyph — so the one card the
    /// rider has to notice before it's behind them doesn't look like the rest.
    var invertsGlyph: Bool { state.phase == .landmark }

    /// The artwork alone is a mid indigo (~#464789), leaving white text at about 4.6:1 —
    /// legible in a screenshot, marginal on a lock screen in daylight. This takes it to the
    /// depth the design shows, and to ~12:1. The landmark card sits lighter on purpose.
    var scrimOpacity: Double { state.phase == .landmark ? 0.18 : 0.42 }

    /// Metres up to a kilometre, then kilometres — value and unit split so each can be set
    /// at its own size. A whole number of kilometres drops its decimal: "4 km", not "4.0 km".
    var distance: (value: String, unit: String) {
        guard state.metersRemaining >= 1000 else {
            return (String(format: "%.0f", state.metersRemaining), "m")
        }
        let km = (state.metersRemaining / 100).rounded() / 10
        return (String(format: km == km.rounded() ? "%.0f" : "%.1f", km), "km")
    }

    var landmarkSideText: String {
        switch state.landmarkSide {
        case "left": "Look to your left"
        case "right": "Look to your right"
        default: "Look ahead"
        }
    }

    // MARK: Lock screen

    var cardTitle: String {
        switch state.phase {
        case .walking, .walkingToDestination: "Walking to \(state.placeName)"
        case .riding: "Your Stop: \(state.placeName)"
        case .gettingOff: "Get off at \(state.placeName)"
        case .landmark, .arrived: state.placeName
        }
    }

    /// The small line above the name on the announcement cards.
    var cardCaption: String? {
        switch state.phase {
        case .landmark: landmarkSideText
        case .arrived: "You've Arrived at"
        default: nil
        }
    }

    // MARK: Dynamic Island

    /// The island leads with the name itself — a stop by its own name, the final walk by the
    /// action, arrival by the announcement.
    var islandTitle: String {
        switch state.phase {
        case .walkingToDestination: "Walk to \(state.placeName)"
        case .arrived: "You've Arrived!"
        default: state.placeName
        }
    }

    var islandDetail: String {
        switch state.phase {
        case .walking, .walkingToDestination:
            "\(state.minutesRemaining) min · \(distance.value) \(distance.unit)"
        case .riding:
            "\(state.minutesRemaining) min (\(distance.value) \(distance.unit))"
                + (state.stopsRemaining.map { " · \($0) \($0 == 1 ? "Stop" : "Stops")" } ?? "")
        case .gettingOff:
            "\(state.minutesRemaining) min · Next Stop"
        case .landmark:
            landmarkSideText
        case .arrived:
            state.placeName
        }
    }

    /// Enough for the pill beside the camera: the glyph carries the state, this carries the
    /// one number worth reading at a glance.
    var compactTrailingText: String? {
        switch state.phase {
        case .walking, .walkingToDestination, .riding, .gettingOff: "\(state.minutesRemaining)m"
        case .landmark, .arrived: nil
        }
    }

    @ViewBuilder
    func circledGlyph(diameter: CGFloat, glyphSize: CGFloat) -> some View {
        Image(systemName: glyph)
            .font(.system(size: glyphSize, weight: .medium))
            .foregroundStyle(invertsGlyph ? Color.activityAccent : Color.activityGlyph)
            .frame(width: diameter, height: diameter)
            .background(invertsGlyph ? Color.activityGlyph : Color.activityAccent, in: Circle())
    }

    /// The artwork, its fallback, and the legibility scrim — the backdrop both surfaces sit on.
    @ViewBuilder
    var backdrop: some View {
        ZStack {
            Color.activityBackdrop
            Image("live-activites-bg")
                .resizable()
                .scaledToFill()
            Color.black.opacity(scrimOpacity)
        }
    }
}

/// The expanded Dynamic Island: badge, name, and the detail line under it.
///
/// Fills the region the system hands over, edge to edge — the widget zeroes the expanded
/// content margins (see `contentMargins(_:_:for:)` below) and the system clips this to the
/// island's own shape, so the artwork needs no corner radius of its own. The padding here is
/// the text's breathing room, not an inset for the panel.
struct RoutingActivityIslandRow: View {
    let state: RoutingActivityAttributes.ContentState

    private var style: ActivityStyle { ActivityStyle(state: state) }

    var body: some View {
        HStack(spacing: 14) {
            // Back to 40pt: at 54 the island's own clip cut the circle. The expanded region
            // is shorter than it measures from a screenshot, so this is the size that fits.
            style.circledGlyph(diameter: 40, glyphSize: 19)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.islandTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    // Never below the detail line's 13pt. Bali stop names run to 45 characters
                    // ("Pos Pengamanan Terpadu Dalung (Puter Balik)"), and a lower floor shrank
                    // the title under its own subtitle. A legible truncated name beats a
                    // complete unreadable one, and the distinguishing part comes first.
                    .minimumScaleFactor(0.85)
                Text(style.islandDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 0)
        }
        // Asymmetric on purpose. The row sits low in the island (the sensor strip takes the
        // top), which puts the badge right where the bottom-left corner curves in and clips
        // it. The wider sides clear the curve horizontally; the heavier bottom lifts the row
        // out of it. Keep the bottom greater than the top if these are ever retuned.
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Bled outward on purpose. Even with the expanded content margins zeroed, the system
        // still hands over a frame inset from the island's edge, which left the artwork
        // ringed by a band of the island's black. Oversizing the backdrop covers that band;
        // the island's own shape clips whatever spills past it.
        .background(style.backdrop.padding(-24))
        .foregroundStyle(.white)
    }
}

/// The lock-screen card. Two layouts: a row (glyph, title, metrics) for the legs the rider
/// is working through, and a centred one for the two moments that are announcements rather
/// than progress — a landmark alongside, and arrival.
struct RoutingActivityLockScreenView: View {
    let state: RoutingActivityAttributes.ContentState

    private var style: ActivityStyle { ActivityStyle(state: state) }

    private var isAnnouncement: Bool { style.isAnnouncement }

    private var title: String { style.cardTitle }

    private var caption: String? { style.cardCaption }

    private var distance: (value: String, unit: String) { style.distance }

    var body: some View {
        ZStack {
            style.backdrop
            if isAnnouncement { announcement } else { legProgress }
        }
        .foregroundStyle(.white)
    }

    private var legProgress: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                circledGlyph
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
                    // Stop names run long ("Puri Agung Pemecutan"); shrink rather than
                    // truncate, since the name is the one thing the card is telling you.
                    .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Spacer(minLength: 0)
                metric(String(state.minutesRemaining), "min")
                metric(distance.value, distance.unit)
                // Only while there's still a ride to count down. On the get-off card the
                // answer is always "this one", so the design drops it for time and distance.
                if state.phase == .riding, let stops = state.stopsRemaining {
                    metric(String(stops), stops == 1 ? "stop" : "stops")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(22)
    }

    private var announcement: some View {
        VStack(spacing: 6) {
            circledGlyph
            if let caption {
                Text(caption)
                    .font(.system(size: 13, weight: .regular))
            }
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var circledGlyph: some View {
        style.circledGlyph(
            diameter: isAnnouncement ? 36 : 50,
            glyphSize: isAnnouncement ? 18 : 26
        )
    }

    private func metric(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .light))
            Text(unit)
                .font(.system(size: 13, weight: .regular))
        }
        .foregroundStyle(.white)
    }
}

struct RoutingActivityWidget: Widget {
    let kind: String = "RoutingActivityWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutingActivityAttributes.self) { context in
            RoutingActivityLockScreenView(state: context.state)
                // The artwork is the background, so the system tint must not sit on top of it.
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let style = ActivityStyle(state: context.state)

            return DynamicIsland {
                // One full-width pill rather than the leading/trailing split: the design is a
                // single row, and only `.bottom` spans the whole island under the camera.
                DynamicIslandExpandedRegion(.bottom) {
                    RoutingActivityIslandRow(state: context.state)
                }
            } compactLeading: {
                Image(systemName: style.glyph)
                    .foregroundStyle(Color.activityAccent)
            } compactTrailing: {
                if let text = style.compactTrailingText {
                    Text(text)
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: style.glyph)
                    .foregroundStyle(Color.activityAccent)
            }
            // The system's default margins would inset the artwork, leaving it floating in the
            // island's black instead of filling it. Zeroing them hands the whole expanded
            // region over; `RoutingActivityIslandRow` pads its own text back in.
            .contentMargins(.all, 0, for: .expanded)
        }
    }
}
