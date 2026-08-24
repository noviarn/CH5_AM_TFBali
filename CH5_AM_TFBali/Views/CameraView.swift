import SwiftUI
import AVFoundation

struct CameraView: View {
    @State private var controller: CameraController
    @Environment(\.dismiss) private var dismiss

    let configuration: CameraConfiguration
    var onFinish: (URL) -> Void

    init(configuration: CameraConfiguration = CameraConfiguration(), onFinish: @escaping (URL) -> Void) {
        self.configuration = configuration
        self.onFinish = onFinish
        _controller = State(wrappedValue: CameraController(configuration: configuration))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Mounted up front rather than gated on `isSessionRunning`. The preview layer has
            // to be bound to the session before it starts running, or the first launch — the
            // one where configuration happens after the permission prompt — comes up black.
            if !controller.permissionDenied {
                CameraPreviewView(controller: controller)
                    .ignoresSafeArea()

                if !controller.isSessionRunning {
                    ProgressView()
                        .tint(.white)
                }
            }

            VStack {
                topBar

                Spacer()

                if controller.permissionDenied {
                    permissionDeniedView
                }

                Spacer()

                bottomBar
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .statusBarHidden()
        .onAppear {
            controller.onFinishRecording = { url in
                onFinish(url)
                dismiss()
            }
            controller.requestAccessAndConfigure()
        }
        .onDisappear {
            controller.stopSession()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }

            Spacer()

            if configuration.allowsFlashToggle {
                Button {
                    Haptics.toggle()
                    controller.toggleFlash()
                } label: {
                    Image(systemName: controller.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.4), in: Circle())
                }
            }
        }
        .padding(.horizontal)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text("Camera & microphone access needed")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private var bottomBar: some View {
        HStack {
            if configuration.allowsCameraSwitching {
                Button {
                    Haptics.toggle()
                    controller.toggleCameraPosition()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.black.opacity(0.4), in: Circle())
                }
            } else {
                Color.clear.frame(width: 52, height: 52)
            }

            Spacer()

            RecordButton(
                isRecording: controller.isRecording,
                progress: controller.recordingProgress,
                accentColor: configuration.accentColor,
                action: {
                    if controller.isRecording {
                        Haptics.success()
                        controller.stopRecording()
                    } else {
                        Haptics.tap()
                        controller.startRecording()
                    }
                }
            )

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 32)
    }
}

private struct RecordButton: View {
    let isRecording: Bool
    let progress: Double
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)

                RoundedRectangle(cornerRadius: isRecording ? 6 : 28)
                    .fill(accentColor)
                    .frame(width: isRecording ? 28 : 56, height: isRecording ? 28 : 56)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
    }
}
