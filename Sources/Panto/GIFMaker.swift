import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum GIFMaker {
    enum GIFError: LocalizedError {
        case noVideo
        case destination
        case failed

        var errorDescription: String? {
            switch self {
            case .noVideo: return "No video track."
            case .destination: return "Could not create the GIF."
            case .failed: return "Could not finish the GIF."
            }
        }
    }

    static func make(
        input: URL,
        output: URL,
        start: Double = 0,
        duration: Double = 6,
        fps: Double = 15,
        maxWidth: CGFloat = 960
    ) async throws {
        let asset = AVURLAsset(url: input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFError.noVideo
        }
        let natural = try await track.load(.naturalSize)
        let scale = min(1, maxWidth / max(natural.width, 1))
        let size = CGSize(width: (natural.width * scale).rounded(), height: (natural.height * scale).rounded())

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)

        let count = max(1, Int(duration * fps))
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.gif.identifier as CFString,
            count,
            nil
        ) else {
            throw GIFError.destination
        }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)

        let frameProperties = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / fps]
        ] as CFDictionary

        for frame in 0..<count {
            let time = start + Double(frame) / fps
            guard let image = try? generator.copyCGImage(
                at: CMTime(seconds: time, preferredTimescale: 600),
                actualTime: nil
            ) else { continue }
            let scaled = resize(image, to: size) ?? image
            CGImageDestinationAddImage(destination, scaled, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFError.failed
        }
    }

    private static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
