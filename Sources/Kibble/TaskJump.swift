import AppKit
import Darwin
import SwiftUI

// Clicking a task in the card brings you to where it lives: the exact
// session in the Claude or Codex app when a verified deep link exists, else
// the app hosting the process (with the exact Terminal or iTerm tab when
// possible), else the project folder in Finder.
//
// Deep links, as the apps themselves build them (verified in their bundles):
//   claude://code/continue?session=local_<id>  Claude.app's own "Continue
//       session" entries; `session` must match ^local_[A-Za-z0-9-]{1,64}$,
//       which is the `hostSessionId` Claude Code writes for desktop sessions.
//   codex://threads/<thread id>                Codex's "Copy deeplink" command.

// MARK: Where an agent lives

/// What Kibble knows about where a task runs, read from the session files.
struct AgentOrigin: Equatable {
    /// The agent's own process, when the session file names it (Claude).
    var pid: Int32?
    var cwd = ""
    /// Claude's `sessionId`, or the Codex thread the app lists (the root
    /// thread for subagents).
    var sessionID: String?
    /// Claude desktop's `hostSessionId` ("local_…").
    var hostSessionID: String?
    /// Claude's `entrypoint` ("cli", "claude-desktop", "sdk-cli", …) or
    /// Codex's `originator` ("Codex Desktop", "codex-tui", …).
    var entrypoint: String?
    /// The Codex rollout log, held open by the process running the thread.
    var logPath: String?

    static func claude(session obj: [String: Any]) -> AgentOrigin {
        AgentOrigin(
            pid: (obj["pid"] as? Int).map { Int32(truncatingIfNeeded: $0) },
            cwd: obj["cwd"] as? String ?? "",
            sessionID: obj["sessionId"] as? String,
            hostSessionID: obj["hostSessionId"] as? String,
            entrypoint: obj["entrypoint"] as? String
        )
    }

    static func codex(log url: URL) -> AgentOrigin { CodexMetaCache.shared.origin(for: url) }

    /// Reads the `session_meta` line at the head of a rollout log.
    static func codex(meta text: String, logPath: String) -> AgentOrigin {
        func field(_ key: String) -> String? {
            guard let r = text.range(of: #""\#(key)":"([^"]*)""#, options: .regularExpression) else { return nil }
            let value = text[r].dropFirst(key.count + 4).dropLast()
            return value.isEmpty ? nil : String(value)
        }
        // Subagent threads keep their root thread in session_id; the app lists the root.
        return AgentOrigin(
            cwd: field("cwd") ?? "",
            sessionID: field("session_id") ?? field("id"),
            entrypoint: field("originator"),
            logPath: logPath
        )
    }
}

/// A log's session_meta never changes, so each is read once.
final class CodexMetaCache: @unchecked Sendable {
    static let shared = CodexMetaCache()
    private var map: [String: AgentOrigin] = [:]
    private let lock = NSLock()

    func origin(for url: URL) -> AgentOrigin {
        if let hit = lock.withLock({ map[url.path] }) { return hit }
        var text = ""
        if let h = try? FileHandle(forReadingFrom: url) {
            text = String(decoding: (try? h.read(upToCount: 32 * 1024)) ?? Data(), as: UTF8.self)
            try? h.close()
        }
        let origin = AgentOrigin.codex(meta: text, logPath: url.path)
        lock.withLock { map[url.path] = origin }
        return origin
    }
}

// MARK: Apps

enum AppKind: Equatable {
    case terminal, iTerm, ghostty, warp, vsCode, cursor, zed, claude, codex, chrome
    case other(String)

    init?(bundleID: String?) {
        switch bundleID?.lowercased() {
        case "com.apple.terminal": self = .terminal
        case "com.googlecode.iterm2": self = .iTerm
        case "com.mitchellh.ghostty": self = .ghostty
        case "dev.warp.warp-stable", "dev.warp.warp-preview", "dev.warp.warp": self = .warp
        case "com.microsoft.vscode", "com.microsoft.vscodeinsiders": self = .vsCode
        case "com.todesktop.230313mzl4w4u92": self = .cursor
        case "dev.zed.zed", "dev.zed.zed-preview": self = .zed
        case "com.anthropic.claudefordesktop": self = .claude
        // The Codex app ships as ChatGPT.app but keeps this identifier.
        case "com.openai.codex": self = .codex
        case "com.google.chrome": self = .chrome
        default: return nil
        }
    }

