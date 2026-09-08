/// Physical, event-time modifier bits from IOKit/hidsystem/IOLLEvent.h.
/// Do not query the live keyboard here: queued press/release events may be older.
public enum ModifierState {
    private static let masks: [(Int, UInt64)] = [
        (59, 0x00000001), (56, 0x00000002), (60, 0x00000004),
        (55, 0x00000008), (54, 0x00000010), (58, 0x00000020),
        (61, 0x00000040), (57, 0x00000080), (62, 0x00002000),
        (63, 0x00800000)
    ]
    public static func applying(flags: UInt64, to current: Set<Int>) -> Set<Int> {
        var result = current
        for (key, mask) in masks {
            if flags & mask != 0 { result.insert(key) } else { result.remove(key) }
        }
        return result
    }
}
