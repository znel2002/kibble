import Foundation

/// Codex records its plan limits in every `token_count` event of its session
/// logs (~/.codex/sessions/YYYY/MM/DD/*.jsonl), so no network call is needed.
struct CodexSource {
    var home = FileManager.default.homeDirectoryForCurrentUser

    private var sessionsDir: URL { home.appending(path: ".codex/sessions") }

    /// Session logs, newest first.
    func recentLogs(limit: Int = 12) -> [(url: URL, modified: Date)] {
        let fm = FileManager.default
        var found: [(URL, Date)] = []
        // Walk year/month/day directories newest first and stop once we have enough.
        func sortedDirs(_ url: URL) -> [URL] {
            ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.hasDirectoryPath }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }
        outer: for year in sortedDirs(sessionsDir) {
            for month in sortedDirs(year) {
                for day in sortedDirs(month) {
                    let files = (try? fm.contentsOfDirectory(at: day, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
                    for f in files where f.pathExtension == "jsonl" {
                        let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                        found.append((f, m))
                    }
                    if found.count >= limit { break outer }
                }
            }
        }
        return found.sorted { $0.1 > $1.1 }.prefix(limit).map { (url: $0.0, modified: $0.1) }
    }

    func usage(now: Date = .now) -> ProviderUsage {
        for log in recentLogs() {
            let lines = FileTail.lines(of: log.url, maxBytes: 768 * 1024)
            for line in lines.reversed() where line.contains("\"rate_limits\"") {
                if let usage = Self.parse(line: line, now: now) { return usage }
            }
        }
        return ProviderUsage(provider: .codex, error: "No Codex sessions yet")
    }

    static func parse(line: String, now: Date = .now) -> ProviderUsage? {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let payload = obj["payload"] as? [String: Any],
              let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        var windows: [UsageWindow] = []
        for key in ["primary", "secondary"] {
            guard let w = limits[key] as? [String: Any], let used = w["used_percent"] as? Double else { continue }
            let minutes = w["window_minutes"] as? Int ?? 0
            let resets = (w["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            windows.append(UsageWindow(label: UsageWindow.label(forMinutes: minutes), usedPercent: used, resetsAt: resets))
        }
        guard !windows.isEmpty else { return nil }
        // Shortest window first, so "5-hour" sits above "Weekly" like Claude's.
        windows.sort { ($0.label == "5-hour" ? 0 : 1) < ($1.label == "5-hour" ? 0 : 1) }
        let asOf = (obj["timestamp"] as? String).flatMap(ClaudeSource.parseDate)
        return ProviderUsage(provider: .codex, windows: windows.map { $0.normalized(now: now) }, asOf: asOf)
    }

    /// A Codex session is live if its log was written recently. It is busy if
    /// the last turn event is a `task_started` with no matching completion, and
    /// waiting if that turn ended on a question to the user. An unanswered
    /// question keeps the thread listed for two hours rather than thirty minutes.
    func agents(now: Date = .now) -> [Agent] {
        let titles = threadTitles()
        return recentLogs(limit: 20).compactMap { log in
            let age = now.timeIntervalSince(log.modified)
            guard age < 2 * 3600 else { return nil }
            let turn = TurnTracker.shared.turn(of: log.url)
            guard age < 30 * 60 || turn == .awaitingReply else { return nil }
            var busy = false
            var waiting = false
            var since = log.modified
            switch turn {
            case .started(let at):
                busy = age < 10 * 60
                since = at ?? log.modified
            case .finished:
                break
            case .awaitingReply:
                waiting = true
            case .unknown:
                // A turn so long its start is out of reach: still writing means still working.
                busy = age < 2 * 60
            }
            let cwd = FileTail.firstMatch(in: log.url, pattern: "\"cwd\":\"([^\"]+)\"") ?? ""
            let project = URL(fileURLWithPath: cwd).lastPathComponent
            let origin = AgentOrigin.codex(log: log.url)
            // The filename usually ends in the thread id, but not always; session_meta
            // also names the root thread, which is what the app titles for subagents.
            let title = Self.threadID(of: log.url).flatMap { titles[$0] }
                ?? origin.sessionID.flatMap { titles[$0] }
                ?? Self.firstPrompt(in: log.url) ?? project
            return Agent(
                id: "codex-\(log.url.lastPathComponent)",
                provider: .codex,
                title: title,
                project: project,
                busy: busy,
                since: since,
                origin: origin,
                waiting: waiting
            )
        }
    }

    /// Codex names threads in ~/.codex/session_index.jsonl; later lines win.
    func threadTitles() -> [String: String] {
        guard let text = try? String(contentsOf: home.appending(path: ".codex/session_index.jsonl"), encoding: .utf8) else { return [:] }
        var out: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let id = obj["id"] as? String, let name = obj["thread_name"] as? String, !name.isEmpty else { continue }
            out[id] = name
        }
        return out
    }

    /// rollout-2026-10-02T12-12-28-<uuid>.jsonl -> <uuid>
    static func threadID(of url: URL) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.count >= 36 else { return nil }
        return String(name.suffix(36))
    }

    /// Before Codex names a new thread, use its first real prompt. Forked threads
    /// carry megabytes of inherited context first, so this streams up to 16 MB,
    /// and the answer is cached because a thread's first prompt never changes.
    static func firstPrompt(in url: URL) -> String? {
        if let hit = PromptCache.shared.get(url.path) { return hit.title }
        let title = scanFirstPrompt(in: url)
        PromptCache.shared.set(url.path, title)
        return title
    }

    private static func scanFirstPrompt(in url: URL, limit: Int = 16 << 20) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var buffer = Data()
        var read = 0
        let marker = Data(#""role":"user""#.utf8)
        while read < limit {
            guard let chunk = try? h.read(upToCount: 1 << 20), !chunk.isEmpty else { break }
            read += chunk.count
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                if line.range(of: marker) != nil, let title = prompt(fromLine: Data(line)) { return title }
            }
        }
        // The last line may have no trailing newline.
        if read < limit, buffer.range(of: marker) != nil { return prompt(fromLine: buffer) }
        return nil
    }

