import Foundation

/// A change in what an agent is doing that the pet should tell the user about.
enum AgentEvent: Equatable {
    /// A turn of at least `AgentEvents.minimumTurn` ended and the session is still there.
    case finished(Agent, duration: TimeInterval)
    /// The agent is blocked on the user: a permission prompt or a question.
    case startedWaiting(Agent)
    /// The prompt was answered or dismissed, or the session went away.
    case stoppedWaiting(Agent)
}

/// Diffs successive agent lists into events. A turn runs from the first poll
/// that sees an agent busy (or waiting) until it is neither; only a turn that
/// ends with the session still alive counts as finished, so a closed terminal
/// is never "done".
struct AgentEvents {
    /// Quick replies don't deserve a celebration.
    var minimumTurn: TimeInterval = 20

    private var previous: [String: Agent] = [:]
    private var turnStart: [String: Date] = [:]

    mutating func update(_ agents: [Agent], now: Date = .now) -> [AgentEvent] {
        var events: [AgentEvent] = []
        var current: [String: Agent] = [:]
        for a in agents where current[a.id] == nil {
            current[a.id] = a
            let old = previous[a.id]
            let active = a.busy || a.waiting
            // Sources know when a turn really began; a poll only sees it later.
            if active, turnStart[a.id] == nil { turnStart[a.id] = min(a.since, now) }

            if a.waiting, old?.waiting != true { events.append(.startedWaiting(a)) }
            if !a.waiting, old?.waiting == true { events.append(.stoppedWaiting(a)) }
            if let old, old.busy, !active, let start = turnStart[a.id] {
                let duration = now.timeIntervalSince(start)
                if duration >= minimumTurn { events.append(.finished(a, duration: duration)) }
            }
            if !active { turnStart[a.id] = nil }
        }
        for (id, old) in previous.sorted(by: { $0.key < $1.key }) where current[id] == nil {
            if old.waiting { events.append(.stoppedWaiting(old)) }
            turnStart[id] = nil
        }
        previous = current
        return events
    }
}

/// Spaces out "done" announcements. Everything that finishes before the next
/// slot opens is announced together, so five agents finishing at once make one
/// "5 tasks done" rather than five bubbles in a row.
struct DoneQueue {
    var spacing: TimeInterval = 8

    private(set) var pending: [Agent] = []
    private var lastShown: Date = .distantPast

    mutating func add(_ agent: Agent) {
        pending.removeAll { $0.id == agent.id }
        pending.append(agent)
    }

    /// The tasks to announce now, if a slot is open.
    mutating func next(now: Date) -> [Agent]? {
        guard !pending.isEmpty, now.timeIntervalSince(lastShown) >= spacing else { return nil }
        defer { pending.removeAll(); lastShown = now }
        return pending
    }
}

/// Who is waiting on the user, and when the pet should ask again. A click on
/// the pet acknowledges every wait open at that moment; a new wait asks again.
struct Attention {
    var interval: TimeInterval = 10

    /// Oldest first.
    private(set) var waiting: [Agent] = []
    private var acknowledged: Set<String> = []
    private var lastNudge: Date = .distantPast

    var open: [Agent] { waiting.filter { !acknowledged.contains($0.id) } }
    var needsAttention: Bool { !open.isEmpty }

    mutating func start(_ agent: Agent) {
        waiting.removeAll { $0.id == agent.id }
        waiting.append(agent)
        acknowledged.remove(agent.id)
        lastNudge = .distantPast  // ask right away
    }

    mutating func stop(_ id: String) {
        waiting.removeAll { $0.id == id }
        acknowledged.remove(id)
    }

    mutating func acknowledge() {
        acknowledged.formUnion(waiting.map(\.id))
    }

    /// The waits to ask about now, newest first, if a nudge is due.
    mutating func due(now: Date) -> [Agent]? {
        let open = open
        guard !open.isEmpty, now.timeIntervalSince(lastNudge) >= interval else { return nil }
        lastNudge = now
        return open.reversed()
    }
}

/// The words for announcements, kept short enough for the speech bubble.
enum AgentLines {
    static let bubbleWidth = 26

    static func done(_ agents: [Agent], pet: PetArt) -> (title: String, subtitle: String?) {
        guard let first = agents.first else { return (pet.doneLine, nil) }
        if agents.count == 1 { return (pet.doneLine, clip(first.title, bubbleWidth)) }
        let providers = Provider.allCases.filter { p in agents.contains { $0.provider == p } }.map(\.name)
        return ("\(agents.count) tasks done", "From " + providers.joined(separator: " and "))
    }

    static func waiting(_ agents: [Agent]) -> (title: String, subtitle: String?) {
        let title = agents.count > 1 ? "\(agents.count) need you" : "Needs you"
        return (title, agents.first.map { clip($0.title, bubbleWidth) })
    }

    static func clip(_ s: String, _ max: Int) -> String {
        guard s.count > max else { return s }
        return String(s.prefix(max - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

extension PetArt {
    var doneLine: String {
        switch kind {
        case "cat": "Prrp, done!"
        case "hamster": "Done! Eep!"
        default: "Done!"
        }
    }
}
