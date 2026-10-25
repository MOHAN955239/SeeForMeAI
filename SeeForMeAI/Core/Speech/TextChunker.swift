import Foundation

enum TextChunker {
    /// Splits text into paragraph-sized pieces, then sentence groups, so playback is manageable.
    static func chunks(_ text: String, maxLength: Int = 320) -> [String] {
        let paras = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var out: [String] = []
        for p in paras {
            if p.count <= maxLength { out.append(p); continue }
            var cur = ""
            p.enumerateSubstrings(in: p.startIndex..., options: .bySentences) { s, _, _, _ in
                guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return }
                if cur.isEmpty { cur = s }
                else if cur.count + s.count + 1 <= maxLength { cur += " " + s }
                else { out.append(cur); cur = s }
            }
            if !cur.isEmpty { out.append(cur) }
        }
        return out
    }
}
