import SwiftUI

struct RoutingControl: View {
    @Binding var isRouting: Bool
    let routeName: String

    var body: some View {
        HStack(spacing: 12) {
            if isRouting {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text("Routing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.blue.opacity(0.1))
                .cornerRadius(8)

                Button {
                    Haptics.tap()
                    isRouting = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.red.opacity(0.1))
                        .cornerRadius(6)
                }
            } else {
                Button {
                    Haptics.success()
                    isRouting = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Route")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
        .background(.white.opacity(0.95))
        .cornerRadius(10)
        .padding()
    }
}

#Preview {
    @Previewable @State var isRouting = false
    RoutingControl(isRouting: $isRouting, routeName: "Kuta Loop")
}
