import Foundation
import IOKit.hid

enum DeviceInventory {
    /// Identifiers only, never reports or key values. Changes invalidate qualification.
    static func fingerprint() -> String? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else { return nil }
        let names = devices.map { device -> String in
            let keys = [kIOHIDVendorIDKey, kIOHIDProductIDKey, kIOHIDLocationIDKey, kIOHIDTransportKey, kIOHIDProductKey]
            return keys.map { String(describing: IOHIDDeviceGetProperty(device, $0 as CFString) ?? "-" as CFString) }.joined(separator: ":")
        }.sorted()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"
        return ([version, ProcessInfo.processInfo.operatingSystemVersionString] + names).joined(separator: "|")
    }
}
