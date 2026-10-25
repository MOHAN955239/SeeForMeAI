import Foundation
import UserNotifications
import Observation

struct TimerItem: Identifiable, Equatable { let id = UUID(); var label: String; var fireDate: Date }

/// In-app timers and reminders, plus a local notification so they still fire if the app is backgrounded.
@MainActor @Observable
final class TimerService {
    private(set) var timers: [TimerItem] = []
    var onFire: ((String) -> Void)?
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func start(seconds: TimeInterval, label: String) {
        guard seconds > 0 else { return }
        let item = TimerItem(label: label, fireDate: Date().addingTimeInterval(seconds))
        timers.append(item)
        schedule(item, seconds: seconds)
        tasks[item.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.fire(item) }
        }
    }

    func cancel(_ id: UUID) {
        tasks[id]?.cancel(); tasks[id] = nil
        timers.removeAll { $0.id == id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func cancelAll() { timers.map(\.id).forEach(cancel) }

    func remainingSummary() -> String {
        guard !timers.isEmpty else { return "No timers are running." }
        return timers.map { "\($0.label): \(Self.describe(max(0, $0.fireDate.timeIntervalSinceNow))) left" }.joined(separator: ". ") + "."
    }

    static func describe(_ s: TimeInterval) -> String {
        let t = Int(s.rounded()); let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if sec > 0 || parts.isEmpty { parts.append("\(sec) second\(sec == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    private func fire(_ item: TimerItem) {
        guard timers.contains(where: { $0.id == item.id }) else { return }
        timers.removeAll { $0.id == item.id }; tasks[item.id] = nil
        Haptics.success()
        onFire?("\(item.label) is done.")
    }

    private func schedule(_ item: TimerItem, seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let c = UNMutableNotificationContent(); c.title = "SeeForMe AI"; c.body = "\(item.label) is done."; c.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            center.add(UNNotificationRequest(identifier: item.id.uuidString, content: c, trigger: trigger))
        }
    }
}
