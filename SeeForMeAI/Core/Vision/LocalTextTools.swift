import Foundation
import Observation

/// Offline parsing of OCR text. Heuristics: they can misread, so callers add a caution.
enum LocalTextTools {
    private static func matches(_ pattern: String, in text: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    // MARK: Dates
    private static let datePattern = #"\b(?:\d{1,2}[\/.\-]\d{1,2}[\/.\-]\d{2,4}|\d{1,2}[\/.\-]\d{4}|(?:\d{1,2}\s?)?(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s.,\-]*(?:\d{1,2}[\s.,\-]*)?\d{2,4})\b"#

    static func expiry(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let keyword = try! NSRegularExpression(pattern: #"exp|best\s*before|use\s*by|\bbb\b|bbe"#, options: [.caseInsensitive])
        var labelled: [String] = []
        for (i, line) in lines.enumerated() {
            let range = NSRange(location: 0, length: (line as NSString).length)
            guard keyword.firstMatch(in: line, range: range) != nil else { continue }
            // look on this line and the next one
            let window = line + " " + (i + 1 < lines.count ? lines[i + 1] : "")
            labelled += matches(datePattern, in: window)
        }
        if let first = labelled.first { return "I found a date next to an expiry word: \(first)." }
        let any = matches(datePattern, in: text)
        if any.isEmpty { return nil }
        return "I found these dates, but none were next to an expiry word, so one could be a manufacturing date: \(any.prefix(3).joined(separator: ", "))."
    }

    // MARK: Money
    private static let amountPattern = #"(?:₹|Rs\.?|INR|\$|€|£)?\s?\d{1,3}(?:,\d{2,3})*\.\d{2}|(?:₹|Rs\.?|INR|\$|€|£)\s?\d+"#

    struct Receipt: Equatable { var total: String?; var items: [String] }

    static func receipt(from text: String) -> Receipt {
        var total: String?
        var items: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let l = line.lowercased()
            guard let amount = matches(amountPattern, in: line).last?.trimmingCharacters(in: .whitespaces) else { continue }
            if l.contains("grand total") || l.contains("amount due") || l.contains("net total") { total = amount }
            else if l.contains("total"), !l.contains("sub"), !l.contains("tax"), !l.contains("gst"), total == nil { total = amount }
            else if !l.contains("total"), !l.contains("tax"), !l.contains("gst"), !l.contains("change"), !l.contains("cash") {
                let name = line.replacingOccurrences(of: amount, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { items.append("\(name) \(amount)") }
            }
        }
        return Receipt(total: total, items: items)
    }

    static func receiptSpoken(_ r: Receipt) -> String? {
        guard r.total != nil || !r.items.isEmpty else { return nil }
        var parts: [String] = []
        parts.append(r.total.map { "Total: \($0)." } ?? "I could not find a total.")
        if !r.items.isEmpty { parts.append("\(r.items.count) items: " + r.items.prefix(15).joined(separator: ", ") + ".") }
        return parts.joined(separator: " ")
    }

    static func prices(from text: String) -> String? {
        let found = matches(amountPattern, in: text).map { $0.trimmingCharacters(in: .whitespaces) }
        guard !found.isEmpty else { return nil }
        return found.count == 1 ? "The price shown is \(found[0])." : "Prices shown: " + found.prefix(8).joined(separator: ", ") + "."
    }

    // MARK: Recipe steps
    static func recipeSteps(from paragraphs: [String]) -> [String] {
        var steps: [String] = []
        let marker = try! NSRegularExpression(pattern: #"(?:^|\s)(?:step\s*)?\d{1,2}[.)]\s"#, options: [.caseInsensitive])
        for p in paragraphs {
            let ns = p as NSString
            let hits = marker.matches(in: p, range: NSRange(location: 0, length: ns.length))
            if hits.count >= 2 {
                for (i, h) in hits.enumerated() {
                    let end = i + 1 < hits.count ? hits[i + 1].range.location : ns.length
                    let piece = ns.substring(with: NSRange(location: h.range.location, length: end - h.range.location))
                    steps.append(piece.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else if !p.trimmingCharacters(in: .whitespaces).isEmpty { steps.append(p.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        return steps
    }

    // MARK: Spelling
    static func spell(_ word: String) -> String {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return "" }
        return "\(w): " + w.map { String($0).uppercased() }.joined(separator: ", ") + "."
    }
}

/// Step-by-step reader for recipes and instructions (voice: next, previous, repeat).
@MainActor @Observable
final class StepReader {
    private(set) var steps: [String] = []
    private(set) var index = 0
    var isLoaded: Bool { !steps.isEmpty }

    func load(_ s: [String]) { steps = s; index = 0 }
    func clear() { steps = []; index = 0 }
    var current: String? { steps.indices.contains(index) ? "Step \(index + 1) of \(steps.count). \(steps[index])" : nil }
    func next() -> String { guard isLoaded else { return "No recipe is loaded. Use Read recipe first." }
        if index + 1 < steps.count { index += 1; return current! }
        return "That was the last step." }
    func previous() -> String { guard isLoaded else { return "No recipe is loaded. Use Read recipe first." }
        if index > 0 { index -= 1 }; return current! }
}
