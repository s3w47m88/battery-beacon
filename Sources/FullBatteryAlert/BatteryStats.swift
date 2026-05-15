import Foundation
import IOKit
import IOKit.ps
import AppKit
import Combine

/// Observable model exposing detailed battery telemetry (temperature, mAh,
/// age, manufactured date, time-to-full/empty, macOS health string/condition,
/// cycle count, health %, replacement-date estimate) with a low-impact
/// "smart scan" loop.
///
/// Smart scan strategy:
/// - One IOPS + AppleSmartBattery read per tick feeds every @Published field.
/// - Cadence: 60s on battery, 30s plugged-and-charging, 5s in the final 5%
///   approaching full.
/// - IOPSNotificationCreateRunLoopSource drives event-based refreshes so we
///   refresh on real power-source changes, not just on a timer.
/// - Polling pauses when the app is inactive and no alert is pending.
/// - IOKit-only; no Bluetooth, no network.
@MainActor
final class BatteryStats: ObservableObject {
    // Temperature
    @Published var temperatureCelsius: Double? = nil
    @Published var temperatureFahrenheit: Double? = nil

    // Capacity in mAh
    @Published var currentCapacityMah: Int? = nil
    @Published var maxCapacityMah: Int? = nil
    @Published var designCapacityMah: Int? = nil

    // Age / manufactured date
    @Published var ageYears: Int? = nil
    @Published var ageMonths: Int? = nil
    @Published var manufacturedDate: Date? = nil

    // Time estimates
    @Published var timeToFullMinutes: Int? = nil
    @Published var timeToEmptyMinutes: Int? = nil

    // macOS-reported health
    @Published var macOSHealthStatus: String? = nil
    @Published var macOSHealthCondition: String? = nil

    // Cycles / health % / replacement projection
    @Published var cycleCount: Int? = nil
    @Published var healthPercent: Int? = nil
    @Published var estimatedReplacementDate: Date? = nil

    // State used to drive cadence
    @Published private(set) var percentage: Int = 0
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false

    /// Apple's rated cycle count for modern Mac notebook batteries.
    static let maxCycles: Int = 1000