    /// For an app bundle whose Info.plist could not be read.
    init?(appName: String) {
        switch appName {
        case "Terminal": self = .terminal
        case "iTerm", "iTerm2": self = .iTerm
        case "Ghostty": self = .ghostty
        case "Warp": self = .warp
        case "Visual Studio Code": self = .vsCode
        case "Cursor": self = .cursor
        case "Zed": self = .zed
        case "Claude": self = .claude
        case "Codex": self = .codex
        case "Google Chrome": self = .chrome
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .terminal: "Terminal"
        case .iTerm: "iTerm"
        case .ghostty: "Ghostty"
        case .warp: "Warp"
        case .vsCode: "VS Code"
        case .cursor: "Cursor"
        case .zed: "Zed"
        case .claude: "Claude"
        case .codex: "Codex"
        case .chrome: "Chrome"
        case .other(let name): name
        }
    }

    /// Apps whose tabs can be picked out by tty over AppleScript.
    var focusesTab: Bool { self == .terminal || self == .iTerm }
}

/// One process on the way from an agent up to launchd.
struct Ancestor: Equatable {
    var pid: Int32
    var path: String
    /// Identifier of the outermost app bundle containing `path`, if any.
    var bundleID: String?
    /// A regular, Dock-visible app (not a helper or background agent).
    var isRegularApp = false
}

struct HostApp: Equatable {
    var kind: AppKind
    var appPath: String
    var pid: Int32
}

enum ProcessChain {
    /// "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
    /// -> "/Applications/ChatGPT.app". Helpers nest inside the app that owns them.
    static func outermostApp(in path: String) -> String? {
        if let r = path.range(of: ".app/") { return String(path[..<r.lowerBound]) + ".app" }
        return path.hasSuffix(".app") ? path : nil
    }

    static func appName(_ appPath: String) -> String {
        URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
    }

    /// The nearest ancestor inside an app Kibble knows; failing that, the
    /// nearest regular app. Nil when the agent runs detached (tmux, launchd).
    static func host(of chain: [Ancestor]) -> HostApp? {
        for a in chain {
            guard let app = outermostApp(in: a.path) else { continue }
            let kind = a.bundleID == nil ? AppKind(appName: appName(app)) : AppKind(bundleID: a.bundleID)
            if let kind { return HostApp(kind: kind, appPath: app, pid: a.pid) }
        }
        if let a = chain.first(where: \.isRegularApp), let app = outermostApp(in: a.path) {
            return HostApp(kind: .other(appName(app)), appPath: app, pid: a.pid)
        }
        return nil
    }
}

// MARK: Deciding where to go

enum JumpTarget: Equatable {
    /// A deep link straight to the session or thread.
    case link(URL, AppKind)
    /// Bring the hosting app forward; `tty` ("/dev/ttys001") picks the tab.
    case app(HostApp, tty: String?)
    case folder(String)
    case none

