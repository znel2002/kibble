import XCTest
@testable import Kibble

final class ParsingTests: XCTestCase {
    func testClaudeUsageParsesFiveHourAndWeekly() throws {
        let json = """
        {"five_hour":{"utilization":11.0,"resets_at":"2026-10-02T14:40:00.021041+00:00"},
         "seven_day":{"utilization":31.0,"resets_at":"2026-10-05T05:00:00+00:00"},
         "seven_day_opus":null}
        """
        let u = try ClaudeSource.parse(Data(json.utf8))
        XCTAssertEqual(u.windows.map(\.label), ["5-hour", "Weekly"])
        XCTAssertEqual(u.windows[0].leftPercent, 89)
        XCTAssertNotNil(u.windows[1].resetsAt)
        XCTAssertEqual(u.tightest?.label, "Weekly")
    }

    func testCodexRateLimitLine() {
        let line = #"{"timestamp":"2026-10-02T10:20:00.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":64.0,"window_minutes":10080,"resets_at":1791047781},"secondary":{"used_percent":20.0,"window_minutes":300,"resets_at":1791047781}}}}"#
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let u = CodexSource.parse(line: line, now: now)
        XCTAssertEqual(u?.windows.map(\.label), ["5-hour", "Weekly"])
        XCTAssertEqual(u?.windows.last?.usedPercent, 64)
        XCTAssertNotNil(u?.asOf)
    }

    func testCodexWindowPastResetCountsAsEmpty() {
        let line = #"{"type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":95.0,"window_minutes":10080,"resets_at":1000}}}}"#
        let u = CodexSource.parse(line: line, now: Date(timeIntervalSince1970: 5000))
        XCTAssertEqual(u?.windows.first?.usedPercent, 0)
    }

    func testCredentialsToken() {
        let data = Data(#"{"claudeAiOauth":{"accessToken":"abc","expiresAt":1}}"#.utf8)
        XCTAssertEqual(ClaudeSource.token(fromCredentials: data), "abc")
    }

    @MainActor
    func testAlertsFireOncePerThresholdAndOnlyLoudest() {
        UserDefaults.standard.removeObject(forKey: "firedAlerts")
        let ledger = AlertLedger()
        let reset = Date.now.addingTimeInterval(3600)
        func usage(_ used: Double) -> ProviderUsage {
            ProviderUsage(provider: .claude, windows: [UsageWindow(label: "5-hour", usedPercent: used, resetsAt: reset)])
        }
        XCTAssertTrue(ledger.check(old: usage(0), new: usage(50)).isEmpty)
        XCTAssertEqual(ledger.check(old: usage(50), new: usage(80)).map(\.level), [.low])
        XCTAssertTrue(ledger.check(old: usage(80), new: usage(82)).isEmpty)
        XCTAssertEqual(ledger.check(old: usage(82), new: usage(100)).map(\.level), [.empty])
        XCTAssertTrue(ledger.check(old: usage(100), new: usage(100)).isEmpty)
        UserDefaults.standard.removeObject(forKey: "firedAlerts")
    }

    func testSynthProducesAudibleWav() {
        let wav = Synth.wav(Synth.samples(for: .bark))
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertGreaterThan(wav.count, 4000)
    }

    func testEveryPetHasEveryFrameAtCanvasSize() {
        let required = ["sit", "sit_blink", "sit_sway", "sit_bark", "sit_serene", "sit_happy", "run0", "run1", "run2", "run3", "sleep"]
        XCTAssertEqual(SpriteData.pets.first?.id, "afghan")
        for pet in SpriteData.pets {
            XCTAssertEqual(Set(pet.frames.keys), Set(required), pet.id)
            for (name, rows) in pet.frames {
                XCTAssertEqual(rows.count, SpriteData.height, "\(pet.id).\(name)")
                XCTAssertTrue(rows.allSatisfy { $0.count == SpriteData.width }, "\(pet.id).\(name)")
                let used = Set(rows.joined()).subtracting([" "])
                XCTAssertTrue(used.isSubset(of: Set(pet.palette.keys)), "\(pet.id).\(name) uses unknown colours")
            }
        }
    }

    func testCatSoundsSynthesise() {
        for kind in SoundBank.Kind.allCases {
            XCTAssertGreaterThan(Synth.samples(for: kind).count, 1000, "\(kind)")
        }
    }
}

final class CornerSnapTests: XCTestCase {
    let screen = CGRect(x: 0, y: 63, width: 1800, height: 1067)
    let size = CGSize(width: 170, height: 196)

