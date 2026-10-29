import AVFoundation
import AppKit
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    struct Result {
        let url: URL
        let events: [ZoomEvent]
        let duration: Double
    }

    enum RecorderError: LocalizedError {
        case noDisplay
        case noStream
        case writerFailed(String)
        case captureFailed(String)

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "No display available to capture."
            case .noStream: return "Recorder is not running."
            case .writerFailed(let message): return "Could not write the video: \(message)"
            case .captureFailed(let message): return "Screen capture failed: \(message)"
            }
        }
    }

    private let queue = DispatchQueue(label: "app.panto.capture", qos: .userInitiated)
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var firstPTS: CMTime?
    private var lastPTS: CMTime?
    private var startHost: CFTimeInterval = 0
    private var sessionStarted = false
    private var tracker: ClickTracker?

    var isRecording: Bool { stream != nil }

    func start(displayID: CGDirectDisplayID) async throws {
        guard stream == nil else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw RecorderError.noDisplay
        }

        let screen = NSScreen.screens.first { $0.pantoDisplayID == display.displayID }
        let screenFrame = screen?.frame ?? CGRect(
            x: 0, y: 0,
            width: CGFloat(display.width), height: CGFloat(display.height)
        )

        let nativeWidth = CGFloat(max(CGDisplayPixelsWide(display.displayID), 2))
        let nativeHeight = CGFloat(max(CGDisplayPixelsHigh(display.displayID), 2))
        let downscale = min(1, 2560 / nativeWidth)
        let width = max(2, Int((nativeWidth * downscale).rounded()) & ~1)
        let height = max(2, Int((nativeHeight * downscale).rounded()) & ~1)

        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 6
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.scalesToFit = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let directory = FileManager.default.pantoRecordingsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Panto \(Self.timestamp()).mov")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 14_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 60
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw RecorderError.writerFailed(writer.error?.localizedDescription ?? "unknown error")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)

        self.writer = writer
        self.videoInput = input
        self.adaptor = adaptor
        self.outputURL = url
        self.stream = stream
        self.firstPTS = nil
        self.lastPTS = nil
        self.sessionStarted = false
        self.startHost = 0

        let tracker = ClickTracker(screenFrame: screenFrame)
        tracker.start()
        self.tracker = tracker

        do {
            try await stream.startCapture()
        } catch {
            self.stream = nil
            self.writer = nil
            throw RecorderError.captureFailed(error.localizedDescription)
        }
    }

    func stop() async throws -> Result {
        guard let stream, let writer, let input = videoInput, let url = outputURL else {
            throw RecorderError.noStream
        }

        try? await stream.stopCapture()
        self.stream = nil

        tracker?.stop()
        let rawClicks = tracker?.rawEvents() ?? []
        tracker = nil

        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }

        guard writer.status == .completed else {
            throw RecorderError.writerFailed(writer.error?.localizedDescription ?? "writer status \(writer.status.rawValue)")
        }

        let duration = max(0, CMTimeGetSeconds(CMTimeSubtract(lastPTS ?? .zero, firstPTS ?? .zero)))
        let events: [ZoomEvent] = rawClicks.compactMap { click in
            let t = click.host - startHost
            guard t >= 0, t <= duration + 0.4 else { return nil }
            return ZoomEvent(t: t, x: click.x, y: click.y)
        }

        self.writer = nil
        self.videoInput = nil
        self.adaptor = nil
        self.outputURL = nil
        self.firstPTS = nil
        self.lastPTS = nil
        self.sessionStarted = false

        return Result(url: url, events: events, duration: duration)
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let writer, let input = videoInput, let adaptor else { return }

        if !sessionStarted {
            sessionStarted = true
            firstPTS = pts
            startHost = CACurrentMediaTime()
            writer.startSession(atSourceTime: pts)
        }

        lastPTS = pts
        guard input.isReadyForMoreMediaData, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        adaptor.append(pixelBuffer, withPresentationTime: pts)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        FileHandle.standardError.write(Data("Panto capture stopped: \(error.localizedDescription)\n".utf8))
        self.stream = nil
    }

    // MARK: - Helpers

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}

extension NSScreen {
    var pantoDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

extension FileManager {
    var pantoRecordingsDirectory: URL {
        let base = urls(for: .moviesDirectory, in: .userDomainMask).first ?? homeDirectoryForCurrentUser
        return base.appendingPathComponent("Panto", isDirectory: true)
    }
}
