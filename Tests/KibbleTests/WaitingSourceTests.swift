import XCTest
@testable import Kibble

/// Where "waiting on the user" comes from: Claude's session status and
/// Codex's unanswered questions.
final class WaitingSourceTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "kibble-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testClaudeWaitingStatus() throws {
        let home = try tempDir()
        defer { try? FileManager.default.removeItem(at: home) }
        let sessions = home.appending(path: ".claude/sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let pid = Int(ProcessInfo.processInfo.processIdentifier)
        let json = #"{"pid":\#(pid),"cwd":"/tmp/kibble","name":"Fix the parser","status":"waiting","waitingFor":"permission prompt","statusUpdatedAt":1790000000000}"#
        try json.write(to: sessions.appending(path: "\(pid).json"), atomically: true, encoding: .utf8)
        let agents = ClaudeSource(home: home).agents()
        XCTAssertEqual(agents.count, 1)
        XCTAssertEqual(agents.first?.waiting, true)
        XCTAssertEqual(agents.first?.busy, false)
    }

    private func log(_ lines: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "turn-\(UUID()).jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func append(_ line: String, to url: URL) throws {
        let h = try FileHandle(forWritingTo: url)
        try h.seekToEnd()
        try h.write(contentsOf: Data((line + "\n").utf8))
        try h.close()
    }

    static let start = #"{"type":"event_msg","payload":{"type":"task_started"}}"#
    static let complete = #"{"type":"event_msg","payload":{"type":"task_complete"}}"#
    static let question = #"{"type":"response_item","payload":{"type":"function_call","name":"request_user_input_async","arguments":"{}"}}"#
    static let reply = #"{"type":"response_item","payload":{"type":"function_call_output","output":"{\"accepted\":true}"}}"#

    func testCodexQuestionThenTurnEndIsAwaitingReply() throws {
        let url = try log([Self.start, Self.question, Self.reply, Self.complete])
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(TurnTracker().turn(of: url), .awaitingReply)
    }

    func testCodexQuestionIsNotWaitingWhileTheTurnRuns() throws {
        let url = try log([Self.start, Self.question, Self.reply])
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = TurnTracker()
        XCTAssertEqual(tracker.turn(of: url), .started(nil))
        // Read incrementally: the question was seen in an earlier poll.
        try append(Self.complete, to: url)
        XCTAssertEqual(tracker.turn(of: url), .awaitingReply)
        // The user answers: a new turn starts.
        try append(Self.start, to: url)
        XCTAssertEqual(tracker.turn(of: url), .started(nil))
        try append(Self.complete, to: url)
        XCTAssertEqual(tracker.turn(of: url), .finished)
    }

    func testCodexQuestionFromAnEarlierTurnDoesNotCount() throws {
        let url = try log([Self.start, Self.question, Self.complete, Self.start, Self.complete])
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(TurnTracker().turn(of: url), .finished)
    }

    func testCodexQuestionFarBeforeTheEndOfALongTurn() throws {
        // The turn's end and its question are megabytes apart, in different chunks.
        let filler = Array(repeating: #"{"type":"event_msg","payload":{"type":"token_count"}}"# + String(repeating: "x", count: 2000), count: 1500)
        let url = try log([Self.complete, Self.start, Self.question] + filler + [Self.complete])
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(TurnTracker().turn(of: url), .awaitingReply)
    }
}
