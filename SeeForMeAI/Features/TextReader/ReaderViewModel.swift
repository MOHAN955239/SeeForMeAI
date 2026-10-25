import UIKit
import Observation

@MainActor @Observable
final class ReaderViewModel {
    enum State: Equatable { case idle, processing, result(OCRResult), failed(AppError) }

    private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private let ocr: TextRecognizing
    private let session: ConversationSession
    private let speech: SpeechOutputService
    private let history: HistoryService

    init(ocr: TextRecognizing, session: ConversationSession, speech: SpeechOutputService, history: HistoryService) {
        self.ocr = ocr; self.session = session; self.speech = speech; self.history = history
    }

    var isBusy: Bool { state == .processing }
    var image: UIImage? { session.image }

    func imageSelected(_ image: UIImage) {
        guard !isBusy else { return }
        do { try session.setImage(image) } catch { state = .failed(.invalidImage); return }
        if let tip = session.qualityTips.first { Announcer.say(tip) }
        runOCR()
    }

    /// Runs OCR on the current session image (also used by the voice command "read this text").
    func runOCR() {
        guard !isBusy else { return }
        guard let img = session.image else { state = .failed(.noContext); return }
        state = .processing
        speech.stop()
        Announcer.say("Reading text.")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await ocr.recognize(img)
                try Task.checkCancellation()
                session.setContextText(result.text)   // enables follow-up questions about the text
                history.add(kind: .text, summary: String(result.text.prefix(140)), spokenText: result.text)
                state = .result(result); Haptics.success()
                speech.speak((result.guidance.map { $0 + " " } ?? "") + result.text)
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    func cancel() { task?.cancel(); if isBusy { state = .idle } }
}
