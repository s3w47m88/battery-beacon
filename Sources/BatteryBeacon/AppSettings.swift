import Foundation
import Combine
import ServiceManagement

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var thresholds: [Int] {
        didSet { defaults.set(thresholds, forKey: "thresholds") }
    }

    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: "playSound") }
    }

    @Published var showPercentageInIcon: Bool {
        didSet { defaults.set(showPercentageInIcon, forKey: "showPercentageInIcon") }
    }

    @Published var openOnStartup: Bool {
        didSet {
            defaults.set(openOnStartup, forKey: "openOnStartup")
            applyOpenOnStartup()
        }
    }

    @Published var peripheralAlertsEnabled: Bool {
        didSet { defaults.set(peripheralAlertsEnabled, forKey: "peripheralAlertsEnabled") }
    }

    @Published var peripheralLowThreshold: Int {
        didSet { defaults.set(peripheralLowThreshold, forKey: "peripheralLowThreshold") }
    }

    @Published var peripheralCriticalThreshold: Int {
        didSet { defaults.set(peripheralCriticalThreshold, forKey: "peripheralCriticalThreshold") }
    }

    @Published var analyticsEnabled: Bool {
        didSet { defaults.set(analyticsEnabled, forKey: "analyticsEnabled") }
    }

    /// Whether we've shown the first-run analytics consent prompt yet.
    @Published var analyticsConsentAsked: Bool {
        didSet { defaults.set(analyticsConsentAsked, forKey: "analyticsConsentAsked") }
    }

    init() {
        if let arr = UserDefaults.standard.array(forKey: "thresholds") as? [Int], !arr.isEmpty {
            self.thresholds = arr
        } else {
            self.thresholds = [95, 100]
        }
        self.playSound = (UserDefaults.standard.object(forKey: "playSound") as? Bool) ?? true
        self.showPercentageInIcon = (UserDefaults.standard.object(forKey: "showPercentageInIcon") as? Bool) ?? true
        // Default OFF: Mac App Store guideline 2.4.5(iii) forbids auto-launching
        // at login without explicit user consent. The user opts in via Settings.
        self.openOnStartup = (UserDefaults.standard.object(forKey: "openOnStartup") as? Bool) ?? false
        self.peripheralAlertsEnabled = (UserDefaults.standard.object(forKey: "peripheralAlertsEnabled") as? Bool) ?? true
        self.peripheralLowThreshold = (UserDefaults.standard.object(forKey: "peripheralLowThreshold") as? Int) ?? 20
        self.peripheralCriticalThreshold = (UserDefaults.standard.object(forKey: "peripheralCriticalThreshold") as? Int) ?? 10
        // Default OFF: guideline 5.1.2 requires explicit consent before any
        // personal data is uploaded. Enabled only after the first-run consent
        // prompt (or the Settings toggle).
        self.analyticsEnabled = (UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool) ?? false
        self.analyticsConsentAsked = (UserDefaults.standard.object(forKey: "analyticsConsentAsked") as? Bool) ?? false
        applyOpenOnStartup()
    }

    func applyOpenOnStartup() {
        let service = SMAppService.mainApp
        do {
            if openOnStartup {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            NSLog("openOnStartup toggle failed: \(error.localizedDescription)")
        }
    }

    func setThreshold(at index: Int, to value: Int) {
        guard index >= 0 && index < thresholds.count else { return }
        var copy = thresholds
        copy[index] = min(100, max(1, value))
        thresholds = copy
    }

    func addThreshold(_ value: Int) {
        let v = min(100, max(1, value))
        guard !thresholds.contains(v) else { return }
        thresholds = (thresholds + [v]).sorted()
    }

    func removeThreshold(at index: Int) {
        guard index >= 0 && index < thresholds.count else { return }
        var copy = thresholds
        copy.remove(at: index)
        thresholds = copy
    }
}
