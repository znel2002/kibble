import Foundation

/// Reads Claude plan limits from Anthropic's OAuth usage endpoint, using the
/// token Claude Code already keeps in the login keychain. Kibble never
/// refreshes or stores the token; Claude Code owns it.
struct ClaudeSource {
    var home = FileManager.default.homeDirectoryForCurrentUser

    enum Failure: LocalizedError {
        case notSignedIn, expired, rateLimited, http(Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: "Sign in to Claude Code"
            case .expired: "Open Claude Code to refresh sign-in"
            case .rateLimited: "Rate limited, retrying soon"
            case .http(let code): "Usage API error \(code)"
            }
        }
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard let token = accessToken() else { throw Failure.notSignedIn }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("kibble/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200: return try Self.parse(data)
        case 401, 403: throw Failure.expired
        case 429: throw Failure.rateLimited
        default: throw Failure.http(code)
        }
    }

    static func parse(_ data: Data, now: Date = .now) throws -> ProviderUsage {
        struct Window: Decodable { let utilization: Double?; let resets_at: String? }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let names: [(key: String, label: String)] = [
            ("five_hour", "5-hour"),
            ("seven_day", "Weekly"),
            ("seven_day_opus", "Weekly Opus"),
            ("seven_day_sonnet", "Weekly Sonnet"),
        ]
        var windows: [UsageWindow] = []
        for (key, label) in names {
            guard let w = root[key] as? [String: Any], let used = w["utilization"] as? Double else { continue }
            let resets = (w["resets_at"] as? String).flatMap(parseDate)
            windows.append(UsageWindow(label: label, usedPercent: used, resetsAt: resets))
        }
        return ProviderUsage(provider: .claude, windows: windows, asOf: now)
    }

    static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// macOS keeps Claude Code's credentials in the keychain; Linux-style
    /// installs keep them in ~/.claude/.credentials.json.
    func accessToken() -> String? {
        if let json = Shell.run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
           let token = Self.token(fromCredentials: Data(json.utf8)) {
            return token
        }
        let file = home.appending(path: ".claude/.credentials.json")
        if let data = try? Data(contentsOf: file) { return Self.token(fromCredentials: data) }
        return nil
    }

    static func token(fromCredentials data: Data) -> String? {
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let oauth = obj?["claudeAiOauth"] as? [String: Any]
        return oauth?["accessToken"] as? String
    }

    // MARK: Agents

    /// Claude Code writes one JSON file per live session, with its pid and
    /// whether it is busy, idle or waiting on the user.
    func agents() -> [Agent] {
        let dir = home.appending(path: ".claude/sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = obj["pid"] as? Int, Process.isAlive(pid) else { return nil }
            let cwd = obj["cwd"] as? String ?? ""
            let since = (obj["statusUpdatedAt"] as? Double ?? obj["startedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now
            let project = URL(fileURLWithPath: cwd).lastPathComponent
            let name = (obj["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            // "busy", "idle", "shell", or "waiting" while a permission prompt,
            // question or dialog is open (the reason is in "waitingFor").
            let status = obj["status"] as? String
            return Agent(
                id: "claude-\(pid)",
                provider: .claude,
                title: Agent.isPlaceholder(name) ? project : name,
                project: project,
                busy: status == "busy",
                since: since,
                origin: .claude(session: obj),
                waiting: status == "waiting"
            )
        }
    }
}

enum Shell {
    static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Process {
    static func isAlive(_ pid: Int) -> Bool {
        kill(pid_t(pid), 0) == 0 || errno == EPERM
    }
}
