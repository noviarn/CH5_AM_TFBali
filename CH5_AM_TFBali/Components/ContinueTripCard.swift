import SwiftUI

/// Offers a trip the app was killed in the middle of.
///
/// A force-quit used to lose the journey outright — the session survived in the store, but
/// nothing on screen said so, so the rider had no way back to it. Relaunching now surfaces
/// it here rather than shoving them straight back onto the map: the trip may well be over in
/// practice, and that is theirs to decide.
struct ContinueTripCard: View {
    let destinationName: String
    let minutesRemaining: Double?
    let stopsRemaining: Int?
    let nextStopName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("In Progress")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow, in: Capsule())

            Text(destinationName)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryPurple)
                .lineLimit(2)

            HStack(alignment: .top, spacing: 0) {
                stat("Arriving in", arrivingText)
                divider
                stat("Stop Remaining", stopsText)
                divider
                stat("Next Stop", nextStopName ?? "—")
            }

            Text("Continue Your Trip")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primaryOrange, in: Capsule())
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primaryOrange.opacity(0.5), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 10)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryPurple)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dashes rather than a fabricated number: these come from the last snapshot the trip
    /// managed to write, and a trip killed before its route resolved has none.
    private var arrivingText: String {
        guard let minutesRemaining, minutesRemaining > 0 else { return "—" }
        let total = Int(minutesRemaining.rounded())
        let hours = total / 60
        let minutes = total % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes) min" : "\(hours)h" }
        return "\(minutes) min"
    }

    private var stopsText: String {
        guard let stopsRemaining else { return "—" }
        return "\(stopsRemaining) Stop\(stopsRemaining == 1 ? "" : "s")"
    }
}

#Preview {
    ContinueTripCard(
        destinationName: "Bajra Sandhi Monument",
        minutesRemaining: 80,
        stopsRemaining: 12,
        nextStopName: "Sentral Parkir Kuta Luar"
    )
    .padding()
    .background(Color.appBackground)
}
