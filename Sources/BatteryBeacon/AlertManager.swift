import Foundation
import UserNotifications

final class AlertManager {
    static let shared = AlertManager()

    private var firedThresholds: Set<Int> = []
    private var requestedAuth = false
    private init() {}

    func notifyPeripheralLow(device: PeripheralDevice, isCritical: Bool) {
        requestAuthIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = isCritical ? "\(device.name) battery critical" : "\(device.name) battery low"
        content.body = "Battery at \(device.percent)%. Charge soon."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "peripheral.\(device.id).\(isCritical ? "crit" : "low")",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func requestAuthIfNeeded() {
        guard !requestedAuth else { return }
        requestedAuth = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func handleUpdate(percentage: Int, isCharging: Bool, isPluggedIn: Bool,
                      settings: AppSettings,
                      onFire: (Int) -> Void) {
        // Reset when unplugged or below the lowest threshold
        if !isPluggedIn || percentage < (settings.thresholds.min() ?? 0) {
            firedThresholds.removeAll()
            return
        }
        for threshold in settings.thresholds.sorted() {
            if percentage >= threshold && !firedThresholds.contains(threshold) {
                firedThresholds.insert(threshold)
                onFire(threshold)
            }
        }
    }
}
