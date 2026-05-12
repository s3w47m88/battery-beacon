import Foundation
import UserNotifications
import AppKit

final class AlertManager {
    static let shared = AlertManager()

    private var firedThresholds: Set<Int> = []
    private var lastPercentage: Int = -1

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func handleUpdate(percentage: Int, isCharging: Bool, isPluggedIn: Bool, settings: AppSettings) {
        defer { lastPercentage = percentage }

        // Reset fired thresholds when battery drops below the lowest threshold or unplugged
        if !isPluggedIn || percentage < (settings.thresholds.min() ?? 0) {
            firedThresholds.removeAll()
            return
        }

        // Only alert when plugged in and charging up
        guard isPluggedIn else { return }

        for threshold in settings.thresholds.sorted() {
            if percentage >= threshold && !firedThresholds.contains(threshold) {
                firedThresholds.insert(threshold)
                fireAlert(threshold: threshold, percentage: percentage, playSound: settings.playSound)
            }
        }
    }

    private func fireAlert(threshold: Int, percentage: Int, playSound: Bool) {
        let content = UNMutableNotificationContent()
        if threshold >= 100 {
            content.title = "Battery Fully Charged"
            content.body = "Your Mac is at \(percentage)%. Unplug to preserve battery health."
        } else {
            content.title = "Battery at \(threshold)%"
            content.body = "Charging is approaching full (\(percentage)%)."
        }
        if playSound {
            content.sound = .default
        }
        let req = UNNotificationRequest(identifier: "battery-\(threshold)-\(Date().timeIntervalSince1970)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
