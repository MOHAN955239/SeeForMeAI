import UIKit

/// Cheap heuristic coach: darkness, glare and blur. Thresholds are untuned guesses; tune on real photos.
enum PhotoQualityChecker {
    struct Report: Equatable { var tips: [String]; var isGood: Bool { tips.isEmpty } }

    static func analyze(gray: [UInt8], width: Int, height: Int) -> Report {
        guard width > 2, height > 2, gray.count >= width * height else { return Report(tips: []) }
        let mean = Double(gray.reduce(0) { $0 + Int($1) }) / Double(gray.count)
        var tips: [String] = []
        if mean < 45 { tips.append("The photo looks very dark. Turn on a light or move somewhere brighter, then try again.") }
        else if mean > 220 { tips.append("The photo looks very bright or has glare. Tilt the page or move away from the light, then try again.") }

        // Laplacian variance as a blur measure.
        var sum = 0.0, sumSq = 0.0, n = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let lap = 4 * Int(gray[i]) - Int(gray[i - 1]) - Int(gray[i + 1]) - Int(gray[i - width]) - Int(gray[i + width])
                let v = Double(lap); sum += v; sumSq += v * v; n += 1
            }
        }
        let variance = sumSq / n - (sum / n) * (sum / n)
        if variance < 25 && mean >= 45 { tips.append("The photo may be blurry. Hold the phone steady for a moment, or move a little farther back, then try again.") }
        return Report(tips: tips)
    }

    static func analyze(_ image: UIImage, side: Int = 192) -> Report {
        guard let cg = image.cgImage else { return Report(tips: []) }
        var pixels = [UInt8](repeating: 0, count: side * side)
        let space = CGColorSpaceCreateDeviceGray()
        let ok: Bool = pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return ok ? analyze(gray: pixels, width: side, height: side) : Report(tips: [])
    }
}
