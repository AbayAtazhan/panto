import AppKit
import SwiftUI

/// Floating recording controls. The app is excluded from the capture, so this
/// panel never ends up in the video.
final class ZoomCounter: ObservableObject {
    @Published var count = 0
}

final class HUDController {
    private var panel: NSPanel?

    func show(counter: ZoomCounter, onZoom: @escaping () -> Void, onStop: @escaping () -> Void) {
        hide()
        let view = HUDView(counter: counter, onZoom: onZoom, onStop: onStop)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 250, height: 54)

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
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hosting
        self.panel = panel

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - 125, y: frame.minY + 64))
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct HUDView: View {
    @ObservedObject var counter: ZoomCounter
    let onZoom: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("REC")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                if counter.count > 0 {
                    Text("\(counter.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.black)
                }
            }

            Divider().frame(height: 20)

            Button(action: onZoom) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.magnifyingglass")
                    Text("Zoom")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Divider().frame(height: 20)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.78))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        )
        .padding(4)
    }
}
