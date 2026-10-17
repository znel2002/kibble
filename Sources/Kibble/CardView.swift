import SwiftUI

/// The detail card that opens next to the pet on click.
struct CardView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var hound: Hound
    var onClose: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { _ in
            // On a screen too short for everything, drop detail in steps rather
            // than clip: first the history chart, then the idle list, then reset
            // times, forecasts and extra tasks.
            ViewThatFits(in: .vertical) {
                card(.full, chart: true)
                card(.full)
                card(.compact)
                card(.minimal)
            }
        }
        .environment(\.closeCard, onClose)
    }

    enum Density { case full, compact, minimal }

    private func card(_ density: Density, chart: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)
            sections(density)
            if chart {
                UsageChartSection(history: store.history)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
            }
            footer
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
        .padding(16)
        .frame(width: 284)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
        .padding(CardPlacement.margin)
    }

    private func sections(_ density: Density) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Provider.allCases) { p in
                ProviderSection(usage: store.usage(for: p), busy: store.busy(p), showResets: density != .minimal,
                                forecasts: density == .minimal ? [:] : store.forecasts(for: p))
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
            }
            AgentsSection(agents: store.agents, showIdle: density == .full, maxWorking: density == .minimal ? 2 : 6)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            SpriteView(frame: "avatar", pet: hound.pet, scale: 1)
            VStack(alignment: .leading, spacing: 1) {
                Text("Kibble").font(.system(size: 14, weight: .semibold))
                Text(updatedLine).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: store.refreshNow) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")
        }
    }

    private var updatedLine: String {
        let waiting = store.agents.filter(\.waiting).count
        let working = store.agents.filter { $0.busy && !$0.waiting }.count
        var parts: [String] = []
        if waiting > 0 { parts.append(waiting == 1 ? "1 needs you" : "\(waiting) need you") }
        if working > 0 { parts.append(working == 1 ? "1 agent working" : "\(working) agents working") }
        return parts.isEmpty ? "No agents working" : parts.joined(separator: " · ")
    }

    private var footer: some View {
        HStack {
            Button {
                hound.muted.toggle()
            } label: {
                Text(hound.muted ? "Turn sounds on" : "Mute sounds")
                    .font(.system(size: 11.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Close", action: onClose)
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
    }
}

struct ProviderSection: View {
    let usage: ProviderUsage
    let busy: Bool
    var showResets = true
    /// Burn-rate forecasts by window label; empty hides them.
    var forecasts: [String: BurnForecast] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(usage.provider.tint).frame(width: 7, height: 7)
                Text(usage.provider.name).font(.system(size: 13, weight: .semibold))
                if busy {
                    Text("Working").font(.system(size: 11.5)).foregroundStyle(usage.provider.tint)
                }
                Spacer()
                if let asOf = usage.asOf, usage.provider == .codex {
                    Text("Updated \(Format.ago(asOf))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            if usage.windows.isEmpty {
                Text(usage.error ?? "Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            ForEach(usage.windows) { w in
                WindowRow(window: w, tint: usage.provider.tint, showReset: showResets, forecast: forecasts[w.label])
            }
            if let e = usage.error, !usage.windows.isEmpty {
                Text(e).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

struct WindowRow: View {
    let window: UsageWindow
    let tint: Color
    var showReset = true
    var forecast: BurnForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(window.leftPercent.rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(window.leftPercent <= 10 ? Theme.danger : .primary)
                + Text(" left").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            LevelBar(fraction: window.leftPercent / 100, color: Theme.barColor(left: window.leftPercent, tint: tint), height: 5)
            if let forecast {
                Text(forecast.phrase())
                    .font(.system(size: 11))
                    .foregroundStyle(forecast.isSoon() ? AnyShapeStyle(Theme.warn) : AnyShapeStyle(.tertiary))
            }
            if showReset, let r = window.resetsAt {
                Text("Resets \(Format.relative(r)), \(r.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, forecast == nil ? 0 : -3)
            }
        }
    }
}

struct AgentsSection: View {
    let agents: [Agent]
    var showIdle = true
    var maxWorking = 6

    var body: some View {
        // Tasks waiting on the user come first.
        let working = agents.filter(\.waiting) + agents.filter { $0.busy && !$0.waiting }
        // Forked threads share a title; list each idle task once.
        var seen = Set(working.map { "\($0.provider.rawValue)|\($0.title)" })
        let idle = agents.filter { !$0.busy && !$0.waiting }.sorted { $0.since > $1.since }
            .filter { seen.insert("\($0.provider.rawValue)|\($0.title)").inserted }
        VStack(alignment: .leading, spacing: 10) {
            Text("Working on").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            if working.isEmpty {
                Text("Nothing in progress.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            ForEach(working.prefix(maxWorking)) { a in
                TaskRow(agent: a).jumpable(a)
            }
            if working.count > maxWorking {
                Text("and \(working.count - maxWorking) more").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            if showIdle, !idle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Idle").font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
                    ForEach(idle.prefix(3)) { a in
                        HStack(spacing: 7) {
                            Circle().strokeBorder(a.provider.tint.opacity(0.7), lineWidth: 1.1).frame(width: 6, height: 6)
                            Text(a.title).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(a.provider.name).font(.system(size: 10.5)).foregroundStyle(.tertiary)
                        }
                        .jumpable(a)
                    }
                    if idle.count > 3 {
                        Text("and \(idle.count - 3) more").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

/// One task an agent is busy with: its title, where, and for how long.
struct TaskRow: View {
    let agent: Agent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            WorkingDot(tint: agent.provider.tint, active: true)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                (Text(subtitle).foregroundStyle(.tertiary) + needsYou)
                    .font(.system(size: 10.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        var parts = [agent.provider.name]
        if !agent.project.isEmpty, agent.project != agent.title { parts.append(agent.project) }
        if !agent.waiting { parts.append("for \(Format.duration(since: agent.since))") }
        return parts.joined(separator: " · ")
    }

    /// In place of the duration while the agent waits on the user.
    private var needsYou: Text {
        agent.waiting ? Text(" · ").foregroundStyle(.tertiary) + Text("Needs you").fontWeight(.medium).foregroundStyle(agent.provider.tint) : Text("")
    }
}
