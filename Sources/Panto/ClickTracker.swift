import AppKit
import CoreGraphics

struct RawClick {
    let host: CFTimeInterval
    let x: Double
    let y: Double
}

/// Tracks clicks globally. Uses an event monitor when Accessibility is granted;
/// otherwise falls back to detecting where the pointer rests (no permissions).
final class ClickTracker {
    private let screenFrame: CGRect
    private var monitor: Any?
    private var timer: Timer?
    private var events: [RawClick] = []
    private var lastPoint: CGPoint = .zero
    private var stillSince: CFTimeInterval = 0
    private var emittedDwell = false
    private let lock = NSLock()

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
    }

    func start() {
        lastPoint = NSEvent.mouseLocation
        stillSince = CACurrentMediaTime()

        if AXIsProcessTrusted() {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.record(NSEvent.mouseLocation)
            }
        }

        if monitor == nil {
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.poll()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        timer?.invalidate()
        monitor = nil
        timer = nil
    }

    func rawEvents() -> [RawClick] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    private func record(_ point: CGPoint) {
        guard screenFrame.width > 1, screenFrame.height > 1, screenFrame.contains(point) else { return }
        let x = (point.x - screenFrame.minX) / screenFrame.width
        let y = (screenFrame.maxY - point.y) / screenFrame.height
        lock.lock()
        events.append(RawClick(host: CACurrentMediaTime(), x: x, y: y))
        lock.unlock()
    }

    private func poll() {
        let now = CACurrentMediaTime()
        let point = NSEvent.mouseLocation
        if hypot(point.x - lastPoint.x, point.y - lastPoint.y) > 4 {
            lastPoint = point
            stillSince = now
            emittedDwell = false
        } else if now - stillSince > 0.55, !emittedDwell {
            emittedDwell = true
            record(point)
        }
    }
}
