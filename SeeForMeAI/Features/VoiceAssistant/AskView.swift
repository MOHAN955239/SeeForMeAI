import SwiftUI

struct AskView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = ""
    @State private var pulse = false

    var body: some View {
        let vm = env.ask
        ScrollView {
            VStack(spacing: Theme.spacing) {
                contextCard
                Button { vm.toggleListening() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: vm.isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 64))
                            .scaleEffect(vm.isListening && pulse && !reduceMotion ? 1.08 : 1)
                        Text(vm.isListening ? "Listening… tap to finish" : "Tap to speak")
                    }
                }
                .buttonStyle(BigButtonStyle(prominent: !vm.isListening))
                .disabled(vm.state == .processing)
                .accessibilityLabel(vm.isListening ? "Stop listening" : "Ask a question by voice")
                .accessibilityHint("Starts listening only after you tap. Say for example: describe this scene, read this text, or what color is this.")
                .onChange(of: vm.isListening) { _, on in
                    if on && !reduceMotion { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true } } else { pulse = false }
                }

                statusLine(vm)
                if vm.isListening, !vm.partial.isEmpty { Text(vm.partial).foregroundStyle(Theme.secondary).card() }

                if case .failed(let e) = vm.state {
                    ErrorCard(error: e) { performRecovery($0, env: env) { vm.retryLast() } }
                }
                if let n = vm.notice { Label(n, systemImage: "info.circle").foregroundStyle(Theme.text).card() }
                if let r = vm.response {
                    VStack(alignment: .leading, spacing: 10) {
                        if !vm.transcript.isEmpty { Text("You asked: \(vm.transcript)").font(.subheadline).foregroundStyle(Theme.secondary) }
                        Text(r.summary).font(.title3).foregroundStyle(Theme.text)
                        if let u = r.uncertainty { Label(u, systemImage: "questionmark.circle").font(.subheadline).foregroundStyle(Theme.secondary) }
                    }.card().accessibilityElement(children: .combine)
                }
                SpeechControls(speech: env.speech)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Or type").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
                    TextField("Type a question or command", text: $typed).textFieldStyle(.roundedBorder).font(.title3)
                        .submitLabel(.send).onSubmit { submit(vm) }
                    Button { submit(vm) } label: { Label("Send", systemImage: "paperplane.fill") }
                        .buttonStyle(BigButtonStyle()).disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || vm.state == .processing)
                }.card()

                if env.session.hasContext || vm.response != nil {
                    Button(role: .destructive) { vm.newSession() } label: { Label("Start fresh", systemImage: "trash") }
                        .buttonStyle(BigButtonStyle())
                }
                SafetyFootnote()
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Ask a Question")
        .onAppear { Announcer.say("Question mode.") }
    }

    private var contextCard: some View {
        let s = env.session
        return VStack(alignment: .leading, spacing: 8) {
            Label(s.image != nil ? "Photo ready" : "No photo yet", systemImage: s.image != nil ? "checkmark.circle.fill" : "photo")
            if s.contextText != nil { Label("Extracted text ready", systemImage: "text.alignleft") }
            if !s.hasContext {
                NavigationLink(value: Route.scene) { Label("Take a photo first", systemImage: "camera.fill") }.buttonStyle(BigButtonStyle())
            }
        }.font(.headline).foregroundStyle(Theme.text).card()
    }

    @ViewBuilder private func statusLine(_ vm: AskViewModel) -> some View {
        switch vm.state {
        case .processing: HStack { ProgressView().tint(Theme.accent); Text("Thinking…").foregroundStyle(Theme.text) }.accessibilityElement(children: .combine)
        default:
            if env.speech.state == .speaking { Label("Speaking", systemImage: "speaker.wave.2.fill").foregroundStyle(Theme.text) }
        }
    }

    private func submit(_ vm: AskViewModel) { let t = typed; typed = ""; vm.submitTyped(t) }
}
