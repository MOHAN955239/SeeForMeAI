import Foundation
import Observation

/// Stores text summaries only (never images or audio), and only if the user opted in.
@MainActor @Observable
final class HistoryService {
    private(set) var items: [HistoryItem] = []
    /// Off by default. Turning it off keeps existing items until the user clears them.
    var isEnabled: Bool {
        get { access(keyPath: \.isEnabled); return defaults.bool(forKey: "historyEnabled") }
        set { withMutation(keyPath: \.isEnabled) { defaults.set(newValue, forKey: "historyEnabled") } }
    }
    static let maxItems = 50

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let defaults: UserDefaults

    init(fileURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fileURL = fileURL ?? {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("history.json")
        }()
        load()
    }

    func add(kind: HistoryItem.Kind, summary: String, spokenText: String) {
        guard isEnabled, !summary.isEmpty else { return }
        items.insert(HistoryItem(kind: kind, summary: summary, spokenText: spokenText), at: 0)
        if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
        save()
    }

    func delete(id: UUID) { items.removeAll { $0.id == id }; save() }

    func clearAll() {
        items = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
