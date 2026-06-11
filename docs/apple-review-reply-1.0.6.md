# Reply to App Review — Submission a2c34ba3-44c3-4647-b45c-0c08308723e4

**Paste this into App Store Connect → Resolution Center reply for the rejected version.**

---

Hello, and thank you for the review.

We've uploaded a new build, **1.0.6 (15)**, which we'd appreciate you reviewing. Before that, we want to respectfully flag that the three issues described do not appear to match the binary we submitted (Battery Beacon, a menu‑bar battery‑percentage alert utility). We've re-verified the uploaded build and believe a different app's binary may have been reviewed:

**2.1(a) — "Take Screenshot" and "Start/Stop Recording" tabs unresponsive.**
Battery Beacon has no screenshot or screen‑recording functionality of any kind — there are no such tabs or controls anywhere in the app. It is a single menu‑bar item that opens a small popover showing battery percentage and alert‑threshold settings. We were unable to locate the UI described in the feedback. To be safe, we also fixed a first‑click responsiveness edge case in the menu‑bar popover (an accessory/LSUIElement activation issue) in build 1.0.6 (15).

**2.4.5(i) — `com.apple.security.assets.pictures.read-write` entitlement.**
The submitted binary does not request this entitlement. Its only entitlements are `com.apple.security.app-sandbox` and `com.apple.security.network.client` (used for anonymous, opt‑in analytics over HTTPS). We've re‑confirmed this in build 1.0.6 (15).

**2.4.5(iii) — Auto-launch at login without consent.**
The app does not launch at login by default. The "Open at login" option is **off** by default and is only registered via `SMAppService` after the user explicitly enables it in Settings.

The version listed for review showed as **0.1.0 (14)**, whereas our submitted build is **1.0.5 (14)** / now **1.0.6 (15)**, which may corroborate the mismatch.

We're happy to provide a screen recording of the app's full UI if helpful. Thank you again for your time.

— The Battery Beacon team
