import Foundation
import Observation

struct NoteItem: Codable, Identifiable, Equatable {
    var id = UUID(); var text: String; var amount: Double?; var date = Date()
}

/// User-entered lists (shopping, pantry, belongings, last-seen notes, budget). Local only, file-protected.
@MainActor @Observable
final class NoteListStore {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case shopping, pantry, belongings, lastSeen, budget
        var id: String { rawValue }
        var title: String {
            switch self { case .shopping: return "Shopping list"; case .pantry: return "Pantry"; case .belongings: return "My items"
            case .lastSeen: return "Where I left things"; case .budget: return "Spending" }
        }
    }
    private(set) var lists: [Kind: [NoteItem]] = [:]
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("lists.json")
        }()
        if let d = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode([String: [NoteItem]].self, from: d) {
            for (k, v) in decoded { if let kind = Kind(rawValue: k) { lists[kind] = v } }
        }
    }

    func items(_ k: Kind) -> [NoteItem] { lists[k] ?? [] }
    func add(_ k: Kind, text: String, amount: Double? = nil) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
        lists[k, default: []].insert(NoteItem(text: t, amount: amount), at: 0); save()
    }
    func delete(_ k: Kind, id: UUID) { lists[k]?.removeAll { $0.id == id }; save() }
    func clear(_ k: Kind) { lists[k] = []; save() }
    func clearAll() { lists = [:]; try? FileManager.default.removeItem(at: fileURL) }
    func budgetTotal() -> Double { items(.budget).compactMap(\.amount).reduce(0, +) }

    /// Finds notes mentioning a word, newest first (for "where are my keys").
    func find(_ word: String) -> [NoteItem] {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return [] }
        return (items(.lastSeen) + items(.belongings)).filter { $0.text.lowercased().contains(w) }.sorted { $0.date > $1.date }
    }

    func spoken(_ k: Kind) -> String {
        let it = items(k)
        if it.isEmpty { return "Your \(k.title.lowercased()) is empty." }
        if k == .budget {
            return "You have \(it.count) entries, totalling \(String(format: "%.2f", budgetTotal())). Latest: \(it[0].text)."
        }
        return "\(k.title): " + it.map(\.text).joined(separator: ", ") + "."
    }

    private func save() {
        let enc = Dictionary(uniqueKeysWithValues: lists.map { ($0.key.rawValue, $0.value) })
        guard let d = try? JSONEncoder().encode(enc) else { return }
        try? d.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
