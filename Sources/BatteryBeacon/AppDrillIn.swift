import AppKit
import ApplicationServices

enum DrillInResult {
    case opened
    case hint(message: String)
}

enum AppDrillIn {
    private static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "company.thebrowser.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    static func openResourceMonitor(for app: AppEnergy) -> DrillInResult {
        guard let bundleID = app.bundleIdentifier else {
            return openActivityMonitor()
        }
        if chromiumBundleIDs.contains(bundleID) {
            return drillIntoChromium(bundleID: bundleID, appName: app.displayName)
        }
        if bundleID == "com.apple.Safari" {
            return drillIntoSafari()
        }
        if bundleID == "org.mozilla.firefox" {
            return drillIntoFirefox()
        }
        return openActivityMonitor()
    }

    private static func drillIntoChromium(bundleID: String, appName: String) -> DrillInResult {
        guard activate(bundleIdentifier: bundleID) else {
            return openActivityMonitor()
        }
        return sendKeystroke(
            keyCode: 0x35,
            flags: .maskShift,
            hint: "Press ⇧⎋ in \(appName) to see per-tab energy."
        )
    }

    private static func drillIntoSafari() -> DrillInResult {
        guard activate(bundleIdentifier: "com.apple.Safari") else {
            return openActivityMonitor()
        }
        return sendKeystroke(
            keyCode: 0x00,
            flags: [.maskCommand, .maskAlternate],
            hint: "Open Window → Activity in Safari to see per-tab energy."
        )
    }

    private static func drillIntoFirefox() -> DrillInResult {
        guard activate(bundleIdentifier: "org.mozilla.firefox") else {
            return openActivityMonitor()
        }
        let source = "tell application \"Firefox\" to open location \"about:performance\""
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&error)
            if error == nil {
                return .opened
            }
        }
        return .hint(message: "Open about:performance in Firefox to see per-tab energy.")
    }

    private static func activate(bundleIdentifier: String) -> Bool {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return false
        }
        return running.activate()
    }

    private static func sendKeystroke(keyCode: CGKeyCode, flags: CGEventFlags, hint: String) -> DrillInResult {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options: CFDictionary = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            return .hint(message: hint)
        }
        // `activate()` is fire-and-forget — the focus change is async. Posting
        // the keystroke immediately sends it to whatever app is currently
        // frontmost (often ours). Delay long enough for the target app to
        // become frontmost.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let src = CGEventSource(stateID: .combinedSessionState)
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else {
                return
            }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
        return .opened
    }

    private static func openActivityMonitor() -> DrillInResult {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        if FileManager.default.fileExists(atPath: url.path) {
            if NSWorkspace.shared.open(url) {
                return .opened
            }
        }
        let legacyURL = URL(fileURLWithPath: "/Applications/Utilities/Activity Monitor.app")
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            if NSWorkspace.shared.open(legacyURL) {
                return .opened
            }
        }
        return .hint(message: "Couldn't open Activity Monitor.")
    }
}
