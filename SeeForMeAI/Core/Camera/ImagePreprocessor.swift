import UIKit

enum ImagePreprocessor {
    /// Normalises orientation and downsizes so uploads are small and OCR gets upright pixels.
    static func normalized(_ image: UIImage, maxDimension: CGFloat = 1600) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func jpeg(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        normalized(image, maxDimension: maxDimension)?.jpegData(compressionQuality: quality)
    }
}
