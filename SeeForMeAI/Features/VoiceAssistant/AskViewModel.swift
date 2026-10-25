import Foundation
import Observation

@MainActor @Observable
final class AskViewModel {
    enum State: Equatable { case idle, listening, processing, failed(AppError) }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var response: SceneAnalysisResult?
    private(set) var notice: String?
    private var task: Task<Void, Never>?
    private var lastQuestion: String?

    private let assistant: AssistantService
    private let session: ConversationSession
    private let speech: SpeechOutputService
    private let voice: VoiceInputService
    private let reader: ReaderViewModel
    private let runner: ToolRunner
    private let steps: StepReader
    private let lists: NoteListStore
    private let timers: TimerService
    private let calendar: CalendarService
    private let contacts: ContactsService

    init(assistant: AssistantService, session: ConversationSession, speech: SpeechOutputService, voice: VoiceInputService,
         reader: ReaderViewModel, runner: ToolRunner, steps: StepReader, lists: NoteListStore, timers: TimerService,
         calendar: CalendarService, contacts: ContactsService) {
        self.calendar = calendar; self.contacts = contacts
        self.assistant = assistant; self.session = session; self.speech = speech; self.voice = voice; self.reader = reader
        self.runner = runner; self.steps = steps; self.lists = lists; self.timers = timers
    }

    var isListening: Bool { voice.state == .listening }
    var partial: String { voice.partialTranscript }

    func toggleListening() {
        if voice.state == .listening { voice.stop(); Announcer.say("Stopped listening."); return }
        guard voice.state == .idle, state != .processing else { return }
        speech.stop()
        voice.localeID = assistant.settings.languageID
        Task { [weak self] in
            guard let self else { return }
            do {
                try await voice.start { [weak self] text in self?.handle(text) }
                state = .listening
                Haptics.tap(); Announcer.say("Listening.")
            } catch { state = .failed(AppError.map(error)) }
        }
    }

    func submitTyped(_ text: String) { handle(text) }

    func handle(_ text: String) {
        transcript = text; notice = nil
        if state == .listening { state = .idle }
        switch VoiceCommandParser.parse(text) {
        case .stopSpeaking: speech.stop(); state = .idle
        case .repeatLast:
            if speech.lastSpoken.isEmpty { say("There is nothing to repeat yet.") } else { speech.repeatLast() }
        case .nextStep: say(steps.next())
        case .previousStep: say(steps.previous())
        case .setTimer(let s, let label):
            timers.start(seconds: s, label: label); say("Timer set for \(TimerService.describe(s)).")
        case .remind(let s, let t):
            timers.start(seconds: s, label: "Reminder: \(t)"); say("Okay, I will remind you in \(TimerService.describe(s)).")
        case .addNote(let kind, let t, let amt):
            lists.add(kind, text: t, amount: amt); say("Added to \(kind.title.lowercased()).")
        case .readList(let kind): say(lists.spoken(kind))
        case .calendar: runAsync { [self] in
            let ev = try await calendar.upcoming()
            return ev.isEmpty ? "You have no events in the next 24 hours." : "Next 24 hours: " + ev.joined(separator: ". ") + "." }
        case .briefing: runAsync { [self] in
            var parts: [String] = []
            do {
                let ev = try await calendar.upcoming()
                parts.append(ev.isEmpty ? "No events in the next 24 hours." : "Events: " + ev.joined(separator: ". ") + ".")
            } catch { parts.append("I could not read your calendar.") }
            parts.append(timers.remainingSummary())
            let n = lists.items(.shopping).count
            parts.append(n == 0 ? "Your shopping list is empty." : "You have \(n) item\(n == 1 ? "" : "s") on your shopping list.")
            return "Your briefing. " + parts.joined(separator: " ") }
        case .findContact(let name): runAsync { [self] in ContactsService.spoken(try await contacts.find(name)) }
        case .whereIsMy(let item):
            let found = lists.find(item)
            say(found.first.map { "You noted: \($0.text)." } ?? "I don't have a note about \(item). I can't see your things unless you take a photo.")
        case .readText:
            guard session.image != nil else { state = .failed(.noContext); return }
            reader.runOCR(); notice = "Reading the text in your current photo. Open Read Text to see it."
        case .describeScene: ask(question: nil, detailed: false)
        case .explainMore: ask(question: lastQuestion, detailed: true)
        case .runFeature(let id, let input):
            guard let f = FeatureCatalog.feature(id) else { return }
            if f.needsImage, session.image == nil { state = .failed(.noContext); return }
            if f.inputPrompt != nil, (input ?? "").isEmpty { say(f.inputPrompt ?? "What do you need?"); return }
            runTool(f, input: input)
        case .question(let q): lastQuestion = q; ask(question: q, detailed: false)
        }
    }

    /// Show and speak a short local reply.
    private func say(_ s: String) {
        response = SceneAnalysisResult(summary: s, detail: "", uncertainty: nil)
        state = .idle
        speech.speak(s)
    }

    /// Runs a short async lookup and speaks its result.
    private func runAsync(_ work: @escaping () async throws -> String) {
        guard state != .processing else { return }
        state = .processing
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await work()
                try Task.checkCancellation()
                say(text); Haptics.success()
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    private func runTool(_ f: AssistantFeature, input: String?) {
        guard state != .processing else { return }
        state = .processing
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let out = try await runner.run(f, input: input)
                try Task.checkCancellation()
                response = SceneAnalysisResult(summary: out.display, detail: "", uncertainty: out.uncertainty)
                state = .idle; Haptics.success(); speech.speak(out.spoken)
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    private func ask(question: String?, detailed: Bool) {
        guard state != .processing else { return }
        state = .processing
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // Text-only questions (for example "what does serene mean") work without a photo.
                let r = try await assistant.analyze(question: question, detailed: detailed, requireContext: question == nil)
                try Task.checkCancellation()
                response = r; state = .idle; Haptics.success()
                speech.speak(detailed ? r.spokenDetailed : r.summary)
            } catch {
                let e = AppError.map(error)
                if e == .interrupted { state = .idle } else { state = .failed(e); Haptics.error(); Announcer.say(e.message) }
            }
        }
    }

    func retryLast() { if !transcript.isEmpty { handle(transcript) } }
    func clearError() { state = .idle }
    func cancel() { task?.cancel(); if state == .processing || state == .listening { state = .idle } }
    func newSession() { cancel(); voice.cancel(); speech.stop(); session.reset(); steps.clear(); response = nil; transcript = ""; notice = nil; state = .idle }
}
