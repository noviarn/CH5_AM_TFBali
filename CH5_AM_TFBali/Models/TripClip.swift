import Foundation
import AVFoundation
import UIKit

/// One recorded landmark clip, ready to play.
struct TripClip: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}

extension TripClip {
    enum MergeError: Error {
        case noTrack
        case exportSessionFailed
    }

    /// Concatenates clips into a single file, in order — for a share/save flow that needs
    /// one exportable video for the whole trip rather than a clip per landmark.
    ///
    /// Each clip gets its own composition track and its own time-ranged instruction. Stacking
    /// every clip onto one shared track can't work: a composition track reports a single
    /// `naturalSize` (its first segment's) and takes a single transform, so every clip after
    /// the first is rendered against the wrong geometry and comes out cropped or rotated.
    static func merge(_ clips: [TripClip]) async throws -> URL {
        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        var cursor = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var captions: [Caption] = []
        // Set by the first clip and held for the rest, so the canvas doesn't change shape
        // mid-video. Clips that don't match it are fitted into it rather than cropped.
        var renderSize: CGSize?

        for clip in clips {
            let asset = AVURLAsset(url: clip.url)
            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
                  let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }

            // The video track's own range, not `asset.duration` — a recording's audio track
            // usually runs a little past its video, so the asset duration overshoots what the
            // video actually supplies. Advancing the cursor by the longer figure drifted every
            // instruction ahead of its footage until the last clip's landed past the end of
            // the composition and never got rendered.
            let range = try await sourceVideoTrack.load(.timeRange)
            let duration = range.duration
            try videoTrack.insertTimeRange(range, of: sourceVideoTrack, at: cursor)

            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            // The clip as the viewer should see it: the recorded buffer is landscape with a
            // rotation tagged alongside, so upright dimensions come from applying that rotation.
            let orientedSize = naturalSize.applying(preferredTransform)
            let uprightSize = CGSize(width: abs(orientedSize.width), height: abs(orientedSize.height))

            let canvas = renderSize ?? uprightSize
            renderSize = canvas

            // Fit rather than fill: a clip shaped differently from the canvas gets bars, never
            // a crop that eats the frame the rider actually recorded.
            let scale = min(canvas.width / uprightSize.width, canvas.height / uprightSize.height)
            let scaled = CGSize(width: uprightSize.width * scale, height: uprightSize.height * scale)
            let transform = preferredTransform
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(
                    translationX: (canvas.width - scaled.width) / 2,
                    y: (canvas.height - scaled.height) / 2
                ))

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(transform, at: .zero)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: duration)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            if let audioTrack, let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                // Trimmed to the video's length so the sound of one clip doesn't run over the
                // start of the next.
                let audioRange = try await sourceAudioTrack.load(.timeRange)
                let clamped = CMTimeRange(
                    start: audioRange.start,
                    duration: CMTimeMinimum(audioRange.duration, duration)
                )
                try? audioTrack.insertTimeRange(clamped, of: sourceAudioTrack, at: cursor)
            }
            captions.append(Caption(text: clip.name, start: cursor.seconds, duration: duration.seconds))
            cursor = cursor + duration
        }

        guard let renderSize, !instructions.isEmpty else { throw MergeError.noTrack }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions
        videoComposition.animationTool = captionTool(for: captions, renderSize: renderSize)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw MergeError.exportSessionFailed
        }
        exportSession.videoComposition = videoComposition
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trip-export-\(UUID().uuidString).mp4")
        try await exportSession.export(to: outputURL, as: .mp4)
        return outputURL
    }

    /// A clip's label and the stretch of the finished video it belongs to, in seconds.
    private struct Caption {
        let text: String
        let start: Double
        let duration: Double
    }

    /// Bakes each clip's label into the exported frames, styled like the capsule the viewer
    /// shows over a moment.
    ///
    /// It has to be burned in rather than drawn over the player: once the file leaves the app —
    /// saved to Photos, handed to a friend — none of our own views are left to draw it.
    private static func captionTool(
        for captions: [Caption],
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool? {
        let labelled = captions.filter { !$0.text.isEmpty && $0.duration > 0 }
        guard !labelled.isEmpty else { return nil }

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        for caption in labelled {
            guard let image = captionImage(caption.text, renderSize: renderSize),
                  let cgImage = image.cgImage
            else { continue }

            let layer = CALayer()
            layer.contents = cgImage
            layer.frame = CGRect(
                x: (renderSize.width - image.size.width) / 2,
                y: (renderSize.height - image.size.height) / 2,
                width: image.size.width,
                height: image.size.height
            )
            // Off by default, switched on for exactly this clip's stretch of the timeline.
            // Both animations are kept on the layer and filled forwards, because that is what
            // holds opacity steady between the two switches — an animation that tidies itself
            // up snaps the label back the instant it finishes.
            layer.opacity = 0

            let show = CABasicAnimation(keyPath: "opacity")
            show.fromValue = 0
            show.toValue = 1
            // A begin time of plain zero reads as "now" to Core Animation, which during an
            // offline render amounts to never; this constant is how the timeline's own zero
            // is spelled.
            show.beginTime = caption.start == 0 ? AVCoreAnimationBeginTimeAtZero : caption.start
            show.duration = 0.01
            show.fillMode = .forwards
            show.isRemovedOnCompletion = false
            layer.add(show, forKey: "show")

            let hide = CABasicAnimation(keyPath: "opacity")
            hide.fromValue = 1
            hide.toValue = 0
            hide.beginTime = caption.start + caption.duration
            hide.duration = 0.01
            hide.fillMode = .forwards
            hide.isRemovedOnCompletion = false
            layer.add(hide, forKey: "hide")

            parentLayer.addSublayer(layer)
        }

        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }

    /// Draws the capsule once as a bitmap rather than assembling it from a `CATextLayer` and
    /// friends — the whole look stays in one place, and drawing at the video's own pixel size
    /// keeps the text sharp.
    private static func captionImage(_ text: String, renderSize: CGSize) -> UIImage? {
        // Measured off the video rather than fixed, so the label reads the same whatever
        // dimensions the recording came in at.
        let fontSize = max(14, renderSize.width * 0.045)
        let horizontalPadding = fontSize * 0.9
        let verticalPadding = fontSize * 0.5
        let spacing = fontSize * 0.3

        let base = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: fontSize) } ?? base

        let icon = UIImage(
            systemName: "mappin.and.ellipse",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize, weight: .semibold)
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ])

        let iconWidth = icon?.size.width ?? 0
        let gap = icon == nil ? 0 : spacing
        // Capped so a long caption stays inside the frame and truncates, rather than growing a
        // capsule wider than the video.
        let maxTextWidth = renderSize.width * 0.86 - horizontalPadding * 2 - iconWidth - gap
        guard maxTextWidth > 0 else { return nil }

        let textWidth = min(attributed.size().width.rounded(.up), maxTextWidth)
        let textHeight = font.lineHeight.rounded(.up)
        let size = CGSize(
            width: horizontalPadding * 2 + iconWidth + gap + textWidth,
            height: max(textHeight, icon?.size.height ?? 0) + verticalPadding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        // Already working in the video's pixels, and the export runs off the main actor where
        // the screen's own scale isn't ours to ask for.
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.withAlphaComponent(0.35).setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: size.height / 2
            ).fill()

            var x = horizontalPadding
            if let icon {
                icon.draw(in: CGRect(
                    x: x,
                    y: (size.height - icon.size.height) / 2,
                    width: icon.size.width,
                    height: icon.size.height
                ))
                x += icon.size.width + spacing
            }
            attributed.draw(in: CGRect(
                x: x,
                y: (size.height - textHeight) / 2,
                width: textWidth,
                height: textHeight
            ))
        }
    }
}

/// Payload for presenting a landmark's recorded markings.
///
/// Presenting by item rather than by a bare `Bool` is deliberate: setting the clips and
/// flipping an `isPresented` flag in the same update let SwiftUI build the cover before the
/// clips landed, which is why the first play showed an empty player and every later one
/// worked.
struct ClipPlayback: Identifiable {
    let id = UUID()
    let title: String
    let clips: [TripClip]
}
