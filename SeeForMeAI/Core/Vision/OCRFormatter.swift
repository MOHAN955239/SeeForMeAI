import Foundation
import CoreGraphics

/// Pure reading-order and paragraph logic, separated from Vision so it can be unit tested.
enum OCRFormatter {
    static func format(_ lines: [OCRLine]) -> OCRResult? {
        let cleaned = lines.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cleaned.isEmpty else { return nil }

        let heights = cleaned.map { $0.box.height }.sorted()
        let medianH = max(heights[heights.count / 2], 0.005)

        // Top-to-bottom (Vision origin is bottom-left, so larger midY = higher on page).
        let byTop = cleaned.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRLine]] = []
        for line in byTop {
            if var last = rows.last, let ref = last.first, abs(ref.box.midY - line.box.midY) < medianH * 0.6 {
                last.append(line); rows[rows.count - 1] = last
            } else { rows.append([line]) }
        }
        rows = rows.map { $0.sorted { $0.box.minX < $1.box.minX } }

        var paragraphs: [String] = []
        var current: [String] = []
        var prevMinY: CGFloat?
        for row in rows {
            let text = row.map(\.text).joined(separator: " ")
            let topY = row.map { $0.box.maxY }.max() ?? 0
            if let p = prevMinY, (p - topY) > medianH * 1.5, !current.isEmpty {
                paragraphs.append(current.joined(separator: " ")); current = []
            }
            current.append(text)
            prevMinY = row.map { $0.box.minY }.min()
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }

        let conf = Double(cleaned.map(\.confidence).reduce(0, +)) / Double(cleaned.count)
        var guidance: String?
        if conf < 0.5 {
            guidance = "The text was hard to read, so this may contain mistakes. Try better light, hold the phone steady, and fill the frame with the page."
        }
        return OCRResult(text: paragraphs.joined(separator: "\n\n"), paragraphs: paragraphs, confidence: conf, guidance: guidance)
    }
}
