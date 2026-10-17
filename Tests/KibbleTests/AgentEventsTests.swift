import XCTest
@testable import Kibble

final class AgentEventsTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func agent(_ id: String = "claude-1", busy: Bool = false, waiting: Bool = false, since: Date? = nil, title: String = "Fix the parser") -> Agent {
        Agent(id: id, provider: .claude, title: title, project: "kibble", busy: busy, since: since ?? t0, waiting: waiting)
    }

    func testLongTurnFinishing() {
        var events = AgentEvents()
        XCTAssertEqual(events.update([agent(busy: true)], now: t0 + 5), [])
        XCTAssertEqual(events.update([agent(busy: true)], now: t0 + 60), [])
        let out = events.update([agent(since: t0 + 90)], now: t0 + 95)
        XCTAssertEqual(out, [.finished(agent(since: t0 + 90), duration: 95)])
    }

    func testShortTurnIsIgnored() {
        var events = AgentEvents()
        _ = events.update([agent()], now: t0)
        _ = events.update([agent(busy: true, since: t0 + 2)], now: t0 + 5)
        XCTAssertEqual(events.update([agent(since: t0 + 12)], now: t0 + 15), [])
    }

    func testAgentAlreadyIdleAtLaunchIsNotDone() {
        var events = AgentEvents()
        XCTAssertEqual(events.update([agent()], now: t0 + 600), [])
    }

    func testSessionDisappearingIsNotDone() {
        var events = AgentEvents()
        _ = events.update([agent(busy: true)], now: t0 + 60)
        XCTAssertEqual(events.update([], now: t0 + 120), [])
    }

    func testTurnSurvivesAPermissionPrompt() {
        // Claude: busy, then a permission prompt (statusUpdatedAt moves), then busy, then idle.
        var events = AgentEvents()
        _ = events.update([agent(busy: true)], now: t0 + 5)
        XCTAssertEqual(events.update([agent(waiting: true, since: t0 + 8)], now: t0 + 10), [.startedWaiting(agent(waiting: true, since: t0 + 8))])
        XCTAssertEqual(events.update([agent(busy: true, since: t0 + 14)], now: t0 + 15), [.stoppedWaiting(agent(busy: true, since: t0 + 14))])
        // 25 s in total, though only 11 s since the last status change.
        XCTAssertEqual(events.update([agent(since: t0 + 24)], now: t0 + 25), [.finished(agent(since: t0 + 24), duration: 25)])
    }

    func testWaitingStartAndStop() {
        var events = AgentEvents()
        XCTAssertEqual(events.update([agent(waiting: true)], now: t0), [.startedWaiting(agent(waiting: true))])
        XCTAssertEqual(events.update([agent(waiting: true)], now: t0 + 5), [])
        XCTAssertEqual(events.update([agent()], now: t0 + 10), [.stoppedWaiting(agent())])
    }

    func testWaitingSessionClosingStopsTheWait() {
        var events = AgentEvents()
        _ = events.update([agent(waiting: true)], now: t0)
        XCTAssertEqual(events.update([], now: t0 + 5), [.stoppedWaiting(agent(waiting: true))])
    }

    func testCodexTurnEndingOnAQuestionWaitsInsteadOfFinishing() {
        var events = AgentEvents()
        _ = events.update([agent(busy: true)], now: t0 + 60)
        XCTAssertEqual(events.update([agent(waiting: true, since: t0 + 120)], now: t0 + 125), [.startedWaiting(agent(waiting: true, since: t0 + 120))])
    }

    // MARK: Done queue

    @MainActor func testFinishesArrivingTogetherAreCoalesced() {
        var queue = DoneQueue()
        for i in 1...3 { queue.add(agent("a\(i)", title: "Task \(i)")) }
        let batch = queue.next(now: t0)
        XCTAssertEqual(batch?.map(\.id), ["a1", "a2", "a3"])
        XCTAssertEqual(AgentLines.done(batch!, pet: Pets.all[0]).title, "3 tasks done")
        XCTAssertNil(queue.next(now: t0 + 1))
    }

    func testFinishesDuringTheGapWaitForTheNextSlotAndMerge() {
        var queue = DoneQueue()
        queue.add(agent("a1"))
        XCTAssertEqual(queue.next(now: t0)?.count, 1)
        queue.add(agent("a2"))
        XCTAssertNil(queue.next(now: t0 + 3))
        queue.add(agent("a3"))
        XCTAssertNil(queue.next(now: t0 + 6))
        XCTAssertEqual(queue.next(now: t0 + 8)?.map(\.id), ["a2", "a3"])
    }

    @MainActor func testDoneLinesFitTheBubble() {
        let long = agent(title: "Rewrite the session parser so forked threads keep their titles")
        let one = AgentLines.done([long], pet: Pets.all[0])
        XCTAssertLessThanOrEqual(one.subtitle!.count, AgentLines.bubbleWidth)
        XCTAssertTrue(one.subtitle!.hasSuffix("…"))
        let codex = Agent(id: "c", provider: .codex, title: "Wiki cleanup", project: "", busy: false, since: t0)
        let many = AgentLines.done([long, agent("b"), codex], pet: Pets.all[0])
        XCTAssertEqual(many.title, "3 tasks done")
        XCTAssertEqual(many.subtitle, "From Claude and Codex")
    }

    // MARK: Attention

    func testNudgesRepeatUntilAcknowledged() {
        var attention = Attention()
        attention.start(agent(waiting: true))
        XCTAssertEqual(attention.due(now: t0)?.count, 1)
        XCTAssertNil(attention.due(now: t0 + 5))
        XCTAssertNotNil(attention.due(now: t0 + 10))
        attention.acknowledge()
        XCTAssertFalse(attention.needsAttention)
        XCTAssertNil(attention.due(now: t0 + 30))
        // A second wait asks again, straight away.
        attention.start(agent("codex-x", waiting: true))
        XCTAssertEqual(attention.due(now: t0 + 31)?.map(\.id), ["codex-x"])
    }

    func testStoppedWaitEndsTheNudging() {
        var attention = Attention()
        attention.start(agent(waiting: true))
        _ = attention.due(now: t0)
        attention.stop("claude-1")
        XCTAssertNil(attention.due(now: t0 + 20))
    }
}