    func testSnapsToNearestCorner() {
        let nearBottomRight = CGRect(origin: CGPoint(x: 1560, y: 120), size: size)
        XCTAssertEqual(CornerSnap.target(for: nearBottomRight, in: screen), CGPoint(x: 1622, y: 67))
        let nearTopLeft = CGRect(origin: CGPoint(x: 40, y: 900), size: size)
        XCTAssertEqual(CornerSnap.target(for: nearTopLeft, in: screen), CGPoint(x: 8, y: 934))
    }

    func testStaysPutAwayFromCorners() {
        let middle = CGRect(origin: CGPoint(x: 800, y: 500), size: size)
        XCTAssertNil(CornerSnap.target(for: middle, in: screen))
        let bottomEdgeMiddle = CGRect(origin: CGPoint(x: 800, y: 67), size: size)
        XCTAssertNil(CornerSnap.target(for: bottomEdgeMiddle, in: screen))
    }
}

final class TaskTitleTests: XCTestCase {
    func testPlaceholderNamesFallBackToProject() {
        XCTAssertTrue(Agent.isPlaceholder("cfd8eb08"))
        XCTAssertTrue(Agent.isPlaceholder("vault-22"))
        XCTAssertTrue(Agent.isPlaceholder(""))
        XCTAssertFalse(Agent.isPlaceholder("Codex/Claude usage tracker tool"))
        XCTAssertFalse(Agent.isPlaceholder("BWINF-45 round 1"))
    }

    func testCodexThreadIDFromRolloutFilename() {
        let url = URL(fileURLWithPath: "/x/rollout-2026-10-02T12-12-28-01a0fc19-dc01-7f70-aa42-888e2285f686.jsonl")
        XCTAssertEqual(CodexSource.threadID(of: url), "01a0fc19-dc01-7f70-aa42-888e2285f686")
    }

    func testCodexFirstPromptSkipsHarnessWrappers() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "kibble-\(UUID()).jsonl")
        let lines = [
            #"{"type":"session_meta","payload":{"cwd":"/tmp/demo"}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>cwd</environment_context>"}]}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the login redirect\nmore detail"}]}}"#,
        ]
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(CodexSource.firstPrompt(in: url), "Fix the login redirect")
    }

    func testPromptTitlesDropConversationalFiller() {
        XCTAssertEqual(CodexSource.titleCase("Okay can you now make a plan for the final video?"), "Make a plan for the final video?")
        XCTAssertEqual(CodexSource.titleCase("please fix the build"), "Fix the build")
        XCTAssertEqual(CodexSource.titleCase("Refactor the parser"), "Refactor the parser")
    }
}

