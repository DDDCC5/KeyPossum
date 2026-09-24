import AppKit
import Carbon
import CoreGraphics
import KeyPossumCore

struct InputSnapshot {
    let phase: Phase
    let progress: Double
    let remaining: Double
    let reason: FinishReason?
    let trial: Bool
    let reachedCleaning: Bool
    let error: String?
}

final class InputController {
    // ANSI physical positions. Labels describe keycaps, independent of the active IME.
    static let codes: [Character: Int] = [
        "A":0,"B":11,"C":8,"D":2,"E":14,"F":3,"G":5,"H":4,"J":38,"K":40,"L":37,
        "M":46,"N":45,"P":35,"Q":12,"R":15,"S":1,"T":17,"U":32,"V":9,"W":13,
        "X":7,"Y":16,"Z":6,"2":19,"3":20,"4":21,"5":23,"6":22,"7":26,"8":28,"9":25
    ]
    private let lock = NSLock()
    private var requestedStop: String?
    private var uiHeartbeat = Clock.now
    private var thread: Thread?
    private var tap: CFMachPort?
    private var session: Session
    private var pressed: Set<Int> = []
    private let trial: Bool
    private let fingerprint: String
    private let onSnapshot: (InputSnapshot) -> Void
    private var safety: SafetyProcess?
    private var reachedCleaning = false
    private var lastPublish: Double = 0
    private var lastSafetyBeat: Double = 0
    private var monitor: DispatchSourceTimer?

    init(code: String, trial: Bool, fingerprint: String, onSnapshot: @escaping (InputSnapshot) -> Void) {
        self.trial = trial
        self.fingerprint = fingerprint
        self.onSnapshot = onSnapshot
        session = Session(keys: Set(code.compactMap { Self.codes[$0] }), duration: trial ? 15 : 180)
    }

