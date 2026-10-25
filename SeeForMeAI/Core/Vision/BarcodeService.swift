import Foundation
import UIKit
import Vision

protocol BarcodeLooking {
    func scan(_ image: UIImage) async throws -> String
    func lookup(_ code: String) async -> String
}

/// Barcode detection is on-device (Vision). Only the digits are sent to the public Open Food Facts API.
struct BarcodeService: BarcodeLooking {
    var session: URLSession = .shared

    func scan(_ image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw AppError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNDetectBarcodesRequest()
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req])
                    if let code = req.results?.compactMap({ $0.payloadStringValue }).first { cont.resume(returning: code) }
                    else { cont.resume(throwing: AppError.nothingFound) }
                } catch { cont.resume(throwing: AppError.invalidImage) }
            }
        }
    }

    struct Product: Decodable { let product_name: String?; let brands: String?; let quantity: String? }
    struct Response: Decodable { let status: Int?; let product: Product? }

    static func spoken(code: String, response: Response?) -> String {
        guard let p = response?.product, response?.status == 1,
              let name = p.product_name, !name.isEmpty else {
            return "I read barcode \(code), but it is not in the public product database."
        }
        var s = "Barcode \(code): \(name)"
        if let b = p.brands, !b.isEmpty { s += ", by \(b)" }
        if let q = p.quantity, !q.isEmpty { s += ", \(q)" }
        return s + ". This comes from a community database and may be wrong."
    }

    func lookup(_ code: String) async -> String {
        guard code.allSatisfy(\.isNumber),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,brands,quantity") else {
            return "I read a code, but it is not a standard product barcode."
        }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue("SeeForMeAI-iOS/0.1 (accessibility app)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else {
            return "I read barcode \(code), but could not reach the product database."
        }
        return Self.spoken(code: code, response: try? JSONDecoder().decode(Response.self, from: data))
    }
}
