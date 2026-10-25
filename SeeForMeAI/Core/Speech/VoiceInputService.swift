import Foundation
import AVFoundation
import Speech
import Observation

/// Push-to-talk speech recognition. Records ONLY between start() and stop()/finish,
/// never longer than `maxDuration`, and prefers on-device recognition when supported.
@MainActor @Observable
final class VoiceInputService {
    enum State: Equatable { case idle, listening, finishing }

    private(set) var state: State = .idle
    private(set) var partialTranscript = ""

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var handler: (@MainActor (String) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    var localeID = "en-US"
    static let maxDuration: UInt64 = 30

    func start(onFinal: @escaping @MainActor (String) -> Void) async throws {
        guard state == .idle else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else { throw AppError.speechRecognitionUnavailable }

        let speechStatus = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { throw AppError.speechRecognitionDenied }
        guard await AVAudioApplication.requestRecordPermission() else { throw AppError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { throw AppError.speechRecognitionUnavailable }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req
        handler = onFinal
        partialTranscript = ""

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { cleanup(); throw AppError.speechRecognitionUnavailable }
        state = .listening

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.state != .idle else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal { self.deliver(); return }
                }
                if error != nil { self.deliver() }
            }
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.maxDuration * 1_000_000_000)
            await MainActor.run { if self?.state == .listening { self?.stop() } }
        }
    }

    /// Ends audio capture; the final transcript is delivered via the handler.
    func stop() {
        guard state == .listening else { return }
        state = .finishing
        stopAudio()
        request?.endAudio()
        // Safety net so the UI can never hang waiting for a final result.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { if self?.state == .finishing { self?.deliver() } }
        }
    }

    func cancel() {
        handler = nil
        task?.cancel()
        cleanup()
    }

    private func deliver() {
        let text = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = handler
        cleanup()
        if !text.isEmpty { h?(text) }
    }

    private func stopAudio() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func cleanup() {
        timeoutTask?.cancel(); timeoutTask = nil
        if engine.isRunning { stopAudio() }
        task = nil; request = nil; handler = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
