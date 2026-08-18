import SwiftUI
import AVKit

struct VideoPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    let landmarkName: String

    init(url: URL, landmarkName: String) {
        _player = State(initialValue: AVPlayer(url: url))
        self.landmarkName = landmarkName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear {
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                    }

                Text(landmarkName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
