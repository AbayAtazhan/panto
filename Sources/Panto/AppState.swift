import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    struct Display: Identifiable, Hashable {
        let id: CGDirectDisplayID
        let name: String
        let pixelWidth: Int
        let pixelHeight: Int
    }

    let settings: AppSettings

    @Published var displays: [Display] = []
    @Published var isRecording = false
    @Published var isBusy = false
    @Published var status = "Ready"
    @Published var elapsed: TimeInterval = 0
    @Published var lastURL: URL?
    @Published var hasScreenPermission = false
    @Published var hasAccessibility = false
    @Published var editor: EditorModel?

    private let recorder = Recorder()
    private let hud = HUDController()
    private var timer: Timer?
    private var startedAt: Date?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        refreshEnvironment()
        registerHotKey()

        HotKeyCenter.shared.onPress = { [weak self] in
            self?.hotKeyPressed()
        }
        settings.$hotKey
            .dropFirst()
            .sink { [weak self] _ in self?.registerHotKey() }
            .store(in: &cancellables)
    }

    private func registerHotKey() {
        HotKeyCenter.shared.register(settings.hotKey)
    }

    private func hotKeyPressed() {
        guard isRecording else { return }
        recorder.addManualZoom()
        flash("Zoom added")
    }

    func refreshEnvironment() {
        hasScreenPermission = CGPreflightScreenCaptureAccess()
        hasAccessibility = AXIsProcessTrusted()
        refreshDisplays()
        registerHotKey()
    }

    func refreshDisplays() {
        let screens = NSScreen.screens.compactMap { screen -> Display? in
            guard let id = screen.pantoDisplayID else { return nil }
            let pixelsWide = Int(CGDisplayPixelsWide(id))
            let pixelsHigh = Int(CGDisplayPixelsHigh(id))
            return Display(
                id: id,
                name: screen.localizedName,
                pixelWidth: pixelsWide,
                pixelHeight: pixelsHigh
            )
        }
        displays = screens
        if displays.isEmpty == false,
           settings.selectedDisplayID == nil || !screens.contains(where: { $0.id == settings.selectedDisplayID }) {
            settings.selectedDisplayID = screens.first?.id
        }
    }

    var selectedDisplay: Display? {
        displays.first { $0.id == settings.selectedDisplayID } ?? displays.first
    }

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !isRecording, !isBusy else { return }
        guard let display = selectedDisplay else {
            status = "No display found."
            return
        }

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            hasScreenPermission = CGPreflightScreenCaptureAccess()
            guard hasScreenPermission else {
                status = "Allow Screen Recording, then reopen Panto."
                showWindow()
                return
            }
        }

        status = "Starting…"
        isBusy = true
        Task {
            do {
                try await recorder.start(options: Recorder.Options(
                    displayID: display.id,
                    systemAudio: settings.systemAudio,
                    trigger: settings.trigger
                ))
                isRecording = true
                isBusy = false
                startedAt = Date()
                elapsed = 0
                startTimer()
                hideWindow()
                status = "Recording"
                if settings.showHUD {
                    hud.show(
                        onZoom: { [weak self] in self?.manualZoom() },
                        onStop: { [weak self] in self?.stop() }
                    )
                }
            } catch {
                isBusy = false
                status = error.localizedDescription
                showWindow()
            }
        }
    }

    func manualZoom() {
        guard isRecording else { return }
        recorder.addManualZoom()
        flash("Zoom added")
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        hud.hide()
        timer?.invalidate()
        timer = nil
        isBusy = true
        status = "Finishing recording…"

        Task {
            do {
                let result = try await recorder.stop()
                isBusy = false
                showWindow()
                let model = EditorModel(result: result, zoom: settings.zoom)
                model.onExported = { [weak self] url in
                    guard let self else { return }
                    self.lastURL = url
                    self.editor = nil
                    self.status = "Saved \(url.lastPathComponent)"
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                editor = model
                status = "Edit your zooms"
            } catch {
                isBusy = false
                status = error.localizedDescription
                showWindow()
            }
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

    /// Ad-hoc builds get a new code hash on every rebuild, and macOS keys the
    /// screen-recording grant to that hash. Resetting clears the stale entry so the
    /// system prompt can appear again.
    func resetPermissions() {
        let bundleID = Bundle.main.bundleIdentifier ?? "app.panto.recorder"
        for service in ["ScreenCapture", "Accessibility", "Microphone"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
        hasScreenPermission = false
        status = "Permission reset — quit Panto, open it again, then allow screen recording."
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func flash(_ message: String) {
        status = message
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
