import Foundation

/// When a window will run out if usage keeps rising at its recent pace.
struct BurnForecast: Equatable {
    let emptyAt: Date
    /// The fitted pace, in percentage points per hour.
    let percentPerHour: Double

    /// Within the hour: worth showing in the warning colour.
    func isSoon(now: Date = .now) -> Bool { emptyAt.timeIntervalSince(now) <= 3600 }

    /// "15:40" today, "Sat 09:10" on another day. Rounded to five minutes,
    /// since a forecast is never that precise.
    func timeText(now: Date = .now, calendar: Calendar = .current) -> String {
        let t = Date(timeIntervalSince1970: (emptyAt.timeIntervalSince1970 / 300).rounded() * 300)
        return calendar.isDate(t, inSameDayAs: now)
            ? t.formatted(date: .omitted, time: .shortened)
            : t.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    func phrase(now: Date = .now) -> String { "At this pace: empty around \(timeText(now: now))" }
}

/// The forecast maths, kept pure so it can be tested without a clock or disk.
enum BurnRate {
    /// How far back the fit looks.
    static let lookback: TimeInterval = 60 * 60
    static let minSamples = 3
    static let minSpan: TimeInterval = 15 * 60
    /// The newest reading must be at least this fresh.
    static let maxStaleness: TimeInterval = 10 * 60
    /// A fall of more than this many points means the window reset.
    static let resetDrop = 3.0
    /// Usage must have risen by at least this much across the fit.
    static let minRise = 1.0

    /// Projects when `current` reaches 100 % from recent readings of the same
    /// window. Returns nil unless there is a clear, recent rise that would empty
    /// the window before it resets.
    static func forecast(_ samples: [UsageSample], current: UsageWindow, now: Date) -> BurnForecast? {
        guard current.usedPercent < 100 else { return nil }
        var points = samples
            .filter { $0.time <= now && now.timeIntervalSince($0.time) <= lookback && UsageSample.sameInstance($0.resetsAt, current.resetsAt) }
            .sorted { $0.time < $1.time }
        // A drop starts a new series: only what came after the last reset counts.
        if let cut = points.indices.dropFirst().last(where: { points[$0].used < points[$0 - 1].used - resetDrop }) {
            points = Array(points[cut...])
        }
        guard points.count >= minSamples, let first = points.first, let last = points.last,
              last.time.timeIntervalSince(first.time) >= minSpan,
              now.timeIntervalSince(last.time) <= maxStaleness,
              last.used - first.used >= minRise,
              current.usedPercent >= last.used - resetDrop,
              let slope = slope(points), slope > 0 else { return nil }

        let hours = (100 - current.usedPercent) / slope
        guard hours <= 7 * 24 else { return nil }
        let emptyAt = now.addingTimeInterval(hours * 3600)
        if let reset = current.resetsAt, emptyAt >= reset { return nil }
        return BurnForecast(emptyAt: emptyAt, percentPerHour: slope)
    }

    /// Least-squares slope through the readings, in points per hour.
    static func slope(_ points: [UsageSample]) -> Double? {
        guard points.count >= 2, let t0 = points.first?.time else { return nil }
        let xs = points.map { $0.time.timeIntervalSince(t0) / 3600 }
        let ys = points.map(\.used)
        let mx = xs.reduce(0, +) / Double(xs.count)
        let my = ys.reduce(0, +) / Double(ys.count)
        var sxy = 0.0, sxx = 0.0
        for (x, y) in zip(xs, ys) {
            sxy += (x - mx) * (y - my)
            sxx += (x - mx) * (x - mx)
        }
        return sxx > 0 ? sxy / sxx : nil
    }
}

extension UsageStore {
    /// The burn-rate forecast for one window, from the recorded history.
    func forecast(_ provider: Provider, _ window: UsageWindow, now: Date = .now) -> BurnForecast? {
        let recent = history.samples(provider, window: window.label, since: now.addingTimeInterval(-BurnRate.lookback))
        return BurnRate.forecast(recent, current: window, now: now)
    }

    /// Forecasts for a provider's windows, keyed by window label.
    func forecasts(for provider: Provider, now: Date = .now) -> [String: BurnForecast] {
        var out: [String: BurnForecast] = [:]
        for w in usage(for: provider).windows {
            if let f = forecast(provider, w, now: now) { out[w.label] = f }
        }
        return out
    }
}
