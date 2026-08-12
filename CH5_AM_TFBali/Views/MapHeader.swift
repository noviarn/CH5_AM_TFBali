import SwiftUI

struct MapHeader: View {
    var onOpenHistory: () -> Void = {}

    var body: some View {
        HStack {
            Text("Bali Map")
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

            Spacer()
        }
        .padding()
    }
}

#Preview {
    MapHeader()
}
