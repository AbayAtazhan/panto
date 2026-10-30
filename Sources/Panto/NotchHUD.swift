import AppKit
import SwiftUI

/// Collapsed state = a black strip that hangs off the notch; hovering expands it
/// into REC + Zoom + Stop. The app is excluded from the capture, so it never
/// appears in the recording.
final class NotchHUDController {
    private var panel: NSPanel?
    private var hosting: HoverHostingView<NotchHUDView>?
    private var notchFrame: NSRect = .zero
    private var expanded = false
    private let expansion = HUDExpansion()
    private var onZoom: (() -> Void)?
    private var onStop: (() -> Void)?

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
        expanded = false
        expansion.expanded = false
        self.onZoom = onZoom
        self.onStop = onStop

        let view = NotchHUDView(
            counter: counter,
            expansion: expansion,
            startedAt: startedAt,
            onZoom: onZoom,
            onStop: onStop
        )
        let hosting = HoverHostingView(rootView: view)
        hosting.onHover = { [weak self] inside in
            self?.setExpanded(inside)
        }
        hosting.frame = NSRect(origin: .zero, size: collapsedSize)

        let panel = NSPanel(
            contentRect: hosting.frame,
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
        panel.acceptsMouseMovedEvents = true
        panel.contentView = hosting
        self.panel = panel
        self.hosting = hosting

        layout(animated: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
        expanded = false
    }

    private var collapsedSize: NSSize {
        NSSize(width: notchFrame.width, height: 26)
    }

    private var expandedSize: NSSize {
        NSSize(width: 286, height: 80)
    }

    private func setExpanded(_ value: Bool) {
        guard value != expanded else { return }
        expanded = value
        if value {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                expansion.expanded = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                expansion.expanded = false
            }
        }
        layout(animated: true)
    }

    private func layout(animated: Bool) {
        guard let panel else { return }
        let size = expanded ? expandedSize : collapsedSize
        let frame = NSRect(
            x: notchFrame.midX - size.width / 2,
            y: notchFrame.minY - size.height,
            width: size.width,
            height: size.height
        )
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}

final class HUDExpansion: ObservableObject {
    @Published var expanded = false
}

/// NSHostingView that reports hover in and out.
final class HoverHostingView<Content: View>: NSHostingView<Content> {
    var onHover: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}

struct NotchHUDView: View {
    @ObservedObject var counter: ZoomCounter
    @ObservedObject var expansion: HUDExpansion
    let startedAt: Date
    let onZoom: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            NotchShape()
                .fill(Color.black)

            HStack(spacing: expansion.expanded ? 12 : 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)

                SwiftUI.TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Text(timecode)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                if counter.count > 0 {
                    Text("\(counter.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.black)
                }

                if expansion.expanded {
                    Divider().frame(height: 16)

                    Button(action: onZoom) {
                        Label("Zoom", systemImage: "plus.magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 16)

                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: expansion.expanded ? 30 : 26)
            .padding(.bottom, expansion.expanded ? 26 : 0)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: expansion.expanded)
    }

    private var timecode: String {
        let total = Int(Date().timeIntervalSince(startedAt))
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
