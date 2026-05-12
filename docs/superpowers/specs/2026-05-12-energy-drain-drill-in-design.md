# Energy-Drain List with Drill-In — Design

**Date:** 2026-05-12
**Status:** Approved (pending user review of this written spec)
**Component:** MacOS Fully Battery Alert menu-bar app

## Problem

The settings popover currently shows a static line: `"No Apps Using Significant Energy"` (`SettingsView.swift:49`). Users want to actually see what's draining their battery and, for apps that have internal sub-units (browser tabs, primarily), drill in to find the specific tab/sub-unit responsible.

## Goal

Replace the static placeholder with a live list of the top energy-using apps. Clicking an app routes the user to the most accurate per-sub-unit view available — Chrome's built-in Task Manager for Chromium browsers, Safari's Activity window for Safari, `about:performance` for Firefox, Activity Monitor for everything else.

## Non-Goals

- Building our own per-tab inspector. Chrome's task manager already maps tabs to processes; reimplementing that is large scope for marginal win.
- Persistent historical energy tracking, charts, or trends. List is live-only.
- Surfacing per-tab data inside our app's own UI. We route to the native tool that already shows it.
- Killing/quitting processes from our app. View-only.

## Architecture

Three new files plus targeted edits to two existing files.

### New: `Sources/FullBatteryAlert/EnergyMonitor.swift`

`@MainActor final class EnergyMonitor: ObservableObject`.

Responsibilities:

- Spawn `top -l 1 -stats pid,command,power -o power -n 20` as a subprocess on a 5-second timer.
- Parse stdout into `[RawProcess]` (pid, command, power-impact-number).
- Group rows by owning application:
  - For each pid, resolve the owning `NSRunningApplication` via `NSRunningApplication(processIdentifier:)`.
  - If `NSRunningApplication` is nil (helper processes, daemons), fall back to the parent pid; if still nil, treat the command string as the group key.
  - Sum power impact across all pids in a group. This is how Chrome's many helpers collapse into one "Google Chrome" row.
- Publish `@Published var topApps: [AppEnergy]` — sorted descending, capped at 5, each entry above the threshold (configurable; default 1.0 power-impact units).
- Start/stop polling via `start()` / `stop()` — called by `AppDelegate` based on popover visibility.

Data model:

```swift
struct AppEnergy: Identifiable {
    let id: pid_t              // representative pid (highest-impact in group)
    let displayName: String    // from NSRunningApplication.localizedName, or command
    let bundleIdentifier: String?
    let icon: NSImage?         // from NSRunningApplication.icon
    let powerImpact: Double    // summed across grouped pids
    let pids: [pid_t]          // all pids contributing to this row
}
```

### New: `Sources/FullBatteryAlert/EnergyListView.swift`

SwiftUI view. Inputs: `@ObservedObject var monitor: EnergyMonitor`, `onSelect: (AppEnergy) -> Void`.

Layout:

- Section header: `"Using Significant Energy"` (matches macOS Battery menu wording).
- If `monitor.topApps.isEmpty`: render the existing fallback line `"No Apps Using Significant Energy"` in `.secondary` color.
- Else: up to 5 rows. Each row:
  - 16pt rounded-rect app icon (from `AppEnergy.icon`, or generic `app` SF Symbol as fallback)
  - App `displayName`
  - Trailing energy badge: `"High"` (impact > 50), `"Medium"` (10–50), or numeric for smaller values. Matches Activity Monitor's tone.
  - Trailing chevron `chevron.right` to signal tappability.
- Whole row is a `Button` styled `.plain`; on tap, calls `onSelect(app)`.

### New: `Sources/FullBatteryAlert/AppDrillIn.swift`

Single entry point:

```swift
enum AppDrillIn {
    static func openResourceMonitor(for app: AppEnergy)
}
```

Logic (bundle-ID first, then name fallback):

| Bundle ID                          | App           | Action                                                                          |
|------------------------------------|---------------|---------------------------------------------------------------------------------|
| `com.google.Chrome`                | Chrome        | Activate app, then send Shift+Esc via `CGEvent` keystroke                       |
| `com.microsoft.edgemac`            | Edge          | Same                                                                            |
| `com.brave.Browser`                | Brave         | Same                                                                            |
| `company.thebrowser.Browser`       | Arc           | Same                                                                            |
| `com.vivaldi.Vivaldi`              | Vivaldi       | Same                                                                            |
| `com.operasoftware.Opera`          | Opera         | Same                                                                            |
| `com.apple.Safari`                 | Safari        | Activate, send Cmd+Option+A (Window → Activity)                                 |
| `org.mozilla.firefox`              | Firefox       | Activate, then run AppleScript `tell application "Firefox" to open location "about:performance"` via `NSAppleScript` |
| _anything else_                    | —             | Open Activity Monitor (`/System/Applications/Utilities/Activity Monitor.app`)   |

Implementation notes:

