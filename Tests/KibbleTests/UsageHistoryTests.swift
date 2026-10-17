import XCTest
@testable import Kibble

final class BurnRateTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_791_000_000)

    /// Readings every `step` minutes ending at `now`, one per value.
    func series(_ values: [Double], step: Double = 5, resetsAt: Date?) -> [UsageSample] {
        values.enumerated().map { i, v in
            let minutesAgo = Double(values.count - 1 - i) * step
            return UsageSample(time: now.addingTimeInterval(-minutesAgo * 60), provider: .claude, window: "5-hour", used: v, resetsAt: resetsAt)
        }
    }

    func testSteadyBurnProjectsEmptyTime() throws {
        let reset = now.addingTimeInterval(4 * 3600)
        // 2 points every 5 minutes: 24 points an hour, from 30 to 48 over 45 minutes.
        let samples = series(stride(from: 30.0, through: 48, by: 2).map { $0 }, resetsAt: reset)
        let f = try XCTUnwrap(BurnRate.forecast(samples, current: UsageWindow(label: "5-hour", usedPercent: 48, resetsAt: reset), now: now))
        XCTAssertEqual(f.percentPerHour, 24, accuracy: 0.01)
        // 52 points left at 24 an hour.
        XCTAssertEqual(f.emptyAt.timeIntervalSince(now), 52.0 / 24 * 3600, accuracy: 60)
        XCTAssertFalse(f.isSoon(now: now))
    }

    func testFlatUsageHasNoForecast() {
        let reset = now.addingTimeInterval(3600)
        let samples = series(Array(repeating: 40, count: 10), resetsAt: reset)
        XCTAssertNil(BurnRate.forecast(samples, current: UsageWindow(label: "5-hour", usedPercent: 40, resetsAt: reset), now: now))
    }

    func testResetMidSeriesStartsOver() throws {
        let oldReset = now.addingTimeInterval(-30 * 60)
        let newReset = now.addingTimeInterval(5 * 3600)
        // Before the reset: 70 → 90. After: 2 → 20 over 20 minutes (54 an hour).
        let before = series([70, 80, 90], step: 10, resetsAt: oldReset).map {
            UsageSample(time: $0.time.addingTimeInterval(-40 * 60), provider: .claude, window: "5-hour", used: $0.used, resetsAt: oldReset)
        }
        let after = series([2, 8, 14, 20], resetsAt: newReset)
        let current = UsageWindow(label: "5-hour", usedPercent: 20, resetsAt: newReset)
        let f = try XCTUnwrap(BurnRate.forecast(before + after, current: current, now: now))
        XCTAssertEqual(f.percentPerHour, 72, accuracy: 0.01)

        // The same drop with an unchanged reset time is still read as a reset.
        let jittered = series([60, 70, 80, 2, 8, 14, 20], resetsAt: newReset)
        let g = try XCTUnwrap(BurnRate.forecast(jittered, current: current, now: now))
        XCTAssertEqual(g.percentPerHour, 72, accuracy: 0.01)
    }

    func testTooFewSamplesOrTooShortHaveNoForecast() {
        let reset = now.addingTimeInterval(3600)
        let current = UsageWindow(label: "5-hour", usedPercent: 60, resetsAt: reset)
        XCTAssertNil(BurnRate.forecast(series([40, 60], step: 20, resetsAt: reset), current: current, now: now))
        // Three readings, but only ten minutes apart in all.
        XCTAssertNil(BurnRate.forecast(series([40, 50, 60], resetsAt: reset), current: current, now: now))
        // Enough readings, but the newest is twenty minutes old.
        let stale = series([40, 45, 50, 55, 60], resetsAt: reset).map {
            UsageSample(time: $0.time.addingTimeInterval(-20 * 60), provider: .claude, window: "5-hour", used: $0.used, resetsAt: reset)
        }
        XCTAssertNil(BurnRate.forecast(stale, current: current, now: now))
    }

    func testNoForecastWhenEmptyWouldComeAfterReset() {
        // 6 points an hour from 50 leaves over eight hours; the window resets in two.
        let reset = now.addingTimeInterval(2 * 3600)
        let samples = series([45.5, 46, 46.5, 47, 47.5, 48, 48.5, 49, 49.5, 50], resetsAt: reset)
        XCTAssertNil(BurnRate.forecast(samples, current: UsageWindow(label: "5-hour", usedPercent: 50, resetsAt: reset), now: now))
    }

    func testSoonForecastAndPhrase() throws {
        let reset = now.addingTimeInterval(3 * 3600)
        let samples = series([50, 55, 60, 65, 70, 75, 80], resetsAt: reset)
        let f = try XCTUnwrap(BurnRate.forecast(samples, current: UsageWindow(label: "5-hour", usedPercent: 80, resetsAt: reset), now: now))
        XCTAssertTrue(f.isSoon(now: now))
        XCTAssertTrue(f.phrase(now: now).hasPrefix("At this pace: empty around "))
    }
}

