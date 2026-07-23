import SwiftUI
import UIKit

/// Dominant-colour extraction for artwork.
///
/// The old approach averaged every pixel and then snapped the result onto a fixed
/// eight-colour palette. For a mostly-white artwork the average is a pale grey, and the
/// nearest palette entry to pale grey happened to be a purple — which is why desaturated
/// covers always ended up with a magenta glow. Here we look for a genuinely vibrant
/// colour instead, and when the artwork simply doesn't have one we return a neutral tone
/// derived from the artwork itself rather than falling back to a fixed accent.
struct ArtworkColor: Sendable {
    /// Colour to tint glows, buttons and shadows with.
    let accent: Color
    /// True when the artwork had no vibrant colour and `accent` is a neutral tone.
    let isNeutral: Bool

    /// Used before any artwork has loaded.
    static let placeholder = ArtworkColor(accent: Color(white: 0.55), isNeutral: true)
}

extension UIImage {
    /// Picks the most vibrant colour in the image, falling back to a neutral tone that
    /// matches the artwork's own luminance when nothing vibrant exists.
    func dominantArtworkColor() -> ArtworkColor {
        // Downscale hard — we only need colour distribution, not detail. 32x32 keeps this
        // well under a millisecond even on older devices.
        let side = 32
        guard let cgImage = downscaledCGImage(to: side) else { return .placeholder }

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .placeholder }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Bucket by hue (24 buckets = 15° each) and score each bucket by how vibrant it is.
        // Scoring by total rather than peak means a large field of medium-saturation colour
        // beats a handful of stray vivid pixels.
        let bucketCount = 24
        var scores = [Double](repeating: 0, count: bucketCount)
        var sumHueX = [Double](repeating: 0, count: bucketCount)
        var sumHueY = [Double](repeating: 0, count: bucketCount)
        var sumSat = [Double](repeating: 0, count: bucketCount)
        var sumBright = [Double](repeating: 0, count: bucketCount)

        var luminanceTotal = 0.0
        var sampleCount = 0.0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.35 else { continue }

            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255

            luminanceTotal += 0.299 * red + 0.587 * green + 0.114 * blue
            sampleCount += 1

            let (hue, saturation, brightness) = Self.rgbToHSB(red: red, green: green, blue: blue)

            // Ignore near-black and blown-out pixels: they carry no usable hue and would
            // otherwise dominate covers that are mostly shadow or mostly paper-white.
            guard brightness > 0.18, brightness < 0.97, saturation > 0.22 else { continue }

            // Favour saturated, mid-to-bright pixels.
            let score = saturation * saturation * brightness
            let bucket = min(bucketCount - 1, Int(hue * Double(bucketCount)))

            // Accumulate hue on the unit circle so the 359°/0° wraparound averages correctly.
            let radians = hue * 2 * .pi
            sumHueX[bucket] += cos(radians) * score
            sumHueY[bucket] += sin(radians) * score
            sumSat[bucket] += saturation * score
            sumBright[bucket] += brightness * score
            scores[bucket] += score
        }

        let totalPixels = Double(side * side)
        guard sampleCount > 0 else { return .placeholder }

        let bestBucket = scores.indices.max { scores[$0] < scores[$1] } ?? 0
        let bestScore = scores[bestBucket]

        // Require the winning hue to cover a meaningful share of the artwork. Below this the
        // cover is effectively monochrome and a coloured glow would be invented, not derived.
        let vibrancyThreshold = totalPixels * 0.02
        guard bestScore > vibrancyThreshold else {
            let averageLuminance = luminanceTotal / sampleCount
            return ArtworkColor(accent: Self.neutralAccent(luminance: averageLuminance), isNeutral: true)
        }

        var hue = atan2(sumHueY[bestBucket], sumHueX[bestBucket]) / (2 * .pi)
        if hue < 0 { hue += 1 }

        // Lift saturation and clamp brightness so the accent reads clearly against the
        // app's black background without becoming neon.
        let saturation = min(1.0, max(0.55, sumSat[bestBucket] / bestScore))
        let brightness = min(0.98, max(0.62, sumBright[bestBucket] / bestScore))

        let accent = Color(hue: hue, saturation: saturation, brightness: brightness)
        return ArtworkColor(accent: accent, isNeutral: false)
    }

    /// Neutral tone for monochrome artwork: a light warm grey for bright covers, a cooler
    /// dim grey for dark ones. Never a hue the artwork doesn't contain.
    private static func neutralAccent(luminance: Double) -> Color {
        let level = min(0.82, max(0.42, luminance * 0.85 + 0.28))
        return Color(hue: 0.6, saturation: 0.05, brightness: level)
    }

    private func downscaledCGImage(to side: Int) -> CGImage? {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    private static func rgbToHSB(red: Double, green: Double, blue: Double) -> (Double, Double, Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }

        let saturation = maxValue == 0 ? 0 : delta / maxValue
        return (hue, saturation, maxValue)
    }
}

/// Loads artwork and extracts its accent colour, caching results so revisiting a screen
/// (or scrolling a feed) never re-downloads or re-analyses the same image.
///
/// Deliberately an `actor`, not `@MainActor`: image decoding and the pixel scan are heavy
/// enough that running them on the main thread froze the UI while a feed or profile grid
/// loaded. As an actor this work runs on a background executor and only the finished colour
/// crosses back to the caller.
actor ArtworkColorLoader {
    static let shared = ArtworkColorLoader()

    private var cache: [URL: ArtworkColor] = [:]
    private var inFlight: [URL: Task<ArtworkColor, Never>] = [:]

    private init() {}

    func color(for url: URL?) async -> ArtworkColor {
        guard let url else { return .placeholder }

        if let cached = cache[url] { return cached }
        if let existing = inFlight[url] { return await existing.value }

        let task = Task<ArtworkColor, Never>.detached(priority: .utility) {
            // Goes through the shared URLCache, so the artwork the UI is already showing
            // is usually served from disk rather than refetched.
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else {
                return ArtworkColor.placeholder
            }
            return image.dominantArtworkColor()
        }

        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        cache[url] = result
        return result
    }
}
