import Foundation

public enum Combination {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static func normalize(_ value: String) -> String? {
        // Reject Unicode before case conversion (e.g. full-width letters).
        guard value.utf8.count == 4, value.unicodeScalars.allSatisfy({ $0.isASCII }) else { return nil }
        let result = value.uppercased()
        guard Set(result).count == 4, result.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return result
    }
    public static func random() -> String { String(alphabet.shuffled().prefix(4)) }
}

public enum Phase: String { case checking, releaseToPrepare, preparing, cleaning, draining, finished }
public enum FinishReason: String { case chord, timeout, cancelled, failure }

/// Pure monotonic state machine; no IO, timers, OS hooks or UI access.
public struct Session {
    public private(set) var phase: Phase = .checking
    public private(set) var reason: FinishReason?
    public private(set) var pressed: Set<Int> = []
    public private(set) var deadline: Double?
    private let chord: Set<Int>
    private let duration: Double
    private var prepareAt: Double?
    private var holdAt: Double?
    private var drainAt: Double?
    private var lastTime: Double = 0

    public init(keys: Set<Int>, duration: Double = 180) {
        precondition(keys.count == 4)
        precondition(duration > 0 && duration <= 180)
        chord = keys
        self.duration = duration
    }

    public mutating func update(keys: Set<Int>, now: Double) {
        pressed = keys
        if phase == .preparing && !keys.isEmpty {
            phase = .checking
            prepareAt = nil
        }
        tick(now: now)
    }

    public mutating func activity(now: Double) {
        if phase == .preparing || phase == .releaseToPrepare {
            phase = .checking
            prepareAt = nil
        }
        // Do not call tick here: a non-key event must not revalidate the old chord.
        lastTime = max(lastTime, now)
    }

    public mutating func tick(now supplied: Double) {
        guard supplied.isFinite else { return }
        let now = max(lastTime, supplied)
        lastTime = now
        if let deadline, now >= deadline, phase != .finished {
            finish(.timeout)
            return
        }
        switch phase {
        case .checking:
            if pressed == chord { phase = .releaseToPrepare }
        case .releaseToPrepare:
            if !pressed.isSubset(of: chord) { phase = .checking }
            else if pressed.isEmpty { phase = .preparing; prepareAt = now }
        case .preparing:
            if let prepareAt, now - prepareAt >= 3 {
                phase = .cleaning
                deadline = now + duration
            }
        case .cleaning:
            if pressed == chord {
                if holdAt == nil { holdAt = now }
                if now - (holdAt ?? now) >= 5 {
                    phase = .draining
                    reason = .chord
                    drainAt = now
                }
            } else { holdAt = nil }
        case .draining:
            if pressed.isEmpty || now - (drainAt ?? now) >= 1.5 { finish(.chord) }
        case .finished: break
        }
    }

    public mutating func finish(_ reason: FinishReason) {
        self.reason = reason
        phase = .finished
        holdAt = nil
    }

    public func progress(now: Double) -> Double {
        if phase == .draining { return 1 }
        guard phase == .cleaning, pressed == chord, let holdAt else { return 0 }
        return min(1, max(0, (now - holdAt) / 5))
    }

    public func remaining(now: Double) -> Double {
        if phase == .preparing { return max(0, 3 - (now - (prepareAt ?? now))) }
        if let deadline { return max(0, deadline - now) }
        return duration
    }
}