    static func prompt(fromLine line: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = obj["payload"] as? [String: Any],
              let content = payload["content"] as? [[String: Any]] else { return nil }
        for part in content {
            guard let t = part["text"] as? String else { continue }
            let first = t.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
            // Skip harness wrappers like <environment_context> and app events.
            if first.isEmpty || first.hasPrefix("<") || first.hasPrefix("#") { continue }
            return titleCase(first)
        }
        return nil
    }

    /// "Okay can you now make a plan for the video?" -> "Make a plan for the video?"
    static func titleCase(_ prompt: String) -> String {
        var s = prompt
        let filler = #"^(?i)((ok(ay)?|so|hey|hi|please|pls|now|then|also|alright|right|great|cool|thanks)[,.!]?\s+|(can|could|would|will) you\s+(please\s+)?)+"#
        if let r = s.range(of: filler, options: .regularExpression) { s.removeSubrange(r) }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { s = prompt }
        s = s.prefix(1).uppercased() + s.dropFirst()
        return s.count > 64 ? String(s.prefix(63)).trimmingCharacters(in: .whitespaces) + "…" : s
    }

    static func timestamp(_ line: String) -> Date? {
        guard let r = line.range(of: #""timestamp":"([^"]+)""#, options: .regularExpression) else { return nil }
        let s = line[r].dropFirst(13).dropLast()
        return ClaudeSource.parseDate(String(s))
    }
}

/// Where each Codex log's current turn stands. Remembers how far it has read,
/// so each poll only scans bytes written since the last one; a log seen for
/// the first time is scanned backwards up to 16 MB.
final class TurnTracker: @unchecked Sendable {
    /// `awaitingReply`: the turn ended after Codex asked the user something
    /// with `request_user_input_async`, and no new turn has started since.
    enum Turn: Equatable { case started(Date?), finished, awaitingReply, unknown }

    static let shared = TurnTracker()
    /// `asked`: the latest turn asked the user a question.
    private struct State { var size: UInt64; var turn: Turn; var asked: Bool }
    private var states: [String: State] = [:]
    private let lock = NSLock()

