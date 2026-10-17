import Charts
import SwiftUI

/// The highest share of a plan a provider used on one day, across its windows.
struct DailyPeak: Identifiable, Equatable {
    var id: String { "\(provider.rawValue)-\(day.timeIntervalSince1970)" }
    let day: Date
    let provider: Provider
    let peak: Double
}

enum UsageChart {
    static let days = 7

    /// The first day shown: six days before today, at midnight.
    static func start(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
    }

    /// Daily peak of each provider's tightest window over the last week.
    static func dailyPeaks(_ samples: [UsageSample], now: Date, calendar: Calendar = .current) -> [DailyPeak] {
        let from = start(now: now, calendar: calendar)
        var peaks: [Provider: [Date: Double]] = [:]
        for s in samples where s.time >= from && s.time <= now {
            let day = calendar.startOfDay(for: s.time)
            peaks[s.provider, default: [:]][day] = max(peaks[s.provider]?[day] ?? 0, min(s.used, 100))
        }
        return Provider.allCases.flatMap { p in
            (peaks[p] ?? [:]).map { DailyPeak(day: $0.key, provider: p, peak: $0.value) }.sorted { $0.day < $1.day }
        }
    }

    /// A chart needs readings from at least two days to say anything.
    static func hasEnoughHistory(_ peaks: [DailyPeak]) -> Bool {
        Set(peaks.map(\.day)).count >= 2
    }
}

/// "Peak use, last 7 days": one thin bar per provider per day.
struct UsageChartSection: View {
    let history: UsageHistory

    var body: some View {
        let now = Date.now
        let peaks = UsageChart.dailyPeaks(history.samples(since: UsageChart.start(now: now)), now: now)
        let enough = UsageChart.hasEnoughHistory(peaks)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Peak use, last 7 days").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if enough { legend(Provider.allCases.filter { p in peaks.contains { $0.provider == p } }) }
            }
            if enough {
                chart(peaks, now: now)
            } else {
                Text("History builds up over the next days.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func legend(_ providers: [Provider]) -> some View {
        HStack(spacing: 10) {
            ForEach(providers) { p in
                HStack(spacing: 4) {
                    Circle().fill(p.tint).frame(width: 6, height: 6)
                    Text(p.name).font(.system(size: 10.5)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func chart(_ peaks: [DailyPeak], now: Date) -> some View {
        let start = UsageChart.start(now: now)
        let end = Calendar.current.date(byAdding: .day, value: UsageChart.days, to: start) ?? now
        return Chart(peaks) { p in
            BarMark(
                x: .value("Day", p.day, unit: .day),
                y: .value("Peak", p.peak),
                width: .fixed(6)
            )
            .position(by: .value("Provider", p.provider.name), span: .fixed(16))
            .foregroundStyle(p.provider.tint)
            .cornerRadius(1.5)
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { v in
                if v.as(Double.self) == 0 {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.hairline)
                }
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text(d == 100 ? "100%" : "\(Int(d))") }
                }
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .chartLegend(.hidden)
        .frame(height: 66)
        .accessibilityLabel("Daily peak usage over the last 7 days")
    }
}
