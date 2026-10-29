import AppKit
import AVFoundation

/// Builds a synthetic "screen recording" so the zoom pipeline can be tested
/// (and demoed) without screen-recording permissions.
enum SyntheticVideo {
    static func make(url: URL, seconds: Double, size: CGSize) throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 12_000_000
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw NSError(domain: "Panto", code: 1, userInfo: [NSLocalizedDescriptionKey: "synthetic writer failed"])
        }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frames = Int(seconds * Double(fps))
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }
            guard let pool = adaptor.pixelBufferPool else { continue }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixelBuffer = buffer else { continue }
            draw(frame: frame, frames: frames, into: pixelBuffer, size: size)
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "Panto", code: 2, userInfo: [NSLocalizedDescriptionKey: "synthetic writer failed"])
        }
    }

    private static func draw(frame: Int, frames: Int, into buffer: CVPixelBuffer, size: CGSize) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: base,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return }

        // CVPixelBuffer row 0 is the top row; flip once so the flipped AppKit
        // coordinate system (y down) lines up with the encoded frame.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics

        let canvas = NSRect(origin: .zero, size: size)
        NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.95, alpha: 1).setFill()
        canvas.fill()

        // Browser window.
        let window = NSRect(x: 60, y: 46, width: size.width - 120, height: size.height - 92)
        let windowPath = NSBezierPath(roundedRect: window, xRadius: 16, yRadius: 16)
        NSColor.white.setFill()
        windowPath.fill()

        let chrome = NSRect(x: window.minX, y: window.minY, width: window.width, height: 46)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        let chromePath = NSBezierPath(roundedRect: chrome, xRadius: 16, yRadius: 16)
        chromePath.fill()
        NSRect(x: chrome.minX, y: chrome.maxY - 16, width: chrome.width, height: 16).fill()

        for (index, color) in [NSColor(calibratedRed: 1, green: 0.37, blue: 0.34, alpha: 1),
                               NSColor(calibratedRed: 1, green: 0.74, blue: 0.18, alpha: 1),
                               NSColor(calibratedRed: 0.26, green: 0.79, blue: 0.34, alpha: 1)].enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: chrome.minX + 18 + CGFloat(index) * 22,
                y: chrome.minY + 16,
                width: 12, height: 12
            )).fill()
        }

        let urlPill = NSRect(x: chrome.midX - 170, y: chrome.minY + 11, width: 340, height: 24)
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: urlPill, xRadius: 12, yRadius: 12).fill()
        drawText("panto.app", at: NSPoint(x: urlPill.midX - 30, y: urlPill.minY + 5), size: 13, weight: .medium, color: NSColor(calibratedWhite: 0.45, alpha: 1))

        // Nav.
        drawText("Panto", at: NSPoint(x: window.minX + 34, y: window.minY + 70), size: 22, weight: .bold, color: NSColor(calibratedWhite: 0.12, alpha: 1))
        for (index, item) in ["Product", "Pricing", "Docs"].enumerated() {
            drawText(item, at: NSPoint(x: window.minX + 150 + CGFloat(index) * 96, y: window.minY + 76), size: 14, weight: .medium, color: NSColor(calibratedWhite: 0.42, alpha: 1))
        }
        drawText("Sign in", at: NSPoint(x: window.maxX - 90, y: window.minY + 76), size: 14, weight: .medium, color: NSColor(calibratedWhite: 0.42, alpha: 1))

        // Hero.
        let hero = "Ship features 2x faster."
        drawText(hero, at: NSPoint(x: window.minX + 46, y: window.minY + 168), size: 52, weight: .bold, color: NSColor(calibratedWhite: 0.10, alpha: 1))
        drawText("The all-in-one workspace for small teams.", at: NSPoint(x: window.minX + 46, y: window.minY + 240), size: 22, weight: .regular, color: NSColor(calibratedWhite: 0.45, alpha: 1))

        // CTA button.
        let cta = NSRect(x: window.minX + 46, y: window.minY + 300, width: 250, height: 64)
        NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: cta, xRadius: 14, yRadius: 14).fill()
        drawText("Start free trial", at: NSPoint(x: cta.minX + 42, y: cta.minY + 20), size: 21, weight: .semibold, color: .white)
        drawText("Book a demo →", at: NSPoint(x: cta.maxX + 34, y: cta.minY + 20), size: 19, weight: .medium, color: NSColor(calibratedWhite: 0.35, alpha: 1))

        // Chart card.
        let card = NSRect(x: window.maxX - 500, y: window.minY + 150, width: 450, height: 330)
        NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
        let cardPath = NSBezierPath(roundedRect: card, xRadius: 18, yRadius: 18)
        cardPath.fill()
        NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()
        drawText("Weekly active teams", at: NSPoint(x: card.minX + 24, y: card.minY + 24), size: 17, weight: .semibold, color: NSColor(calibratedWhite: 0.25, alpha: 1))
        drawText("+38% vs last week", at: NSPoint(x: card.minX + 24, y: card.minY + 50), size: 13, weight: .medium, color: NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.35, alpha: 1))

        let bars: [CGFloat] = [0.34, 0.46, 0.40, 0.58, 0.66, 0.62, 0.80, 0.92]
        let chartRect = NSRect(x: card.minX + 26, y: card.minY + 86, width: card.width - 52, height: card.height - 116)
        for (index, value) in bars.enumerated() {
            let barWidth = chartRect.width / CGFloat(bars.count) - 10
            let height = chartRect.height * value
            let rect = NSRect(
                x: chartRect.minX + CGFloat(index) * (barWidth + 10),
                y: chartRect.minY + chartRect.height - height,
                width: barWidth,
                height: height
            )
            let color = index == bars.count - 1
                ? NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.18, alpha: 1)
                : NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.93, alpha: 1)
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
        }

        // Recent activity card.
        let list = NSRect(x: window.maxX - 500, y: window.minY + 510, width: 450, height: 200)
        NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
        let listPath = NSBezierPath(roundedRect: list, xRadius: 18, yRadius: 18)
        listPath.fill()
        NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
        listPath.lineWidth = 1
        listPath.stroke()
        drawText("Recent activity", at: NSPoint(x: list.minX + 24, y: list.minY + 22), size: 17, weight: .semibold, color: NSColor(calibratedWhite: 0.25, alpha: 1))
        for index in 0..<3 {
            NSColor(calibratedWhite: 0.86, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(
                x: list.minX + 24,
                y: list.minY + 68 + CGFloat(index) * 38,
                width: list.width - 48 - CGFloat(index) * 30,
                height: 14
            ), xRadius: 7, yRadius: 7).fill()
        }

        // Cursor + click ripples.
        let time = Double(frame) / 30.0
        let ctaPoint = NSPoint(x: cta.midX, y: cta.midY)
        let chartPoint = NSPoint(x: card.midX + 60, y: card.midY)
        let startPoint = NSPoint(x: size.width * 0.55, y: size.height * 0.88)

        var cursor = startPoint
        if time < 2.0 {
            cursor = lerp(startPoint, ctaPoint, smoothstep(time / 2.0))
        } else if time < 5.0 {
            cursor = lerp(ctaPoint, chartPoint, smoothstep((time - 2.0) / 3.0))
        } else {
            cursor = chartPoint
        }

        for click in [2.0, 5.0] {
            let age = time - click
            guard age >= 0, age < 0.5 else { continue }
            let radius = 18 + age * 120
            let ripple = NSBezierPath(ovalIn: NSRect(
                x: cursor.x - radius, y: cursor.y - radius,
                width: radius * 2, height: radius * 2
            ))
            NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.18, alpha: 0.55 * (1 - age / 0.5)).setStroke()
            ripple.lineWidth = 4
            ripple.stroke()
        }

        let pointer = NSBezierPath()
        pointer.move(to: cursor)
        pointer.line(to: NSPoint(x: cursor.x, y: cursor.y + 30))
        pointer.line(to: NSPoint(x: cursor.x + 8, y: cursor.y + 23))
        pointer.line(to: NSPoint(x: cursor.x + 18, y: cursor.y + 27))
        pointer.close()
        NSColor.black.withAlphaComponent(0.85).setFill()
        pointer.fill()
        NSColor.white.setStroke()
        pointer.lineWidth = 2
        pointer.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func lerp(_ a: NSPoint, _ b: NSPoint, _ t: Double) -> NSPoint {
        let clamped = min(max(t, 0), 1)
        return NSPoint(x: a.x + (b.x - a.x) * clamped, y: a.y + (b.y - a.y) * clamped)
    }

    private static func smoothstep(_ value: Double) -> Double {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static func drawText(_ string: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (string as NSString).draw(at: point, withAttributes: attributes)
    }
}

