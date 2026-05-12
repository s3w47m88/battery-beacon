# Energy-Drain List with Drill-In — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static `"No Apps Using Significant Energy"` line in the settings popover with a live top-energy-users list that drills into each app's native resource monitor (Chrome Task Manager, Safari Activity, etc.).

**Architecture:** Add `EnergyMonitor` (polls `top` while the popover is open and groups pids by `NSRunningApplication`), `EnergyListView` (SwiftUI list with tap rows), and `AppDrillIn` (routes a tapped app to its native resource monitor via keystroke synthesis / AppleScript / Activity Monitor fallback). Inject into existing `SettingsView` and lifecycle-manage from `AppDelegate.toggleSettings(_:)`.

**Tech Stack:** Swift, SwiftUI, AppKit, Foundation `Process`, `CGEvent`, `NSAppleScript`, `NSRunningApplication`. No new dependencies. Built with the existing `./build.sh` (raw `swiftc`).

**Testing approach:** The project has no test suite (confirmed in spec). Each task ends with a manual verification step using `./build.sh` and the running app. Spec section `## Testing` lists six manual scenarios that must pass after Task 7.

**Companion spec:** `docs/superpowers/specs/2026-05-12-energy-drain-drill-in-design.md`

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `Sources/FullBatteryAlert/EnergyMonitor.swift` | new | `AppEnergy` struct + `EnergyMonitor` observable object that polls `top` and publishes top apps |
| `Sources/FullBatteryAlert/EnergyListView.swift` | new | SwiftUI list of energy-using apps with tap-to-drill-in rows |
| `Sources/FullBatteryAlert/AppDrillIn.swift` | new | `openResourceMonitor(for:)` — routes to Chromium task manager / Safari Activity / Firefox `about:performance` / Activity Monitor |
| `Sources/FullBatteryAlert/SettingsView.swift` | edit | replace placeholder `Text` block (lines 49–51) with `EnergyListView`; receive `energy` parameter; render hint toast |
| `Sources/FullBatteryAlert/App.swift` | edit | own `EnergyMonitor`; call `start()`/`stop()` from `toggleSettings(_:)` |

---

## Task 1: AppEnergy model + top output parser

**Files:**
- Create: `Sources/FullBatteryAlert/EnergyMonitor.swift` (parser + model only — no class yet)

- [ ] **Step 1: Create the file with model and parser**

