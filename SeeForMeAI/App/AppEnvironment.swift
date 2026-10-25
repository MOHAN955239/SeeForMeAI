import SwiftUI
import Observation

@MainActor @Observable
final class AppEnvironment {
    let settings: AppSettings
    let connectivity: ConnectivityService
    let history: HistoryService
    let session: ConversationSession
    let speech: SpeechOutputService
    let voice: VoiceInputService
    let assistant: AssistantService
    let lists: NoteListStore
    let timers: TimerService
    let steps: StepReader
    let location: LocationService
    let calendar: CalendarService
    let contacts = ContactsService()
    let runner: ToolRunner
    let scene: SceneViewModel
    let reader: ReaderViewModel
    let tools: ToolViewModel
    let ask: AskViewModel
    var path: [Route] = []

    init() {
        let settings = AppSettings()
        let connectivity = ConnectivityService()
        let history = HistoryService()
        let session = ConversationSession()
        let speech = SpeechOutputService(settings: settings)
        let voice = VoiceInputService()
        let assistant = AssistantService(settings: settings, connectivity: connectivity, history: history, session: session)
        let ocr = VisionOCRService()
        let steps = StepReader()
        let lists = NoteListStore()
        let timers = TimerService()
        let runner = ToolRunner(assistant: assistant, ocr: ocr, session: session, steps: steps)
        let reader = ReaderViewModel(ocr: ocr, session: session, speech: speech, history: history)
        timers.onFire = { [weak speech] msg in speech?.speak(msg) }
        self.settings = settings; self.connectivity = connectivity; self.history = history
        self.session = session; self.speech = speech; self.voice = voice; self.assistant = assistant
        self.lists = lists; self.timers = timers; self.steps = steps; self.location = LocationService(); self.calendar = CalendarService()
        self.runner = runner; self.reader = reader
        self.scene = SceneViewModel(assistant: assistant, session: session, speech: speech)
        self.tools = ToolViewModel(runner: runner, session: session, speech: speech)
        self.ask = AskViewModel(assistant: assistant, session: session, speech: speech, voice: voice, reader: reader,
                                runner: runner, steps: steps, lists: lists, timers: timers, calendar: calendar, contacts: contacts)
    }

    func enteredBackground() {
        scene.cancel(); reader.cancel(); tools.cancel(); ask.cancel(); voice.cancel(); speech.stop()
    }

    func clearAllData() {
        history.clearAll(); lists.clearAll(); timers.cancelAll(); steps.clear(); session.reset(); speech.stop(); settings.resetKeysAndConsent()
    }
}
