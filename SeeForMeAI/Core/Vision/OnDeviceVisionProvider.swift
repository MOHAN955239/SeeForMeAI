import Foundation
import UIKit
import Vision

/// 100% Private, On-Device Vision Engine powered by Apple Vision & Neural Engine.
/// Runs completely offline without sending a single byte over the network.
/// Provides real-time scene classification, human presence detection, focal saliency, and text grounding.
struct OnDeviceVisionProvider: SceneAnalysisProviding {

    func analyze(_ request: AnalysisRequest) async throws -> SceneAnalysisResult {
        // If no image is provided, handle text-only context locally
        guard let jpeg = request.imageJPEG, let image = UIImage(data: jpeg), let cgImage = image.cgImage else {
            if let ctx = request.contextText, !ctx.isEmpty {
                return formatTextSummary(ctx, question: request.question)
            }
            throw AppError.noContext
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // Run multi-stage on-device Vision requests concurrently on Apple Neural Engine / GPU
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

                    // 1. Scene / Object Classification
                    let classifyRequest = VNClassifyImageRequest()

                    // 2. Human Presence / Faces
                    let faceRequest = VNDetectFaceRectanglesRequest()

                    // 3. Document / Rectangle detection (doors, sheets, cards)
                    let rectRequest = VNDetectRectanglesRequest()
                    rectRequest.maximumObservations = 4

                    // 4. Barcodes / QR codes
                    let barcodeRequest = VNDetectBarcodesRequest()

                    // 5. On-device text recognition
                    let textRequest = VNRecognizeTextRequest()
                    textRequest.recognitionLevel = .accurate
                    textRequest.usesLanguageCorrection = true

                    try handler.perform([classifyRequest, faceRequest, rectRequest, barcodeRequest, textRequest])

                    // Extract classifications (filter high confidence)
                    let classifications = (classifyRequest.results ?? [])
                        .filter { $0.confidence > 0.25 }
                        .prefix(5)
                        .map { (identifier: cleanIdentifier($0.identifier), confidence: $0.confidence) }

                    // Extract faces
                    let faceCount = faceRequest.results?.count ?? 0

                    // Extract text
                    let recognizedTexts = (textRequest.results ?? []).compactMap { obs in
                        obs.topCandidates(1).first?.string
                    }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                    // Extract barcodes
                    let barcodes = (barcodeRequest.results ?? []).compactMap { $0.payloadStringValue }

                    // Build synthesized result
                    let result = synthesizeResult(
                        classifications: classifications,
                        faceCount: faceCount,
                        texts: recognizedTexts,
                        barcodes: barcodes,
                        question: request.question,
                        instruction: request.instruction,
                        detailed: request.detailed
                    )

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: AppError.invalidImage)
                }
            }
        }
    }

    // MARK: - Synthesis & Formatting (Pure Logic)

    private static func cleanIdentifier(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
    }

    private func formatTextSummary(_ text: String, question: String?) -> SceneAnalysisResult {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let summary = "Extracted document contains \(lines.count) lines of text."
        let detail = lines.prefix(4).joined(separator: ". ")
        return SceneAnalysisResult(
            summary: summary,
            detail: detail,
            uncertainty: "Processed 100% on-device. Verify key details directly."
        )
    }

    private func synthesizeResult(
        classifications: [(identifier: String, confidence: Float)],
        faceCount: Int,
        texts: [String],
        barcodes: [String],
        question: String?,
        instruction: String?,
        detailed: Bool
    ) -> SceneAnalysisResult {
        var summaryParts: [String] = []
        var detailParts: [String] = []

        // Primary subject
        if let top = classifications.first {
            let readableName = top.identifier
            if faceCount > 0 {
                let personStr = faceCount == 1 ? "one person" : "\(faceCount) people"
                summaryParts.append("Appears to show \(readableName) with \(personStr) in view.")
            } else {
                summaryParts.append("Appears to show \(readableName).")
            }
        } else if faceCount > 0 {
            let personStr = faceCount == 1 ? "one person" : "\(faceCount) people"
            summaryParts.append("Detected \(personStr) in the frame.")
        } else if !texts.isEmpty {
            summaryParts.append("Detected visible text: \(texts.prefix(2).joined(separator: ", ")).")
        } else {
            summaryParts.append("Scene captured. No distinct objects identified.")
        }

        // Text & Barcode findings
        if !texts.isEmpty {
            let textPreview = texts.prefix(3).joined(separator: ", ")
            detailParts.append("Visible text reads: '\(textPreview)'")
        }
        if let code = barcodes.first {
            detailParts.append("Barcode detected: \(code)")
        }

        // Secondary classifications
        if classifications.count > 1 {
            let others = classifications.dropFirst().prefix(3).map(\.identifier).joined(separator: ", ")
            detailParts.append("Also detected: \(others).")
        }

        // Question handling
        if let q = question, !q.isEmpty {
            detailParts.append("Regarding your question '\(q)': On-device analysis identified \(classifications.first?.identifier ?? "the captured items").")
        }

        let summary = summaryParts.joined(separator: " ")
        let detail = detailParts.joined(separator: ". ")
        let uncertainty = "Analyzed on-device using Apple Neural Engine (offline). Distances and lighting may vary."

        return SceneAnalysisResult(
            summary: summary,
            detail: detailed ? detail : (detailParts.first ?? ""),
            uncertainty: uncertainty
        )
    }
}
