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

    init() {
        if let arr = UserDefaults.standard.array(forKey: "thresholds") as? [Int], !arr.isEmpty {
            self.thresholds = arr
        } else {
            self.thresholds = [95, 100]
        }
        self.playSound = (UserDefaults.standard.object(forKey: "playSound") as? Bool) ?? true
        self.showPercentageInIcon = (UserDefaults.standard.object(forKey: "showPercentageInIcon") as? Bool) ?? true
        self.openOnStartup = (UserDefaults.standard.object(forKey: "openOnStartup") as? Bool) ?? true
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
