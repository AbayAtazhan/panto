import AVFoundation
import CoreGraphics

enum RendererError: LocalizedError {
    case noVideoTrack
    case exportFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The recording has no video track."
        case .exportFailed(let message): return "Export failed: \(message)"
        case .cancelled: return "Export was cancelled."
        }
    }
}

enum Renderer {
    /// Applies the auto-zoom camera move to a raw recording and writes an mp4 next to it.
    static func render(input: URL, events: [ZoomEvent], zoom: CGFloat) async throws -> URL {
        guard !events.isEmpty else { return input }

        let asset = AVURLAsset(url: input)
        guard let source = try await asset.loadTracks(withMediaType: .video).first else {
            throw RendererError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds > 0.1 else { return input }

        let naturalSize = try await source.load(.naturalSize)
        let preferredTransform = try await source.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)
        let renderSize = CGSize(
            width: max(2, abs(transformed.width).rounded()),
            height: max(2, abs(transformed.height).rounded())
        )

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RendererError.noVideoTrack
        }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)

        let shots = ZoomMath.shots(from: events)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 60)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        var lastTransform = CGAffineTransform.identity
        var time = 0.0

        // A little camera model: the scale comes from the click timeline, the center
        // is clamped so the frame never shows black bars, and the pan is smoothed.
        var camera = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
        let step = 1.0 / 30.0
        let smoothing = 1 - exp(-step / 0.10)

        while time <= seconds + 0.001 {
            let state = ZoomMath.state(at: time, shots: shots, maxZoom: Double(zoom))
            let scale = CGFloat(max(state.scale, 1))
            let halfWidth = renderSize.width / (2 * scale)
            let halfHeight = renderSize.height / (2 * scale)

            var target = CGPoint(x: state.x * renderSize.width, y: state.y * renderSize.height)
            target.x = min(max(target.x, halfWidth), renderSize.width - halfWidth)
            target.y = min(max(target.y, halfHeight), renderSize.height - halfHeight)

            camera.x += (target.x - camera.x) * smoothing
            camera.y += (target.y - camera.y) * smoothing
            if scale <= 1.001 {
                camera = CGPoint(x: renderSize.width / 2, y: renderSize.height / 2)
            }

            let ease = ZoomMath.smoothstep(Double((scale - 1) / 0.18))
            let offsetX = (renderSize.width / 2 - scale * camera.x) * CGFloat(ease)
            let offsetY = (renderSize.height / 2 - scale * camera.y) * CGFloat(ease)

            var transform = CGAffineTransform(
                a: scale, b: 0, c: 0, d: scale,
                tx: offsetX, ty: offsetY
            )
            if !preferredTransform.isIdentity {
                transform = transform.concatenating(preferredTransform)
            }
            if !nearlyEqual(transform, lastTransform) {
                layer.setTransform(transform, at: CMTime(seconds: time, preferredTimescale: 600))
                lastTransform = transform
            }
            time += step
        }
        layer.setTransform(lastTransform, at: CMTime(seconds: max(0, seconds - 0.001), preferredTimescale: 600))

        instruction.layerInstructions = [layer]
        videoComposition.instructions = [instruction]

        let output = outputURL(for: input)
        try? FileManager.default.removeItem(at: output)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw RendererError.exportFailed("could not create an export session")
        }
        session.videoComposition = videoComposition
        session.outputURL = output
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }

        guard session.status == .completed else {
            throw RendererError.exportFailed(session.error?.localizedDescription ?? "status \(session.status.rawValue)")
        }
        return output
    }

    static func outputURL(for input: URL) -> URL {
        let base = input.deletingPathExtension().lastPathComponent
        return input.deletingLastPathComponent().appendingPathComponent("\(base) (zoom).mp4")
    }

    private static func nearlyEqual(_ lhs: CGAffineTransform, _ rhs: CGAffineTransform) -> Bool {
        let epsilon = 0.0004
        return abs(lhs.a - rhs.a) < epsilon
            && abs(lhs.b - rhs.b) < epsilon
            && abs(lhs.c - rhs.c) < epsilon
            && abs(lhs.d - rhs.d) < epsilon
            && abs(lhs.tx - rhs.tx) < 0.05
            && abs(lhs.ty - rhs.ty) < 0.05
    }
}
