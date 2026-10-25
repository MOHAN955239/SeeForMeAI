import UIKit
import Observation

@MainActor @Observable
final class SceneViewModel {
    enum State: Equatable { case idle, loading, result(SceneAnalysisResult), failed(AppError) }

    private(set) var state: State = .idle
    private(set) var showDetailed = false
    var lastError: AppError?
    private var lastRequest: (question: String?, detailed: Bool) = (nil, false)
    private var task: Task<Void, Never>?
    private let assistant: AssistantService
    private let session: ConversationSession
    private let speech: SpeechOutputService

    init(assistant: AssistantService, session: ConversationSession, speech: SpeechOutputService) {
        self.assistant = assistant; self.session = session; self.speech = speech
    }

    var isBusy: Bool { state == .loading }
    var image: UIImage? { session.image }

    func imageSelected(_ image: UIImage) {
        guard !isBusy else { return }
        do { try session.setImage(image) } catch { state = .failed(.invalidImage); return }
        state = .idle
        if let tip = session.qualityTips.first { Announcer.say(tip) }
        run(question: nil, detailed: false)
    }

    func ask(_ question: String) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        run(question: q, detailed: false)
    }

    func moreDetail() { run(question: lastRequest.question, detailed: true) }
    func retry() { run(question: lastRequest.question, detailed: lastRequest.detailed) }

    func run(question: String?, detailed: Bool) {
        guard !isBusy else { return }            // blocks accidental repeated requests
        lastRequest = (question, detailed)
        state = .loading
        speech.stop()
        Announcer.say("Analyzing. Please wait.")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let r = try await assistant.analyze(question: question, detailed: detailed)
                try Task.checkCancellation()
                showDetailed = detailed
                state = .result(r); Haptics.success()
                speech.speak(detailed ? r.spokenDetailed : r.summary)
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    func cancel() { task?.cancel(); if isBusy { state = .idle } }

    func newSession() { cancel(); speech.stop(); session.reset(); state = .idle; showDetailed = false }
}
