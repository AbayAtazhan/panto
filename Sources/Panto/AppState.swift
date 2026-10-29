import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    struct Display: Identifiable, Hashable {
        let id: CGDirectDisplayID
        let name: String
        let width: Int
        let height: Int
    }

    @Published var displays: [Display] = []
    @Published var selectedID: CGDirectDisplayID?
    @Published var isRecording = false
    @Published var isBusy = false
    @Published var status = "Ready"
    @Published var zoom: Double = 2.0
    @Published var autoZoom = true
    @Published var elapsed: TimeInterval = 0
    @Published var lastURL: URL?
    @Published var lastWasZoomed = false
    @Published var hasScreenPermission = false
    @Published var hasAccessibility = false

    private let recorder = Recorder()
    private var timer: Timer?
    private var startedAt: Date?

    init() {
        refreshEnvironment()
    }

    func refreshEnvironment() {
        hasScreenPermission = CGPreflightScreenCaptureAccess()
        hasAccessibility = AXIsProcessTrusted()
        refreshDisplays()
    }

    func refreshDisplays() {
        let screens = NSScreen.screens.compactMap { screen -> Display? in
            guard let id = screen.pantoDisplayID else { return nil }
            return Display(
                id: id,
                name: "\(screen.localizedName) · \(Int(screen.frame.width))×\(Int(screen.frame.height))",
                width: Int(screen.frame.width),
                height: Int(screen.frame.height)
            )
        }
        displays = screens
        if selectedID == nil || !screens.contains(where: { $0.id == selectedID }) {
            selectedID = screens.first?.id
        }
    }

    func toggle() {
        if isRecording {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isRecording, !isBusy, let displayID = selectedID else { return }

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            hasScreenPermission = CGPreflightScreenCaptureAccess()
            guard hasScreenPermission else {
                status = "Allow Screen Recording, then restart Panto."
                showWindow()
                return
            }
        }

        status = "Starting…"
        Task {
            do {
                try await recorder.start(displayID: displayID)
                isRecording = true
                startedAt = Date()
                elapsed = 0
                startTimer()
                hideWindow()
                status = hasAccessibility
                    ? "Recording — click around."
                    : "Recording — auto-zoom follows where your pointer rests."
            } catch {
                status = error.localizedDescription
                showWindow()
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate()
        timer = nil
        isBusy = true
        status = "Finishing recording…"

        Task {
            do {
                let result = try await recorder.stop()
                var output = result.url
                lastWasZoomed = false

                if autoZoom, result.events.count > 0, result.duration > 0.5 {
                    status = "Auto-zooming \(result.events.count) click\(result.events.count == 1 ? "" : "s")…"
                    output = try await Renderer.render(input: result.url, events: result.events, zoom: CGFloat(zoom))
                    lastWasZoomed = output != result.url
                }

                lastURL = output
                status = "Saved \(output.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([output])
            } catch {
                status = error.localizedDescription
            }
            isBusy = false
            showWindow()
        }
    }

    func revealLast() {
        guard let lastURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastURL])
    }

    func openRecordingsFolder() {
        let directory = FileManager.default.pantoRecordingsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func hideWindow() {
        NSApp.windows.filter { $0.canBecomeKey }.forEach { $0.orderOut(nil) }
    }

    func requestScreenPermission() {
        CGRequestScreenCaptureAccess()
        hasScreenPermission = CGPreflightScreenCaptureAccess()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.elapsed = Date().timeIntervalSince(startedAt)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
