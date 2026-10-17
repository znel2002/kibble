#if DEBUG
import AppKit
import SwiftUI

/// `Kibble --video-assets <dir>` renders everything the launch video needs:
/// transparent PNG sequences of each pet action (10 fps, like the app), stills
/// of the card, and every sound as a WAV. Uses demo numbers and made-up tasks,
/// never the user's real usage or task titles, and never calls the network.
@MainActor
enum VideoExport {
    /// Points per sprite pixel; with the renderer at 2x each art pixel is 12 px.
    static let spriteScale: CGFloat = 6

    static func run(into dir: URL) -> Never {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let store = UsageStore(history: HistorySeed.temporaryHistory())
        HistorySeed.seed(store)
        store.injectDemoAgents(demoAgents)

        let afghan = Pets.named("afghan")
        clip("idle", pet: afghan, store: store, ticks: 40, into: dir)
        clip("run", pet: afghan, store: store, ticks: 16, into: dir) { h, t in if t == 0 { h.setMode(.working) } }
        clip("sleep", pet: afghan, store: store, ticks: 42, into: dir) { h, t in if t == 0 { h.setMode(.sleeping) } }
        clip("pet", pet: afghan, store: store, ticks: 30, into: dir) { h, t in if t == 0 { h.cuddle() } }
        clip("bark-90", pet: afghan, store: store, ticks: 42, stage: true, into: dir) { h, t in
            if t == 0 {
                store.injectDemo(.claude, used: 91)
                h.alert(UsageAlert(provider: .claude, window: window(91), level: .high))
            }
        }
        clip("howl-100", pet: afghan, store: store, ticks: 40, stage: true, into: dir) { h, t in
            if t == 0 {
                store.injectDemo(.claude, used: 100)
                h.alert(UsageAlert(provider: .claude, window: window(100), level: .empty))
            }
        }
        store.injectDemo(.claude, used: 58)
        clip("done", pet: afghan, store: store, ticks: 22, stage: true, into: dir) { h, t in
            if t == 0 { h.celebrate("Done!", "Fixed the login test", Provider.claude.tint) }
        }
        clip("needs-you", pet: afghan, store: store, ticks: 22, stage: true, into: dir) { h, t in
            if t == 0 { h.nudge("Needs you", "Approve a migration", Provider.codex.tint, sound: false) }
        }
        clip("stage-idle", pet: afghan, store: store, ticks: 40, stage: true, into: dir)

        // Line-up: each pet says hello once.
        for pet in Pets.all where pet.kind != "hamster" {
            clip("lineup-\(pet.id)", pet: pet, store: store, ticks: 36, into: dir) { h, t in if t == 2 { h.greet() } }
        }

        // The stinger: the pixel hamster riding, then screaming.
        if Pets.all.contains(where: { $0.id == "hamster" }) {
            let hamster = Pets.named("hamster")
            clip("hamster-ride", pet: hamster, store: store, ticks: 16, into: dir) { h, t in if t == 0 { h.setMode(.working) } }
            clip("hamster-scream", pet: hamster, store: store, ticks: 40, into: dir) { h, t in
                if t == 0 { h.alert(UsageAlert(provider: .claude, window: window(100), level: .empty)) }
            }
        }

        // Stills of the card: light and dark, with the forecast and chart.
        let hound = Hound()
        hound.silent = true
        hound.choose(afghan)
        hound.pose("sit")
        for (name, scheme) in [("card-light", ColorScheme.light), ("card-dark", ColorScheme.dark)] {
            write(CardView(store: store, hound: hound, onClose: {}).environment(\.colorScheme, scheme),
                  to: dir.appending(path: "stills/\(name).png"), scale: 3)
        }

        // Sounds.
        let sfx = dir.appending(path: "sfx")
        try? fm.createDirectory(at: sfx, withIntermediateDirectories: true)
        for kind in SoundBank.Kind.allCases {
            try? Synth.wav(Synth.samples(for: kind)).write(to: sfx.appending(path: "\(kind).wav"))
        }
        for (name, samples) in ComedySFX.all {
            try? Synth.wav(samples).write(to: sfx.appending(path: "extra-\(name).wav"))
        }

        print("video assets written to \(dir.path)")
        exit(0)
    }