    /// Tooltip for the row.
    var label: String? {
        switch self {
        case .link(_, let kind): "Open in \(kind.name)"
        case .app(let host, _): "Open in \(host.kind.name)"
        case .folder: "Show folder"
        case .none: nil
        }
    }
}

enum JumpPlanner {
    static func claudeLink(hostSessionID: String?) -> URL? {
        guard let id = hostSessionID, id.range(of: #"^local_[A-Za-z0-9-]{1,64}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "claude://code/continue?session=\(id)")
    }

    static func codexLink(threadID: String?) -> URL? {
        guard let id = threadID, id.range(of: #"^[A-Za-z0-9-]{8,64}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }

    /// "Codex Desktop", "codex_work_desktop": threads the Codex app lists.
    static func isCodexApp(originator: String?) -> Bool {
        originator?.lowercased().contains("desktop") == true
    }

    /// - Parameters:
    ///   - host: the app found up the process chain, if any.
    ///   - tty: the agent's terminal device name, e.g. "ttys001".
    ///   - canOpen: whether a handler is installed for a URL scheme.
    ///   - isFolder: whether a path is an existing directory.
    static func plan(
        provider: Provider,
        origin: AgentOrigin,
        host: HostApp?,
        tty: String?,
        canOpen: (String) -> Bool = { _ in true },
        isFolder: (String) -> Bool = { _ in true }
    ) -> JumpTarget {
        switch provider {
        case .claude:
            if host?.kind == .claude || origin.entrypoint == "claude-desktop",
               let url = claudeLink(hostSessionID: origin.hostSessionID), canOpen("claude") {
                return .link(url, .claude)
            }
        case .codex:
            if host?.kind == .codex || isCodexApp(originator: origin.entrypoint),
               let url = codexLink(threadID: origin.sessionID), canOpen("codex") {
                return .link(url, .codex)
            }
        }
        if let host {
            return .app(host, tty: host.kind.focusesTab ? TerminalFocus.devicePath(tty: tty) : nil)
        }
        if !origin.cwd.isEmpty, isFolder(origin.cwd) { return .folder(origin.cwd) }
        return .none
    }
}

// MARK: Terminal tabs

enum TerminalFocus {
    /// "ttys001" -> "/dev/ttys001". Anything else is refused, so nothing
    /// unexpected ever reaches a script.
    static func devicePath(tty: String?) -> String? {
        guard let tty, tty.range(of: #"^ttys?[0-9]{1,4}$"#, options: .regularExpression) != nil else { return nil }
        return "/dev/\(tty)"
    }

    /// Fixed scripts; the tty arrives as an argument, never spliced in.
    static func script(for kind: AppKind) -> String? {
        switch kind {
        case .terminal:
            return """
            on run argv
                set target to item 1 of argv
                tell application id "com.apple.Terminal"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if tty of t is target then
                                set selected of t to true
                                set index of w to 1
                                activate
                                return
                            end if
                        end repeat
                    end repeat
                end tell
            end run
            """
        case .iTerm:
            return """
            on run argv
                set target to item 1 of argv
                tell application id "com.googlecode.iterm2"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if tty of s is target then
                                    select w
                                    select t
                                    select s
                                    activate
                                    return
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
            end run
            """
        default:
            return nil
        }
    }
}

// MARK: Reading processes

/// Read-only process lookups through libproc: no subprocesses, no signals.
enum ProcessProbe {
    static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    static func path(of pid: Int32) -> String? {
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
        return String(cString: buf)
    }

    /// "ttys001", or nil for a process without a terminal.
    static func tty(of pid: Int32) -> String? {
        guard let dev = bsdInfo(pid)?.e_tdev, dev != UInt32.max, dev != 0,
              let name = devname(dev_t(bitPattern: dev), mode_t(S_IFCHR)) else { return nil }
        return String(cString: name)
    }

    static func chain(from pid: Int32) -> [Ancestor] {
        var out: [Ancestor] = []
        var p = pid
        var seen = Set<Int32>()
        while p > 1, out.count < 32, seen.insert(p).inserted, let path = path(of: p) {
            let bundleID = ProcessChain.outermostApp(in: path).flatMap { Bundle(path: $0)?.bundleIdentifier }
            let regular = NSRunningApplication(processIdentifier: p)?.activationPolicy == .regular
            out.append(Ancestor(pid: p, path: path, bundleID: bundleID, isRegularApp: regular))
            guard let parent = bsdInfo(p)?.pbi_ppid else { break }
            p = Int32(bitPattern: parent)
        }
        return out
    }

    /// The process (by name) that has `file` open, e.g. the codex process
    /// writing a rollout log.
    static func pid(holdingOpen file: String, named names: Set<String>) -> Int32? {
        let target = URL(fileURLWithPath: file).resolvingSymlinksInPath().path
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        guard capacity > 64 else { return nil }
        var pids = [Int32](repeating: 0, count: capacity)
        let count = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<Int32>.stride)))
        for pid in pids.prefix(max(0, count)) where pid > 1 {
            var name = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &name, UInt32(name.count)) > 0, names.contains(String(cString: name)) else { continue }
            if holds(pid, target) { return pid }
        }
        return nil
    }

    private static func holds(_ pid: Int32, _ target: String) -> Bool {
        let stride = MemoryLayout<proc_fdinfo>.stride
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0 else { return false }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / stride + 16)
        let got = Int(proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * stride))) / stride
        let size = Int32(MemoryLayout<vnode_fdinfowithpath>.stride)
        for fd in fds.prefix(max(0, got)) where fd.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) {
            var info = vnode_fdinfowithpath()
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else { continue }
            let path = withUnsafeBytes(of: &info.pvip.vip_path) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            if path == target { return true }
        }
        return false
    }
}

// MARK: Jumping

