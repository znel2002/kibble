import XCTest
@testable import Kibble

final class TaskJumpTests: XCTestCase {
    // MARK: Classification

    func testKnownBundleIDs() {
        XCTAssertEqual(AppKind(bundleID: "com.apple.Terminal"), .terminal)
        XCTAssertEqual(AppKind(bundleID: "com.googlecode.iterm2"), .iTerm)
        XCTAssertEqual(AppKind(bundleID: "com.mitchellh.ghostty"), .ghostty)
        XCTAssertEqual(AppKind(bundleID: "dev.warp.Warp-Stable"), .warp)
        XCTAssertEqual(AppKind(bundleID: "com.microsoft.VSCode"), .vsCode)
        XCTAssertEqual(AppKind(bundleID: "com.todesktop.230313mzl4w4u92"), .cursor)
        XCTAssertEqual(AppKind(bundleID: "com.anthropic.claudefordesktop"), .claude)
        XCTAssertEqual(AppKind(bundleID: "com.openai.codex"), .codex)
        XCTAssertNil(AppKind(bundleID: "com.anthropic.claude-code"))
        XCTAssertNil(AppKind(bundleID: "com.openai.codex.cli"))
        XCTAssertNil(AppKind(bundleID: nil))
    }

    func testOutermostAppSkipsNestedHelpers() {
        XCTAssertEqual(
            ProcessChain.outermostApp(in: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"),
            "/Applications/ChatGPT.app")
        XCTAssertEqual(
            ProcessChain.outermostApp(in: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)"),
            "/Applications/Visual Studio Code.app")
        XCTAssertNil(ProcessChain.outermostApp(in: "/Users/me/.local/share/claude/versions/2.1.287"))
        XCTAssertNil(ProcessChain.outermostApp(in: "/bin/zsh"))
    }

    /// claude -> disclaimer -> Claude, as Claude.app launches Claude Code.
    func testClaudeDesktopChain() {
        let chain = [
            Ancestor(pid: 51798, path: "/Users/me/Library/Application Support/Claude/claude-code/2.1.286/x/claude.app/Contents/MacOS/claude", bundleID: "com.anthropic.claude-code"),
            Ancestor(pid: 51797, path: "/Applications/Claude.app/Contents/Helpers/disclaimer", bundleID: "com.anthropic.claudefordesktop"),
            Ancestor(pid: 14855, path: "/Applications/Claude.app/Contents/MacOS/Claude", bundleID: "com.anthropic.claudefordesktop", isRegularApp: true),
        ]
        XCTAssertEqual(ProcessChain.host(of: chain), HostApp(kind: .claude, appPath: "/Applications/Claude.app", pid: 51797))
    }

    /// claude -> zsh -> login -> Terminal.
    func testTerminalChain() {
        let chain = [
            Ancestor(pid: 10, path: "/Users/me/.local/share/claude/versions/2.1.287"),
            Ancestor(pid: 9, path: "/bin/zsh"),
            Ancestor(pid: 8, path: "/usr/bin/login"),
            Ancestor(pid: 7, path: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal", bundleID: "com.apple.Terminal", isRegularApp: true),
        ]
        XCTAssertEqual(ProcessChain.host(of: chain)?.kind, .terminal)
        XCTAssertEqual(ProcessChain.host(of: chain)?.appPath, "/System/Applications/Utilities/Terminal.app")
    }

    func testUnknownRegularAppIsUsedByName() {
        let chain = [
            Ancestor(pid: 10, path: "/opt/bin/claude"),
            Ancestor(pid: 9, path: "/Applications/Nova.app/Contents/MacOS/Nova", bundleID: "com.panic.Nova", isRegularApp: true),
        ]
        XCTAssertEqual(ProcessChain.host(of: chain), HostApp(kind: .other("Nova"), appPath: "/Applications/Nova.app", pid: 9))
    }

    func testAppNameFallbackWithoutBundleID() {
        let chain = [Ancestor(pid: 9, path: "/Applications/iTerm.app/Contents/MacOS/iTerm2")]
        XCTAssertEqual(ProcessChain.host(of: chain)?.kind, .iTerm)
    }

    /// A background session under `claude bg-pty-host`, or tmux: no app at all.
    func testDetachedChainHasNoHost() {
        let chain = [
            Ancestor(pid: 91836, path: "/Users/me/.local/share/claude/versions/2.1.287"),
            Ancestor(pid: 91831, path: "/Users/me/.local/share/claude/versions/2.1.287"),
        ]
        XCTAssertNil(ProcessChain.host(of: chain))
        XCTAssertNil(ProcessChain.host(of: []))
    }

    func testNonRegularUnknownAppIsNotAHost() {
        let chain = [Ancestor(pid: 9, path: "/Users/me/Library/Application Support/Claude/claude-code/2.1.286/x/claude.app/Contents/MacOS/claude", bundleID: "com.anthropic.claude-code")]
        XCTAssertNil(ProcessChain.host(of: chain))
    }

    // MARK: Origins

    func testClaudeOriginFromSessionFile() {
        let obj: [String: Any] = ["pid": 51798, "cwd": "/Users/me/proj", "sessionId": "a1b2c3d4", "hostSessionId": "local_0f1e2d3c-4b5a", "entrypoint": "claude-desktop", "kind": "interactive"]
        let o = AgentOrigin.claude(session: obj)
        XCTAssertEqual(o.pid, 51798)
        XCTAssertEqual(o.cwd, "/Users/me/proj")
        XCTAssertEqual(o.hostSessionID, "local_0f1e2d3c-4b5a")
        XCTAssertEqual(o.entrypoint, "claude-desktop")
    }

    func testCodexOriginUsesRootThreadForSubagents() {
        let meta = #"{"timestamp":"2026-10-03T13:40:28.165Z","type":"session_meta","payload":{"session_id":"01a00000-0000-7000-8000-000000000001","id":"01a00000-0000-7000-8000-000000000002","parent_thread_id":"01a00000-0000-7000-8000-000000000001","cwd":"/Users/me/notes","originator":"Codex Desktop","source":{"subagent":{}}}}"#
        let o = AgentOrigin.codex(meta: meta, logPath: "/tmp/x.jsonl")
        XCTAssertEqual(o.sessionID, "01a00000-0000-7000-8000-000000000001")
        XCTAssertEqual(o.cwd, "/Users/me/notes")
        XCTAssertEqual(o.entrypoint, "Codex Desktop")
        XCTAssertEqual(o.logPath, "/tmp/x.jsonl")
        XCTAssertNil(o.pid)
    }

    func testCodexOriginWithoutSessionIDFallsBackToID() {
        let meta = #"{"type":"session_meta","payload":{"id":"01a00000-0000-7000-8000-000000000003","cwd":"/Users/me/doe","originator":"codex-tui"}}"#
        XCTAssertEqual(AgentOrigin.codex(meta: meta, logPath: "").sessionID, "01a00000-0000-7000-8000-000000000003")
    }

    // MARK: Planning

    func testClaudeDesktopSessionDeepLinks() {
        let origin = AgentOrigin(pid: 1, cwd: "/p", hostSessionID: "local_0f1e2d3c-4b5a-48c7-b781-03c34b3f8a78", entrypoint: "claude-desktop")
        let t = JumpPlanner.plan(provider: .claude, origin: origin, host: nil, tty: nil)
        XCTAssertEqual(t, .link(URL(string: "claude://code/continue?session=local_0f1e2d3c-4b5a-48c7-b781-03c34b3f8a78")!, .claude))
        XCTAssertEqual(t.label, "Open in Claude")
    }

    func testClaudeLinkRejectsUnexpectedIDs() {
        XCTAssertNil(JumpPlanner.claudeLink(hostSessionID: "a1b2c3d4-5e6f"))
        XCTAssertNil(JumpPlanner.claudeLink(hostSessionID: "local_../x&y=1"))
        XCTAssertNil(JumpPlanner.claudeLink(hostSessionID: nil))
        // Without a usable id, the app itself is the next best place.
        let host = HostApp(kind: .claude, appPath: "/Applications/Claude.app", pid: 2)
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(cwd: "/p", hostSessionID: "bogus"), host: host, tty: nil)
        XCTAssertEqual(t, .app(host, tty: nil))
    }

    func testNoDeepLinkWhenSchemeIsNotInstalled() {
        let origin = AgentOrigin(cwd: "/p", hostSessionID: "local_abc", entrypoint: "claude-desktop")
        let t = JumpPlanner.plan(provider: .claude, origin: origin, host: nil, tty: nil, canOpen: { _ in false })
        XCTAssertEqual(t, .folder("/p"))
    }

    func testTerminalSessionFocusesItsTab() {
        let host = HostApp(kind: .terminal, appPath: "/System/Applications/Utilities/Terminal.app", pid: 7)
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(pid: 10, cwd: "/p", entrypoint: "cli"), host: host, tty: "ttys001")
        XCTAssertEqual(t, .app(host, tty: "/dev/ttys001"))
        XCTAssertEqual(t.label, "Open in Terminal")
    }

