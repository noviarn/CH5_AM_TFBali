import SwiftUI

struct MapHeader: View {
    var body: some View {
        HStack {
            Text("Bali Map")
                .font(.headline)
                .padding()
                .background(.white.opacity(0.9))
                .cornerRadius(8)
                .padding()

            Spacer()
        }
    }
}

#Preview {
    MapHeader()
}
