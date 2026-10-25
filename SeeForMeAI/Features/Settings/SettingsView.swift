import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var scxKey = ""
    @State private var anthropicKey = ""
    @State private var elevenKey = ""
    @State private var confirmWipe = false
    @State private var isTestingVoice = false
    @State private var testVoiceNotice = ""

    var body: some View {
        @Bindable var s = env.settings
        Form {
            Section("Track & Experience Mode") {
                Picker("Active Mode", selection: $s.appMode) {
                    ForEach(AppMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(s.appMode == .community
                     ? "Community Impact Mode: Assistive visual companion for blind and low-vision independence."
                     : "Enterprise Mode: Workplace safety audits, analog gauge inspection, asset tags, and logistics.")
                    .font(.footnote).foregroundStyle(Theme.secondary)

                Toggle("Stage Demo Mode (Fail-safe Pitch)", isOn: $s.demoMode)
                if s.demoMode {
                    Text("Demo Mode provides guaranteed instant, deterministic responses for on-stage hackathon presentations without relying on venue Wi-Fi.")
                        .font(.footnote).foregroundStyle(Theme.accent)
                }
            }

            Section("AI Vision Provider") {
                Picker("Vision Engine", selection: $s.visionProvider) {
                    ForEach(VisionProviderType.allCases) { Text($0.title).tag($0) }
                }
                Text("SCX Sovereign AI guarantees 100% Australian data residency in Sydney NSW. Apple On-Device runs fully offline on the Apple Neural Engine.")
                    .font(.footnote).foregroundStyle(Theme.secondary)

                Toggle("Allow sending photos for analysis", isOn: $s.remoteAnalysisConsent)
                Text("When on, photos are analyzed remotely via your selected provider. Apple On-Device AI never sends data outside the device even when this is off.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }

            Section("SCX Sovereign AI (Sydney, Australia)") {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Theme.accent)
                    Text("Australian Sovereign Infrastructure")
                        .font(.subheadline.bold())
                }
                SecureField(s.hasSCXKey ? "SCX API key saved. Enter to replace" : "SCX API key", text: $scxKey)
                    .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Save SCX key") {
                    s.setSCXKey(scxKey); scxKey = ""
                }.disabled(scxKey.isEmpty)

                TextField("SCX Endpoint", text: $s.scxEndpoint)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("SCX Model", text: $s.scxModel)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            }

            Section("ElevenLabs Conversational Voice AI") {
                Toggle("Use ElevenLabs natural voice", isOn: $s.elevenLabsEnabled)
                Text("Ultra-human conversational speech narration for VoiceOver and visual descriptions.")
                    .font(.footnote).foregroundStyle(Theme.secondary)

                SecureField(s.hasElevenLabsKey ? "API key saved. Enter to replace" : "ElevenLabs API key", text: $elevenKey)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Save key") {
                    s.setElevenLabsKey(elevenKey); elevenKey = ""
                }.disabled(elevenKey.isEmpty)

                Picker("Voice", selection: $s.elevenVoiceID) {
                    ForEach(ElevenVoice.all) { voice in
                        Text("\(voice.name) (\(voice.previewAccent)) - \(voice.description)").tag(voice.id)
                    }
                }

                Picker("Model", selection: $s.elevenLabsModel) {
                    Text("Turbo v2.5 (Fastest, Mobile Optimized)").tag(ElevenLabsService.turboModel)
                    Text("Multilingual v2 (Rich Expression)").tag(ElevenLabsService.multilingualModel)
                }

                Button {
                    testElevenLabsVoice()
                } label: {
                    HStack {
                        Image(systemName: isTestingVoice ? "speaker.wave.3.fill" : "play.fill")
                        Text(isTestingVoice ? "Testing voice..." : "Preview ElevenLabs Voice")
                    }
                }
                .disabled(isTestingVoice || s.elevenLabsKey.isEmpty)

                if !testVoiceNotice.isEmpty {
                    Text(testVoiceNotice).font(.footnote).foregroundStyle(Theme.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Fallback built-in voice speed")
                    Slider(value: $s.speechRate, in: 0.2...0.8).accessibilityLabel("Speech speed")
                }
            }

            Section("Anthropic Claude (Fallback)") {
                SecureField(s.hasAnthropicKey ? "Claude key saved. Enter to replace" : "Anthropic API key", text: $anthropicKey)
                    .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Save key") {
                    s.setAnthropicKey(anthropicKey); anthropicKey = ""
                }.disabled(anthropicKey.isEmpty)
                TextField("Model", text: $s.visionModel)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            }

            Section("Language and style") {
                Picker("Language", selection: $s.languageID) {
                    ForEach(AppLanguage.all) { Text($0.name).tag($0.id) }
                }
                Picker("Detail level", selection: $s.verbosity) {
                    ForEach(Verbosity.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Vibration feedback", isOn: $s.hapticsEnabled)
                TextField("Emergency number", text: $s.emergencyNumber).keyboardType(.phonePad)
            }

            Section("Accessibility") {
                Toggle("Low-vision mode (larger text)", isOn: $s.lowVisionMode)
                    .onChange(of: s.lowVisionMode) { _, on in Announcer.say(on ? "Low vision mode on." : "Low vision mode off.") }
            }

            Section("Privacy & Storage") {
                Toggle("Save recent results", isOn: Bindable(env.history).isEnabled)
                Button("Delete all saved data and keys", role: .destructive) { confirmWipe = true }
            }

            Section("Safety") {
                SafetyFootnote()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .confirmationDialog("Delete history, current photo, saved keys and consent?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { env.clearAllData() }
        }
    }

    private func testElevenLabsVoice() {
        guard !env.settings.elevenLabsKey.isEmpty else { return }
        isTestingVoice = true
        testVoiceNotice = "Synthesizing sample audio..."
        let key = env.settings.elevenLabsKey
        let voiceID = env.settings.elevenVoiceID
        Task {
            do {
                let service = ElevenLabsService(apiKey: key, voiceID: voiceID, modelID: env.settings.elevenLabsModel)
                let sampleText = "G'day! This is SeeForMe AI, testing your ElevenLabs voice configuration."
                let data = try await service.synthesize(sampleText)
                testVoiceNotice = "Playing sample audio..."
                env.speech.speak(sampleText)
                isTestingVoice = false
            } catch {
                testVoiceNotice = "Preview failed: \(error.localizedDescription). Check your ElevenLabs key."
                isTestingVoice = false
            }
        }
    }
}
