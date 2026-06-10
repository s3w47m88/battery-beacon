import SwiftUI
import AppKit
import Combine

@main
struct BatteryBeaconApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() } // Required Scene; never shown (LSUIElement).
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let battery = BatteryMonitor()
    private let energy = EnergyMonitor()
    private let peripherals = PeripheralBatteryMonitor()

    private var statusItem: NSStatusItem!
    private var settingsPopover: NSPopover!
    private var alertPopover: NSPopover!
    private var alertDismissTimer: Timer?
    private var settingsCancellable: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let outPath = ProcessInfo.processInfo.environment["FBA_SCREENSHOT_OUT"] {
            ScreenshotRenderer.render(
                settings: settings, battery: battery, energy: energy, to: outPath
            )
            return
        }
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopovers()
        updateIcon()

        // Analytics is opt-in (guideline 5.1.2): nothing is uploaded until the
        // user explicitly consents. Sync the current state, then — on first run
        // only — ask for consent before any event is sent.
        UmamiAnalytics.shared.isEnabled = settings.analyticsEnabled
        if !settings.analyticsConsentAsked {
            requestAnalyticsConsent()
        } else if settings.analyticsEnabled {
            startAnalytics()
        }

        // Re-render the icon when the percent-in-icon toggle changes, and keep
        // the analytics enabled-state in sync with the live setting.
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateIcon()
                UmamiAnalytics.shared.isEnabled = self?.settings.analyticsEnabled ?? false
            }
        }

        battery.onChange = { [weak self] pct, charging, plugged in
            guard let self else { return }
            self.updateIcon()
            AlertManager.shared.handleUpdate(
                percentage: pct, isCharging: charging, isPluggedIn: plugged,
                settings: self.settings,
                onFire: { threshold in
                    self.presentAlertPopover(threshold: threshold, percentage: pct)
                    UmamiAnalytics.shared.track(
                        "alert_fired", path: "/app/alert",
                        data: ["threshold": threshold, "charging": charging]
                    )
                }
            )
            // Piggyback peripheral refresh + alert eval on the system battery tick
            // — IOPS callbacks happen on every meaningful battery state change,
            // and the IORegistry attach/detach notifications cover hot-plug.
            self.peripherals.refresh()
            self.evaluatePeripheralAlerts()
        }
        peripherals.onLowBattery = { [weak self] device, isCritical in
            guard let self, self.settings.peripheralAlertsEnabled else { return }
            AlertManager.shared.notifyPeripheralLow(device: device, isCritical: isCritical)
        }
        evaluatePeripheralAlerts()
        AlertManager.shared.handleUpdate(
            percentage: battery.percentage, isCharging: battery.isCharging, isPluggedIn: battery.isPluggedIn,
            settings: settings, onFire: { _ in }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if settings.analyticsEnabled {
            UmamiAnalytics.shared.track("app_quit", path: "/app/quit")
        }
    }

    /// First-run consent (guideline 5.1.2): clearly state that anonymous usage
    /// data will be uploaded to our server, and only enable analytics if the
    /// user agrees. Nothing is sent before this choice.
    private func requestAnalyticsConsent() {
        let alert = NSAlert()
        alert.messageText = "Help improve Battery Beacon?"
        alert.informativeText = """
        Battery Beacon can send anonymous usage data (such as when an alert \
        fires and your app/macOS version) to the developer's own server at \
        analytics.theportlandcompany.com to help improve the app.

        No names, emails, or personal information are collected, and the data \
        is never used for advertising or tracking. You can change this anytime \
        in Settings.
        """
        alert.addButton(withTitle: "Share Anonymous Data")
        alert.addButton(withTitle: "No Thanks")
        NSApp.activate(ignoringOtherApps: true)
        let agreed = alert.runModal() == .alertFirstButtonReturn
        settings.analyticsEnabled = agreed
        settings.analyticsConsentAsked = true
        UmamiAnalytics.shared.isEnabled = agreed
        if agreed { startAnalytics() }
    }

    /// Begin sending analytics for this session — only ever called after consent.
    private func startAnalytics() {
        UmamiAnalytics.shared.flushPending()
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        UmamiAnalytics.shared.track(
            "app_launched", path: "/app/launch",
            data: ["macos": "\(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion)"]
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(toggleSettings(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopovers() {
        settingsPopover = NSPopover()
        settingsPopover.behavior = .transient
        settingsPopover.contentSize = NSSize(width: 320, height: 360)
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(
                settings: settings,
                battery: battery,
                energy: energy,
                peripherals: peripherals,
                onTestAlert: { [weak self] in self?.presentAlertPopover(threshold: 100, percentage: self?.battery.percentage ?? 100) }
            )
        )

        alertPopover = NSPopover()
        alertPopover.behavior = .semitransient
        alertPopover.contentSize = NSSize(width: 280, height: 110)
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let pct = max(0, min(100, battery.percentage))
        let img = BatteryIconRenderer.render(
            percentage: pct,
            isCharging: battery.isCharging,
            isPluggedIn: battery.isPluggedIn,
            showPercentage: settings.showPercentageInIcon
        )
        button.image = img
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "\(pct)%" + (battery.isCharging ? " (charging)" : battery.isPluggedIn ? " (plugged in)" : "")
    }

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

    private func evaluatePeripheralAlerts() {
        guard settings.peripheralAlertsEnabled else { return }
        peripherals.evaluateAlerts(
            lowThreshold: settings.peripheralLowThreshold,
            criticalThreshold: settings.peripheralCriticalThreshold
        )
    }

    func presentAlertPopover(threshold: Int, percentage: Int) {
        guard let button = statusItem.button else { return }
        let title: String
        let body: String
        if threshold >= 100 {
            title = "Battery Fully Charged"
            body = "Your Mac is at \(percentage)%. Unplug to preserve battery health."
        } else {
            title = "Battery at \(threshold)%"
            body = "Charging is approaching full (\(percentage)%)."
        }
        alertPopover.contentViewController = NSHostingController(
            rootView: AlertBubbleView(title: title, message: body, onDismiss: { [weak self] in
                self?.alertPopover.performClose(nil)
            })
        )
        if !alertPopover.isShown {
            alertPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        alertDismissTimer?.invalidate()
        alertDismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.alertPopover.performClose(nil) }
        }
        if settings.playSound {
            NSSound(named: "Glass")?.play()
        }
    }
}
