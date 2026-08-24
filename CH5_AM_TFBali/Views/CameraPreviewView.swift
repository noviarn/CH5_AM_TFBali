import SwiftUI
@preconcurrency import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = controller.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        applyRotation(to: view)
        return view
    }

    /// Re-applied on every update, not only at creation. On a cold start the layer is built
    /// before the camera's `RotationCoordinator` exists, so the angle read at that moment is
    /// only the fallback — this picks up the real one once the session is up.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        applyRotation(to: uiView)
    }

    private func applyRotation(to view: PreviewView) {
        let angle = controller.currentRotationAngle()
        if let connection = view.videoPreviewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
