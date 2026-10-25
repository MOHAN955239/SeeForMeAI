import Foundation

enum VoiceCommand: Equatable {
    case describeScene
    case explainMore
    case readText
    case repeatLast
    case stopSpeaking
    case nextStep, previousStep
    case setTimer(seconds: TimeInterval, label: String)
    case remind(seconds: TimeInterval, text: String)
    case addNote(NoteListStore.Kind, text: String, amount: Double?)
    case readList(NoteListStore.Kind)
    case whereIsMy(String)
    case calendar, briefing
    case findContact(String)
    case runFeature(id: String, input: String?)
    case question(String)
}

enum VoiceCommandParser {
    private static let numberWords: [String: Double] = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "ten": 10, "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "sixty": 60]
    private static let listWords: [String: NoteListStore.Kind] = ["shopping": .shopping, "grocery": .shopping, "pantry": .pantry,
        "belongings": .belongings, "inventory": .belongings, "items": .belongings]

    private static func groups(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) else { return nil }
        return (1..<m.numberOfRanges).map { i in
            let r = m.range(at: i); return r.location == NSNotFound ? "" : (text as NSString).substring(with: r)
        }
    }
    private static func seconds(_ amount: String, _ unit: String) -> TimeInterval? {
        guard let n = Double(amount) ?? numberWords[amount.lowercased()] else { return nil }
        let u = unit.lowercased()
        if u.hasPrefix("h") { return n * 3600 }
        if u.hasPrefix("m") { return n * 60 }
        return n
    }

    static func parse(_ raw: String) -> VoiceCommand {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if text == "stop" || has("stop speaking", "stop talking", "stop reading", "be quiet", "be silent") { return .stopSpeaking }
        if has("next step", "next instruction") { return .nextStep }
        if has("previous step", "step back", "go back a step") { return .previousStep }
        if has("repeat", "say that again", "say it again") { return .repeatLast }

        if let g = groups(#"(?:set|start)(?: a| an)? timer (?:for )?(\d+(?:\.\d+)?|a|an|one|two|three|four|five|six|ten|fifteen|twenty|thirty|forty|sixty) ?(seconds?|secs?|minutes?|mins?|hours?)"#, in: text),
           let s = seconds(g[0], g[1]) { return .setTimer(seconds: s, label: "Timer") }
        if let g = groups(#"remind me in (\d+|a|an|one|two|three|five|ten|fifteen|twenty|thirty) ?(seconds?|minutes?|mins?|hours?) to (.+)"#, in: text),
           let s = seconds(g[0], g[1]) { return .remind(seconds: s, text: g[2]) }

        if has("daily briefing", "my briefing", "morning briefing") { return .briefing }
        if has("my calendar", "my schedule", "my appointments", "my events", "upcoming events") { return .calendar }
        if let g = groups(#"(?:find contact|phone number (?:for|of)|number for|contact for|look up contact) (.+)"#, in: text) { return .findContact(g[0]) }

        if let g = groups(#"(?:read|what(?:'s| is) on)(?: out)?(?: my| the)? (shopping|grocery|pantry|belongings|inventory) list"#, in: text),
           let k = listWords[g[0]] { return .readList(k) }
        if let g = groups(#"add (.+?) to (?:my |the )?(shopping|grocery|pantry|belongings|inventory) list"#, in: text),
           let k = listWords[g[1]] { return .addNote(k, text: g[0], amount: nil) }
        if let g = groups(#"i (?:spent|paid) (?:rs\.?|₹|\$)? ?(\d+(?:\.\d+)?) (?:on|for) (.+)"#, in: text), let amt = Double(g[0]) {
            return .addNote(.budget, text: g[1], amount: amt)
        }
        if groups(#"^i (?:left|put|kept|placed|parked) my "#, in: text) != nil { return .addNote(.lastSeen, text: original, amount: nil) }
        if let g = groups(#"where (?:are|is|did i (?:leave|put)) my (.+)"#, in: text) { return .whereIsMy(g[0]) }

        // Catalog phrases. For features that need input, the input is whatever follows the phrase.
        var best: (feature: AssistantFeature, phrase: String)?
        for f in FeatureCatalog.all {
            for ph in f.phrases where text.contains(ph) {
                if best == nil || ph.count > best!.phrase.count { best = (f, ph) }
            }
        }
        if let (f, ph) = best {
            var input: String?
            if f.inputPrompt != nil, let r = text.range(of: ph) {
                var rest = String(text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                for lead in ["my ", "the ", "a ", "an "] where rest.hasPrefix(lead) { rest = String(rest.dropFirst(lead.count)) }
                input = rest.isEmpty ? nil : rest
            }
            return .runFeature(id: f.id, input: input)
        }
        if has("more detail", "in detail", "explain more", "tell me more") { return .explainMore }
        if has("read this", "read the text", "read text", "read it", "read aloud", "read out") { return .readText }
        if has("describe", "what is in front", "what's in front", "what do you see", "what am i looking at") { return .describeScene }

        return .question(original)
    }
}