    static var permitted: Bool { AXIsProcessTrusted() && CGPreflightListenEventAccess() }
    static var secureInput: Bool { IsSecureEventInputEnabled() }

    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestListenEventAccess()
    }

    func heartbeat() { lock.lock(); uiHeartbeat = Clock.now; lock.unlock() }
    func stop(_ error: String = "cancelled") { lock.lock(); requestedStop = error; lock.unlock() }

    func start() {
        let worker = Thread { [self] in run() }
        worker.name = "KeyPossum input filter"
        worker.qualityOfService = .userInteractive
        thread = worker
        let monitor = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "KeyPossum device monitor"))
        monitor.schedule(deadline: .now() + 1, repeating: 1)
        monitor.setEventHandler { [weak self] in
            guard let self else { return }
            if DeviceInventory.fingerprint() != self.fingerprint { self.stop("devices") }
        }
        self.monitor = monitor
        monitor.resume()
        worker.start()
    }

    private func run() {
        do { safety = try SafetyProcess() }
        catch { complete(error: "watchdog"); return }
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask.max,
            callback: { _, type, event, data in
                guard let data else { return Unmanaged.passUnretained(event) }
                return Unmanaged<InputController>.fromOpaque(data).takeUnretainedValue().handle(type, event)
            }, userInfo: info) else { complete(error: "permissions"); return }
        self.tap = tap
        let runLoop = CFRunLoopGetCurrent()
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            complete(error: "tap"); return
        }
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        pressed = Set((0..<128).filter { CGEventSource.keyState(.hidSystemState, key: CGKeyCode($0)) })
        let heldMouse = (0..<32).contains { value in
            guard let button = CGMouseButton(rawValue: UInt32(value)) else { return false }
            return CGEventSource.buttonState(.hidSystemState, button: button)
        }
        guard pressed.isEmpty && !heldMouse else {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            complete(error: "release-initial"); return
        }
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(), 0.02, 0, 0) { [weak self] _ in
            self?.pulse()
        }
        CFRunLoopAddTimer(runLoop, timer, .commonModes)
        publish()
        while session.phase != .finished { CFRunLoopRunInMode(.defaultMode, 0.1, true) }
        CFRunLoopTimerInvalidate(timer)
        CFRunLoopRemoveSource(runLoop, source, .commonModes)
        complete(error: requestedError())
    }

    private func requestedError() -> String? {
        lock.lock(); defer { lock.unlock() }; return requestedStop
    }

    private func pulse() {
        lock.lock(); let stop = requestedStop; let lastUI = uiHeartbeat; lock.unlock()
        if stop != nil { session.finish(stop == "cancelled" ? .cancelled : .failure) }
        else if Clock.now - lastUI > 2 { self.stop("heartbeat"); session.finish(.failure) }
        else if !Self.permitted || Self.secureInput { self.stop("permissions"); session.finish(.failure) }
        else if let tap, !CGEvent.tapIsEnabled(tap: tap) { self.stop("tap"); session.finish(.failure) }
        // Reserve cleanup time inside the hard bound so ordinary timeout does
        // not race the supervisor and terminate an otherwise healthy window.
        if let deadline = session.deadline, Clock.now >= deadline - 0.25, session.phase != .finished {
            session.finish(.timeout)
        }
        if session.phase != .finished { session.tick(now: Clock.now) }
        if session.phase == .cleaning { reachedCleaning = true }
        if Clock.now - lastSafetyBeat >= 0.15 {
            lastSafetyBeat = Clock.now
            if safety?.beat(deadline: session.deadline) != true {
                self.stop("watchdog"); session.finish(.failure)
            }
        }
        // Ended is published only after removing the tap in complete().
        if session.phase != .finished && Clock.now - lastPublish >= 0.05 { publish() }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop("tap"); session.finish(.failure)
            return Unmanaged.passUnretained(event)
        }
        let phaseBefore = session.phase
        // Programmatic events are suppressed while locked, but cannot satisfy the chord.
        let physical = event.getIntegerValueField(.eventSourceUnixProcessID) == 0
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if physical && (type == .keyDown || type == .keyUp) {
            if type == .keyDown { pressed.insert(key) } else { pressed.remove(key) }
            session.update(keys: pressed, now: Clock.now)
        } else if physical && type == .flagsChanged {
            pressed = ModifierState.applying(flags: event.flags.rawValue, to: pressed)
            session.update(keys: pressed, now: Clock.now)
        } else if physical && type.rawValue == 14 {
            switch MediaEventDecoder.decode(event) {
            case .value(let transition):
                if let transition {
                    if transition.isDown { pressed.insert(transition.key) }
                    else { pressed.remove(transition.key) }
                    session.update(keys: pressed, now: Clock.now)
                } else { session.activity(now: Clock.now) }
            case .unavailable:
                // Fail open through normal tap cleanup if the UI cannot decode promptly.
                stop("event-decoding"); session.finish(.failure)
            }
        } else {
            session.activity(now: Clock.now)
        }
        // Verification consumes keyboard input locally. Pointer input remains usable until cleaning.
        let locked = phaseBefore == .cleaning || phaseBefore == .draining
        if locked { return nil }
        if type == .keyDown || type == .keyUp || type == .flagsChanged { return nil }
        return Unmanaged.passUnretained(event)
    }

    private func publish(error: String? = nil) {
        lastPublish = Clock.now
        let value = InputSnapshot(phase: session.phase, progress: session.progress(now: Clock.now),
            remaining: session.remaining(now: Clock.now), reason: session.reason, trial: trial,
            reachedCleaning: reachedCleaning, error: error)
        DispatchQueue.main.async { [onSnapshot] in onSnapshot(value) }
    }

    private func complete(error: String?) {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        tap = nil
        monitor?.cancel(); monitor = nil
        safety?.stop(); safety = nil
        if session.phase != .finished { session.finish(.failure) }
        publish(error: error)
        thread = nil
    }
}
