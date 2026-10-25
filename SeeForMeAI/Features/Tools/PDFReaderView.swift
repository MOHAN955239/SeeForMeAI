import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Reads the text layer of a PDF on the device. Scanned PDFs without a text layer are not OCR'd here.
struct PDFReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showImporter = false
    @State private var text: String?
    @State private var error: AppError?
    static let maxChars = 60_000

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                Button { showImporter = true } label: { Label("Choose a PDF", systemImage: "doc.badge.plus") }
                    .buttonStyle(BigButtonStyle(prominent: true))
                    .accessibilityHint("Opens the Files picker.")
                if let e = error { ErrorCard(error: e) { performRecovery($0, env: env) { showImporter = true } } }
                if let t = text {
                    SpeechControls(speech: env.speech)
                    Text(t.prefix(6000)).font(.title3).foregroundStyle(Theme.text).card().textSelection(.enabled)
                    if t.count > 6000 { Text("Showing the first part on screen. The whole text is read aloud.").font(.footnote).foregroundStyle(Theme.secondary) }
                    NavigationLink(value: Route.ask) { Label("Ask about this PDF", systemImage: "mic.fill") }.buttonStyle(BigButtonStyle())
                }
            }.padding(Theme.spacing)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("PDF Reader")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .failure: error = .invalidImage
            case .success(let url): load(url)
            }
        }
    }

    private func load(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { error = .invalidImage; return }
        let full = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else {
            error = .unknown("This PDF has no readable text, so it may be a scan. Photograph its pages with Read Text instead.")
            text = nil; return
        }
        error = nil
        let t = String(full.prefix(Self.maxChars))
        text = t
        env.session.reset()
        env.session.setContextText(String(t.prefix(8000)))   // lets you ask follow-ups (text only)
        Haptics.success()
        env.speech.speak(t)
    }
}
