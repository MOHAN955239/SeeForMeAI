import Foundation
import UIKit
import Vision

protocol TextRecognizing {
    func recognize(_ image: UIImage) async throws -> OCRResult
}

/// On-device OCR using Apple's Vision framework. No network.
struct VisionOCRService: TextRecognizing {
    func recognize(_ image: UIImage) async throws -> OCRResult {
        guard let cg = image.cgImage else { throw AppError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let lines: [OCRLine] = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
                    let out = (request.results ?? []).compactMap { obs -> OCRLine? in
                        guard let top = obs.topCandidates(1).first else { return nil }
                        return OCRLine(text: top.string, box: obs.boundingBox, confidence: top.confidence)
                    }
                    cont.resume(returning: out)
                } catch { cont.resume(throwing: AppError.invalidImage) }
            }
        }
        guard let result = OCRFormatter.format(lines) else { throw AppError.emptyOCR }
        return result
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
