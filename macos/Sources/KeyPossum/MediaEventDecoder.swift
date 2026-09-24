import AppKit

struct MediaKeyTransition: Equatable {
    let key: Int
    let isDown: Bool
}

enum MediaEventDecoder {
    enum Result<Value> {
        case value(Value)
        case unavailable
    }

    private final class Pending<Value> {
        let lock = NSLock()
        var result: Result<Value> = .unavailable
        var expired = false
    }

    // NSEvent can enter HIToolbox's main-queue-only input-source handling.
    // Never dispatch synchronously: a busy UI must not strand the input tap.
    static func onMain<Value>(timeout: TimeInterval = 0.05, _ operation: @escaping () -> Value) -> Result<Value> {
        if Thread.isMainThread { return .value(operation()) }
        let pending = Pending<Value>()
        let ready = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            pending.lock.lock()
            let expired = pending.expired
            pending.lock.unlock()
            guard !expired else { return }
            let value = operation()
            pending.lock.lock()
            if !pending.expired { pending.result = .value(value) }
            pending.lock.unlock()
            ready.signal()
        }
        let completed = ready.wait(timeout: .now() + timeout) == .success
        pending.lock.lock()
        defer { pending.lock.unlock() }
        if !completed { pending.expired = true; return .unavailable }
        return pending.result
    }

    static func decode(_ event: CGEvent) -> Result<MediaKeyTransition?> {
        guard let copy = event.copy() else { return .unavailable }
        return onMain {
            guard let native = NSEvent(cgEvent: copy), native.subtype.rawValue == 8 else { return nil }
            let state = (native.data1 >> 8) & 0xff
            guard state == 0x0a || state == 0x0b else { return nil }
            return MediaKeyTransition(key: 1000 + ((native.data1 >> 16) & 0xffff), isDown: state == 0x0a)
        }
    }
}
