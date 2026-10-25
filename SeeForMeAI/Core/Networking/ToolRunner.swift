import UIKit

struct ToolOutput: Equatable {
    var spoken: String
    var display: String
    var uncertainty: String? = nil
    var caution: String? = nil
}

/// Runs any catalog feature through the right pipeline (local OCR/parsing, text-only AI, or vision AI).
@MainActor
final class ToolRunner {
    let assistant: AssistantService
    let ocr: TextRecognizing
    let session: ConversationSession
    let steps: StepReader
    let barcode: BarcodeLooking

    init(assistant: AssistantService, ocr: TextRecognizing, session: ConversationSession, steps: StepReader, barcode: BarcodeLooking = BarcodeService()) {
        self.assistant = assistant; self.ocr = ocr; self.session = session; self.steps = steps; self.barcode = barcode
    }

    func run(_ f: AssistantFeature, input: String? = nil, detailed: Bool = false) async throws -> ToolOutput {
        if f.inputPrompt != nil, (input ?? "").trimmingCharacters(in: .whitespaces).isEmpty { throw AppError.nothingFound }
        var out: ToolOutput
        switch f.engine {
        case .spell:
            out = ToolOutput(spoken: LocalTextTools.spell(input ?? ""), display: LocalTextTools.spell(input ?? ""))

        case .textOnly:
            let r = try await assistant.analyze(question: nil, detailed: detailed, instruction: f.resolvedInstruction(input: input),
                                                includeImage: false, requireContext: false)
            out = fromAI(r, detailed: detailed)

        case .vision:
            let r = try await assistant.analyze(question: nil, detailed: detailed, instruction: f.resolvedInstruction(input: input))
            out = fromAI(r, detailed: detailed)

        case .barcode:
            guard let img = session.image else { throw AppError.noContext }
            let code = try await barcode.scan(img)
            let text = await barcode.lookup(code)
            out = ToolOutput(spoken: text, display: text)

        case .readAloud:
            let r = try await readText()
            let spoken = (r.guidance.map { $0 + " " } ?? "") + r.text
            out = ToolOutput(spoken: spoken, display: r.text)

        case .parse(let p):
            let r = try await readText()
            switch p {
            case .expiry:
                let s = LocalTextTools.expiry(from: r.text) ?? "I could not find a date. Here is the text I read: \(r.text)"
                out = ToolOutput(spoken: s, display: s)
            case .receipt:
                let s = LocalTextTools.receiptSpoken(LocalTextTools.receipt(from: r.text)) ?? "I could not find amounts. Here is the text I read: \(r.text)"
                out = ToolOutput(spoken: s, display: s)
            case .price:
                let s = LocalTextTools.prices(from: r.text) ?? "I could not find a price. Here is the text I read: \(r.text)"
                out = ToolOutput(spoken: s, display: s)
            case .recipe:
                let list = LocalTextTools.recipeSteps(from: r.paragraphs)
                steps.load(list)
                let s = list.isEmpty ? "I could not find recipe steps." : "I found \(list.count) steps. \(steps.current ?? "")"
                out = ToolOutput(spoken: s, display: list.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n"))
            }

        case .textAI:
            let r = try await readText()      // OCR on device; only the text is sent to the model
            let res = try await assistant.analyze(question: nil, detailed: detailed, instruction: f.resolvedInstruction(input: input), includeImage: false)
            out = fromAI(res, detailed: detailed)
            _ = r
        }
        out.caution = f.caution
        if let c = f.caution { out.spoken += " " + c }
        return out
    }

    private func readText() async throws -> OCRResult {
        guard let img = session.image else { throw AppError.noContext }
        let r = try await ocr.recognize(img)
        session.setContextText(r.text)
        return r
    }

    private func fromAI(_ r: SceneAnalysisResult, detailed: Bool) -> ToolOutput {
        let display = [r.summary, r.detail].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return ToolOutput(spoken: detailed || !r.detail.isEmpty ? r.spokenDetailed : r.summary, display: display, uncertainty: r.uncertainty)
    }
}
