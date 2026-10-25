import SwiftUI

struct SceneView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var question = ""
    @State private var localError: AppError?

    var body: some View {
        let vm = env.scene
        ScrollView {
            VStack(spacing: Theme.spacing) {
                ImageSourceButtons(onImage: { vm.imageSelected($0) }, onError: { localError = $0 }, disabled: vm.isBusy)

                if let img = vm.image {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .accessibilityLabel("Selected photo")
                }
                if let e = localError { ErrorCard(error: e) { performRecovery($0, env: env) { localError = nil } } }

                switch vm.state {
                case .idle: EmptyView()
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(Theme.accent)
                        Text("Analyzing your photo…").foregroundStyle(Theme.text)
                        Button("Cancel") { vm.cancel() }.buttonStyle(BigButtonStyle())
                    }.card().accessibilityElement(children: .contain)
                case .result(let r):
                    VStack(alignment: .leading, spacing: 12) {
                        Text(r.summary).font(.title3).foregroundStyle(Theme.text)
                        if vm.showDetailed {
                            if !r.detail.isEmpty { Text(r.detail).foregroundStyle(Theme.text) }
                            if let u = r.uncertainty { Label(u, systemImage: "questionmark.circle").foregroundStyle(Theme.secondary) }
                        } else if let u = r.uncertainty {
                            Label(u, systemImage: "questionmark.circle").font(.subheadline).foregroundStyle(Theme.secondary)
                        }
                    }.card().accessibilityElement(children: .combine)
                    if !vm.showDetailed {
                        Button { vm.moreDetail() } label: { Label("More detail", systemImage: "text.append") }
                            .buttonStyle(BigButtonStyle()).disabled(vm.isBusy)
                    }
                    SpeechControls(speech: env.speech)
                    ShareLink(item: r.spokenDetailed) { Label("Share description", systemImage: "square.and.arrow.up") }
                        .buttonStyle(BigButtonStyle())
                    followUp(vm)
                    SafetyFootnote()
                case .failed(let e):
                    ErrorCard(error: e) { performRecovery($0, env: env) { vm.retry() } }
                }

                if env.session.hasContext {
                    Button(role: .destructive) { vm.newSession() } label: { Label("Start fresh", systemImage: "trash") }
                        .buttonStyle(BigButtonStyle())
                        .accessibilityHint("Clears the current photo and conversation.")
                }
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Describe Scene")
        .onAppear { Announcer.say("Scene mode.") }
    }

    private func followUp(_ vm: SceneViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about this photo").font(.headline).foregroundStyle(Theme.text).accessibilityAddTraits(.isHeader)
            TextField("For example: what color is the cup?", text: $question)
                .textFieldStyle(.roundedBorder).font(.title3).submitLabel(.send)
                .onSubmit { send(vm) }
            Button { send(vm) } label: { Label("Ask", systemImage: "paperplane.fill") }
                .buttonStyle(BigButtonStyle(prominent: true))
                .disabled(vm.isBusy || question.trimmingCharacters(in: .whitespaces).isEmpty)
            NavigationLink(value: Route.ask) { Label("Ask by voice", systemImage: "mic.fill") }.buttonStyle(BigButtonStyle())
        }.card()
    }

    private func send(_ vm: SceneViewModel) { vm.ask(question); question = "" }
}
