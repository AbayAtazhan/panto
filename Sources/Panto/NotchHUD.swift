import AppKit
import SwiftUI

/// Controls that hang off the notch. Two fixed-size panels instead of one resizing
/// panel: resizing a SwiftUI hosting view under the cursor made AppKit throw inside
/// a layout pass (SIGTRAP), and tracking areas fired bogus exits during the resize.
final class NotchHUDController {
    private var strip: NSPanel?
    private var expanded: NSPanel?
    private var timer: Timer?
    private var notchFrame: NSRect = .zero
    private var hideWorkItem: DispatchWorkItem?
    private var hiding = false

    static func notchFrame(for screen: NSScreen) -> NSRect? {
        guard screen.safeAreaInsets.top > 1,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let width = screen.frame.width - left.width - right.width
        guard width > 60 else { return nil }
        let height = screen.safeAreaInsets.top
        return NSRect(
            x: screen.frame.minX + left.width,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    static var isSupported: Bool {
        NSScreen.screens.contains { notchFrame(for: $0) != nil }
    }

    func show(counter: ZoomCounter, startedAt: Date, onZoom: @escaping () -> Void, onStop: @escaping () -> Void) {
        hide()
        guard let screen = NSScreen.screens.first(where: { Self.notchFrame(for: $0) != nil }),
              let notch = Self.notchFrame(for: screen) else { return }

        notchFrame = notch

        let stripSize = NSSize(width: notch.width, height: 24)
        let strip = makePanel(size: stripSize, root: NotchStripView(startedAt: startedAt))
        strip.setFrameOrigin(NSPoint(x: notch.midX - stripSize.width / 2, y: notch.minY - stripSize.height))
        strip.orderFrontRegardless()

        let expandedSize = NSSize(width: 304, height: 88)
        let expanded = makePanel(
            size: expandedSize,
            root: NotchExpandedView(
                counter: counter,
                startedAt: startedAt,
                onZoom: onZoom,
                onStop: onStop
            )
        )
        expanded.setFrameOrigin(NSPoint(x: notch.midX - expandedSize.width / 2, y: notch.minY - expandedSize.height))
        expanded.alphaValue = 0

        self.strip = strip
        self.expanded = expanded

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        hideWorkItem?.cancel()
        hideWorkItem = nil
        hiding = false
        strip?.orderOut(nil)
        expanded?.orderOut(nil)
        strip = nil
        expanded = nil
    }

    // MARK: - Hover

    private func tick() {
        guard let strip, let expanded else { return }
        let mouse = NSEvent.mouseLocation
        let stripHit = strip.frame.insetBy(dx: -6, dy: -4)
        let expandedHit = expanded.frame.insetBy(dx: -12, dy: -12)
        let inside = stripHit.contains(mouse) || (expanded.isVisible && expandedHit.contains(mouse))

        if inside {
            hideWorkItem?.cancel()
            hideWorkItem = nil
            showExpanded()
        } else if expanded.isVisible, hideWorkItem == nil {
            let work = DispatchWorkItem { [weak self] in self?.hideExpanded() }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }
    }

    private func showExpanded() {
        guard let expanded else { return }
        hiding = false
        if !expanded.isVisible {
            expanded.alphaValue = 0
            expanded.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            expanded.animator().alphaValue = 1
        }
    }

    private func hideExpanded() {
        hideWorkItem = nil
        guard let expanded, expanded.isVisible else { return }
        // Re-check: the pointer may have come back while the fade was scheduled.
        if expanded.frame.insetBy(dx: -12, dy: -12).contains(NSEvent.mouseLocation) { return }
        hiding = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            expanded.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.hiding else { return }
            expanded.orderOut(nil)
            self.hiding = false
        })
    }

    // MARK: - Panels

    private func makePanel<Content: View>(size: NSSize, root: Content) -> NSPanel {
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        return panel
    }
}

struct NotchStripView: View {
    let startedAt: Date

    var body: some View {
        ZStack {
            NotchShape(radius: 12).fill(Color.black)
            HStack(spacing: 5) {
                Circle().fill(Color.red).frame(width: 6, height: 6)
                SwiftUI.TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Text(NotchTimecode.string(since: startedAt))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.bottom, 2)
        }
    }
}

struct NotchExpandedView: View {
    @ObservedObject var counter: ZoomCounter
    let startedAt: Date
    let onZoom: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack {
            NotchShape(radius: 16).fill(Color.black)

            HStack(spacing: 12) {
                Circle().fill(Color.red).frame(width: 8, height: 8)

                SwiftUI.TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Text(NotchTimecode.string(since: startedAt))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                if counter.count > 0 {
                    Text("\(counter.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.black)
                }

                Spacer(minLength: 0)

                Button(action: onZoom) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.magnifyingglass")
                        Text("Zoom")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
    }
}

enum NotchTimecode {
    static func string(since date: Date) -> String {
        let total = Int(Date().timeIntervalSince(date))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Rectangle with rounded bottom corners, square top — merges with the menu bar.
struct NotchShape: Shape {
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
