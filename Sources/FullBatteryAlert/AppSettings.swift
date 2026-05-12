import Foundation
import Combine

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard
    private let keyThresholds = "thresholds"
    private let keyPlaySound = "playSound"
    private let keyLaunchAtLogin = "launchAtLogin"

    @Published var thresholds: [Int] {
        didSet {
            defaults.set(thresholds, forKey: keyThresholds)
        }
    }

    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: keyPlaySound) }
    }

    init() {
        if let arr = UserDefaults.standard.array(forKey: "thresholds") as? [Int], !arr.isEmpty {
            self.thresholds = arr
        } else {
            self.thresholds = [95, 100]
        }
        if UserDefaults.standard.object(forKey: "playSound") != nil {
            self.playSound = UserDefaults.standard.bool(forKey: "playSound")
        } else {
            self.playSound = true
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