```swift
import Foundation
import AppKit

struct AppEnergy: Identifiable {
    let id: pid_t
    let displayName: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let powerImpact: Double
    let pids: [pid_t]
}

enum EnergyParser {
    /// One raw row from `top` output: pid, command name, power impact value.
    struct RawProcess {
        let pid: pid_t
        let command: String
        let powerImpact: Double
    }

    /// Parse stdout from `top -l 1 -stats pid,command,power -o power -n 20`.
    ///
    /// `top` prints a header section (uptime, load, mem stats) followed by a
    /// blank line, a column header row ("PID    COMMAND          POWER"), and
    /// then one row per process. We skip everything until we see the column
    /// header, then parse subsequent rows by whitespace.
    static func parse(_ output: String) -> [RawProcess] {
        var rows: [RawProcess] = []
        var seenHeader = false
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !seenHeader {
                // The column header starts with "PID" and contains "POWER".
                if trimmed.hasPrefix("PID") && trimmed.contains("POWER") {
                    seenHeader = true
                }
                continue
            }
            if trimmed.isEmpty { continue }
            // Last token is the power value; first token is the pid; middle is the command.
            // `top` may pad command with spaces, so split on runs of whitespace.
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 3,
                  let pid = pid_t(parts[0]),
                  let power = Double(parts[parts.count - 1])
            else { continue }
            let command = parts[1..<(parts.count - 1)].joined(separator: " ")
            rows.append(RawProcess(pid: pid, command: command, powerImpact: power))
        }
        return rows
    }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `./build.sh`
Expected: `Built: build/MacOS Fully Battery Alert.app` with no Swift errors. The new file is included by the `Sources/FullBatteryAlert/*.swift` glob.

- [ ] **Step 3: Sanity-check the parser against real `top` output**

Run:
```bash
top -l 1 -stats pid,command,power -o power -n 5
```
Expected: a header section, then a row starting with `PID    COMMAND      POWER` (or similar), then 5 process rows. Confirm the column header detection in the parser will fire on this format.

- [ ] **Step 4: Commit**

```bash
git add Sources/FullBatteryAlert/EnergyMonitor.swift
git commit -m "Add AppEnergy model and top output parser"
```

---

## Task 2: EnergyMonitor class with polling lifecycle

**Files:**
- Modify: `Sources/FullBatteryAlert/EnergyMonitor.swift` — append the `EnergyMonitor` class below the parser

- [ ] **Step 1: Add imports and helper for running `top`**

Append to the same file:

```swift
import Combine

@MainActor
final class EnergyMonitor: ObservableObject {
    @Published private(set) var topApps: [AppEnergy] = []

    /// Apps with power impact at or below this are filtered out.
    /// Mirrors Activity Monitor's "negligible" cutoff.
    private let significanceThreshold: Double = 1.0
    private let maxRows: Int = 5
    private let pollInterval: TimeInterval = 5.0

    private var timer: Timer?
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// Force an immediate refresh (used when the popover first opens so the
    /// list is populated rather than blank for 5 seconds).
    func refreshNow() {
        refresh()
    }

    private func refresh() {
        let raw = Self.runTop()
        let parsed = EnergyParser.parse(raw)
        let grouped = Self.group(parsed)
        let filtered = grouped
            .filter { $0.powerImpact > significanceThreshold }
            .sorted { $0.powerImpact > $1.powerImpact }
            .prefix(maxRows)
        topApps = Array(filtered)
    }

    private static func runTop() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-stats", "pid,command,power", "-o", "power", "-n", "20"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Group raw rows by the owning NSRunningApplication. Multiple helper pids
    /// (e.g. Chrome's renderer processes) collapse into one row whose
    /// powerImpact is the sum.
    private static func group(_ raw: [EnergyParser.RawProcess]) -> [AppEnergy] {
        var byKey: [String: AppEnergy] = [:]
        for row in raw {
            let runningApp = NSRunningApplication(processIdentifier: row.pid)
            let key = runningApp?.bundleIdentifier ?? row.command
            if let existing = byKey[key] {
                byKey[key] = AppEnergy(
                    id: existing.powerImpact >= row.powerImpact ? existing.id : row.pid,
                    displayName: existing.displayName,
                    bundleIdentifier: existing.bundleIdentifier,
                    icon: existing.icon,
                    powerImpact: existing.powerImpact + row.powerImpact,
                    pids: existing.pids + [row.pid]
                )
            } else {
                byKey[key] = AppEnergy(
                    id: row.pid,
                    displayName: runningApp?.localizedName ?? row.command,
                    bundleIdentifier: runningApp?.bundleIdentifier,
                    icon: runningApp?.icon,
                    powerImpact: row.powerImpact,
                    pids: [row.pid]
                )
            }
        }
        return Array(byKey.values)
    }
}
```

- [ ] **Step 2: Build**

Run: `./build.sh`
Expected: clean build. If you see a concurrency warning about `Timer` capturing `self`, that's expected and harmless given the `Task { @MainActor in ... }` hop.

- [ ] **Step 3: Commit**

```bash
git add Sources/FullBatteryAlert/EnergyMonitor.swift
git commit -m "Add EnergyMonitor with timer-based polling and pid grouping"
```

---

## Task 3: EnergyListView

**Files:**
- Create: `Sources/FullBatteryAlert/EnergyListView.swift`

- [ ] **Step 1: Create the SwiftUI view**

```swift
import SwiftUI
import AppKit

struct EnergyListView: View {
    @ObservedObject var monitor: EnergyMonitor
    var onSelect: (AppEnergy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if monitor.topApps.isEmpty {
                Text("No Apps Using Significant Energy")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Using Significant Energy")
                    .font(.subheadline.weight(.semibold))
                ForEach(monitor.topApps) { app in
                    Button { onSelect(app) } label: {
                        EnergyRow(app: app)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EnergyRow: View {
    let app: AppEnergy

    var body: some View {
        HStack(spacing: 8) {
            iconView
                .frame(width: 18, height: 18)
            Text(app.displayName)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(badgeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
        }
    }

    private var badgeText: String {
        switch app.powerImpact {
        case 50...: return "High"
        case 10..<50: return "Medium"
        default: return String(format: "%.0f", app.powerImpact)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `./build.sh`
Expected: clean build. The view isn't used anywhere yet — that's fine; Swift will compile an unused public type.

- [ ] **Step 3: Commit**

```bash
git add Sources/FullBatteryAlert/EnergyListView.swift
git commit -m "Add EnergyListView for top energy users with tap-to-drill rows"
```

---

## Task 4: AppDrillIn — Activity Monitor fallback only

This task implements the safe default path (no permissions required). Browser-specific paths come in Task 6.

**Files:**
- Create: `Sources/FullBatteryAlert/AppDrillIn.swift`

- [ ] **Step 1: Create the file with the result enum and the fallback implementation**

```swift
import AppKit

enum DrillInResult {
    case opened
    case hint(message: String)
}

enum AppDrillIn {
    static func openResourceMonitor(for app: AppEnergy) -> DrillInResult {
        // Browser-specific paths land in Task 6; for now everything routes to
        // Activity Monitor.
        return openActivityMonitor()
    }

    private static func openActivityMonitor() -> DrillInResult {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return .opened
        }
        // Fallback by name (older macOS layouts).
        if NSWorkspace.shared.launchApplication("Activity Monitor") {
            return .opened
        }
        return .hint(message: "Couldn't open Activity Monitor.")
    }
}
```

- [ ] **Step 2: Build**

Run: `./build.sh`
Expected: clean build. You may see a deprecation warning on `launchApplication` — that's fine; it's only the second-fallback.

- [ ] **Step 3: Commit**

```bash
git add Sources/FullBatteryAlert/AppDrillIn.swift
git commit -m "Add AppDrillIn with Activity Monitor fallback path"
```

---

## Task 5: Wire EnergyMonitor + EnergyListView into the app

This is the integration task — after it lands, the app actually shows the energy list and clicking opens Activity Monitor.

**Files:**
- Modify: `Sources/FullBatteryAlert/SettingsView.swift`
- Modify: `Sources/FullBatteryAlert/App.swift`

- [ ] **Step 1: Update `SettingsView` to accept the monitor and render the list**

Replace the property block at the top of `SettingsView`:

```swift
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var battery: BatteryMonitor
    @ObservedObject var energy: EnergyMonitor
    var onTestAlert: () -> Void = {}
    @State private var newThreshold: Double = 90
    @State private var hintMessage: String?
```

Then replace the placeholder block — currently:

```swift
            Text("No Apps Using Significant Energy")
                .font(.callout)
                .foregroundStyle(.secondary)
```

with:

```swift
            EnergyListView(monitor: energy, onSelect: handleSelect)
            if let hint = hintMessage {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
```

And add the handler method at the bottom of the `SettingsView` struct (before the closing brace, alongside `formatMinutes`):

```swift
    private func handleSelect(_ app: AppEnergy) {
        switch AppDrillIn.openResourceMonitor(for: app) {
        case .opened:
            hintMessage = nil
        case .hint(let message):
            hintMessage = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if hintMessage == message { hintMessage = nil }
            }
        }
    }
```

- [ ] **Step 2: Update `App.swift` to own `EnergyMonitor` and lifecycle it**

In `AppDelegate`, add the property next to `battery`:

```swift
    private let settings = AppSettings()
    private let battery = BatteryMonitor()
    private let energy = EnergyMonitor()
```

In `setupPopovers()`, update the `SettingsView` construction to pass `energy`:

```swift
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                battery: battery,
                energy: energy,
                onTestAlert: { [weak self] in self?.presentAlertPopover(threshold: 100, percentage: self?.battery.percentage ?? 100) }
            )
        )
```

Replace `toggleSettings(_:)` so it manages `energy` lifecycle:

```swift
    @objc private func toggleSettings(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            energy.stop()
        } else {
            alertPopover.performClose(nil)
            energy.start()
            settingsPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            settingsPopover.contentViewController?.view.window?.makeKey()
        }
    }
```

- [ ] **Step 3: Build**

Run: `./build.sh`
Expected: clean build.

- [ ] **Step 4: Manually verify the live list**

Run:
```bash
open "build/MacOS Fully Battery Alert.app"
```
Then:
1. Click the menu-bar battery icon to open the popover.
2. With at least one busy app (e.g. an active Chrome window playing a YouTube video, or `yes > /dev/null` running in a terminal), you should see the "Using Significant Energy" section populate within ~5 seconds.
3. Click any row → Activity Monitor opens.
4. Close the popover → confirm `top` is no longer being spawned (in a terminal: `pgrep -fl '/usr/bin/top -l 1' || echo 'no top running'`).

If with no busy apps you see only "No Apps Using Significant Energy", that's correct.

- [ ] **Step 5: Commit**

```bash
git add Sources/FullBatteryAlert/SettingsView.swift Sources/FullBatteryAlert/App.swift
git commit -m "Wire EnergyMonitor + EnergyListView into settings popover"
```

---

## Task 6: Browser-specific drill-in (Chromium / Safari / Firefox)

**Files:**
- Modify: `Sources/FullBatteryAlert/AppDrillIn.swift`

- [ ] **Step 1: Replace `openResourceMonitor(for:)` with the bundle-ID router**

Replace the entire body of the enum (keep `DrillInResult` as-is) with:

```swift
enum AppDrillIn {
    /// Bundle IDs of Chromium-family browsers. All expose a Task Manager via
    /// the Shift+Esc shortcut.
    private static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "company.thebrowser.Browser",   // Arc
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

    // MARK: - Chromium

    private static func drillIntoChromium(bundleID: String, appName: String) -> DrillInResult {
        guard activate(bundleIdentifier: bundleID) else {
            return openActivityMonitor()
        }
        // Shift+Esc opens Chromium's built-in Task Manager.
        // Virtual keycode for Escape is 0x35.
        return sendKeystroke(keyCode: 0x35, flags: .maskShift, hint: "Press ⇧⎋ in \(appName) to see per-tab energy.")
    }

    // MARK: - Safari

    private static func drillIntoSafari() -> DrillInResult {
        guard activate(bundleIdentifier: "com.apple.Safari") else {
            return openActivityMonitor()
        }
        // Cmd+Option+A opens Window → Activity in recent Safari versions.
        // Virtual keycode for 'A' is 0x00.
        return sendKeystroke(keyCode: 0x00, flags: [.maskCommand, .maskAlternate], hint: "Open Window → Activity in Safari to see per-tab energy.")
    }

    // MARK: - Firefox

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

    // MARK: - Shared helpers

    private static func activate(bundleIdentifier: String) -> Bool {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return false
        }
        return running.activate(options: [.activateIgnoringOtherApps])
    }

    /// Synthesize a keystroke. Requires the Accessibility permission. If the
    /// permission isn't granted, returns `.hint` with the provided fallback
    /// message so the user can perform the keystroke themselves.
    private static func sendKeystroke(keyCode: CGKeyCode, flags: CGEventFlags, hint: String) -> DrillInResult {
        // Prompt the user the first time. AXIsProcessTrustedWithOptions with
        // kAXTrustedCheckOptionPrompt shows the standard system prompt.
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options: CFDictionary = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            return .hint(message: hint)
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else {
            return .hint(message: hint)
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return .opened
    }

    private static func openActivityMonitor() -> DrillInResult {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return .opened
        }
        if NSWorkspace.shared.launchApplication("Activity Monitor") {
            return .opened
        }
        return .hint(message: "Couldn't open Activity Monitor.")
    }
}
```

- [ ] **Step 2: Build**

Run: `./build.sh`
Expected: clean build.

- [ ] **Step 3: Manually verify Chrome path (Accessibility-not-granted)**

This is the first-run path — before granting Accessibility.

1. If you've already granted Accessibility for the test build, open System Settings → Privacy & Security → Accessibility and toggle off `MacOS Fully Battery Alert` (or remove it).
2. Quit and relaunch: `open "build/MacOS Fully Battery Alert.app"`.
3. Make Chrome busy (open a YouTube tab and start a video so it shows up in the list).
4. Open the menu-bar popover and click the Chrome row.
5. Expected: macOS shows the Accessibility prompt; the popover shows the hint message "Press ⇧⎋ in Google Chrome to see per-tab energy."; Chrome activates to the foreground.

- [ ] **Step 4: Manually verify Chrome path (Accessibility granted)**

1. Grant Accessibility permission to the test app in System Settings.
2. Relaunch the app, open popover, click Chrome row again.
3. Expected: Chrome activates AND its Task Manager window opens (sorted by CPU/network/memory — each tab is a row).
4. Repeat with Safari (if installed): the Activity window should open.
5. Repeat with Firefox (if installed): the `about:performance` page should open in a new tab.

- [ ] **Step 5: Commit**

```bash
git add Sources/FullBatteryAlert/AppDrillIn.swift
git commit -m "Add browser-specific drill-in for Chromium, Safari, Firefox"
```

---

## Task 7: Final manual verification pass

No code changes — this is the end-to-end check against the spec's `## Testing` section.

- [ ] **Step 1: Run through all six scenarios from the spec**

Build a clean app: `./build.sh && open "build/MacOS Fully Battery Alert.app"`

For each scenario, observe and check off:

1. **Heavy Chrome → appears in list.** Open a video tab. Within ~5s of opening the popover, "Google Chrome" appears with a High/Medium badge.
2. **Click Chrome → activates and Task Manager opens.** With Accessibility granted, the click does both.
3. **Revoke Accessibility, repeat → hint toast.** Toggle off in System Settings; click Chrome; popover shows "Press ⇧⎋ in Google Chrome to see per-tab energy."
4. **Nothing busy → placeholder copy.** Quit all heavy apps; reopen popover; "No Apps Using Significant Energy" appears.
5. **No leaked `top` after close.** With popover closed, run `pgrep -fl '/usr/bin/top -l 1'` — should print nothing.
6. **Click an unknown / system row → Activity Monitor.** Find a non-browser row (e.g. `WindowServer` if it shows up); click it; Activity Monitor opens.

- [ ] **Step 2: Smoke-test the existing features still work**

1. Adjust an existing threshold slider — change is persisted.
2. Click "Send test alert" — alert popover appears.
3. Plug/unplug your Mac while the popover is open — power-source text updates within a second.

All three should behave identically to pre-feature.

- [ ] **Step 3: Final commit if any fixups landed during verification**

If you fixed anything during this pass, commit it with a clear message. Otherwise skip.

```bash
git status
# If there are changes:
# git add <files> && git commit -m "<message>"
```

---

## Self-review (verification of this plan against the spec)

**Spec coverage check:**

- `EnergyMonitor.swift` — Task 1 (model + parser), Task 2 (class + polling + grouping). ✓
- `EnergyListView.swift` — Task 3. ✓
- `AppDrillIn.swift` — Task 4 (skeleton), Task 6 (browser routing + keystroke + AppleScript). ✓
- `SettingsView.swift` edits — Task 5 (replace placeholder, inject monitor, render hint). ✓
- `App.swift` edits — Task 5 (own monitor, wire start/stop). ✓
- Polling lifecycle (popover-open only) — Task 5 (toggleSettings handles start/stop). ✓
- Bundle-ID branching for Chromium / Safari / Firefox / fallback — Task 6. ✓
- Accessibility permission handling + hint fallback — Task 6 (sendKeystroke + result type used by SettingsView in Task 5). ✓
- Defaults: 5s, top 5, threshold 1.0 — Task 2 (constants). ✓
- Error handling: failed `top`, unparseable lines, nil `NSRunningApplication`, missing Activity Monitor — Task 1 parser skips bad lines; Task 2 catches subprocess error; Task 4/6 fallbacks. ✓

**Type consistency check:** `AppEnergy`, `DrillInResult.opened`/`.hint(message:)`, `EnergyMonitor.start()/stop()/refreshNow()/topApps`, `AppDrillIn.openResourceMonitor(for:)`, `SettingsView.handleSelect(_:)` — all signatures match across tasks.

**Placeholder scan:** No "TBD", no "implement later", no "add error handling" hand-waves. Every step shows the code.
