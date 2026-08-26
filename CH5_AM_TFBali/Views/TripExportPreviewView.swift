import SwiftUI
import AVKit
import Photos

/// Preview of a trip's clips compiled into one file, shown before the rider commits to saving
/// or sharing it. Cancel/Save/Share mirror the design handed off for this screen.
struct TripExportPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let videoURL: URL

    @State private var player: AVPlayer?
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // No label drawn over the player: each clip's own caption is burned into the
                // file itself, so what plays here is exactly what gets saved or shared.
                Group {
                    if let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(20)

                actionRow
                    .padding(.bottom, 24)
            }
        }
        .task { player = AVPlayer(url: videoURL) }
        .onDisappear { player?.pause() }
        .alert(
            statusMessage ?? "",
            isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })
        ) {
            Button("OK") {}
        }
    }

    private var actionRow: some View {
        HStack(spacing: 40) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                actionLabel("xmark", "Cancel")
            }

            Button {
                Haptics.tap()
                saveToPhotos()
            } label: {
                actionLabel("arrow.down", "Save")
            }

            ShareLink(item: videoURL) {
                actionLabel("square.and.arrow.up", "Share")
            }
        }
    }

    private func actionLabel(_ systemName: String, _ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.primaryOrange, in: Circle())
            Text(text)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { statusMessage = "Photos access is needed to save this video." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: videoURL, options: nil)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    statusMessage = success ? "Saved to Photos." : "Couldn't save this video."
                }
            }
        }
    }
}
