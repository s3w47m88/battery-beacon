import Foundation
import AppKit

/// Lightweight, privacy-respecting telemetry client for the self-hosted Umami
/// instance at analytics.theportlandcompany.com.
///
/// Native apps cannot use Umami's browser `t.js` tracker, so events are POSTed
/// directly to `/api/send`. Sends are fire-and-forget with a small on-disk
/// queue: events that fail (offline, server down) are persisted and retried on
/// the next launch. Nothing blocks the UI.
///
/// Privacy: the only identifier sent is an anonymous, app-local install UUID.
/// No names, emails, file paths, or battery serial numbers are ever sent. All
/// sending is gated by the user's opt-out toggle (`AppSettings.analyticsEnabled`).
@MainActor
final class UmamiAnalytics {
    static let shared = UmamiAnalytics()

    // Not secrets — safe to ship in the binary.
    private let endpoint = URL(string: "https://analytics.theportlandcompany.com/api/send")!
    private let websiteID = "8fab5ff2-0907-4cde-a138-2a4b3c5306c7"
    private let hostname = "batterybeacon.app"

    private let defaults = UserDefaults.standard
    private let installIDKey = "umami.installID"
    private let queueKey = "umami.pendingEvents"

    /// Set by AppDelegate from AppSettings; gates all sends.
    var isEnabled = true

    private lazy var userAgent: String = {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let app = appVersion
        // A real-looking desktop UA — Umami's bot filter drops empty/non-browser UAs.
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X \(os.majorVersion)_\(os.minorVersion)_\(os.patchVersion)) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) BatteryBeacon/\(app)"
    }()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var session: URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }

    /// Stable anonymous install identifier — the join key for the future CRM.
    private var installID: String {
        if let existing = defaults.string(forKey: installIDKey) { return existing }
        let new = UUID().uuidString
        defaults.set(new, forKey: installIDKey)
        return new
    }

    // MARK: - Public API

    /// Track an event. `path` is the synthetic screen/context; `name` is the
    /// event name (nil = pageview-style hit). `data` holds custom properties.
    func track(_ name: String?, path: String = "/app", data: [String: Any] = [:]) {
        guard isEnabled else { return }

        var props = data
        props["install_id"] = installID
        props["app_version"] = appVersion

        let payload: [String: Any] = [
            "type": "event",
            "payload": [
                "website": websiteID,
                "hostname": hostname,
                "url": path,
                "name": name as Any,
                "data": props,
            ].compactMapValues { $0 },
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        send(body, enqueueOnFailure: true)
    }

    /// Retry any events queued from a previous offline session. Call on launch.
    func flushPending() {
        guard isEnabled else { return }
        let pending = defaults.array(forKey: queueKey) as? [Data] ?? []
        guard !pending.isEmpty else { return }
        defaults.removeObject(forKey: queueKey)
        for body in pending { send(body, enqueueOnFailure: true) }
    }

    // MARK: - Internals

    private func send(_ body: Data, enqueueOnFailure: Bool) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = body

        session.dataTask(with: req) { [weak self] _, response, error in
            let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            if !ok && enqueueOnFailure {
                _ = error // network failure or non-2xx → persist for retry
                Task { @MainActor in self?.enqueue(body) }
            }
        }.resume()
    }

    private func enqueue(_ body: Data) {
        var pending = defaults.array(forKey: queueKey) as? [Data] ?? []
        pending.append(body)
        // Cap the queue so a long offline stretch can't grow unbounded.
        if pending.count > 200 { pending.removeFirst(pending.count - 200) }
        defaults.set(pending, forKey: queueKey)
    }
}
