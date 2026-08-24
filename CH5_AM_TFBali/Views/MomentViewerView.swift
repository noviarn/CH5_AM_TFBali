import SwiftUI
import AVFoundation
import Photos
import SwiftData

/// Full-screen, swipeable playback of a trip's recorded moments — back/share/menu chrome up
/// top, a landmark pin badge, and native video controls per clip.
struct MomentViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var moments: [LandmarkVideo]
    @State private var currentIndex: Int

    @State private var isEditingCaption = false
    @State private var draftCaption = ""
    /// The moment the caption editor was opened on, held apart from `currentIndex` so the
    /// write lands on the clip the rider actually meant.
    @State private var captionTarget: LandmarkVideo?
    @State private var statusMessage: String?
    @State private var isExporting = false
    @State private var exportedVideoURL: URL?
    /// A ready player per moment, kept only for the clip on screen and its immediate
    /// neighbours. Swapping one player's item on every page turn meant each turn waited on a
    /// fresh read from disk; holding the neighbours warm makes the swipe land on a clip that
    /// has already buffered. Three at a time rather than all of them, so a long trip doesn't
    /// carry a player per moment.
    @State private var players: [UUID: AVPlayer] = [:]

    init(moments: [LandmarkVideo], startIndex: Int) {
        _moments = State(initialValue: moments)
        _currentIndex = State(initialValue: startIndex)
    }

    private var current: LandmarkVideo? {
        moments.indices.contains(currentIndex) ? moments[currentIndex] : nil
    }

    private var currentURL: URL? {
        current.flatMap(HistoryDetailView.fileURL(for:))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if moments.isEmpty {
                Text("No moments to show")
                    .foregroundStyle(.white)
            } else {
                // Only the clip on screen is mounted, and it changes in place. A paged
                // TabView carried each clip in on a horizontal scroll, and a video layer part
                // way through that transition sat visibly off-centre; there is nothing to
                // slide here, so there is nothing to land crooked. Neighbours stay buffered
                // in `players` regardless, so the swap is still immediate.
                if let current {
                    MomentPage(
                        url: HistoryDetailView.fileURL(for: current),
                        player: players[current.id]
                    )
                }

                tapZones

                if let current {
                    Label(current.displayCaption, systemImage: "mappin.and.ellipse")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.35), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                }

                if moments.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(moments.indices, id: \.self) { index in
                            Circle()
                                .fill(.white.opacity(index == currentIndex ? 1 : 0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                }
            }

            topBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { syncPlayers() }
        .onChange(of: currentIndex) { syncPlayers() }
        .onDisappear {
            players.values.forEach { $0.pause() }
            players = [:]
        }
        // One observer for the whole viewer rather than one per clip. The neighbouring clips
        // are kept warm and parked at their first frame, so more than one player is alive at a
        // time and any of them could in principle report a finish; `advance(past:)` decides
        // which one is allowed to turn the page.
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let endedItem = notification.object as? AVPlayerItem else { return }
            advance(past: endedItem)
        }
        .alert("Edit Caption", isPresented: $isEditingCaption) {
            TextField("Caption", text: $draftCaption)
            Button("Cancel", role: .cancel) { finishEditingCaption() }
            Button("Save") {
                saveCaption()
                finishEditingCaption()
            }
        }
        .alert(
            statusMessage ?? "",
            isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })
        ) {
            Button("OK") {}
        }
        .fullScreenCover(
            isPresented: Binding(get: { exportedVideoURL != nil }, set: { if !$0 { exportedVideoURL = nil } })
        ) {
            if let exportedVideoURL {
                TripExportPreviewView(videoURL: exportedVideoURL)
            }
        }
    }

    /// Left half goes back a clip, right half goes on to the next — the whole screen is the
    /// control, since the chrome is deliberately sparse and there are no transport buttons.
    /// Sits below `topBar` in the stack so its buttons still take their own taps.
    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { step(-1) }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { step(1) }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            circleButton("chevron.left") { dismiss() }
            Spacer()
            Button {
                Haptics.tap()
                exportTrip()
            } label: {
                if isExporting {
                    ProgressView()
                        .tint(.primary)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                } else {
                    circleIcon("square.and.arrow.up")
                }
            }
            .disabled(isExporting)
            Menu {
                Button(role: .destructive) { deleteCurrent() } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button { startEditingCaption() } label: {
                    Label("Edit Caption", systemImage: "captions.bubble")
                }
                Button { saveToPhotos() } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            } label: {
                circleIcon("ellipsis")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            circleIcon(systemName)
        }
    }

    private func circleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(.white, in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
    }

    // MARK: - Actions

    /// Holds the clip still for as long as the keyboard is up. Left running, it reaches its
    /// end while the rider is still typing, hands over to the next moment, and the caption
    /// they were writing gets filed against a clip they never opened the editor on.
    private func startEditingCaption() {
        guard let current else { return }
        players[current.id]?.pause()
        captionTarget = current
        draftCaption = current.caption ?? ""
        isEditingCaption = true
    }

    private func saveCaption() {
        // The moment captured when the editor opened, never whatever is on screen by the time
        // Save is tapped.
        guard let captionTarget else { return }
        let trimmed = draftCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        captionTarget.caption = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
    }

    private func finishEditingCaption() {
        captionTarget = nil
        guard let current else { return }
        players[current.id]?.play()
    }

    private func deleteCurrent() {
        guard moments.indices.contains(currentIndex) else { return }
        let moment = moments[currentIndex]
        if let url = HistoryDetailView.fileURL(for: moment) {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(moment)
        try? modelContext.save()

        moments.remove(at: currentIndex)
        if moments.isEmpty {
            dismiss()
        } else if currentIndex >= moments.count {
            currentIndex = moments.count - 1
        } else {
            // The index still points somewhere valid but at a different moment now, so
            // `onChange(of: currentIndex)` won't fire — re-window by hand.
            syncPlayers()
        }
    }

    /// Steps a clip in either direction, stopping at the ends rather than wrapping — the
    /// first and last clip are where the trip actually starts and stops.
    private func step(_ delta: Int) {
        let target = currentIndex + delta
        guard moments.indices.contains(target) else { return }
        Haptics.tap()
        currentIndex = target
    }

    /// Moves to the clip after the one that just finished, addressed by the moment that owns
    /// the ended item rather than by bumping the index.
    ///
    /// The destination is computed, never incremented, so the same end-of-clip notification
    /// arriving twice lands on the same page both times. A relative `currentIndex += 1` here
    /// skipped a moment outright: the second delivery ran against the pre-advance state and
    /// stepped a second time, so clip one handed straight over to clip three.
    private func advance(past endedItem: AVPlayerItem) {
        guard let endedID = players.first(where: { $0.value.currentItem === endedItem })?.key,
              let endedIndex = moments.firstIndex(where: { $0.id == endedID }),
              // Only the clip on screen gets to turn the page — a neighbour is parked at its
              // first frame and has no business ending, but if one ever does it is ignored.
              endedIndex == currentIndex,
              endedIndex + 1 < moments.count
        else { return }
        currentIndex = endedIndex + 1
    }

    /// Brings the window of live players in line with wherever the rider is: builds the ones
    /// now in range, drops the ones that fell out of it, plays the visible clip and parks the
    /// neighbours at their first frame so a swipe reveals a picture rather than black.
    ///
    /// Also called after a delete, where the index can stay put while the moment under it
    /// changes.
    private func syncPlayers() {
        let window = (currentIndex - 1)...(currentIndex + 1)
        let inWindow = moments.indices.filter { window.contains($0) }
        let keepIDs = Set(inWindow.map { moments[$0].id })

        players.keys.filter { !keepIDs.contains($0) }.forEach { id in
            players[id]?.pause()
            players[id] = nil
        }

        for index in inWindow {
            let moment = moments[index]
            if players[moment.id] == nil {
                guard let url = HistoryDetailView.fileURL(for: moment),
                      FileManager.default.fileExists(atPath: url.path) else { continue }
                let player = AVPlayer(url: url)
                // These are local files, so there is nothing to wait for — starting straight
                // away is what makes the cut between clips feel immediate.
                player.automaticallyWaitsToMinimizeStalling = false
                players[moment.id] = player
            }

            guard let player = players[moment.id] else { continue }
            if index == currentIndex {
                player.seek(to: .zero)
                player.play()
            } else {
                player.pause()
                player.seek(to: .zero)
            }
        }
    }

    private func exportTrip() {
        guard !isExporting else { return }
        let clips = moments.compactMap { moment -> TripClip? in
            guard let url = HistoryDetailView.fileURL(for: moment),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            // Same label the viewer shows over the clip, burned into the exported video.
            return TripClip(name: moment.displayCaption, url: url)
        }
        guard !clips.isEmpty else { return }

        isExporting = true
        Task {
            do {
                let url = try await TripClip.merge(clips)
                isExporting = false
                exportedVideoURL = url
            } catch {
                isExporting = false
                statusMessage = "Couldn't prepare this trip's video."
            }
        }
    }

    private func saveToPhotos() {
        guard let url = currentURL else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { statusMessage = "Photos access is needed to save this clip." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    statusMessage = success ? "Saved to Photos." : "Couldn't save this clip."
                }
            }
        }
    }
}

/// One page of the viewer: the clip filling the whole screen (cropped, not letterboxed), with
/// no native transport chrome — this is a stories-style viewer, so the only controls are a tap
/// on either side, and the clip finishing plays the next one automatically.
private struct MomentPage: View {
    let url: URL?
    /// The clip's player, already warmed by the viewer. Nil while one is still being built, or
    /// when the clip's file has gone missing; playback stays the viewer's call, so nothing
    /// here starts or stops anything.
    let player: AVPlayer?

    private var fileMissing: Bool {
        guard let url else { return true }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        Group {
            if fileMissing {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash.fill")
                    Text("Clip unavailable")
                }
                .foregroundStyle(.white)
            } else if let player {
                FullScreenPlayerView(player: player)
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
}

/// Crops to fill the screen edge to edge rather than AVKit's default letterboxed fit.
private struct FullScreenPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
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
