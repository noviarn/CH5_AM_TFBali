import SwiftUI

struct RecenterButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "location.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .background(.blue, in: Circle())
                .shadow(radius: 4)
        }
    }
}

#Preview {
    RecenterButton {}
}
