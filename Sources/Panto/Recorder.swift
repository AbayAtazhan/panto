import AVFoundation
import AppKit
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    struct Options {
        var displayID: CGDirectDisplayID
        var systemAudio: Bool
        var microphone: Bool
        var trigger: TriggerMode
    }

    struct Result {
        let url: URL
        let shots: [ZoomShot]
        let duration: Double
        let hasSystemAudio: Bool
        let hasMicrophone: Bool
        let width: Int
        let height: Int
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

    private let videoQueue = DispatchQueue(label: "app.panto.capture.video", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "app.panto.capture.audio", qos: .userInitiated)
    private let lock = NSLock()

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var microphone: MicrophoneCapture?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var firstPTS: CMTime?
    private var lastPTS: CMTime?
    private var startHost: CFTimeInterval = 0
    private var sessionStarted = false
    private var tracker: ClickTracker?
    private var manualEvents: [ZoomEvent] = []
    private var screenFrame: CGRect = .zero
    private var captureWidth = 0
    private var captureHeight = 0
    private var hasAudio = false
    private var hasMic = false

    var isRecording: Bool { stream != nil }

    func start(options: Options) async throws {
        guard stream == nil else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == options.displayID }) ?? content.displays.first else {
            throw RecorderError.noDisplay
        }

        let screen = NSScreen.screens.first { $0.pantoDisplayID == display.displayID }
        screenFrame = screen?.frame ?? CGRect(
            x: 0, y: 0,
            width: CGFloat(display.width), height: CGFloat(display.height)
        )

        // Native pixel size: no downscaling, no soft text.
        let width = max(2, Int(CGDisplayPixelsWide(display.displayID)) & ~1)
        let height = max(2, Int(CGDisplayPixelsHigh(display.displayID)) & ~1)
        captureWidth = width
        captureHeight = height

        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 8
        configuration.showsCursor = true
        configuration.scalesToFit = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.captureResolution = .best
        configuration.capturesAudio = options.systemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2

        let directory = FileManager.default.pantoRecordingsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Panto \(Self.timestamp()).mov")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoSettings = Self.videoSettings(width: width, height: height)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
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

        var micTrack: AVAssetWriterInput?
        if options.microphone {
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                micTrack = input
            }
        }

        var audio: AVAssetWriterInput?
        if options.systemAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                audio = audioInput
            }
        }

        guard writer.startWriting() else {
            throw RecorderError.writerFailed(writer.error?.localizedDescription ?? "unknown error")
        }

        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = ownApps.isEmpty
            ? SCContentFilter(display: display, excludingWindows: [])
            : SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        if options.systemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        }

        self.writer = writer
        self.videoInput = input
        self.audioInput = audio
        self.micInput = micTrack
        self.adaptor = adaptor
        self.outputURL = url
        self.stream = stream
        self.firstPTS = nil
        self.lastPTS = nil
        self.sessionStarted = false
        self.startHost = 0
        self.hasAudio = options.systemAudio
        self.hasMic = micTrack != nil
        self.manualEvents = []

        if options.trigger != .hotkey {
            let tracker = ClickTracker(screenFrame: screenFrame)
            tracker.start()
            self.tracker = tracker
        }

        if options.microphone {
            let mic = MicrophoneCapture()
            mic.onSample = { [weak self] sample in
                guard let self else { return }
                self.videoQueue.async {
                    self.appendMicrophone(sample)
                }
            }
            try? mic.start()
            self.microphone = mic
        }

        do {
            try await stream.startCapture()
        } catch {
            microphone?.stop()
            microphone = nil
            self.stream = nil
            self.writer = nil
            throw RecorderError.captureFailed(error.localizedDescription)
        }
    }

    /// Called by the hotkey or the floating HUD. Returns false when the press
    /// arrived before the first video frame.
    @discardableResult
    func addManualZoom() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard stream != nil, startHost > 0 else {
            Log.write("zoom: ignored (stream=\(stream != nil), startHost=\(startHost))")
            return false
        }
        let now = CACurrentMediaTime()
        guard now > startHost else { return false }
        let point = NSEvent.mouseLocation
        guard screenFrame.width > 1, screenFrame.height > 1 else { return false }
        let x = min(max((point.x - screenFrame.minX) / screenFrame.width, 0), 1)
        let y = min(max((screenFrame.maxY - point.y) / screenFrame.height, 0), 1)
        let event = ZoomEvent(t: now - startHost, x: x, y: y)
        manualEvents.append(event)
        Log.write(String(format: "zoom: manual at %.2fs (%.2f, %.2f)", event.t, x, y))
        return true
    }

    func stop() async throws -> Result {
        guard let stream, let writer, let input = videoInput, let url = outputURL else {
            throw RecorderError.noStream
        }

        try? await stream.stopCapture()
        self.stream = nil

        tracker?.stop()
        let clickEvents = tracker?.rawEvents() ?? []
        tracker = nil

        microphone?.stop()
        microphone = nil

        input.markAsFinished()
        audioInput?.markAsFinished()
        micInput?.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }

        guard writer.status == .completed else {
            throw RecorderError.writerFailed(writer.error?.localizedDescription ?? "writer status \(writer.status.rawValue)")
        }

        let duration = max(0, CMTimeGetSeconds(CMTimeSubtract(lastPTS ?? .zero, firstPTS ?? .zero)))
        let clicks = clickEvents.compactMap { click -> ZoomEvent? in
            let t = click.host - startHost
            guard t >= 0, t <= duration + 0.4 else { return nil }
            return ZoomEvent(t: t, x: click.x, y: click.y)
        }
        let autoShots = ZoomMath.shots(from: clicks, hold: 1.35)

        lock.lock()
        let manual = manualEvents
        manualEvents = []
        lock.unlock()

        let manualShots = manual.compactMap { event -> ZoomShot? in
            guard event.t >= 0, event.t <= duration else {
                Log.write(String(format: "zoom: dropped manual event at %.2fs (duration %.2f)", event.t, duration))
                return nil
            }
            return ZoomShot(
                start: max(0, event.t - 0.05),
                end: min(duration, event.t + 1.9),
                x: event.x,
                y: event.y
            )
        }
        let shots = (autoShots + manualShots).sorted { $0.start < $1.start }
        Log.write("stop: duration=\(String(format: "%.2f", duration)) clicks=\(clickEvents.count) manual=\(manual.count) shots=\(shots.count)")

        let result = Result(
            url: url,
            shots: shots,
            duration: duration,
            hasSystemAudio: hasAudio,
            hasMicrophone: hasMic,
            width: captureWidth,
            height: captureHeight
        )

        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.micInput = nil
        self.adaptor = nil
        self.outputURL = nil
        self.firstPTS = nil
        self.lastPTS = nil
        self.sessionStarted = false

        return result
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        if type == .audio {
            guard sessionStarted, let audioInput, audioInput.isReadyForMoreMediaData else { return }
            audioInput.append(sampleBuffer)
            return
        }

        guard type == .screen,
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

    private func appendMicrophone(_ sampleBuffer: CMSampleBuffer) {
        guard sessionStarted, let micInput, micInput.isReadyForMoreMediaData else { return }
        micInput.append(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        FileHandle.standardError.write(Data("Panto capture stopped: \(error.localizedDescription)\n".utf8))
        self.stream = nil
    }

    // MARK: - Quality

    private static func videoSettings(width: Int, height: Int) -> [String: Any] {
        let pixels = Double(width * height)
        // ~0.12 bits per pixel per frame: crisp text at 60 fps without silly file sizes.
        let bitrate = max(24_000_000, min(160_000_000, Int(pixels * 60 * 0.12)))
        return [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 120,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoAllowFrameReorderingKey: true
            ]
        ]
    }

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
