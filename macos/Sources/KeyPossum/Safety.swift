import Foundation
import Darwin

enum Clock {
    static var now: Double { ProcessInfo.processInfo.systemUptime }
}

/// Child process owns no input devices. EOF means its parent finished or exited.
/// A live but unresponsive owner is terminated so WindowServer removes its tap.
enum Watchdog {
    static func run(parent: pid_t) -> Never {
        guard parent == getppid(), parent > 1 else { exit(2) }
        var lastBeat = Clock.now
        var deadline = Double.infinity
        var buffer = ""
        _ = fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK)
        while getppid() == parent {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN | POLLHUP), revents: 0)
            let ready = poll(&descriptor, 1, 100)
            // stop() closes the pipe only after removing the tap. A queued old
            // deadline must never kill the owner after orderly shutdown.
            if descriptor.revents & Int16(POLLHUP) != 0 { exit(0) }
            if ready > 0 {
              while true {
                var bytes = [UInt8](repeating: 0, count: 512)
                let count = read(STDIN_FILENO, &bytes, bytes.count)
                if count == 0 { exit(0) }
                if count < 0 {
                    if errno == EAGAIN || errno == EWOULDBLOCK { break }
                    exit(2)
                }
                buffer += String(decoding: bytes.prefix(count), as: UTF8.self)
                while let end = buffer.firstIndex(of: "\n") {
                    let line = String(buffer[..<end])
                    buffer.removeSubrange(...end)
                    if let value = Double(line), value.isFinite {
                        lastBeat = Clock.now
                        deadline = value > 0 ? value : .infinity
                    }
                }
                if buffer.count > 2048 { exit(2) }
              }
            }
            if Clock.now - lastBeat > 4 || Clock.now >= deadline {
                if getppid() == parent { kill(parent, SIGKILL) }
                exit(0)
            }
        }
        exit(0)
    }
}

final class SafetyProcess {
    private let process = Process()
    private let pipe = Pipe()
    init() throws {
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["--watchdog", String(getpid())]
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        pipe.fileHandleForReading.closeFile()
    }
    func beat(deadline: Double?) -> Bool {
        guard process.isRunning else { return false }
        do {
            try pipe.fileHandleForWriting.write(contentsOf: Data("\(deadline ?? 0)\n".utf8))
            return true
        } catch { return false }
    }
    func stop() { try? pipe.fileHandleForWriting.close() }
    deinit { stop() }
}
