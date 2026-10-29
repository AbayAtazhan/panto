import Foundation

/// Tiny append-only log at ~/Library/Logs/Panto.log. Used for permission and
/// hotkey diagnostics that are hard to reproduce from the UI.
enum Log {
    private static let queue = DispatchQueue(label: "app.panto.log")

    static let url: URL = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Panto.log")
    }()

    static func write(_ message: String) {
        queue.async {
            let stamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(stamp) \(message)\n"
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
