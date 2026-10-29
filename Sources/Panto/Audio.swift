import AVFoundation

/// Captures the microphone for voiceover. Sample buffers arrive on a private
/// queue and are timestampted with the host clock, same as ScreenCaptureKit.
final class MicrophoneCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    enum MicError: LocalizedError {
        case noDevice
        case cannotConfigure

        var errorDescription: String? {
            switch self {
            case .noDevice: return "No microphone found."
            case .cannotConfigure: return "Could not configure the microphone."
            }
        }
    }

    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "app.panto.microphone", qos: .userInitiated)

    var onSample: ((CMSampleBuffer) -> Void)?

    func start() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw MicError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw MicError.cannotConfigure }
        session.addInput(input)

        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw MicError.cannotConfigure }
        session.addOutput(output)

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
        DispatchQueue.global(qos: .utility).async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onSample?(sampleBuffer)
    }
}
