import Foundation

/// One reading of one rate-limit window, as stored in the history log.
struct UsageSample: Codable, Equatable {
    let time: Date
    let provider: Provider
    let window: String
    let used: Double
    let resetsAt: Date?

    // Short keys keep a line around 70 bytes.
    enum CodingKeys: String, CodingKey {
        case time = "t", provider = "p", window = "w", used = "u", resetsAt = "r"
    }

    /// Two readings belong to the same window instance when they share a reset
    /// time. Reset times jitter a little between fetches, so allow some slack.
    static func sameInstance(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): abs(a.timeIntervalSince(b)) <= 10 * 60
        default: false
        }
    }
}

/// A local, append-only log of usage readings: one JSON line per window per
/// reading, in one file per day under Application Support. Kept for about
/// 30 days; the last week stays in memory for the forecast and the chart.
///
/// Cheap by design: at most one write a minute per provider, unchanged
/// readings only every few minutes, and pruning is deleting old day files.
final class UsageHistory {
    let directory: URL
    var retention: TimeInterval = 30 * 86_400
    /// How much stays in memory: the chart's week plus a day of slack.
    var memorySpan: TimeInterval = 8 * 86_400
    /// The fewest seconds between two writes for one provider.
    var minInterval: TimeInterval = 60
    /// An unchanged reading is written again only after this long, so a flat
    /// stretch still shows up as flat rather than as a gap.
    var duplicateWindow: TimeInterval = 5 * 60

    private var series: [String: [UsageSample]] = [:]
    private var lastWrite: [Provider: Date] = [:]
    private var lastPruneDay: String?
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Kibble/usage-history", directoryHint: .isDirectory)
    }

    init(directory: URL = UsageHistory.defaultDirectory, now: Date = .now) {
        self.directory = directory
        prune(now: now)
        load(now: now)
    }

    // MARK: Writing

    /// Records the windows of a fresh reading, skipping what would add nothing.
    func record(_ usage: ProviderUsage, now: Date = .now) {
        if let last = lastWrite[usage.provider], now.timeIntervalSince(last) < minInterval { return }
        let time = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded())
        var fresh: [UsageSample] = []
        for w in usage.windows {
            let s = UsageSample(time: time, provider: usage.provider, window: w.label, used: w.usedPercent,
                                resetsAt: w.resetsAt.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded()) })
            if let prev = series[Self.key(usage.provider, w.label)]?.last,
               prev.used == s.used, UsageSample.sameInstance(prev.resetsAt, s.resetsAt),
               now.timeIntervalSince(prev.time) < duplicateWindow {
                continue
            }
            fresh.append(s)
        }
        guard !fresh.isEmpty else { return }
        lastWrite[usage.provider] = now
        insert(fresh, now: now)
        if lastPruneDay != Self.dayName(now) { prune(now: now) }
    }

    /// Adds readings as they are, without throttling. For seeding and tests.
    func importSamples(_ samples: [UsageSample], now: Date = .now) {
        insert(samples.sorted { $0.time < $1.time }, now: now)
        for k in series.keys { series[k]?.sort { $0.time < $1.time } }
    }

    private func insert(_ samples: [UsageSample], now: Date) {
        for s in samples { series[Self.key(s.provider, s.window), default: []].append(s) }
        trimMemory(now: now)
        append(samples)
    }

    private func append(_ samples: [UsageSample]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for (day, group) in Dictionary(grouping: samples, by: { Self.dayName($0.time) }) {
            let text = group.compactMap { (try? encoder.encode($0)).flatMap { String(data: $0, encoding: .utf8) } }
                .map { $0 + "\n" }.joined()
            let url = directory.appending(path: "\(day).jsonl")
            if let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: Data(text.utf8))
            } else {
                fm.createFile(atPath: url.path, contents: Data(text.utf8))
            }
        }
    }

    // MARK: Reading

    /// Readings of one window since a time, oldest first.
    func samples(_ provider: Provider, window: String, since: Date) -> [UsageSample] {
        Self.suffix(series[Self.key(provider, window)] ?? [], since: since)
    }

    /// Readings of every window since a time, oldest first within each window.
    func samples(since: Date) -> [UsageSample] {
        series.values.flatMap { Self.suffix($0, since: since) }
    }

    private static func suffix(_ list: [UsageSample], since: Date) -> [UsageSample] {
        guard let i = list.firstIndex(where: { $0.time >= since }) else { return [] }
        return Array(list[i...])
    }

    // MARK: Housekeeping

    private func load(now: Date) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let cutoff = now.addingTimeInterval(-memorySpan)
        let oldestDay = Self.dayName(cutoff)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where url.pathExtension == "jsonl" && url.deletingPathExtension().lastPathComponent >= oldestDay {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard let s = try? decoder.decode(UsageSample.self, from: Data(line.utf8)), s.time >= cutoff else { continue }
                series[Self.key(s.provider, s.window), default: []].append(s)
            }
        }
        for k in series.keys { series[k]?.sort { $0.time < $1.time } }
    }

    /// Deletes day files older than the retention period.
    private func prune(now: Date) {
        lastPruneDay = Self.dayName(now)
        let oldestKept = Self.dayName(now.addingTimeInterval(-retention))
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "jsonl" && url.deletingPathExtension().lastPathComponent < oldestKept {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func trimMemory(now: Date) {
        let cutoff = now.addingTimeInterval(-memorySpan)
        for (k, list) in series where (list.first?.time ?? now) < cutoff {
            series[k] = Self.suffix(list, since: cutoff)
        }
    }

    private static func key(_ p: Provider, _ window: String) -> String { "\(p.rawValue)|\(window)" }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// The day file a time belongs to, in local time: "2026-10-03".
    static func dayName(_ date: Date) -> String { dayFormatter.string(from: date) }
}