final class TurnTrackerTests: XCTestCase {
    private func log(_ lines: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "turn-\(UUID()).jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testLongTurnStaysStartedPastTheTail() throws {
        let start = #"{"timestamp":"2026-10-02T15:00:00.000Z","type":"event_msg","payload":{"type":"task_started"}}"#
        let filler = Array(repeating: #"{"type":"event_msg","payload":{"type":"token_count"}}"# + String(repeating: "x", count: 2000), count: 1500)
        let url = try log([start] + filler)  // ~3 MB after the start event
        defer { try? FileManager.default.removeItem(at: url) }
        guard case .started(let at) = TurnTracker().turn(of: url) else { return XCTFail("expected started") }
        XCTAssertEqual(at, ClaudeSource.parseDate("2026-10-02T15:00:00.000Z"))
    }

    func testCompletionAfterStartIsFinishedAndAppendsAreIncremental() throws {
        let url = try log([#"{"type":"event_msg","payload":{"type":"task_started"}}"#])
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = TurnTracker()
        XCTAssertEqual(tracker.turn(of: url), .started(nil))
        let h = try FileHandle(forWritingTo: url)
        try h.seekToEnd()
        try h.write(contentsOf: Data((#"{"type":"event_msg","payload":{"type":"task_complete"}}"# + "\n").utf8))
        try h.close()
        XCTAssertEqual(tracker.turn(of: url), .finished)
    }
}

final class CardPlacementTests: XCTestCase {
    let screen = CGRect(x: 0, y: 63, width: 1800, height: 1067)
    let card = CGSize(width: 324, height: 700)
    let pet = CGSize(width: 190, height: 200)

    private func visibleCard(_ f: CGRect) -> CGRect { f.insetBy(dx: CardPlacement.margin, dy: CardPlacement.margin) }

    private func petBody(_ p: CGRect) -> CGRect {
        CGRect(x: p.minX + CardPlacement.petInset, y: p.minY, width: p.width - 2 * CardPlacement.petInset, height: p.height - CardPlacement.petHeadroom)
    }

    private func assertOnScreen(_ f: CGRect, _ visible: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(visible.insetBy(dx: CardPlacement.gap - 0.5, dy: CardPlacement.gap - 0.5).contains(visibleCard(f)), "\(visibleCard(f)) not inside \(visible)", file: file, line: line)
    }

    func testBottomRightOpensToTheLeftWithoutCoveringThePet() {
        let p = CGRect(origin: CGPoint(x: 1622, y: 67), size: pet)
        let (f, spot) = CardPlacement.frame(for: card, pet: p, visible: screen, alignRight: true)
        XCTAssertEqual(spot, .beside)
        XCTAssertLessThanOrEqual(visibleCard(f).maxX, petBody(p).minX)
        assertOnScreen(f, screen)
    }

    func testLeftCornersOpenToTheRight() {
        for y in [67.0, screen.maxY - pet.height] {
            let p = CGRect(origin: CGPoint(x: 8, y: y), size: pet)
            let (f, spot) = CardPlacement.frame(for: card, pet: p, visible: screen, alignRight: false)
            XCTAssertEqual(spot, .beside)
            XCTAssertGreaterThanOrEqual(visibleCard(f).minX, petBody(p).maxX)
            assertOnScreen(f, screen)
        }
    }

    func testNeverCoversThePetAnywhereOnScreen() {
        for x in stride(from: -40.0, through: 1700, by: 85) {
            for y in stride(from: 63.0, through: 1000, by: 70) {
                let p = CGRect(origin: CGPoint(x: x, y: y), size: pet)
                let (f, spot) = CardPlacement.frame(for: card, pet: p, visible: screen, alignRight: p.midX > screen.midX)
                assertOnScreen(f, screen)
                XCTAssertNotEqual(spot, .clamped)
                XCTAssertFalse(visibleCard(f).intersects(petBody(p).insetBy(dx: 1, dy: 1)), "covers pet at \(x),\(y)")
            }
        }
    }

    func testTinyScreenStillKeepsTheCardOnScreen() {
        let tiny = CGRect(x: 0, y: 0, width: 480, height: 500)
        let p = CGRect(origin: CGPoint(x: 300, y: 0), size: pet)
        let (f, _) = CardPlacement.frame(for: card, pet: p, visible: tiny, alignRight: true)
        assertOnScreen(f, tiny)
    }
}

final class PetPlacementTests: XCTestCase {
    let laptop = CGRect(x: 0, y: 63, width: 1800, height: 1067)
    let external = CGRect(x: -177, y: 1169, width: 1920, height: 1080)
    let size = CGSize(width: 190, height: 200)

    func testSavedSpotOnADisconnectedDisplayFallsBackToTheMainCorner() {
        let onExternal = CGPoint(x: 1553, y: 1700)
        let origin = PetPlacement.origin(saved: onExternal, size: size, screens: [laptop], main: laptop)
        XCTAssertEqual(origin, CornerSnap.corners(for: size, in: laptop)[0])
    }

    func testSavedSpotComesBackWhenTheDisplayReturns() {
        let onExternal = CGPoint(x: 900, y: 1700)
        let origin = PetPlacement.origin(saved: onExternal, size: size, screens: [laptop, external], main: laptop)
        XCTAssertEqual(origin, onExternal)
    }

    func testMostlyOffScreenSpotIsPulledBackFullyOnScreen() {
        let hanging = CGPoint(x: 1700, y: 500)  // centre still on screen, right side off it
        let origin = PetPlacement.origin(saved: hanging, size: size, screens: [laptop], main: laptop)
        XCTAssertTrue(laptop.contains(CGRect(origin: origin, size: size)))
    }

    func testNoSavedSpotUsesTheMainCorner() {
        XCTAssertEqual(PetPlacement.origin(saved: nil, size: size, screens: [laptop], main: laptop), CornerSnap.corners(for: size, in: laptop)[0])
    }
}
