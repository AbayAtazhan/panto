import AppKit
import SwiftUI

struct PantoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings: AppSettings
    @StateObject private var state: AppState

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _state = StateObject(wrappedValue: AppState(settings: settings))
    }

    var body: some Scene {
        WindowGroup("Panto") {
            ContentView()
                .environmentObject(state)
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.isRecording ? "stop.circle.fill" : "record.circle")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
