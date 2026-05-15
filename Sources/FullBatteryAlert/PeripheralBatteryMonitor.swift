import Foundation
import IOKit
import Combine

enum PeripheralKind: String {
    case mouse, keyboard, trackpad, airpods, other

    var sfSymbol: String {
        switch self {
        case .mouse: return "magicmouse"
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .airpods: return "airpods"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }
}

struct PeripheralDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: PeripheralKind
    let percent: Int
    let isCharging: Bool
    let lastSeen: Date
}

final class PeripheralBatteryMonitor: ObservableObject {
    @Published private(set) var devices: [PeripheralDevice] = []

    /// Per-device set of fired low/critical thresholds, keyed by device id.
    /// Reset when device crosses back above the threshold or disconnects.
    private var firedLow: Set<String> = []
    private var firedCritical: Set<String> = []

    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    var onLowBattery: ((PeripheralDevice, Bool /* isCritical */) -> Void)?

    init() {
        startObserving()
        refresh()
    }

    deinit {
        for it in iterators { IOObjectRelease(it) }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
        }
    }

    private func startObserving() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else { return }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        notifyPort = port

        let classes = ["AppleDeviceManagementHIDEventService", "BluetoothDevice"]
        for cls in classes {
            guard let match = IOServiceMatching(cls) else { continue }
            let matchAdded = match as CFDictionary
            let matchRemoved = (match as NSDictionary).mutableCopy() as! CFMutableDictionary

            let ctx = Unmanaged.passUnretained(self).toOpaque()
            let callback: IOServiceMatchingCallback = { ctx, iterator in
                guard let ctx else { return }
                let mySelf = Unmanaged<PeripheralBatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
                // Drain iterator
                while case let svc = IOIteratorNext(iterator), svc != 0 {
                    IOObjectRelease(svc)
                }
                DispatchQueue.main.async { mySelf.refresh() }
            }

            var addedIter: io_iterator_t = 0
            if IOServiceAddMatchingNotification(port, kIOMatchedNotification, matchAdded, callback, ctx, &addedIter) == KERN_SUCCESS {
                iterators.append(addedIter)
                while case let svc = IOIteratorNext(addedIter), svc != 0 {
                    IOObjectRelease(svc)
                }
            }
            var removedIter: io_iterator_t = 0
            if IOServiceAddMatchingNotification(port, kIOTerminatedNotification, matchRemoved, callback, ctx, &removedIter) == KERN_SUCCESS {
                iterators.append(removedIter)
                while case let svc = IOIteratorNext(removedIter), svc != 0 {
                    IOObjectRelease(svc)
                }
            }
        }
    }

    /// Re-scan the IORegistry for connected HID/Bluetooth devices that
    /// publish a `BatteryPercent` property. Read-only — no Bluetooth scan.
    func refresh() {
        var found: [PeripheralDevice] = []
        var seenIDs = Set<String>()

        scan(className: "AppleDeviceManagementHIDEventService", into: &found, seen: &seenIDs)
        scan(className: "IOBluetoothHIDDriver", into: &found, seen: &seenIDs)

        // Stable order by kind then name.
        found.sort { ($0.kind.rawValue, $0.name) < ($1.kind.rawValue, $1.name) }
        if found != devices {
            devices = found
        }

        // Drop fired thresholds for devices that vanished.
        let ids = Set(found.map { $0.id })
        firedLow = firedLow.intersection(ids)
        firedCritical = firedCritical.intersection(ids)
    }

    private func scan(className: String, into out: inout [PeripheralDevice], seen: inout Set<String>) {
        guard let match = IOServiceMatching(className) else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = makeDevice(service: service), !seen.contains(device.id) {
                seen.insert(device.id)
                out.append(device)
            }
        }
    }

    private func makeDevice(service: io_service_t) -> PeripheralDevice? {
        guard let percent = readNumber(service: service, key: "BatteryPercent") else { return nil }
        guard percent >= 0 && percent <= 100 else { return nil }

        let product = (readProperty(service: service, key: "Product") as? String)
            ?? (readProperty(service: service, key: "kProductName") as? String)
            ?? "Bluetooth Device"

        let charging = (readProperty(service: service, key: "BatteryIsCharging") as? Bool)
            ?? ((readNumber(service: service, key: "BatteryIsCharging") ?? 0) != 0)

        let kind = classify(name: product)

        let id: String = {
            if let addr = readProperty(service: service, key: "DeviceAddress") as? String { return addr }
            if let serial = readProperty(service: service, key: "SerialNumber") as? String { return serial }
            return "\(product)-\(kind.rawValue)"
        }()

        return PeripheralDevice(
            id: id,
            name: product,
            kind: kind,
            percent: Int(percent),
            isCharging: charging,
            lastSeen: Date()
        )
    }

    private func classify(name: String) -> PeripheralKind {
        let n = name.lowercased()
        if n.contains("airpods") || n.contains("beats") { return .airpods }
        if n.contains("trackpad") { return .trackpad }
        if n.contains("keyboard") { return .keyboard }
        if n.contains("mouse") { return .mouse }
        return .other
    }

    private func readProperty(service: io_service_t, key: String) -> Any? {
        guard let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return prop
    }

    private func readNumber(service: io_service_t, key: String) -> Int64? {
        guard let prop = readProperty(service: service, key: key) as? NSNumber else { return nil }
        return prop.int64Value
    }

    func evaluateAlerts(lowThreshold: Int, criticalThreshold: Int) {
        for device in devices {
            if device.isCharging {
                firedLow.remove(device.id)
                firedCritical.remove(device.id)
                continue
            }
            if device.percent > lowThreshold {
                firedLow.remove(device.id)
            }
            if device.percent > criticalThreshold {
                firedCritical.remove(device.id)
            }
            if device.percent <= criticalThreshold && !firedCritical.contains(device.id) {
                firedCritical.insert(device.id)
                onLowBattery?(device, true)
            } else if device.percent <= lowThreshold && !firedLow.contains(device.id) {
                firedLow.insert(device.id)
                onLowBattery?(device, false)
            }
        }
    }
}
