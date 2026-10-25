import Foundation
import EventKit
import Contacts

/// Reads upcoming events only when the user asks. Nothing is stored or sent anywhere.
@MainActor
final class CalendarService {
    private let store = EKEventStore()

    func upcoming(hours: Int = 24) async throws -> [String] {
        let granted: Bool
        do { granted = try await store.requestFullAccessToEvents() } catch { throw AppError.calendarDenied }
        guard granted else { throw AppError.calendarDenied }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(Double(hours) * 3600), calendars: nil)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }.prefix(15).map { e in
            let when = Calendar.current.isDateInToday(e.startDate)
                ? e.startDate.formatted(date: .omitted, time: .shortened)
                : e.startDate.formatted(date: .abbreviated, time: .shortened)
            return e.isAllDay ? "\(e.title ?? "Event"), all day" : "\(e.title ?? "Event") at \(when)"
        }
    }
}

struct ContactMatch: Equatable { var name: String; var numbers: [String] }

struct ContactsService {
    func find(_ query: String) async throws -> [ContactMatch] {
        let store = CNContactStore()
        let granted: Bool
        do { granted = try await store.requestAccess(for: .contacts) } catch { throw AppError.contactsDenied }
        guard granted else { throw AppError.contactsDenied }
        let keys: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
        let hits = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: query), keysToFetch: keys)
        return hits.prefix(5).map {
            ContactMatch(name: CNContactFormatter.string(from: $0, style: .fullName) ?? query,
                         numbers: $0.phoneNumbers.map { $0.value.stringValue })
        }
    }

    static func spoken(_ m: [ContactMatch]) -> String {
        if m.isEmpty { return "I could not find that contact." }
        return m.map { c in
            c.numbers.isEmpty ? "\(c.name) has no phone number." : "\(c.name): " + c.numbers.prefix(2).map(spellDigits).joined(separator: ", or ") + "."
        }.joined(separator: " ")
    }
    /// Reads digits one by one so a number is easy to follow.
    static func spellDigits(_ s: String) -> String { s.filter { $0.isNumber || $0 == "+" }.map { $0 == "+" ? "plus" : String($0) }.joined(separator: " ") }
}
