import SwiftUI

struct ToolsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var search = ""

    var body: some View {
        List {
            if search.isEmpty {
                NavigationLink(value: Route.pdf) { Label("PDF reader", systemImage: "doc.richtext").frame(minHeight: Theme.minTarget) }
            }
            ForEach(AssistantFeature.Category.allCases, id: \.self) { cat in
                let items = FeatureCatalog.features(in: cat).filter {
                    search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
                }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { f in
                            NavigationLink(value: Route.tool(f.id)) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(f.title).font(.headline)
                                        Text(f.runsLocally ? "Runs on your device" : f.engine == .barcode ? "Scans on device" : "Uses online analysis")
                                            .font(.footnote).foregroundStyle(Theme.secondary)
                                    }
                                } icon: { Image(systemName: f.symbol) }
                                .frame(minHeight: Theme.minTarget)
                            }
                            .accessibilityHint(env.settings.favoriteIDs.contains(f.id) ? "Favorite" : "")
                        }
                    } header: { Text(cat.rawValue).accessibilityAddTraits(.isHeader) }
                }
            }
        }
        .searchable(text: $search, prompt: "Search tools")
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("All Tools")
    }
}

struct ToolRunView: View {
    let featureID: String
    @Environment(AppEnvironment.self) private var env
    @State private var input = ""
    @State private var localError: AppError?

    var body: some View {
        if let f = FeatureCatalog.feature(featureID) { content(f) } else { Text("Unknown tool") }
    }

    private func content(_ f: AssistantFeature) -> some View {
        let vm = env.tools
        let fav = env.settings.favoriteIDs.contains(f.id)
        return ScrollView {
            VStack(spacing: Theme.spacing) {
                if let c = f.caution { Label(c, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.text).card() }
                if let t = f.tip { Text(t).font(.subheadline).foregroundStyle(Theme.secondary) }

                if let prompt = f.inputPrompt {
                    TextField(prompt, text: $input).textFieldStyle(.roundedBorder).font(.title3)
                        .submitLabel(.go).onSubmit { go(f) }
                        .accessibilityLabel(prompt)
                }
                if f.needsImage {
                    ImageSourceButtons(onImage: { vm.imageSelected($0, feature: f, input: input) },
                                       onError: { localError = $0 }, disabled: vm.isBusy)
                }
                if !f.needsImage || (f.inputPrompt != nil && env.session.image != nil) {
                    Button { go(f) } label: { Label(f.needsImage ? "Run on current photo" : "Run", systemImage: "play.fill") }
                        .buttonStyle(BigButtonStyle(prominent: !f.needsImage)).disabled(vm.isBusy)
                }
                if let e = localError { ErrorCard(error: e) { performRecovery($0, env: env) { localError = nil } } }

                if f.needsImage, !env.session.qualityTips.isEmpty, case .idle = vm.state {
                    ForEach(env.session.qualityTips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb").foregroundStyle(Theme.text).card()
                    }
                }

                switch vm.state {
                case .idle: EmptyView()
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large).tint(Theme.accent)
                        Text("Working on it…").foregroundStyle(Theme.text)
                        Button("Cancel") { vm.cancel() }.buttonStyle(BigButtonStyle())
                    }.card()
                case .result(let out):
                    VStack(alignment: .leading, spacing: 12) {
                        Text(out.display).font(.title3).foregroundStyle(Theme.text).textSelection(.enabled)
                        if let u = out.uncertainty { Label(u, systemImage: "questionmark.circle").font(.subheadline).foregroundStyle(Theme.secondary) }
                    }.card()
                    SpeechControls(speech: env.speech)
                    ShareLink(item: out.display) { Label("Share", systemImage: "square.and.arrow.up") }.buttonStyle(BigButtonStyle())
                    if !f.runsLocally && f.engine != .barcode {
                        Button { vm.run(f, input: input, detailed: true) } label: { Label("More detail", systemImage: "text.append") }
                            .buttonStyle(BigButtonStyle())
                    }
                    NavigationLink(value: Route.ask) { Label("Ask a follow-up", systemImage: "mic.fill") }.buttonStyle(BigButtonStyle())
                    SafetyFootnote()
                case .failed(let e):
                    ErrorCard(error: e) { performRecovery($0, env: env) { vm.retry() } }
                }
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(f.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { env.settings.toggleFavorite(f.id); Haptics.tap() } label: { Image(systemName: fav ? "star.fill" : "star") }
                    .accessibilityLabel(fav ? "Remove from favorites" : "Add to favorites")
            }
        }
        .onAppear { vm.reset(); Announcer.say("\(f.title).") }
    }

    private func go(_ f: AssistantFeature) { env.tools.run(f, input: input) }
}