- Use `CGEvent(keyboardEventSource:virtualKey:keyDown:)` with `.maskShift` flags for the Shift+Esc keystroke. Post to `.cghidEventTap`.
- Before sending the first keystroke, check `AXIsProcessTrustedWithOptions` with prompt. If not trusted, fall back to the **hint behavior** (below) instead of silently failing.
- **Hint fallback:** if Accessibility isn't granted, activate the target app and show a transient toast inside our popover: `"Press ⇧⎋ in Chrome to see per-tab energy"`. This means the feature is useful even before the user grants the permission.
- Activating the target app uses `NSRunningApplication.activate(options: .activateIgnoringOtherApps)`.

### Edited: `Sources/FullBatteryAlert/SettingsView.swift`

- Inject `@ObservedObject var energy: EnergyMonitor` alongside the existing `battery` and `settings`.
- Replace the placeholder `Text("No Apps Using Significant Energy")` block (lines 49–51) with `EnergyListView(monitor: energy, onSelect: AppDrillIn.openResourceMonitor)`.
- No other changes — the rest of the view (thresholds, sound toggle, quit) stays put.

### Edited: `Sources/FullBatteryAlert/App.swift`

- `AppDelegate` owns a new `private let energy = EnergyMonitor()`.
- Pass `energy` into `SettingsView`'s constructor (alongside `settings` and `battery`).
- In `toggleSettings(_:)`, call `energy.start()` when opening the popover and `energy.stop()` when closing. Also call `energy.stop()` on app termination (in `applicationWillTerminate` if not already present).
- Initial `energy.refreshNow()` fires when the popover opens so the first frame is populated rather than showing an empty list for 5 seconds.

## Data flow

```
┌─────────────────────────────┐
│ Timer (5s, popover-open)    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ EnergyMonitor.refresh()     │
│  - spawn `top -l 1 ...`     │
│  - parse stdout             │
│  - group by NSRunningApp    │
│  - sort, cap to 5           │
└──────────────┬──────────────┘
               │ @Published
               ▼
┌─────────────────────────────┐
│ EnergyListView              │
│  - row tap → onSelect(app)  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ AppDrillIn.openResourceMon. │
│  - branch on bundle ID      │
│  - Accessibility OK: Shift+Esc / Cmd+Opt+A
│  - else: hint toast + activate target app
└─────────────────────────────┘
```

## Error handling

- `top` subprocess fails or returns non-zero → log to `os_log`, leave `topApps` unchanged (don't blank the UI on a transient failure).
- Output format unexpected → graceful parse: skip unparseable lines, keep what parses.
- `NSRunningApplication(processIdentifier:)` returns nil → group under the command name, no icon (uses generic SF Symbol).
- Keystroke synthesis blocked by lack of Accessibility → hint-toast fallback, no error surfaced.
- Activity Monitor not found at expected path → use `NSWorkspace.shared.launchApplication("Activity Monitor")` as a final fallback.

## Energy footprint of the feature itself

- Polling only while popover is open. The popover is a transient UI element; typical session is seconds.
- `top -l 1` is ~30ms of CPU. At 5-second intervals during an open popover, this is well below the noise floor of the things we're measuring.
- No polling while popover is closed. Zero ongoing cost.

## Testing

Manual scenarios (the project has no test suite today; we won't add one for this feature):

1. Open popover with Chrome running heavy → Chrome appears in list with a "High"/"Medium" badge.
2. Click Chrome → Chrome activates and Task Manager opens (Accessibility granted path).
3. Revoke Accessibility, repeat → Chrome activates, our popover shows the hint toast.
4. Open popover with nothing busy → "No Apps Using Significant Energy" placeholder shows.
5. Open popover, close it, watch `top` processes via `pgrep top` → no leaked subprocess after close.
6. Click an unknown app (e.g. `kernel_task` if it surfaces) → Activity Monitor opens.

## Defaults summary

| Knob                              | Value                            | Rationale                                                  |
|-----------------------------------|----------------------------------|------------------------------------------------------------|
| Poll interval                     | 5s                               | Matches Activity Monitor's update rate; cheap              |
| Max rows shown                    | 5                                | Fits the popover without resizing                          |
| "Significant" threshold           | power impact > 1.0               | Filters background noise; matches Activity Monitor's "low" |
| Poll only when popover visible    | yes                              | Don't be part of the problem                               |

## Files changed

**New:**
- `Sources/FullBatteryAlert/EnergyMonitor.swift`
- `Sources/FullBatteryAlert/EnergyListView.swift`
- `Sources/FullBatteryAlert/AppDrillIn.swift`

**Edited:**
- `Sources/FullBatteryAlert/SettingsView.swift` (replace placeholder, inject monitor)
- `Sources/FullBatteryAlert/App.swift` (own monitor, wire start/stop to popover)

No changes to `project.yml`, entitlements, or build scripts. No new dependencies.

## Permission asks

- **Accessibility** (Privacy & Security → Accessibility) — required only for one-click drill-in via keystroke synthesis. App degrades gracefully to the hint toast without it. We do not prompt up-front; the system prompt fires the first time the user clicks a drillable app.
