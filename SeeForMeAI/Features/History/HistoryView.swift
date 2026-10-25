import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmClear = false

    var body: some View {
        @Bindable var history = env.history
        List {
            Section {
                Toggle("Save recent results", isOn: $history.isEnabled)
                Text("Only short text summaries are saved on this device. Photos and audio are never saved. Nothing is saved unless this is on.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
            Section {
                if history.items.isEmpty {
                    Text(history.isEnabled ? "No results yet." : "Saving is off, so there is nothing here.").foregroundStyle(Theme.secondary)
                }
                ForEach(history.items) { item in
                    Button { env.speech.speak(item.spokenText) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.footnote).foregroundStyle(Theme.secondary)
                            Text(item.summary).font(.body).foregroundStyle(Theme.text)
                        }.frame(minHeight: Theme.minTarget, alignment: .leading)
                    }
                    .accessibilityHint("Double tap to hear this result again.")
                    .accessibilityActions { Button("Delete") { env.history.delete(id: item.id) } }
                    .swipeActions { Button("Delete", role: .destructive) { env.history.delete(id: item.id) } }
                }
            }
            if !history.items.isEmpty {
                Section {
                    SpeechControls(speech: env.speech).listRowBackground(Color.clear)
                    Button("Clear all results", role: .destructive) { confirmClear = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Recent Results")
        .confirmationDialog("Delete all saved results?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { env.history.clearAll() }
        }
    }
}
