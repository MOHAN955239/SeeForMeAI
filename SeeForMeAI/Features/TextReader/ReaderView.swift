import SwiftUI

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var localError: AppError?

    var body: some View {
        let vm = env.reader
        ScrollView {
            VStack(spacing: Theme.spacing) {
                ImageSourceButtons(onImage: { vm.imageSelected($0) }, onError: { localError = $0 }, disabled: vm.isBusy)
                Text("Tip: hold the page flat, fill the frame, and use good light.").font(.footnote).foregroundStyle(Theme.secondary)
                if let e = localError { ErrorCard(error: e) { performRecovery($0, env: env) { localError = nil } } }

                switch vm.state {
                case .idle: EmptyView()
                case .processing:
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(Theme.accent)
                        Text("Reading text on your device…").foregroundStyle(Theme.text)
                    }.card()
                case .result(let r):
                    if let g = r.guidance { Label(g, systemImage: "info.circle").foregroundStyle(Theme.secondary).card() }
                    SpeechControls(speech: env.speech)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(r.paragraphs.enumerated()), id: \.offset) { item in
                            Text(item.element).font(.title3).foregroundStyle(Theme.text)
                        }
                    }.card().textSelection(.enabled)
                    NavigationLink(value: Route.ask) { Label("Ask about this text", systemImage: "mic.fill") }
                        .buttonStyle(BigButtonStyle(prominent: true))
                case .failed(let e):
                    ErrorCard(error: e) { performRecovery($0, env: env) { vm.runOCR() } }
                }
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Read Text")
        .onAppear { Announcer.say("Reading mode.") }
    }
}
