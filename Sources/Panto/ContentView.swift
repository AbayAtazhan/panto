import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            VStack(spacing: 12) {
                recordCard
                settingsCard
                if !state.hasScreenPermission {
                    permissionBanner
                }
            }
            .padding(16)
            footer
        }
        .frame(width: 460)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshEnvironment()
        }
        .sheet(item: $state.editor) { model in
            EditorView(model: model)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Panto")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Screen recordings with a camera")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("0.2")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    // MARK: - Record

    private var recordCard: some View {
        HStack(spacing: 15) {
            Button {
                state.toggle()
            } label: {
                recordButton
            }
            .buttonStyle(.plain)
            .disabled(state.isBusy)
            .help(state.isRecording ? "Stop and edit" : "Start recording")

            VStack(alignment: .leading, spacing: 3) {
                Text(state.isRecording ? "Recording" : "Ready")
                    .font(.system(size: 15, weight: .semibold))

                Text(state.status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if state.isRecording {
                    Text("Press \(settings.hotKey.label) to zoom at the pointer")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if state.isRecording || state.isBusy {
                Text(timecode(state.elapsed))
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(state.isRecording ? Color.red : .secondary)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var recordButton: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 66, height: 66)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.34, blue: 0.31), Color(red: 0.78, green: 0.08, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: .red.opacity(0.3), radius: 8, y: 3)

            if state.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else if state.isRecording {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 17, height: 17)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Display")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 74, alignment: .leading)

                Picker("", selection: Binding(
                    get: { settings.selectedDisplayID },
                    set: { settings.selectedDisplayID = $0 }
                )) {
                    ForEach(state.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .disabled(state.isRecording)
            }

            if let display = state.selectedDisplay {
                Text("\(display.pixelWidth) × \(display.pixelHeight) px · 60 fps · HEVC")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 86)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Zoom on")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $settings.trigger) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(state.isRecording)

                Text(settings.trigger.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if settings.trigger != .clicks {
                    HStack {
                        Text("Hotkey")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HotKeyField(combo: $settings.hotKey)
                            .frame(width: 118, height: 30)
                        Text("draws a zoom where the pointer is")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Text("Zoom")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Slider(value: $settings.zoom, in: 1.3...3.0, step: 0.1)
                Text(String(format: "%.1f×", settings.zoom))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            Divider()

            HStack(spacing: 18) {
                Toggle("System audio", isOn: $settings.systemAudio)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Toggle("Floating controls", isOn: $settings.showHUD)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Spacer()
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Screen Recording is off")
                    .font(.system(size: 11, weight: .semibold))
                Text("Enable it, then reopen Panto.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                state.requestScreenPermission()
                state.openScreenRecordingSettings()
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25))
        )
    }

    // MARK: - Footer

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
                    Label("Reveal last", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }

            Spacer()

            Text("MIT · free forever")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }

    private func timecode(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button(state.isRecording ? "Stop and Edit" : "Start Recording") {
            state.toggle()
        }
        .keyboardShortcut("r")

        Button("Zoom Now") {
            state.manualZoom()
        }
        .disabled(!state.isRecording)

        Divider()

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
