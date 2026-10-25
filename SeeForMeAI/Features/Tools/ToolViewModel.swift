import UIKit
import Observation

@MainActor @Observable
final class ToolViewModel {
    enum State: Equatable { case idle, loading, result(ToolOutput), failed(AppError) }
    private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private var last: (AssistantFeature, String?, Bool)?
    private let runner: ToolRunner
    private let session: ConversationSession
    private let speech: SpeechOutputService

    init(runner: ToolRunner, session: ConversationSession, speech: SpeechOutputService) {
        self.runner = runner; self.session = session; self.speech = speech
    }
    var isBusy: Bool { state == .loading }

    func reset() { cancel(); state = .idle }

    func imageSelected(_ image: UIImage, feature f: AssistantFeature, input: String) {
        guard !isBusy else { return }
        do { try session.setImage(image) } catch { state = .failed(.invalidImage); return }
        if let tip = session.qualityTips.first { Announcer.say(tip) }
        if f.inputPrompt != nil, input.trimmingCharacters(in: .whitespaces).isEmpty {
            Announcer.say("Photo ready. Type what you are looking for, then tap Run."); return
        }
        run(f, input: input)
    }

    func run(_ f: AssistantFeature, input: String?, detailed: Bool = false) {
        guard !isBusy else { return }
        last = (f, input, detailed)
        state = .loading; speech.stop()
        Announcer.say("Working on it.")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let out = try await runner.run(f, input: input, detailed: detailed)
                try Task.checkCancellation()
                state = .result(out); Haptics.success(); speech.speak(out.spoken)
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    func retry() { if let l = last { run(l.0, input: l.1, detailed: l.2) } }
    func cancel() { task?.cancel(); if isBusy { state = .idle } }
}
