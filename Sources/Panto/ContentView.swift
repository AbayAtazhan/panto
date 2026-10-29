import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @State private var hoveringRecord = false

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 12) {
                recordCard
                settingsCard
                if !state.hasScreenPermission {
                    permissionBanner
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            footer
        }
        .frame(width: 480)
        .background(background)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.isRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshEnvironment()
        }
        .sheet(item: $state.editor) { model in
            EditorView(model: model)
        }
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0)],
                center: UnitPoint(x: 0.08, y: 0.0),
                startRadius: 8,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 7, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Panto")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Screen recordings with a camera")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            statusPill
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private var statusPill: some View {
        let active = state.isRecording
        let color: Color = active ? .red : .green
        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(active ? "REC" : "READY")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
        .foregroundStyle(color)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10))
            )
            .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }

    // MARK: - Record

    private var recordCard: some View {
        HStack(spacing: 16) {
            Button {
                state.toggle()
            } label: {
                recordButton
            }
            .buttonStyle(.plain)
            .disabled(state.isBusy)
            .onHover { hoveringRecord = $0 }
            .help(state.isRecording ? "Stop and edit" : "Start recording")

            VStack(alignment: .leading, spacing: 3) {
                Text(state.isRecording ? "Recording" : "Ready to record")
                    .font(.system(size: 16, weight: .semibold))

                Text(state.status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.isRecording
                     ? "Press \(settings.hotKey.label) to zoom at the pointer"
                     : settings.trigger.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if state.isRecording || state.isBusy {
                Text(timecode(state.elapsed))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(state.isRecording ? Color.red : .secondary)
            }
        }
        .padding(16)
        .background(card)
    }

    private var recordButton: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.16), lineWidth: 9)
                .frame(width: 82, height: 82)
                .scaleEffect(state.isRecording ? 1.04 : 1)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.36, blue: 0.33), Color(red: 0.76, green: 0.07, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 60)
                .shadow(color: .red.opacity(0.35), radius: 10, y: 4)

            if state.isBusy {
                ProgressView().controlSize(.small).tint(.white)
            } else if state.isRecording {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(hoveringRecord && !state.isBusy ? 1.04 : 1)
        .animation(.easeOut(duration: 0.15), value: hoveringRecord)
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow(
                icon: "display",
                title: "Display",
                subtitle: displaySubtitle
            ) {
                Picker("", selection: Binding(
                    get: { settings.selectedDisplayID },
                    set: { settings.selectedDisplayID = $0 }
                )) {
                    ForEach(state.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .frame(width: 178)
                .disabled(state.isRecording)
            }

            rowDivider

            settingRow(
                icon: "cursorarrow.click.2",
                title: "Zoom on",
                subtitle: settings.trigger.detail
            ) {
                Picker("", selection: $settings.trigger) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 180)
                .disabled(state.isRecording)
            }

            if settings.trigger != .clicks {
                rowDivider
                settingRow(
                    icon: "command",
                    title: "Hotkey",
                    subtitle: "Click the field and press a combo"
                ) {
                    HotKeyField(combo: $settings.hotKey)
                        .frame(width: 122, height: 28)
                }
            }

            rowDivider

            settingRow(
                icon: "plus.magnifyingglass",
                title: "Zoom strength",
                subtitle: "How close the camera gets"
            ) {
                HStack(spacing: 8) {
                    Slider(value: $settings.zoom, in: 1.3...3.0)
                        .frame(width: 128)
                    Text(String(format: "%.1f×", settings.zoom))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            rowDivider

            settingRow(
                icon: "speaker.wave.2",
                title: "System audio",
                subtitle: "App sound and music"
            ) {
                Toggle("", isOn: $settings.systemAudio)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            rowDivider

            settingRow(
                icon: "mic",
                title: "Microphone",
                subtitle: "Voiceover track, mixed on export"
            ) {
                Toggle("", isOn: $settings.microphone)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            rowDivider

            settingRow(
                icon: "rectangle.on.rectangle",
                title: "Floating controls",
                subtitle: "Never appears in the recording"
            ) {
                Toggle("", isOn: $settings.showHUD)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .background(card)
    }

    private var displaySubtitle: String {
        guard let display = state.selectedDisplay else { return "No display" }
        return "\(display.pixelWidth) × \(display.pixelHeight) px · 60 fps · HEVC"
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 52)
    }

    private func settingRow<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var permissionBanner: some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("Screen Recording is off")
                    .font(.system(size: 11, weight: .semibold))
                Text("If the toggle looks on, macOS lost the grant after a rebuild — reset it.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Button("Fix") {
                state.resetPermissions()
                state.openScreenRecordingSettings()
            }
            .controlSize(.small)
            .help("Reset the stale permission, then reopen Panto")
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.22))
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

            Text("MIT · v0.4")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
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
