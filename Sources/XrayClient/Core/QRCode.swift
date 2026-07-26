import Foundation
import CoreImage

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

/// QR-code generation and decoding helpers built on CoreImage.
enum QRCode {

    /// Renders `string` into a crisp QR-code image of roughly `size` points.
    static func image(from string: String, size: CGFloat = 240) -> PlatformImage? {
        guard let cg = cgImage(from: string, size: size) else { return nil }
        #if canImport(AppKit)
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
        #else
        return UIImage(cgImage: cg)
        #endif
    }

    /// The raw CGImage behind `image(from:size:)`, handy when the caller wants
    /// the bitmap itself rather than a view-ready image.
    static func cgImage(from string: String, size: CGFloat = 240) -> CGImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        // "H" = high error correction, robust when displayed/printed small.
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        // Scale the (small) generated image up to the requested point size.
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return CIContext().createCGImage(scaled, from: scaled.extent)
    }

    /// Detects and returns the first QR-code payload found in an image, if any.
    static func decode(from image: PlatformImage) -> String? {
        #if canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let ci = CIImage(data: tiff) else { return nil }
        #else
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        #endif
        return decode(ciImage: ci)
    }

    /// Decodes a QR payload from raw image data (e.g. a dropped/opened file).
    static func decode(fileURL: URL) -> String? {
        guard let ci = CIImage(contentsOf: fileURL) else { return nil }
        return decode(ciImage: ci)
    }

    static func decode(ciImage: CIImage) -> String? {
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: context,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        for case let qr as CIQRCodeFeature in features {
            if let msg = qr.messageString, !msg.isEmpty { return msg }
        }
        return nil
    }
}
