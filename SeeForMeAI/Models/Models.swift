import Foundation
import CoreGraphics

struct ConversationTurn: Codable, Equatable {
    enum Role: String, Codable { case user, assistant }
    var role: Role
    var text: String
}

struct SceneAnalysisResult: Equatable {
    var summary: String
    var detail: String
    var uncertainty: String?

    var spokenDetailed: String {
        [summary, detail, uncertainty].compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct AnalysisRequest: Equatable {
    var imageJPEG: Data?
    var contextText: String?
    var question: String?
    var history: [ConversationTurn]
    var detailed: Bool
    var instruction: String? = nil   // task preset (for example "read the price tag")
    var style: String? = nil         // verbosity and reply language
}

protocol SceneAnalysisProviding {
    func analyze(_ request: AnalysisRequest) async throws -> SceneAnalysisResult
}

struct OCRLine: Equatable {
    var text: String
    var box: CGRect          // Vision-normalised, origin bottom-left
    var confidence: Float
}

struct OCRResult: Equatable {
    var text: String
    var paragraphs: [String]
    var confidence: Double
    var guidance: String?
}

struct HistoryItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case scene, text, question }
    var id = UUID()
    var date = Date()
    var kind: Kind
    var summary: String
    var spokenText: String
}

enum Route: Hashable { case scene, reader, ask, history, settings, tools, tool(String), lists, around, safety, pdf }
