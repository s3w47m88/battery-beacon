import SwiftUI
import AppKit

@main
struct FullBatteryAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var battery = BatteryMonitor()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(settings: settings, battery: battery)
                .onAppear {
                    appDelegate.bind(settings: settings, battery: battery)
                }
        } label: {
            Text(label)
        }
        .menuBarExtraStyle(.window)
    }

    private var label: String {
        let pct = battery.percentage
        let bolt = battery.isCharging ? "⚡︎" : ""
        return "\(bolt)\(pct)%"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings?
    private var battery: BatteryMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func bind(settings: AppSettings, battery: BatteryMonitor) {
        guard self.battery !== battery else { return }
        self.settings = settings
        self.battery = battery
        battery.onChange = { [weak self] pct, charging, plugged in
            guard let self, let s = self.settings else { return }
            AlertManager.shared.handleUpdate(percentage: pct, isCharging: charging, isPluggedIn: plugged, settings: s)
        }
        // Fire initial check
        AlertManager.shared.handleUpdate(
            percentage: battery.percentage,
            isCharging: battery.isCharging,
            isPluggedIn: battery.isPluggedIn,
            settings: settings
        )
    }
}
