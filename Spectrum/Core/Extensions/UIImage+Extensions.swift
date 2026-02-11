import UIKit
import CoreImage

extension UIImage {
    var averageColor: UIColor? {
        // 1. Try to get CIImage directly
        var inputImage = CIImage(image: self)
        
        // 2. If nil (common for UIImage(data:)), try creating from CGImage
        if inputImage == nil, let cgImage = self.cgImage {
            inputImage = CIImage(cgImage: cgImage)
        }
        
        guard let finalInputImage = inputImage else { return nil }
        
        // 3. Define the extent vector
        let extentVector = CIVector(
            x: finalInputImage.extent.origin.x,
            y: finalInputImage.extent.origin.y,
            z: finalInputImage.extent.size.width,
            w: finalInputImage.extent.size.height
        )

        // 4. Apply Area Average Filter
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: finalInputImage,
            kCIInputExtentKey: extentVector
        ]) else { return nil }
        
        guard let outputImage = filter.outputImage else { return nil }

        // 5. Render to 1x1 bitmap
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // 6. Return UIColor
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255 // Usually ignore alpha for average color, but keeping it is fine
        )
    }
}
