import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            recordPanel
            optionsPanel
            permissionsPanel
            footer
        }
        .padding(22)
        .frame(width: 470)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshEnvironment()
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Panto")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("BETA")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .foregroundStyle(Color.accentColor)
                }
                Text("Auto-zoom for your screen recordings")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var recordPanel: some View {
        VStack(spacing: 10) {
            Button {
                state.toggle()
            } label: {
                recordCircle
            }
            .buttonStyle(.plain)
            .disabled(state.isBusy)
            .help(state.isRecording ? "Stop recording" : "Start recording")

            Text(state.isRecording ? timecode(state.elapsed) : (state.isBusy ? "Rendering…" : "Ready to record"))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(state.isRecording ? Color.red : .primary)

            Text(state.status)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 30, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var recordCircle: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 104, height: 104)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.33, blue: 0.31), Color(red: 0.80, green: 0.09, blue: 0.13)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 82, height: 82)
                .shadow(color: .red.opacity(0.25), radius: 10, y: 4)

            if state.isRecording {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Display")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { state.selectedID },
                    set: { state.selectedID = $0 }
                )) {
                    ForEach(state.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Zoom")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f×", state.zoom))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $state.zoom, in: 1.4...2.6, step: 0.1)
            }

            Toggle("Auto-zoom on clicks", isOn: $state.autoZoom)
                .toggleStyle(.switch)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var permissionsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            permissionRow(
                title: "Screen Recording",
                detail: state.hasScreenPermission ? "Granted" : "Required to capture your screen",
                granted: state.hasScreenPermission,
                actionTitle: "Open",
                action: state.requestScreenPermission
            )

            permissionRow(
                title: "Accessibility",
                detail: state.hasAccessibility ? "Granted — click detection on" : "Optional — enables click detection",
                granted: state.hasAccessibility,
                actionTitle: "Open",
                action: state.openAccessibilitySettings
            )

            if !state.hasScreenPermission {
                Text("After granting Screen Recording, quit Panto and open it again. macOS requires a restart for the permission to apply.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func permissionRow(title: String, detail: String, granted: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(granted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? "Granted" : actionTitle, action: action)
                .buttonStyle(.link)
                .font(.system(size: 11, weight: .medium))
                .disabled(granted)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                state.openRecordingsFolder()
            } label: {
                Label("Recordings", systemImage: "folder")
            }
            .buttonStyle(.link)
            .font(.system(size: 11))

            if state.lastURL != nil {
                Button {
                    state.revealLast()
                } label: {
                    Label(state.lastWasZoomed ? "Reveal zoomed video" : "Reveal last video", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }

            Spacer()

            Text("Raw .mov + zoomed .mp4")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func timecode(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button(state.isRecording ? "Stop Recording" : "Start Recording") {
            state.toggle()
        }
        .keyboardShortcut("r")

        Button("Show Panto") {
            state.showWindow()
        }

        if state.lastURL != nil {
            Button("Reveal Last Recording") {
                state.revealLast()
            }
        }

        Divider()

        Button("Quit Panto") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