    static var demoAgents: [Agent] {
        let now = Date.now
        return [
            Agent(id: "d1", provider: .claude, title: "Refactor the billing service", project: "payments", busy: true, since: now.addingTimeInterval(-14 * 60)),
            Agent(id: "d2", provider: .codex, title: "Write the onboarding emails", project: "growth", busy: true, since: now.addingTimeInterval(-6 * 60)),
            Agent(id: "d3", provider: .claude, title: "Fix the flaky login test", project: "web", busy: true, since: now.addingTimeInterval(-3 * 60)),
            Agent(id: "d4", provider: .codex, title: "Plan the launch post", project: "kibble", busy: false, since: now.addingTimeInterval(-20 * 60)),
        ]
    }

    private static func window(_ used: Double) -> UsageWindow {
        UsageWindow(label: "5-hour", usedPercent: used, resetsAt: .now.addingTimeInterval(2 * 3600))
    }

    /// Renders `ticks` frames of a fresh hound into <dir>/clips/<name>/0000.png …
    private static func clip(_ name: String, pet: PetArt, store: UsageStore, ticks: Int, stage: Bool = false,
                             into dir: URL, script: (Hound, Int) -> Void = { _, _ in }) {
        let hound = Hound()
        hound.silent = true
        hound.facesLeft = true
        hound.choose(pet)
        hound.pose("sit")  // clear the hello bubble choose() shows
        let out = dir.appending(path: "clips/\(name)")
        try? FileManager.default.removeItem(at: out)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for t in 0..<ticks {
            script(hound, t)
            hound.advance()
            // Room above the pet for an enlarged bubble.
            let view = WidgetView(store: store, hound: hound, scale: spriteScale, showsStage: stage, bubbleScale: 2.4)
                .padding(.top, 150)
                .padding(.horizontal, 160)
            write(view, to: out.appending(path: String(format: "%04d.png", t)), scale: 2)
        }
    }

    private static func write(_ view: some View, to url: URL, scale: CGFloat) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let r = ImageRenderer(content: view)
        r.scale = scale
        r.isOpaque = false
        guard let cg = r.cgImage else { return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// A few cartoon sounds for the edit, in the same 8-bit voice as the app.
enum ComedySFX {
    static let rate = Synth.rate

    static var all: [(String, [Float])] {
        [("pop", pop()), ("boing", boing()), ("whoosh", whoosh()), ("scratch", scratch()), ("ding", ding())]
    }

    /// Speech-bubble pop: a quick falling blip.
    static func pop() -> [Float] {
        tone(length: 0.07, loud: 0.45) { t in 1100 - 800 * t }
    }

    /// Cartoon hop: a rising pitch with a wobble that settles.
    static func boing() -> [Float] {
        tone(length: 0.42, loud: 0.4) { t in (220 + 420 * min(1, t * 3)) * (1 + 0.18 * sin(2 * .pi * 14 * t) * (1 - t)) }
    }

    /// Transition swoosh: noise swelling and fading, slowly low-passed.
    static func whoosh() -> [Float] {
        let n = Int(0.55 * rate)
        var low = 0.0
        var rng = SystemRandomNumberGenerator()
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let cutoff = 0.02 + 0.2 * sin(.pi * t)
            low += (Double.random(in: -1...1, using: &rng) - low) * cutoff
            return Float(low * sin(.pi * t) * 1.4)
        }
    }

    /// Record scratch for the hamster stinger: a fast pitch dive with grit.
    static func scratch() -> [Float] {
        let n = Int(0.35 * rate)
        var phase = 0.0
        var rng = SystemRandomNumberGenerator()
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let f = 1400 * pow(1 - t, 2) + 80
            phase += f / rate
            let saw = 2 * phase.truncatingRemainder(dividingBy: 1) - 1
            let noise = Double.random(in: -1...1, using: &rng)
            return Float((saw * 0.6 + noise * 0.4) * (1 - t) * 0.45)
        }
    }

    /// A bright single ding for the end card.
    static func ding() -> [Float] {
        tone(length: 0.6, loud: 0.35, decay: 2.4) { _ in 1568 }
    }

    private static func tone(length: Double, loud: Double, decay: Double = 1.2, pitch: (Double) -> Double) -> [Float] {
        let n = Int(length * rate)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            phase += pitch(t) / rate
            let p = phase.truncatingRemainder(dividingBy: 1)
            let tri = 4 * abs(p - 0.5) - 1
            let env = min(1, t * 30) * pow(1 - t, decay)
            return Float(((tri * env * 8).rounded() / 8) * loud)
        }
    }
}
#endif