enum SelfTest {
    static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("panto-selftest", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let raw = directory.appendingPathComponent("raw.mov")
        print("• building synthetic recording…")
        try SyntheticVideo.make(url: raw, seconds: 8, size: CGSize(width: 1280, height: 800))

        let events = [
            ZoomEvent(t: 2.0, x: 0.213, y: 0.415),
            ZoomEvent(t: 5.0, x: 0.78, y: 0.40)
        ]
        let shots = ZoomMath.shots(from: events)
        print("• shots: \(shots.map { String(format: "%.2f–%.2f @ (%.2f, %.2f)", $0.start, $0.end, $0.x, $0.y) })")

        print("• rendering zoom…")
        let output = try await Renderer.render(input: raw, events: events, zoom: 2.0)
        print("• output: \(output.path)")

        let frames = directory.appendingPathComponent("frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        try Frames.save(from: output, times: [1.0, 2.3, 5.3], to: frames)
        print("• frames: \(frames.path)")
        print("OK")
    }
}

enum Frames {
    static func save(from url: URL, times: [Double], to directory: URL) throws {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        for time in times {
            let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            let representation = NSBitmapImageRep(cgImage: image)
            guard let data = representation.representation(using: .png, properties: [:]) else { continue }
            try data.write(to: directory.appendingPathComponent(String(format: "frame-%.1f.png", time)))
        }
    }
}
