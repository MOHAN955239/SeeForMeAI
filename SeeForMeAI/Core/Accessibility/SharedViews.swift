import SwiftUI
import PhotosUI
import AVFoundation

/// Take Photo / Choose Photo controls. Reports errors instead of failing silently.
struct ImageSourceButtons: View {
    var onImage: (UIImage) -> Void
    var onError: (AppError) -> Void
    var disabled = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            Button { Task { await openCamera() } } label: { Label("Take Photo", systemImage: "camera.fill") }
                .buttonStyle(BigButtonStyle(prominent: true))
                .accessibilityHint("Opens the camera. Point at the object, sign or document, then double tap the shutter.")
            PhotosPicker(selection: $pickerItem, matching: .images) { Label("Choose Photo", systemImage: "photo.on.rectangle") }
                .buttonStyle(BigButtonStyle())
                .accessibilityHint("Pick an existing photo from your library.")
        }
        .disabled(disabled)
        .fullScreenCover(isPresented: $showCamera) { CameraPicker(onImage: onImage).ignoresSafeArea() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                defer { pickerItem = nil }
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { onImage(img) }
                else { onError(.invalidImage) }
            }
        }
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { onError(.cameraUnavailable); return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showCamera = true
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) { showCamera = true } else { onError(.cameraDenied) }
        default: onError(.cameraDenied)
        }
    }
}

struct SpeechControls: View {
    let speech: SpeechOutputService
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                switch speech.state {
                case .speaking:
                    Button { speech.pause() } label: { Label("Pause", systemImage: "pause.fill") }.buttonStyle(BigButtonStyle())
                case .paused:
                    Button { speech.resume() } label: { Label("Resume", systemImage: "play.fill") }.buttonStyle(BigButtonStyle(prominent: true))
                case .idle:
                    Button { speech.repeatLast() } label: { Label("Repeat", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(BigButtonStyle()).disabled(speech.lastSpoken.isEmpty)
                }
                Button { speech.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                    .buttonStyle(BigButtonStyle()).disabled(speech.state == .idle)
            }
            if speech.state != .idle, speech.chunkCount > 1 {
                Text("Part \(speech.chunkIndex + 1) of \(speech.chunkCount)").font(.footnote).foregroundStyle(Theme.secondary)
            }
            if speech.lastError != nil {
                Text("Premium voice unavailable, using the built-in voice.").font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }
}

struct ErrorCard: View {
    let error: AppError
    var onAction: (RecoveryAction) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Problem", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(Theme.danger)
            Text(error.message).font(.body).foregroundStyle(Theme.text)
            if error.recovery != .none {
                Button(error.recovery.title) { onAction(error.recovery) }.buttonStyle(BigButtonStyle(prominent: true))
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }
}

struct SafetyFootnote: View {
    var body: some View {
        Text("SeeForMe AI can make mistakes and is not a navigation or safety device. Keep using your cane, guide or usual orientation methods.")
            .font(.footnote).foregroundStyle(Theme.secondary)
    }
}

func performRecovery(_ action: RecoveryAction, env: AppEnvironment, retry: () -> Void) {
    switch action {
    case .retry: retry()
    case .openSystemSettings:
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    case .configureKey: env.path.append(.settings)
    case .grantConsent: env.settings.remoteAnalysisConsent = true; retry()
    case .newPhoto, .none: break
    }
}
