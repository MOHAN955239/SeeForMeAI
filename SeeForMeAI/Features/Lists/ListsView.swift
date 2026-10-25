import SwiftUI

struct ListsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var kind: NoteListStore.Kind = .shopping
    @State private var text = ""
    @State private var amount = ""
    @State private var timerMinutes = 5

    var body: some View {
        let store = env.lists
        List {
            Section("Timers and reminders") {
                Stepper("Timer: \(timerMinutes) minutes", value: $timerMinutes, in: 1...180)
                Button("Start timer") { env.timers.start(seconds: Double(timerMinutes) * 60, label: "Timer"); Haptics.tap()
                    Announcer.say("Timer set for \(timerMinutes) minutes.") }
                ForEach(env.timers.timers) { t in
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        HStack {
                            Text("\(t.label): \(TimerService.describe(max(0, t.fireDate.timeIntervalSinceNow))) left")
                            Spacer()
                            Button("Cancel") { env.timers.cancel(t.id) }
                        }
                    }
                }
                Button("What is running?") { env.speech.speak(env.timers.remainingSummary()) }
                Text("You can also say: set a timer for 10 minutes, or remind me in 20 minutes to call home.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
            Section("Lists") {
                Picker("List", selection: $kind) { ForEach(NoteListStore.Kind.allCases) { Text($0.title).tag($0) } }
                TextField(kind == .lastSeen ? "For example: keys are on the hall table" : "Add an item", text: $text)
                if kind == .budget { TextField("Amount", text: $amount).keyboardType(.decimalPad) }
                Button("Add") {
                    store.add(kind, text: text, amount: kind == .budget ? Double(amount) : nil); text = ""; amount = ""; Haptics.tap()
                }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Read this list aloud") { env.speech.speak(store.spoken(kind)) }
                ForEach(store.items(kind)) { item in
                    HStack {
                        Text(item.text)
                        if let a = item.amount { Spacer(); Text(String(format: "%.2f", a)) }
                    }
                    .swipeActions { Button("Delete", role: .destructive) { store.delete(kind, id: item.id) } }
                    .accessibilityActions { Button("Delete") { store.delete(kind, id: item.id) } }
                }
                if kind == .budget { Text("Total: \(String(format: "%.2f", store.budgetTotal()))").font(.headline) }
                if !store.items(kind).isEmpty { Button("Clear this list", role: .destructive) { store.clear(kind) } }
            }
            Section { Text("Lists stay on this device. They are never sent to an online service.").font(.footnote).foregroundStyle(Theme.secondary) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Lists and Timers")
    }
}
