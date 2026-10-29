import AppKit
import SwiftUI

/// Renders the main window into a PNG without Screen Recording permission
/// (it captures the app's own view hierarchy, not the display).
enum Screenshot {
    @MainActor
    static func capture(to url: URL, icon: URL?) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if let icon, let image = NSImage(contentsOf: icon) {
            app.applicationIconImage = image
        }

        let settings = AppSettings()
        let state = AppState(settings: settings)
        state.refreshEnvironment()

        let root = ContentView()
            .environmentObject(state)
            .environmentObject(settings)
        let hosting = NSHostingView(rootView: root)
        let fitting = hosting.fittingSize
        let size = NSSize(width: max(fitting.width, 480), height: max(fitting.height, 600))
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -6000, y: -6000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.orderFront(nil)

        RunLoop.main.run(until: Date().addingTimeInterval(0.8))

        guard let view = window.contentView,
              let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        if let data = representation.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
        window.orderOut(nil)
    }
}
