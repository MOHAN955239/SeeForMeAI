import Foundation
import AVFoundation
import Observation

@MainActor @Observable
final class SpeechOutputService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    enum State: Equatable { case idle, speaking, paused }

    private(set) var state: State = .idle
    private(set) var lastSpoken = ""
    private(set) var chunkIndex = 0
    private(set) var chunkCount = 0
    private(set) var usingElevenLabs = false
    var lastError: AppError?

    private let settings: AppSettings
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var fetchTask: Task<Void, Never>?
    private var chunks: [String] = []
    private var currentUtterance: AVSpeechUtterance?

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        let parts = TextChunker.chunks(text)
        guard !parts.isEmpty else { return }
        stop()
        lastSpoken = text
        chunks = parts; chunkCount = parts.count; chunkIndex = 0
        lastError = nil
        playCurrent()
    }

    func repeatLast() { if !lastSpoken.isEmpty { speak(lastSpoken) } }

    func pause() {
        guard state == .speaking else { return }
        if player != nil { player?.pause() } else { synth.pauseSpeaking(at: .immediate) }
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        if player != nil { player?.play() } else { synth.continueSpeaking() }
        state = .speaking
    }

    func stop() {
        fetchTask?.cancel(); fetchTask = nil
        player?.stop(); player = nil
        currentUtterance = nil
        synth.stopSpeaking(at: .immediate)
        chunks = []; chunkIndex = 0; chunkCount = 0
        state = .idle
    }

    // MARK: Playback

    private func playCurrent() {
        guard chunkIndex < chunks.count else { finish(); return }
        let text = chunks[chunkIndex]
        state = .speaking
        let key = settings.elevenLabsKey
        if settings.elevenLabsEnabled, !key.isEmpty {
            let service = ElevenLabsService(apiKey: key, voiceID: settings.elevenVoiceID, modelID: settings.elevenLabsModel)
            let index = chunkIndex
            fetchTask = Task { [weak self] in
                do {
                    let data = try await service.synthesize(text)
                    try Task.checkCancellation()
                    await MainActor.run { self?.playAudio(data, fallbackText: text, index: index) }
                } catch is CancellationError {
                } catch {
                    await MainActor.run { self?.fallBackToNative(text, error: AppError.map(error)) }
                }
            }
        } else {
            speakNative(text)
        }
    }

    private func playAudio(_ data: Data, fallbackText: String, index: Int) {
        guard state != .idle, index == chunkIndex else { return }
        do {
            try configureSession()
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            player = p; usingElevenLabs = true
            if !p.play() { throw AppError.synthesisFailed }
        } catch { fallBackToNative(fallbackText, error: .synthesisFailed) }
    }

    private func fallBackToNative(_ text: String, error: AppError) {
        guard state != .idle else { return }
        lastError = error          // surfaced as a small notice; speech continues natively
        player = nil
        speakNative(text)
    }

    private func speakNative(_ text: String) {
        do { try configureSession() } catch { lastError = .synthesisFailed }
        usingElevenLabs = false
        let u = AVSpeechUtterance(string: text)
        u.rate = Float(settings.speechRate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) + AVSpeechUtteranceMinimumSpeechRate
        u.voice = AVSpeechSynthesisVoice(language: settings.languageID)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        currentUtterance = u
        synth.speak(u)
    }

    private func configureSession() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try s.setActive(true)
    }

    private func advance() {
        player = nil; currentUtterance = nil
        guard state != .idle else { return }
        chunkIndex += 1
        if chunkIndex < chunks.count { playCurrent() } else { finish() }
    }

    private func finish() {
        state = .idle; chunks = []; chunkIndex = 0; chunkCount = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Delegates

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            if let cur = self.currentUtterance, ObjectIdentifier(cur) == id { self.advance() }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.advance() }
    }
}