    /// Set true when an alert window is pending so we don't pause polling.
    var alertPending: Bool = false {
        didSet { rescheduleTimer() }
    }

    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    func start() {
        refresh()
        startObservingPowerSource()
        observeWorkspace()
        rescheduleTimer()
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .defaultMode)
            runLoopSource = nil
        }
        timer?.invalidate()
        timer = nil
        for token in workspaceObservers {
            NotificationCenter.default.removeObserver(token)
        }
        workspaceObservers.removeAll()
    }

    deinit {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
        timer?.invalidate()
        for token in workspaceObservers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Smart scan cadence

    private func currentInterval() -> TimeInterval {
        if isCharging && percentage >= 95 { return 5 }
        if isPluggedIn && isCharging { return 30 }
        return 60
    }

    private func shouldPause() -> Bool {
        if alertPending { return false }
        return !NSApp.isActive
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        if shouldPause() { return }
        let interval = currentInterval()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func observeWorkspace() {
        let nc = NotificationCenter.default
        let activate = nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.rescheduleTimer()
            }
        }
        let deactivate = nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rescheduleTimer() }
        }
        workspaceObservers = [activate, deactivate]
    }

    private func startObservingPowerSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx else { return }
            let mySelf = Unmanaged<BatteryStats>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                mySelf.refresh()
                mySelf.rescheduleTimer()
            }
        }
        if let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = src
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .defaultMode)
        }
    }

    // MARK: - One read per tick

    func refresh() {
        readIOPS()
        readSmartBattery()
    }

    private func readIOPS() {
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
            let toFullRaw = info[kIOPSTimeToFullChargeKey] as? Int ?? -1
            let toEmptyRaw = info[kIOPSTimeToEmptyKey] as? Int ?? -1

            assign(\.percentage, pct)
            assign(\.isCharging, charging)
            assign(\.isPluggedIn, plugged)
            assign(\.timeToFullMinutes, (charging && toFullRaw > 0) ? toFullRaw : nil)
            assign(\.timeToEmptyMinutes, (!plugged && toEmptyRaw > 0) ? toEmptyRaw : nil)
            assign(\.macOSHealthStatus, info[kIOPSBatteryHealthKey] as? String)
            assign(\.macOSHealthCondition, info[kIOPSBatteryHealthConditionKey] as? String)
            return
        }
    }

    private func readSmartBattery() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        if let tempRaw = readNumber(service: service, key: "Temperature") {
            let c = Double(tempRaw) / 100.0
            assign(\.temperatureCelsius, c)
            assign(\.temperatureFahrenheit, c * 9.0 / 5.0 + 32.0)
        }

        let design = readNumber(service: service, key: "DesignCapacity").map { Int($0) }
        let maxCap = (readNumber(service: service, key: "AppleRawMaxCapacity")
            ?? readNumber(service: service, key: "MaxCapacity")
            ?? readNumber(service: service, key: "NominalChargeCapacity")).map { Int($0) }
        let curCap = (readNumber(service: service, key: "AppleRawCurrentCapacity")
            ?? readNumber(service: service, key: "CurrentCapacity")).map { Int($0) }

        assign(\.designCapacityMah, design)
        assign(\.maxCapacityMah, maxCap)
        assign(\.currentCapacityMah, curCap)

        let newCycles = readNumber(service: service, key: "CycleCount").map { Int($0) }
        let newHealth: Int? = {
            guard let d = design, d > 0, let m = maxCap else { return nil }
            return Int(round(Double(m) / Double(d) * 100.0))
        }()
        assign(\.cycleCount, newCycles)
        assign(\.healthPercent, newHealth)
        if let c = newCycles { updateReplacementEstimate(currentCycles: c) }

        if let packed = readNumber(service: service, key: "ManufactureDate") {
            // Packed 16-bit: bits 15-9 = year-1980, bits 8-5 = month, bits 4-0 = day.
            let raw = Int(packed)
            let day = raw & 0x1F
            let month = (raw >> 5) & 0x0F
            let year = ((raw >> 9) & 0x7F) + 1980
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            if month >= 1, month <= 12, day >= 1, day <= 31,
               let date = Calendar.current.date(from: comps) {
                assign(\.manufacturedDate, date)
                let diff = Calendar.current.dateComponents([.year, .month], from: date, to: Date())
                assign(\.ageYears, max(0, diff.year ?? 0))
                assign(\.ageMonths, max(0, diff.month ?? 0))
            }
        }
    }

    private func updateReplacementEstimate(currentCycles: Int) {
        let defaults = UserDefaults.standard
        let baselineKey = "batteryStatsBaselineCycles"
        let baselineDateKey = "batteryStatsBaselineDate"

        let storedBaseline = defaults.object(forKey: baselineKey) as? Int
        let storedDate = defaults.object(forKey: baselineDateKey) as? Date

        guard let baseline = storedBaseline, let date = storedDate, currentCycles >= baseline else {
            defaults.set(currentCycles, forKey: baselineKey)
            defaults.set(Date(), forKey: baselineDateKey)
            assign(\.estimatedReplacementDate, nil)
            return
        }
        let elapsed = Date().timeIntervalSince(date)
        let cyclesUsed = currentCycles - baseline
        guard elapsed >= 86_400, cyclesUsed >= 1 else {
            assign(\.estimatedReplacementDate, nil)
            return
        }
        let cyclesPerSecond = Double(cyclesUsed) / elapsed
        let remaining = Double(BatteryStats.maxCycles - currentCycles)
        guard remaining > 0, cyclesPerSecond > 0 else {
            assign(\.estimatedReplacementDate, Date())
            return
        }
        assign(\.estimatedReplacementDate, Date().addingTimeInterval(remaining / cyclesPerSecond))
    }

    // MARK: - Helpers

    private func assign<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<BatteryStats, T>, _ newValue: T) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    private func readNumber(service: io_service_t, key: String) -> Int64? {
        guard let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        guard let num = prop as? NSNumber else { return nil }
        return num.int64Value
    }
}
