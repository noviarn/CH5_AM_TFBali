import SwiftUI
import AVFoundation

struct TripSummaryPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let clips: [TripClip]

    @State private var player = AVPlayer()
    @State private var currentIndex = 0

    private var currentName: String {
        guard clips.indices.contains(currentIndex) else { return "" }
        return clips[currentIndex].name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if clips.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash.fill")
                            .font(.largeTitle)
                        Text("No landmark videos for this trip")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                } else {
                    PlayerLayerView(player: player)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()

                        Text(currentName)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.5), in: Capsule())

                        Spacer()

                        HStack(spacing: 6) {
                            ForEach(clips.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                                    .frame(height: 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        player.pause()
                        dismiss()
                    }
                }
            }
        }
        // Keyed on the clip list so playback restarts if the cover is reused for another
        // trip, rather than sitting on the previous session's first clip.
        .task(id: clips.map(\.id)) {
            currentIndex = 0
            playClip(at: 0)
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let endedItem = notification.object as? AVPlayerItem,
                  endedItem === player.currentItem else { return }

            let next = currentIndex + 1
            guard next < clips.count else { return }
            currentIndex = next
            playClip(at: next)
        }
    }

    private func playClip(at index: Int) {
        guard clips.indices.contains(index) else { return }
        let url = clips[index].url

        if !FileManager.default.fileExists(atPath: url.path) {
            print("Trip summary: missing video file at \(url.path)")
            return
        }

        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}
