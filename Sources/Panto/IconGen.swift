import AppKit

/// Draws the app icon (1024×1024 PNG) used by the release script.
enum IconGen {
    static func write(to url: URL) {
        let side = 1024
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: representation) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let canvas = NSRect(x: 0, y: 0, width: side, height: side)
        NSColor.clear.setFill()
        canvas.fill()

        let squircle = NSBezierPath(
            roundedRect: canvas.insetBy(dx: 52, dy: 52),
            xRadius: 232,
            yRadius: 232
        )
        squircle.addClip()

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.37, green: 0.24, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.03, blue: 0.22, alpha: 1)
        ])
        gradient?.draw(in: canvas, angle: -68)

        // Screen outline.
        let screen = NSRect(x: 168, y: 268, width: 688, height: 468)
        let screenPath = NSBezierPath(roundedRect: screen, xRadius: 46, yRadius: 46)
        NSColor.white.withAlphaComponent(0.13).setFill()
        screenPath.fill()
        NSColor.white.withAlphaComponent(0.92).setStroke()
        screenPath.lineWidth = 24
        screenPath.stroke()

        // Play triangle inside the screen.
        let play = NSBezierPath()
        play.move(to: NSPoint(x: 372, y: 610))
        play.line(to: NSPoint(x: 372, y: 394))
        play.line(to: NSPoint(x: 556, y: 502))
        play.close()
        NSColor.white.withAlphaComponent(0.95).setFill()
        play.fill()

        // Zoom handle.
        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 738, y: 366))
        handle.line(to: NSPoint(x: 884, y: 220))
        handle.lineWidth = 86
        handle.lineCapStyle = .round
        NSColor.white.setStroke()
        handle.stroke()

        // Lens.
        let lensRect = NSRect(x: 526, y: 300, width: 380, height: 380)
        NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.28, alpha: 1).setFill()
        NSBezierPath(ovalIn: lensRect).fill()
        NSColor.white.setStroke()
        let lens = NSBezierPath(ovalIn: lensRect)
        lens.lineWidth = 44
        lens.stroke()

        // Cursor inside the lens.
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: 682, y: 540))
        cursor.line(to: NSPoint(x: 682, y: 424))
        cursor.line(to: NSPoint(x: 704, y: 450))
        cursor.line(to: NSPoint(x: 722, y: 412))
        cursor.line(to: NSPoint(x: 740, y: 422))
        cursor.line(to: NSPoint(x: 720, y: 460))
        cursor.line(to: NSPoint(x: 752, y: 462))
        cursor.close()
        NSColor(calibratedRed: 0.10, green: 0.05, blue: 0.25, alpha: 1).setFill()
        cursor.fill()

        NSGraphicsContext.restoreGraphicsState()

        guard let data = representation.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
