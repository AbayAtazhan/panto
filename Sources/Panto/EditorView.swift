import AVFoundation
import AppKit
import SwiftUI

@MainActor
final class EditorModel: ObservableObject, Identifiable {
    let id = UUID()
    let input: URL
    let duration: Double
    let player: AVPlayer

    @Published var shots: [ZoomShot]
    @Published var selected: Int?
    @Published var zoom: Double
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var isExporting = false
    @Published var status: String

    var onExported: ((URL) -> Void)?
    private var observer: Any?

    init(result: Recorder.Result, zoom: Double) {
        input = result.url
        duration = max(result.duration, 0.2)
        shots = result.shots
        self.zoom = zoom
        player = AVPlayer(url: result.url)
        status = result.hasSystemAudio ? "System audio captured" : "Silent recording"

        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if self.currentTime >= self.duration - 0.05 {
                self.player.pause()
                self.isPlaying = false
            }
        }
    }

    deinit {
        if let observer {
            player.removeTimeObserver(observer)
        }
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= duration - 0.05 {
                player.seek(to: .zero)
            }
            player.play()
            isPlaying = true
        }
    }

    func seek(toFraction value: Double) {
        let clamped = min(max(value, 0), 1)
        let time = clamped * duration
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }

    /// Adds a zoom at the playhead, centered on a point in the preview (0...1, y from top).
    func addShot(at point: CGPoint) {
        let start = max(0, currentTime - 0.15)
        let shot = ZoomShot(
            start: start,
            end: min(duration, start + 1.7),
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
        shots.append(shot)
        shots.sort { $0.start < $1.start }
        selected = shots.firstIndex(of: shot)
        status = "Zoom added at \(timecode(start))"
    }

    func deleteSelected() {
        guard let selected, shots.indices.contains(selected) else { return }
        shots.remove(at: selected)
        self.selected = nil
    }

    func moveShot(_ index: Int, to start: Double) {
        guard shots.indices.contains(index) else { return }
        let length = shots[index].end - shots[index].start
        let newStart = min(max(start, 0), max(0, duration - length))
        shots[index].start = newStart
        shots[index].end = min(duration, newStart + length)
        selected = index
    }

    func export() {
        guard !isExporting else { return }
        isExporting = true
        status = "Rendering \(shots.count) zooms…"
        let shots = self.shots
        let zoom = self.zoom
        Task {
            do {
                let output = try await Renderer.render(input: input, shots: shots, zoom: CGFloat(zoom))
                isExporting = false
                onExported?(output)
            } catch {
                isExporting = false
                status = error.localizedDescription
            }
        }
    }

    func timecode(_ value: Double) -> String {
        let total = Int(max(0, value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Video surface

final class PlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.backgroundColor = NSColor.black.cgColor
        layer = playerLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

// MARK: - Editor

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            header
            preview
            hint
            TimelineView(model: model)
            controls
        }
        .padding(20)
        .frame(width: 780, height: 640)
        .onDisappear {
            model.player.pause()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit zooms")
                    .font(.system(size: 17, weight: .bold))
                Text("\(model.timecode(model.duration)) · \(model.shots.count) zoom\(model.shots.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var preview: some View {
        PlayerView(player: model.player)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            model.addShot(at: CGPoint(
                                x: location.x / max(geo.size.width, 1),
                                y: location.y / max(geo.size.height, 1)
                            ))
                        }
                }
            )
            .overlay(alignment: .topTrailing) {
                Text(model.timecode(model.currentTime))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .foregroundStyle(.white)
                    .padding(10)
            }
    }

    private var hint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap")
            Text("Click the preview to place a zoom at the playhead. Drag bars to move them.")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.togglePlay()
            } label: {
                Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
            }

            Button {
                model.addShot(at: CGPoint(x: 0.5, y: 0.5))
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add a centered zoom at the playhead")

            Button {
                model.deleteSelected()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(model.selected == nil)
            .keyboardShortcut(.delete, modifiers: [])

            Spacer()

            Text("Zoom")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Slider(value: $model.zoom, in: 1.3...3.0, step: 0.1)
                .frame(width: 120)
            Text(String(format: "%.1f×", model.zoom))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34)

            Button {
                model.export()
            } label: {
                if model.isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Export")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isExporting)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

// MARK: - Timeline

struct TimelineView: View {
    @ObservedObject var model: EditorModel
    @State private var dragIndex: Int?
    @State private var dragStart: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor))

                ForEach(0..<11, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.secondary.opacity(tick % 5 == 0 ? 0.35 : 0.15))
                        .frame(width: 1, height: 8)
                        .offset(x: CGFloat(tick) / 10 * width, y: 0)
                }

                ForEach(Array(model.shots.enumerated()), id: \.offset) { index, shot in
                    shotBar(shot, index: index, width: width)
                }

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 1.5)
                    .offset(x: min(max(model.currentTime / model.duration, 0), 1) * width)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard dragIndex == nil else { return }
                        isScrubbing = true
                        model.seek(toFraction: value.location.x / width)
                    }
                    .onEnded { _ in isScrubbing = false }
            )
        }
        .frame(height: 64)
    }

    private func shotBar(_ shot: ZoomShot, index: Int, width: CGFloat) -> some View {
        let startX = CGFloat(shot.start / model.duration) * width
        let endX = CGFloat(shot.end / model.duration) * width
        let barWidth = max(endX - startX, 10)
        let isSelected = model.selected == index

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected ? Color.accentColor : Color.orange.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0.25), lineWidth: 1)
            )
            .frame(width: barWidth, height: 34)
            .offset(x: startX, y: 18)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragIndex != index {
                            dragIndex = index
                            dragStart = shot.start
                            model.selected = index
                        }
                        let delta = Double(value.translation.width / width) * model.duration
                        model.moveShot(index, to: dragStart + delta)
                    }
                    .onEnded { _ in
                        dragIndex = nil
                    }
            )
    }
}
