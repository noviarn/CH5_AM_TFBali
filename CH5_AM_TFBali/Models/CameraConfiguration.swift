import AVFoundation
import SwiftUI

struct CameraConfiguration {
    var maxDuration: TimeInterval = 2
    var cameraPosition: AVCaptureDevice.Position = .back
    var flashMode: AVCaptureDevice.FlashMode = .off
    var sessionPreset: AVCaptureSession.Preset = .hd1920x1080
    var allowsCameraSwitching: Bool = true
    var allowsFlashToggle: Bool = true
    var mirrorFrontCamera: Bool = true
    var accentColor: Color = .red
}