@MainActor
final class TaskJump {
    static let shared = TaskJump()
    private var cache: [String: (target: JumpTarget, at: Date)] = [:]
    private let scriptQueue = DispatchQueue(label: "kibble.taskjump.applescript")

    func target(for agent: Agent, now: Date = .now) -> JumpTarget {
        if let hit = cache[agent.id], now.timeIntervalSince(hit.at) < 15 { return hit.target }
        let target = resolve(agent)
        if cache.count > 64 { cache = cache.filter { now.timeIntervalSince($0.value.at) < 15 } }
        cache[agent.id] = (target, now)
        return target
    }

    private func resolve(_ agent: Agent) -> JumpTarget {
        let origin = agent.origin
        let canOpen: (String) -> Bool = { scheme in
            URL(string: "\(scheme)://").flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) } != nil
        }
        let isFolder: (String) -> Bool = { path in
            var dir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &dir) && dir.boolValue
        }
        // A deep link needs no process lookup.
        let quick = JumpPlanner.plan(provider: agent.provider, origin: origin, host: nil, tty: nil, canOpen: canOpen, isFolder: isFolder)
        if case .link = quick { return quick }

        let pid = origin.pid ?? origin.logPath.flatMap { ProcessProbe.pid(holdingOpen: $0, named: ["codex"]) }
        let host = pid.map(ProcessProbe.chain(from:)).flatMap(ProcessChain.host(of:))
        let tty = pid.flatMap(ProcessProbe.tty(of:))
        return JumpPlanner.plan(provider: agent.provider, origin: origin, host: host, tty: tty, canOpen: canOpen, isFolder: isFolder)
    }

    func jump(to target: JumpTarget) {
        switch target {
        case .link(let url, _):
            NSWorkspace.shared.open(url)
        case .app(let host, let tty):
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: host.appPath), configuration: config)
            // Picking the tab needs Automation permission; if it is denied the
            // app still comes forward, and the failure stays quiet.
            if let tty, let script = TerminalFocus.script(for: host.kind) {
                scriptQueue.async { _ = Shell.run("/usr/bin/osascript", ["-e", script, tty]) }
            }
        case .folder(let path):
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        case .none:
            break
        }
    }
}

// MARK: Rows

private struct CloseCardKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Closes the detail card; set by CardView.
    var closeCard: () -> Void {
        get { self[CloseCardKey.self] }
        set { self[CloseCardKey.self] = newValue }
    }
}

extension View {
    /// Makes a task row open where the task lives.
    func jumpable(_ agent: Agent) -> some View { modifier(JumpableRow(agent: agent)) }
}

private struct JumpableRow: ViewModifier {
    let agent: Agent
    @Environment(\.closeCard) private var closeCard
    @State private var hovering = false

    func body(content: Content) -> some View {
        let target = TaskJump.shared.target(for: agent)
        if let label = target.label {
            Button {
                hovering = false
                NSCursor.arrow.set()
                TaskJump.shared.jump(to: target)
                closeCard()
            } label: {
                content
            }
            .buttonStyle(RowButtonStyle(hovering: hovering))
            .background(HoverTracker(hovering: $hovering))
            .help(label)
            .accessibilityHint(label)
        } else {
            content
        }
    }
}

private struct RowButtonStyle: ButtonStyle {
    let hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        configuration.label
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.primary.opacity(configuration.isPressed ? 0.08 : hovering ? 0.05 : 0)))
            .contentShape(shape)
            // Keep the row where it was; only the highlight reaches past it.
            .padding(.horizontal, -6)
            .padding(.vertical, -3)
    }
}

/// Hover and the pointing-hand cursor through an AppKit tracking area that
/// stays live while Kibble is inactive, as it always is: the card is a
/// non-activating panel.
private struct HoverTracker: NSViewRepresentable {
    @Binding var hovering: Bool

    func makeNSView(context: Context) -> TrackingView {
        let v = TrackingView()
        v.onChange = { hovering = $0 }
        return v
    }

    func updateNSView(_ v: TrackingView, context: Context) {
        v.onChange = { hovering = $0 }
    }

    final class TrackingView: NSView {
        var onChange: (Bool) -> Void = { _ in }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) {
            onChange(true)
            NSCursor.pointingHand.set()
        }

        override func mouseExited(with event: NSEvent) {
            onChange(false)
            NSCursor.arrow.set()
        }

        override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }

        // Clicks belong to the button above.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
