import Foundation
import IOKit.ps
import Combine

final class BatteryMonitor: ObservableObject {
    @Published private(set) var percentage: Int = 0
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false

    private var runLoopSource: CFRunLoopSource?
    var onChange: ((Int, Bool, Bool) -> Void)?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
    }

    private func startObserving() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx else { return }
            let mySelf = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { mySelf.refresh() }
        }
        if let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = src
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
    }

    func refresh() {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for src in sources {
            guard let info = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let state = info[kIOPSPowerSourceStateKey] as? String ?? ""
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let pct = max > 0 ? Int(round(Double(current) / Double(max) * 100.0)) : 0
            let plugged = (state == kIOPSACPowerValue)

            let oldPct = percentage
            let oldCharging = isCharging
            let oldPlugged = isPluggedIn
            percentage = pct
            isCharging = charging
            isPluggedIn = plugged

            if pct != oldPct || charging != oldCharging || plugged != oldPlugged {
                onChange?(pct, charging, plugged)
            }
            return
        }
    }
}
