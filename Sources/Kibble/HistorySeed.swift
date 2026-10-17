#if DEBUG
import Foundation

/// `--snapshot <dir> --seed-history`: fills a throwaway history in a temporary
/// directory with a plausible week and a recent rise, so the snapshot shows the
/// chart and a forecast. Never touches the real history.
@MainActor
enum HistorySeed {
    static var requested: Bool { CommandLine.arguments.contains("--seed-history") }

    static func temporaryHistory() -> UsageHistory {
        let dir = FileManager.default.temporaryDirectory.appending(path: "kibble-seed-\(UUID().uuidString)")
        return UsageHistory(directory: dir)
    }

    /// Sets demo levels on the store and writes a matching history.
    static func seed(_ store: UsageStore, now: Date = .now) {
        precondition(store.history.directory.path.hasPrefix(FileManager.default.temporaryDirectory.path),
                     "seeding is only for a temporary history")
        // A steady climb on Claude's 5-hour window and a steep one on Codex's.
        store.injectDemo(.claude, used: 58)
        store.injectDemo(.codex, used: 74)
        var samples: [UsageSample] = []
        let rises: [(Provider, Double, Double)] = [(.claude, 40, 58), (.codex, 50, 74)]
        for (p, from, to) in rises {
            guard let w = store.usage(for: p).windows.first(where: { $0.label == "5-hour" }) else { continue }
            for i in 0...9 {
                let f = Double(i) / 9
                samples.append(UsageSample(time: now.addingTimeInterval(-Double(9 - i) * 5 * 60 - 30), provider: p,
                                           window: w.label, used: (from + (to - from) * f).rounded(), resetsAt: w.resetsAt))
            }
        }
        // The week before: a busy working day shape, a quieter weekend.
        let claudePeaks: [Double] = [46, 72, 88, 64, 31, 18, 54]
        let codexPeaks: [Double] = [22, 35, 61, 48, 12, 0, 40]
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        for back in 1...6 {
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { continue }
            for (p, peaks) in [(Provider.claude, claudePeaks), (.codex, codexPeaks)] {
                let peak = peaks[(7 - back) % 7]
                for hour in stride(from: 9, through: 18, by: 1) {
                    let shape = sin(Double(hour - 9) / 9 * .pi)
                    samples.append(UsageSample(time: day.addingTimeInterval(Double(hour) * 3600), provider: p,
                                               window: "5-hour", used: (peak * shape).rounded(), resetsAt: nil))
                }
            }
        }
        store.history.importSamples(samples, now: now)
    }
}
#endif
