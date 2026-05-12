import AppKit
import Foundation

/// Best-effort hide of the macOS Control Center battery menu bar item.
///
/// macOS provides no public API for this, so we do two things:
/// 1. Write the undocumented `com.apple.controlcenter` defaults key that
///    governs the Battery module's menu bar visibility, then restart
///    ControlCenter so the change takes effect.
/// 2. Open System Settings → Control Center so the user can verify or
///    flip the toggle manually if Apple has changed the key on their
///    macOS version.
enum SystemBatteryIndicator {
    static func hide() {
        attemptDefaultsToggle()
        openControlCenterSettings()
    }

    /// Visibility values used by Control Center's defaults plist:
    ///   2 = show in menu bar, 8 = don't show, 24 = show in both.
    private static func attemptDefaultsToggle() {
        let domain = "com.apple.controlcenter"
        let keys = ["Battery", "BatteryShowPercentage"]

        // Set Battery visibility to "don't show in menu bar" (8).
        for key in keys {
            let task = Process()
            task.launchPath = "/usr/bin/defaults"
            task.arguments = ["-currentHost", "write", domain, key, "-int", "8"]
            try? task.run()
            task.waitUntilExit()

            let task2 = Process()
            task2.launchPath = "/usr/bin/defaults"
            task2.arguments = ["write", domain, key, "-int", "8"]
            try? task2.run()
            task2.waitUntilExit()
        }

        // Restart ControlCenter so the menu bar reloads.
        let killall = Process()
        killall.launchPath = "/usr/bin/killall"
        killall.arguments = ["ControlCenter"]
        try? killall.run()
        killall.waitUntilExit()
    }

    private static func openControlCenterSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.controlcenter",
        ]
        for s in urls {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { return }
        }
    }
}
