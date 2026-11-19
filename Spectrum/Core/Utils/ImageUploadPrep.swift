import UIKit

/// Downscales and JPEG-compresses a picked photo so uploads stay small (and under the
/// storage buckets' 5 MB limit).
enum ImageUploadPrep {
    static func jpeg(_ data: Data, maxSide: CGFloat, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: quality)
    }
}
