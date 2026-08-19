import SwiftUI

struct MapHeader: View {
    var title: String = "Bali Map"
    var onOpenHistory: () -> Void = {}
    var onOpenLandmarks: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .padding()
                .background(.white.opacity(0.9))
                .cornerRadius(8)

            Button(action: onOpenHistory) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            }

            Button(action: onOpenLandmarks) {
                Image(systemName: "video.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    MapHeader()
}