    static let startMarker = #""type":"task_started""#
    static let endMarkers = [#""type":"task_complete""#, #""type":"turn_aborted""#]
    /// Codex's question tool. It returns at once and the turn carries on, so a
    /// question only means "waiting" once the turn has ended without a reply.
    static let questionMarker = #""name":"request_user_input_async""#

    func turn(of url: URL) -> Turn {
        guard let h = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let known = lock.withLock { states[url.path] }

        if let known, size >= known.size {
            if size == known.size { return known.turn }
            let state = Self.read(h, from: known.size, to: size).map { Self.advance(known, by: $0, size: size) }
                ?? State(size: size, turn: known.turn, asked: known.asked)
            lock.withLock { states[url.path] = state }
            return state.turn
        }
        // First sighting (or the file was replaced): walk backwards in 1 MB steps
        // to the latest turn event, then on to that turn's start to see whether
        // it asked anything.
        var turn: Turn?
        var asked = false
        var end = size
        let floor = size > 16 << 20 ? size - (16 << 20) : 0
        walk: while end > floor {
            let start = max(floor, end > 1 << 20 ? end - (1 << 20) : 0)
            defer { end = start }
            if turn == nil {
                // Overlap by a line's worth so a marker split across chunks is still seen.
                guard let c = Self.read(h, from: start, to: min(size, end + 4096)) else { continue }
                switch c.last {
                case nil:
                    asked = asked || c.askedAfterLast
                case .start(let at)?:
                    turn = .started(at)
                    asked = asked || c.askedAfterLast
                    break walk
                case .end?:
                    turn = .finished
                    asked = asked || c.askedInTurn
                    if c.startSeen { break walk }
                }
            } else {
                // Still looking for where the finished turn began. Overlap less
                // than a marker's length, so the end already found isn't seen again.
                guard let c = Self.read(h, from: start, to: min(size, end + 21)) else { continue }
                asked = asked || c.askedAfterLast
                if c.last != nil { break walk }
            }
        }
        let state = State(size: size, turn: Self.resolve(turn ?? .unknown, asked: asked), asked: asked)
        lock.withLock { states[url.path] = state }
        return state.turn
    }

    private static func advance(_ known: State, by c: Scan, size: UInt64) -> State {
        var turn = known.turn
        var asked = known.asked
        switch c.last {
        case nil:
            asked = asked || c.askedAfterLast
        case .start(let at)?:
            turn = .started(at)
            asked = c.askedAfterLast
        case .end?:
            turn = .finished
            asked = c.askedInTurn || (!c.startSeen && known.asked)
        }
        return State(size: size, turn: resolve(turn, asked: asked), asked: asked)
    }

    private static func resolve(_ turn: Turn, asked: Bool) -> Turn {
        switch turn {
        case .finished, .awaitingReply: asked ? .awaitingReply : .finished
        default: turn
        }
    }

    /// What a stretch of log says about the turn.
    struct Scan {
        enum Boundary: Equatable { case start(Date?), end }
        /// The last turn start or end in the stretch.
        var last: Boundary?
        /// The stretch also holds the start of the turn that `last` ends.
        var startSeen = false
        /// A question between that turn's start (or the stretch's beginning) and `last`.
        var askedInTurn = false
        /// A question after `last`, or anywhere if there is no boundary.
        var askedAfterLast = false
    }

    static func read(_ h: FileHandle, from: UInt64, to: UInt64) -> Scan? {
        guard to > from else { return nil }
        try? h.seek(toOffset: from)
        guard let data = try? h.read(upToCount: Int(to - from)) else { return nil }
        let c = scan(String(decoding: data, as: UTF8.self))
        return c.last == nil && !c.askedAfterLast ? nil : c
    }

    static func scan(_ text: String) -> Scan {
        let start = text.range(of: startMarker, options: .backwards)
        let end = endMarkers.compactMap { text.range(of: $0, options: .backwards) }.max { $0.lowerBound < $1.lowerBound }
        func asked(from lo: String.Index?, to hi: String.Index? = nil) -> Bool {
            let lo = lo ?? text.startIndex, hi = hi ?? text.endIndex
            return lo < hi && text.range(of: questionMarker, options: .backwards, range: lo..<hi) != nil
        }
        var c = Scan()
        if let s = start, end.map({ s.lowerBound > $0.lowerBound }) ?? true {
            // The timestamp sits at the start of the event's line.
            let lineStart = text[..<s.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            c.last = .start(CodexSource.timestamp(String(text[lineStart..<s.lowerBound])))
            c.startSeen = true
            c.askedAfterLast = asked(from: s.upperBound)
        } else if let e = end {
            c.last = .end
            c.startSeen = start != nil
            c.askedInTurn = asked(from: start?.upperBound, to: e.lowerBound)
            c.askedAfterLast = asked(from: e.upperBound)
        } else {
            c.askedAfterLast = asked(from: nil)
        }
        return c
    }
}

/// Thread-safe memo of first prompts, keyed by log path.
final class PromptCache: @unchecked Sendable {
    static let shared = PromptCache()
    struct Entry { let title: String? }
    private var map: [String: Entry] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> Entry? { lock.withLock { map[key] } }
    func set(_ key: String, _ title: String?) { lock.withLock { map[key] = Entry(title: title) } }
}

enum FileTail {
    /// Complete lines from the last `maxBytes` of a file.
    static func lines(of url: URL, maxBytes: Int) -> [String] {
        guard let h = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? h.seek(toOffset: start)
        guard let data = try? h.readToEnd(), let text = String(data: data, encoding: .utf8) else { return [] }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if start > 0, !lines.isEmpty { lines.removeFirst() } // partial line
        return lines
    }

    static func firstMatch(in url: URL, pattern: String, maxBytes: Int = 96 * 1024) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let data = try? h.read(upToCount: maxBytes),
              let text = String(data: data, encoding: .utf8) ?? String(data: data.prefix(maxBytes - 4), encoding: .utf8),
              let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