    func testEditorTerminalOnlyActivates() {
        let host = HostApp(kind: .vsCode, appPath: "/Applications/Visual Studio Code.app", pid: 7)
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(cwd: "/p", entrypoint: "cli"), host: host, tty: "ttys004")
        XCTAssertEqual(t, .app(host, tty: nil))
        XCTAssertEqual(t.label, "Open in VS Code")
    }

    /// Claude Code driven by the Codex app (entrypoint "sdk-cli").
    func testClaudeInsideCodexAppOpensCodex() {
        let host = HostApp(kind: .codex, appPath: "/Applications/ChatGPT.app", pid: 90728)
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(pid: 40350, cwd: "/p", entrypoint: "sdk-cli"), host: host, tty: nil)
        XCTAssertEqual(t, .app(host, tty: nil))
        XCTAssertEqual(t.label, "Open in Codex")
    }

    func testDetachedSessionShowsFolder() {
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(pid: 91836, cwd: "/Users/me/proj", entrypoint: "cli"), host: nil, tty: "ttys001")
        XCTAssertEqual(t, .folder("/Users/me/proj"))
        XCTAssertEqual(t.label, "Show folder")
    }

    func testMissingFolderMeansNothingToDo() {
        let t = JumpPlanner.plan(provider: .claude, origin: AgentOrigin(cwd: "/gone"), host: nil, tty: nil, isFolder: { _ in false })
        XCTAssertEqual(t, JumpTarget.none)
        XCTAssertNil(t.label)
        XCTAssertEqual(JumpPlanner.plan(provider: .codex, origin: AgentOrigin(), host: nil, tty: nil), JumpTarget.none)
    }

    func testCodexDesktopThreadDeepLinks() {
        let origin = AgentOrigin(cwd: "/v", sessionID: "01a00000-0000-7000-8000-000000000001", entrypoint: "Codex Desktop")
        let t = JumpPlanner.plan(provider: .codex, origin: origin, host: nil, tty: nil)
        XCTAssertEqual(t, .link(URL(string: "codex://threads/01a00000-0000-7000-8000-000000000001")!, .codex))
        XCTAssertEqual(t.label, "Open in Codex")
        XCTAssertTrue(JumpPlanner.isCodexApp(originator: "codex_work_desktop"))
        XCTAssertFalse(JumpPlanner.isCodexApp(originator: "codex-tui"))
    }

    func testCodexCLIInITermFocusesItsSession() {
        let host = HostApp(kind: .iTerm, appPath: "/Applications/iTerm.app", pid: 5)
        let origin = AgentOrigin(cwd: "/v", sessionID: "01a00000-0000-7000-8000-000000000003", entrypoint: "codex-tui")
        XCTAssertEqual(JumpPlanner.plan(provider: .codex, origin: origin, host: host, tty: "ttys012"), .app(host, tty: "/dev/ttys012"))
    }

    func testCodexChromeSidePanelOpensChrome() {
        let host = HostApp(kind: .chrome, appPath: "/Applications/Google Chrome.app", pid: 5)
        let origin = AgentOrigin(cwd: "/v", sessionID: "01a00000-0000-7000-8000-000000000003", entrypoint: "codex-chrome-extension-sidepanel")
        XCTAssertEqual(JumpPlanner.plan(provider: .codex, origin: origin, host: host, tty: nil).label, "Open in Chrome")
    }

    // MARK: Terminal tabs

    func testTTYValidation() {
        XCTAssertEqual(TerminalFocus.devicePath(tty: "ttys001"), "/dev/ttys001")
        XCTAssertNil(TerminalFocus.devicePath(tty: "ttys001\" & do shell script \"x"))
        XCTAssertNil(TerminalFocus.devicePath(tty: "/dev/ttys001"))
        XCTAssertNil(TerminalFocus.devicePath(tty: "??"))
        XCTAssertNil(TerminalFocus.devicePath(tty: nil))
    }

    func testOnlyTerminalAndITermHaveTabScripts() {
        XCTAssertNotNil(TerminalFocus.script(for: .terminal))
        XCTAssertNotNil(TerminalFocus.script(for: .iTerm))
        XCTAssertNil(TerminalFocus.script(for: .ghostty))
        XCTAssertNil(TerminalFocus.script(for: .vsCode))
    }
}
