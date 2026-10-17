import Foundation
import UserNotifications

/// Turns agent events into the pet's reactions: a happy hop and a chime when a
/// task finishes, and a gentle nudge every ten seconds while one waits on the
/// user, until a click on the pet acknowledges it.
@MainActor
final class AgentAnnouncer {
    private let hound: Hound
    private var events = AgentEvents()
    private var done = DoneQueue()
    private var attention = Attention()
    private var timer: Timer?
    /// A wait started since the last nudge, so the next one makes a sound.
    private var ring = false
    /// Keeps one bubble on screen long enough to read before the next.
    private var quietUntil: Date = .distantPast

    init(hound: Hound) {
        self.hound = hound
    }

    /// Unacknowledged waits keep the pet awake.
    var needsAttention: Bool { attention.needsAttention }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func update(_ agents: [Agent], now: Date = .now) {
        for event in events.update(agents, now: now) {
            switch event {
            case .finished(let a, _):
                done.add(a)
            case .startedWaiting(let a):
                attention.start(a)
                ring = true
            case .stoppedWaiting(let a):
                attention.stop(a.id)
            }
        }
        tick(now: now)
    }

    /// A click on the pet: stop asking about the waits open right now.
    func acknowledge() {
        attention.acknowledge()
        ring = false
    }

    private func tick(now: Date = .now) {
        guard now >= quietUntil else { return }
        if let open = attention.due(now: now) {
            let line = AgentLines.waiting(open)
            hound.nudge(line.title, line.subtitle, open[0].provider.tint, sound: ring)
            ring = false
            quietUntil = now.addingTimeInterval(5)
        } else if let finished = done.next(now: now) {
            let line = AgentLines.done(finished, pet: hound.pet)
            hound.celebrate(line.title, line.subtitle, finished[0].provider.tint)
            Notifier.postFinished(finished)
            quietUntil = now.addingTimeInterval(5)
        }
    }

    // Demo hooks for screen recordings (menu bar ▸ Demo).
    func demoDone() {
        let line = AgentLines.done([Self.demoAgent], pet: hound.pet)
        hound.celebrate(line.title, line.subtitle, Provider.claude.tint)
    }

    func demoWaiting() {
        let line = AgentLines.waiting([Self.demoAgent])
        hound.nudge(line.title, line.subtitle, Provider.claude.tint, sound: true)
    }

    private static let demoAgent = Agent(id: "demo", provider: .claude, title: "Add usage forecasts", project: "kibble", busy: false, since: .now)
}

extension Notifier {
    /// "Claude finished: Fix the parser", without a sound.
    static func postFinished(_ agents: [Agent]) {
        guard Bundle.main.bundleIdentifier != nil, let first = agents.first else { return }
        let c = UNMutableNotificationContent()
        if agents.count == 1 {
            c.title = "\(first.provider.name) finished: \(first.title)"
            if !first.project.isEmpty, first.project != first.title { c.body = first.project }
        } else {
            c.title = "\(agents.count) tasks finished"
            c.body = agents.map { "\($0.provider.name): \($0.title)" }.joined(separator: "\n")
        }
        let req = UNNotificationRequest(identifier: "done-\(first.id)-\(Int(Date.now.timeIntervalSince1970))", content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
