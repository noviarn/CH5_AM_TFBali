import SwiftUI

/// What's out of the window right now, floated over the map.
///
/// The trip sheet already carries this, but only once expanded — a rider watching the map
/// with the sheet pulled down to its 80pt bar would ride straight past a landmark without
/// ever being told. Like the recentre button, this only shows while the sheet is minimized:
/// a sheet renders above the view that presented it, so an expanded one covers this anyway,
/// and by then the sheet's own copy is on screen.
struct LandmarkProximityCard: View {
    let name: String
    let distance: String
    let direction: String
    let icon: String
    /// Something to read while the place is still up the road. Dropped once it is actually
    /// in view — by then the rider should be looking out of the window, not at the phone.
    var summary: String?
    /// Opens the camera on the landmark. Kept as a real button inside the card rather than
    /// the card's own action, so reaching for the shutter can't be mistaken for wanting to
    /// read more.
    var onCapture: () -> Void = {}
    var onTap: () -> Void = {}

    var body: some View {
        // A plain tappable container rather than a Button: a Button nested inside another
        // Button doesn't reliably receive its own taps, and the camera below needs to.
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.primaryPurple, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(direction)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.secondaryPurple)

                Text(name)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryPurple)
                    .lineLimit(1)

                if let summary {
                    Text(summary)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.primaryPurple.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(distance)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onCapture) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.primaryOrange, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onTap)
    }
}

#Preview("Still up the road") {
    LandmarkProximityCard(
        name: "Satria Gatotkaca Park",
        distance: "820 m away",
        direction: "Coming up",
        icon: "figure.stand",
        summary: "A small landmark park in Tuban whose centrepiece is a dramatic sculpture of Gatotkaca in battle with Karna."
    )
    .padding()
}

#Preview("In view") {
    LandmarkProximityCard(
        name: "Satria Gatotkaca Park",
        distance: "120 m away",
        direction: "Look on your left!",
        icon: "figure.stand"
    )
    .padding()
}
