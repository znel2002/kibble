import Foundation
import UserNotifications

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var claude = ProviderUsage(provider: .claude)
    @Published private(set) var codex = ProviderUsage(provider: .codex)
    @Published private(set) var agents: [Agent] = []
    @Published private(set) var lastBusy: Date = .now

    /// Called when a window crosses 75 / 90 / 100 % used, or resets.
    var onAlert: ((UsageAlert) -> Void)?

    private let claudeSource = ClaudeSource()
    private let codexSource = CodexSource()
    private var localTimer: Timer?
    private var claudeTask: Task<Void, Never>?
    private let alerts = AlertLedger()
    /// Every reading that lands, kept on disk for the forecast and the chart.
    let history: UsageHistory

    init(history: UsageHistory = UsageHistory()) {
        self.history = history
    }

    func usage(for p: Provider) -> ProviderUsage { p == .claude ? claude : codex }
    var anyBusy: Bool { agents.contains { $0.busy } }
    func busy(_ p: Provider) -> Bool { agents.contains { $0.provider == p && $0.busy } }

    func start() {
        refreshLocal()
        localTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLocal() }
        }
        claudeTask = Task { [weak self] in
            var delay: UInt64 = 90
            while !Task.isCancelled {
                guard let self else { return }
                delay = await self.refreshClaude() ? 90 : min(delay * 2, 600)
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
    }

    func refreshNow() {
        refreshLocal()
        Task { await refreshClaude() }
    }

    private var localTick = 0

    /// Agents every 5 s (cheap: a directory listing and a file tail),
    /// Codex limits every 15 s.
    private func refreshLocal() {
        let now = Date.now
        agents = (claudeSource.agents() + codexSource.agents(now: now))
            .sorted { ($0.busy ? 0 : 1, $0.provider.rawValue) < ($1.busy ? 0 : 1, $1.provider.rawValue) }
        if anyBusy { lastBusy = now }
        if localTick % 3 == 0 { apply(codexSource.usage(now: now)) }
        localTick += 1
    }

    @discardableResult
    private func refreshClaude() async -> Bool {
        do {
            apply(try await claudeSource.fetchUsage())
            return true
        } catch {
            var stale = claude
            stale.error = (error as? LocalizedError)?.errorDescription ?? "Offline"
            claude = stale
            return false
        }
    }

    private func apply(_ new: ProviderUsage, record: Bool = true) {
        let old = usage(for: new.provider)
        if new.provider == .claude { claude = new } else { codex = new }
        if record { history.record(new) }
        for alert in alerts.check(old: old, new: new) { onAlert?(alert) }
    }

#if DEBUG
    /// Video exports show made-up tasks, never the user's real ones.
    func injectDemoAgents(_ list: [Agent]) { agents = list }
#endif

    // Demo hooks for screen recordings (menu bar ▸ Demo).
    func injectDemo(_ provider: Provider, used: Double) {
        var u = usage(for: provider)
        let resets = Date.now.addingTimeInterval(2 * 3600 + 14 * 60)
        u.windows = [UsageWindow(label: "5-hour", usedPercent: used, resetsAt: resets)] + u.windows.filter { $0.label != "5-hour" }
        u.error = nil
        u.asOf = .now
        apply(u, record: false)
    }
}

struct UsageAlert: Equatable {
    enum Level: Int, Comparable {
        case reset = 0, low = 75, high = 90, empty = 100
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    let provider: Provider
    let window: UsageWindow
    let level: Level
}

/// Remembers which thresholds already fired for each window instance, so each
/// alert happens once per window (a window instance is identified by its reset time).
@MainActor
final class AlertLedger {
    private let key = "firedAlerts"
    private var fired: [String: Int]

    init() {
        fired = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    func check(old: ProviderUsage, new: ProviderUsage, now: Date = .now) -> [UsageAlert] {
        var out: [UsageAlert] = []
        for w in new.windows {
            let level: UsageAlert.Level? = switch w.usedPercent {
            case 100...: .empty
            case 90...: .high
            case 75...: .low
            default: nil
            }
            let id = Self.id(new.provider, w)
            if let level, level.rawValue > fired[id, default: 0] {
                fired[id] = level.rawValue
                out.append(UsageAlert(provider: new.provider, window: w, level: level))
            }
            if let prev = old.windows.first(where: { $0.label == w.label }), prev.usedPercent >= 50, w.usedPercent < 5 {
                out.append(UsageAlert(provider: new.provider, window: w, level: .reset))
            }
        }
        // Forget windows that have long since reset.
        fired = fired.filter { k, _ in
            guard let epoch = k.split(separator: "@").last.flatMap({ Double($0) }) else { return false }
            return epoch > now.addingTimeInterval(-86_400).timeIntervalSince1970
        }
        UserDefaults.standard.set(fired, forKey: key)
        // Only the loudest alert per provider; a jump from 70 to 100 is one howl.
        return out.sorted { $0.level > $1.level }.reduce(into: []) { acc, a in
            if !acc.contains(where: { $0.provider == a.provider }) { acc.append(a) }
        }
    }

    nonisolated static func id(_ p: Provider, _ w: UsageWindow) -> String {
        // Reset times jitter by fractions of a second between fetches; bucket by hour.
        let epoch = ((w.resetsAt?.timeIntervalSince1970 ?? 0) / 3600).rounded() * 3600
        return "\(p.rawValue)|\(w.label)@\(Int(epoch))"
    }
}

enum Notifier {
    static func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func post(_ alert: UsageAlert) {
        guard Bundle.main.bundleIdentifier != nil, alert.level != .reset else { return }
        let c = UNMutableNotificationContent()
        let name = alert.provider.name
        c.title = switch alert.level {
        case .empty: "\(name) is out of usage"
        case .high: "\(name) is at 90%"
        default: "\(name) is at 75%"
        }
        var body = "\(alert.window.label) limit"
        if let r = alert.window.resetsAt { body += " · resets \(Format.relative(r))" }
        c.body = body
        let req = UNNotificationRequest(identifier: AlertLedger.id(alert.provider, alert.window) + "-\(alert.level.rawValue)", content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

enum Format {
    static func relative(_ date: Date, now: Date = .now) -> String {
        let s = Int(date.timeIntervalSince(now))
        if s <= 0 { return "now" }
        let d = s / 86_400, h = (s % 86_400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "in \(d)d \(h)h" }
        if h > 0 { return "in \(h)h \(m)m" }
        return "in \(max(m, 1))m"
    }

    static func duration(since date: Date, now: Date = .now) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "under a minute" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    static func ago(_ date: Date, now: Date = .now) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3600)h ago" }
        return "\(s / 86_400)d ago"
    }
}