final class UsageHistoryTests: XCTestCase {
    var dir: URL!
    let day0 = Date(timeIntervalSince1970: 1_791_000_000)

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appending(path: "kibble-history-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func usage(_ used: Double, resets: Date? = nil) -> ProviderUsage {
        ProviderUsage(provider: .claude, windows: [UsageWindow(label: "5-hour", usedPercent: used, resetsAt: resets)])
    }

    func lines() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.flatMap { ((try? String(contentsOf: $0, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    }

    func testSkipsDuplicatesAndThrottles() {
        let h = UsageHistory(directory: dir, now: day0)
        let reset = day0.addingTimeInterval(4 * 3600)
        h.record(usage(10, resets: reset), now: day0)
        h.record(usage(12, resets: reset), now: day0.addingTimeInterval(30))   // within the minute: dropped
        h.record(usage(10, resets: reset), now: day0.addingTimeInterval(120))  // unchanged: skipped
        h.record(usage(10, resets: reset.addingTimeInterval(0.4)), now: day0.addingTimeInterval(180)) // jitter only: skipped
        h.record(usage(10, resets: reset), now: day0.addingTimeInterval(6 * 60)) // unchanged, but 6 min on: kept
        h.record(usage(15, resets: reset), now: day0.addingTimeInterval(7 * 60)) // changed: kept
        let kept = h.samples(.claude, window: "5-hour", since: .distantPast)
        XCTAssertEqual(kept.map(\.used), [10, 10, 15])
        XCTAssertEqual(lines().count, 3)

        // A second instance reads the log back.
        let again = UsageHistory(directory: dir, now: day0.addingTimeInterval(8 * 60))
        XCTAssertEqual(again.samples(.claude, window: "5-hour", since: .distantPast), kept)
    }

    func testPrunesOldDayFiles() throws {
        let h = UsageHistory(directory: dir, now: day0)
        h.record(usage(10), now: day0)
        h.record(usage(20), now: day0.addingTimeInterval(10 * 86_400))
        h.record(usage(30), now: day0.addingTimeInterval(25 * 86_400))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 3)

        // 35 days on, the first reading is past 30 days and its file goes.
        let later = day0.addingTimeInterval(35 * 86_400)
        let fresh = UsageHistory(directory: dir, now: later)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 2)
        // Memory holds only the last week.
        XCTAssertTrue(fresh.samples(since: .distantPast).isEmpty)
        fresh.record(usage(40), now: later)
        XCTAssertEqual(fresh.samples(since: .distantPast).map(\.used), [40])
    }

    func testDailyPeaksNeedTwoDays() {
        let cal = Calendar(identifier: .gregorian)
        let now = day0
        let today = cal.startOfDay(for: now)
        func s(_ p: Provider, _ w: String, _ hoursAgo: Double, _ used: Double) -> UsageSample {
            UsageSample(time: now.addingTimeInterval(-hoursAgo * 3600), provider: p, window: w, used: used, resetsAt: nil)
        }
        let oneDay = [s(.claude, "5-hour", 0.5, 40), s(.claude, "Weekly", 0.5, 55)].filter { $0.time >= today }
        XCTAssertFalse(UsageChart.hasEnoughHistory(UsageChart.dailyPeaks(oneDay, now: now, calendar: cal)))

        let week = oneDay + [s(.claude, "5-hour", 30, 80), s(.claude, "5-hour", 31, 20), s(.codex, "Weekly", 80, 12), s(.claude, "5-hour", 24 * 9, 99)]
        let peaks = UsageChart.dailyPeaks(week, now: now, calendar: cal)
        XCTAssertTrue(UsageChart.hasEnoughHistory(peaks))
        XCTAssertEqual(peaks.filter { $0.provider == .claude }.map(\.peak).max(), 80)
        XCTAssertFalse(peaks.contains { $0.peak == 99 }, "readings older than a week are left out")
    }
}
