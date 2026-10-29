import CoreGraphics
import Foundation

/// A click (or dwell) that should attract the camera.
/// `x`/`y` are normalized 0...1 inside the captured display, `y` measured from the top.
struct ZoomEvent: Equatable {
    var t: Double
    var x: Double
    var y: Double
}

/// A window of time during which the camera is zoomed on a point.
struct ZoomShot: Equatable {
    var start: Double
    var end: Double
    var x: Double
    var y: Double
}

enum ZoomMath {
    /// Merge clicks that are close in time and space so the camera does not jitter.
    static func shots(from events: [ZoomEvent], hold: Double = 1.35, mergeGap: Double = 0.9) -> [ZoomShot] {
        var result: [ZoomShot] = []
        for event in events.sorted(by: { $0.t < $1.t }) {
            if var last = result.last,
               event.t - last.end < mergeGap,
               hypot(event.x - last.x, event.y - last.y) < 0.22 {
                last.end = max(last.end, event.t + hold)
                last.x = last.x * 0.65 + event.x * 0.35
                last.y = last.y * 0.65 + event.y * 0.35
                result[result.count - 1] = last
            } else {
                result.append(ZoomShot(start: event.t, end: event.t + hold, x: event.x, y: event.y))
            }
        }
        return result
    }

    /// Current zoom state: scale in `1...maxZoom` and weighted center.
    static func state(at time: Double, shots: [ZoomShot], maxZoom: Double, fade: Double = 0.32) -> (scale: Double, x: Double, y: Double) {
        guard maxZoom > 1, !shots.isEmpty else { return (1, 0.5, 0.5) }

        var weightSum = 0.0
        var xSum = 0.0
        var ySum = 0.0
        var peak = 0.0

        for shot in shots {
            let w = weight(at: time, start: shot.start, end: shot.end, fade: fade)
            guard w > 0 else { continue }
            weightSum += w
            xSum += shot.x * w
            ySum += shot.y * w
            peak = max(peak, w)
        }

        guard weightSum > 0 else { return (1, 0.5, 0.5) }
        return (1 + (maxZoom - 1) * peak, xSum / weightSum, ySum / weightSum)
    }

    static func weight(at t: Double, start: Double, end: Double, fade: Double) -> Double {
        if t <= start - fade || t >= end + fade { return 0 }
        if t < start { return smoothstep((t - (start - fade)) / fade) }
        if t > end { return smoothstep(((end + fade) - t) / fade) }
        return 1
    }

    static func smoothstep(_ value: Double) -> Double {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// Zoom around a normalized point (origin top-left, y down), which is the
    /// coordinate space of AVVideoComposition layer instructions.
    static func transform(scale: Double, centerX: Double, centerY: Double, size: CGSize) -> CGAffineTransform {
        let px = centerX * size.width
        let py = centerY * size.height
        let s = CGFloat(max(scale, 1))
        return CGAffineTransform(translationX: px, y: py)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -px, y: -py)
    }
}
