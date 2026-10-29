import Darwin
import Foundation

@main
enum Entry {
    static func main() {
        setvbuf(stdout, nil, _IONBF, 0)
        let args = CommandLine.arguments

        if args.contains("--selftest") {
            runBlocking {
                try await SelfTest.run()
            }
            exit(0)
        }

        if let i = args.firstIndex(of: "--gif"), args.count > i + 2 {
            let input = URL(fileURLWithPath: args[i + 1])
            let output = URL(fileURLWithPath: args[i + 2])
            let start = args.count > i + 3 ? (Double(args[i + 3]) ?? 0) : 0
            let duration = args.count > i + 4 ? (Double(args[i + 4]) ?? 6) : 6
            runBlocking {
                try await GIFMaker.make(input: input, output: output, start: start, duration: duration)
            }
            exit(0)
        }

        if let i = args.firstIndex(of: "--icon"), args.count > i + 1 {
            IconGen.write(to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }

        PantoApp.main()
    }
}

private final class TaskBox: @unchecked Sendable {
    var finished = false
    var error: Error?
}

/// Runs async command-line work while keeping the main run loop alive, so AppKit
/// and AVFoundation main-thread work can still be serviced.
private func runBlocking(_ body: @escaping () async throws -> Void) {
    let box = TaskBox()
    Task.detached {
        do {
            try await body()
        } catch {
            box.error = error
        }
        box.finished = true
    }

    while !box.finished {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
    }

    if let error = box.error {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }
}
