# MacOS Fully Battery Alert

A tiny native macOS menu bar app that notifies you when your battery hits configurable thresholds (default: **95%** and **100%**). Built with SwiftUI — uses your system theme automatically, including Liquid Glass on macOS 26 (Tahoe).

## Features

- Lives in the menu bar, shows current battery % (and a ⚡︎ when charging).
- Click the menu bar item to open Settings: add/remove/adjust alert thresholds with sliders.
- Native macOS notifications fire from the top-right corner (near the battery icon) at each threshold while plugged in.
- Optional alert sound.
- Thresholds reset automatically when you unplug, so each charge cycle gets one alert per threshold.

## Requirements

- macOS 14 (Sonoma) or later — built and tested on macOS 26 (Tahoe).
- Apple Silicon. For Intel, change the `-target` in `build.sh`.
- Xcode Command Line Tools (`xcode-select --install`).

## Build & install

```bash
./build.sh
open "build/MacOS Fully Battery Alert.app"
```

Or move the `.app` to `/Applications`:

```bash
cp -R "build/MacOS Fully Battery Alert.app" /Applications/
open "/Applications/MacOS Fully Battery Alert.app"
```

On first launch, approve the notification permission prompt. If macOS Gatekeeper blocks the unsigned ad-hoc build, right-click the app → **Open**.

## Settings

Click the menu bar item to:

- See current battery % and charge state.
- Adjust existing thresholds with sliders.
- Add a new threshold (slider + **Add**) or remove one (minus button).
- Toggle alert sound.
- Quit the app.

Settings are stored in `UserDefaults` under domain `com.spencerhill.fullbatteryalert`.

## How it works

- `BatteryMonitor` uses `IOPSNotificationCreateRunLoopSource` to subscribe to power-source change events.
- `AlertManager` tracks which thresholds have already fired this charge cycle and posts `UNUserNotification`s through the system Notification Center.
- The menu bar UI is a SwiftUI `MenuBarExtra` with `menuBarExtraStyle(.window)`, which renders as a native popover — picking up Liquid Glass automatically.

## License

MIT — see [LICENSE](LICENSE).
