import UIKit
import Observation

/// Holds the current image / extracted text and the follow-up conversation. Memory only.
@Observable
final class ConversationSession {
    static let maxTurns = 10
    private(set) var image: UIImage?
    private(set) var imageJPEG: Data?
    private(set) var contextText: String?
    private(set) var turns: [ConversationTurn] = []
    private(set) var qualityTips: [String] = []

    var hasContext: Bool { imageJPEG != nil || !(contextText ?? "").isEmpty }

    func setImage(_ img: UIImage) throws {
        guard let jpeg = ImagePreprocessor.jpeg(img) else { throw AppError.invalidImage }
        image = img; imageJPEG = jpeg; contextText = nil; turns = []
        qualityTips = PhotoQualityChecker.analyze(img).tips
    }
    func setContextText(_ t: String) { contextText = t }

    func append(user: String, assistant: String) {
        turns.append(.init(role: .user, text: user))
        turns.append(.init(role: .assistant, text: assistant))
        if turns.count > Self.maxTurns { turns = Array(turns.suffix(Self.maxTurns)) }
    }
    func reset() { image = nil; imageJPEG = nil; contextText = nil; turns = []; qualityTips = [] }
}
