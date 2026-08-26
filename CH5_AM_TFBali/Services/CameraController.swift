@preconcurrency import AVFoundation
import SwiftUI
import Observation

@MainActor
@Observable
final class CameraController: NSObject {
    private(set) var isRecording = false
    private(set) var recordingProgress: Double = 0
    private(set) var isSessionRunning = false
    private(set) var cameraPosition: AVCaptureDevice.Position
    private(set) var flashMode: AVCaptureDevice.FlashMode
    var permissionDenied = false

    @ObservationIgnored nonisolated let session = AVCaptureSession()
    @ObservationIgnored var onFinishRecording: ((URL) -> Void)?

    @ObservationIgnored private nonisolated let configuration: CameraConfiguration
    @ObservationIgnored private nonisolated let movieOutput = AVCaptureMovieFileOutput()
    @ObservationIgnored private nonisolated let sessionQueue = DispatchQueue(label: "camera.session.queue")
    @ObservationIgnored private nonisolated(unsafe) var currentVideoInput: AVCaptureDeviceInput?
    @ObservationIgnored private nonisolated(unsafe) var recordingTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var recordingStartDate: Date?
    @ObservationIgnored private nonisolated(unsafe) var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    init(configuration: CameraConfiguration) {
        self.configuration = configuration
        self.cameraPosition = configuration.cameraPosition
        self.flashMode = configuration.flashMode
        super.init()
    }

    func requestAccessAndConfigure() {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if videoGranted && audioGranted {
                        self.configureSession()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }

    func toggleCameraPosition() {
        guard configuration.allowsCameraSwitching else { return }
        let newPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        cameraPosition = newPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            if let currentInput = self.currentVideoInput {
                self.session.removeInput(currentInput)
            }
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else { return }

            self.session.addInput(videoInput)
            self.currentVideoInput = videoInput
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: videoDevice, previewLayer: nil)
            self.applyVideoOrientationAndMirroring(position: newPosition)
        }
    }

    func toggleFlash() {
        guard configuration.allowsFlashToggle else { return }
        flashMode = flashMode == .off ? .on : .off
    }

    func startRecording() {
        guard !isRecording else { return }
        toggleTorchIfNeeded(on: flashMode == .on)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        isRecording = true
        recordingProgress = 0
        recordingStartDate = Date()
        let position = cameraPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.applyVideoOrientationAndMirroring(position: position)
            self.movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartDate else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.recordingProgress = min(elapsed / self.configuration.maxDuration, 1.0)
                if elapsed >= self.configuration.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        toggleTorchIfNeeded(on: false)
        sessionQueue.async { [weak self] in
            self?.movieOutput.stopRecording()
        }
    }

    private func configureSession() {
        // Read here, on the main actor, and carry the value across. The closure below runs on
        // sessionQueue, where main-actor state can't be read safely — same pattern as
        // startRecording already uses.
        let position = cameraPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = self.configuration.sessionPreset

            if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
               self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
                self.currentVideoInput = videoInput
                self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: videoDevice, previewLayer: nil)
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.applyVideoOrientationAndMirroring(position: position)

            self.session.commitConfiguration()
            self.session.startRunning()

            Task { @MainActor [weak self] in
                self?.isSessionRunning = true
            }
        }
    }

    private nonisolated func applyVideoOrientationAndMirroring(position: AVCaptureDevice.Position) {
        let angle = currentRotationAngle()

        if let connection = movieOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = position == .front && configuration.mirrorFrontCamera
        }
    }

    nonisolated func currentRotationAngle() -> CGFloat {
        rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
    }

    private nonisolated func toggleTorchIfNeeded(on: Bool) {
        guard let device = currentVideoInput?.device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRecording = false
            self.recordingProgress = 0
            guard error == nil else {
                print("Recording failed: \(error!)")
                return
            }
            self.onFinishRecording?(outputFileURL)
        }
    }
}
