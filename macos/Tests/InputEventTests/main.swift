import AppKit

func check(_ condition: Bool, _ message: String) {
    if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

let finished = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    let result = MediaEventDecoder.onMain { Thread.isMainThread }
    if case .value(let isMain) = result { check(isMain, "AppKit conversion must execute on main thread") }
    else { check(false, "main thread available") }
    finished.signal()
}
while finished.wait(timeout: .now()) != .success {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
}
print("PASS background conversion executes on main thread")

// Deliberately leave the main queue blocked. The input worker must return quickly.
let timedOut = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    let start = ProcessInfo.processInfo.systemUptime
    let result = MediaEventDecoder.onMain(timeout: 0.02) { true }
    if case .unavailable = result {} else { check(false, "blocked UI must time out") }
    check(ProcessInfo.processInfo.systemUptime - start < 0.5, "input filter must not wait indefinitely")
    timedOut.signal()
}
check(timedOut.wait(timeout: .now() + 1) == .success, "worker cannot deadlock with main")
print("PASS blocked main thread returns unavailable")

for state in [0x0a, 0x0b] {
    let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, subtype: 8, data1: (16 << 16) | (state << 8), data2: -1)!.cgEvent!
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        switch MediaEventDecoder.decode(event) {
        case .value(let transition): check(transition == MediaKeyTransition(key: 1016, isDown: state == 0x0a), "media key transition preserved")
        case .unavailable: check(false, "conversion available")
        }
        done.signal()
    }
    while done.wait(timeout: .now()) != .success { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005)) }
}
print("PASS media key down and up decode from background caller")
