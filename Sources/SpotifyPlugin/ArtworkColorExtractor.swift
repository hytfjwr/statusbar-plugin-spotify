import AppKit
import CoreImage
import SwiftUI

actor ArtworkColorExtractor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private var cache: [(key: String, color: Color)] = []
    private let maxCacheSize = 20

    func dominantColor(for image: NSImage, cacheKey: String) -> Color? {
        if let index = cache.firstIndex(where: { $0.key == cacheKey }) {
            let entry = cache.remove(at: index)
            cache.append(entry)
            return entry.color
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let scale = 50.0 / max(extent.width, extent.height)

        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaled = scaleFilter.outputImage else { return nil }

        // Boost saturation for more vivid results against dark popup background
        guard let saturationFilter = CIFilter(name: "CIColorControls") else { return nil }
        saturationFilter.setValue(scaled, forKey: kCIInputImageKey)
        saturationFilter.setValue(1.3, forKey: kCIInputSaturationKey)

        guard let saturated = saturationFilter.outputImage else { return nil }

        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return nil }
        avgFilter.setValue(saturated, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: saturated.extent), forKey: "inputExtent")

        guard let output = avgFilter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(origin: output.extent.origin, size: CGSize(width: 1, height: 1)),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        let color = Color(
            .sRGB,
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0,
            opacity: 1.0
        )

        if cache.count >= maxCacheSize {
            cache.removeFirst()
        }
        cache.append((key: cacheKey, color: color))

        return color
    }
}
