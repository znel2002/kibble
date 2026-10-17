import Foundation
import SwiftUI

/// Drives the pet: which frame to show, hops, speech bubbles and particles.
@MainActor
final class Hound: ObservableObject {
    enum Mode: Equatable { case idle, working, sleeping }

    struct Particle: Identifiable {
        let id = UUID()
        let glyph: String
        var x: CGFloat
        var y: CGFloat
        var age: Int = 0
        let life: Int
        let drift: CGFloat
    }

    struct Bubble: Equatable {
        let title: String
        let subtitle: String?
        let tint: Color
    }

    @Published private(set) var frame = "sit"
    @Published private(set) var hop: CGFloat = 0
    @Published private(set) var bubble: Bubble?
    @Published private(set) var particles: [Particle] = []
    @Published var facesLeft = true
    @Published private(set) var pet: PetArt = Pets.saved

    private(set) var mode: Mode = .idle
    private var tick = 0
    private var timer: Timer?
    private var action: Action?
    private var bubbleUntil = 0
    private var nextBlink = 30
    private var nextSway = 70

    /// Suppresses sound without touching the saved preference (snapshots).
    var silent = false

    var muted: Bool {
        get { UserDefaults.standard.bool(forKey: "muted") }
        set { UserDefaults.standard.set(newValue, forKey: "muted"); objectWillChange.send() }
    }

    /// A short scripted animation that takes over from the mode.
    private struct Action {
        enum Kind { case bark, howl, pet, yip, cheer, nudge }
        let kind: Kind
        var t = 0
        var length: Int {
            switch kind {
            case .bark: 16
            case .howl: 30
            case .pet: 22
            case .yip: 12
            case .cheer: 18
            case .nudge: 12
            }
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
    }

    /// Switch to another pet, which says hello.
    func choose(_ new: PetArt) {
        guard new.id != pet.id else { return }
        pet = new
        Pets.saved = new
        frame = "sit"
        say(new.voice.hello, new.name, .secondary)
        run(.yip, sound: new.voice.greet)
    }

    /// A hello hop, e.g. when called back to the screen.
    func greet() {
        say(pet.voice.hello, nil, .secondary)
        run(.yip, sound: pet.voice.greet)
    }

    func setMode(_ m: Mode) {
        guard m != mode else { return }
        mode = m
    }

    // MARK: events

    func alert(_ a: UsageAlert) {
        let pct = Int(a.window.usedPercent.rounded())
        let v = pet.voice
        switch a.level {
        case .empty:
            say(v.empty, "\(a.provider.name) is out of usage", a.provider.tint)
            run(.howl, sound: v.emptySound)
        case .high:
            say(v.high, "\(a.provider.name) is at \(pct)%", a.provider.tint)
            run(.bark, sound: v.highSound)
        case .low:
            say(v.low, "\(a.provider.name) is at \(pct)%", a.provider.tint)
            run(.bark, sound: v.lowSound)
        case .reset:
            say(v.reset, "\(a.provider.name) has reset", a.provider.tint)
            run(.yip, sound: v.resetSound)
        }
    }

    func cuddle() {
        run(.pet, sound: pet.voice.petSound)
        for i in 0..<6 {
            particles.append(Particle(glyph: "heart", x: CGFloat.random(in: -34...34), y: CGFloat(-i * 7), life: 20 + i * 3, drift: CGFloat.random(in: -0.8...0.8)))
        }
    }

    /// An agent finished a task: three happy hops and a soft chime.
    func celebrate(_ title: String, _ subtitle: String?, _ tint: Color) {
        say(title, subtitle, tint)
        run(.cheer, sound: .chime)
    }

    /// An agent is waiting on the user: a hop with a short bark face and a "!".
    /// Only the first nudge of a wait makes a sound.
    func nudge(_ title: String, _ subtitle: String?, _ tint: Color, sound: Bool) {
        say(title, subtitle, tint)
        run(.nudge, sound: sound ? pet.voice.lowSound : nil)
        particles.append(Particle(glyph: "bang", x: facesLeft ? -30 : 30, y: 16, life: 16, drift: facesLeft ? -0.2 : 0.2))
    }

    /// For snapshots: pin a frame and bubble without running the clock.
    func pose(_ frame: String, bubble: Bubble? = nil, hop: CGFloat = 0) {
        self.frame = frame
        self.bubble = bubble
        self.hop = hop
    }

    private func say(_ title: String, _ subtitle: String?, _ tint: Color) {
        bubble = Bubble(title: title, subtitle: subtitle, tint: tint)
        bubbleUntil = tick + 45
    }

    private func run(_ kind: Action.Kind, sound: SoundBank.Kind?) {
        action = Action(kind: kind)
        if let sound, !muted, !silent { SoundBank.shared.play(sound) }
    }

    // MARK: animation

    /// One 100 ms animation tick. Public so snapshots can drive the clock.
    func advance() {
        tick += 1
        if bubble != nil, tick > bubbleUntil { bubble = nil }
        stepParticles()

        if var a = action {
            a.t += 1
            action = a.t >= a.length ? nil : a
            frameFor(action: a)
            return
        }

        hop = 0
        switch mode {
        case .working:
            frame = "run\((tick / 1) % 4)"
        case .sleeping:
            frame = "sleep"
            if tick % 14 == 0 {
                particles.append(Particle(glyph: "z", x: facesLeft ? -14 : 14, y: 0, life: 26, drift: facesLeft ? -0.35 : 0.35))
            }
        case .idle:
            if tick >= nextSway {
                frame = "sit_sway"
                if tick >= nextSway + 6 { nextSway = tick + Int.random(in: 50...110) }
            } else if tick >= nextBlink {
                frame = "sit_blink"
                if tick >= nextBlink + 2 { nextBlink = tick + Int.random(in: 25...60) }
            } else {
                frame = "sit"
            }
        }
    }

    private func frameFor(action a: Action) {
        switch a.kind {
        case .bark:
            let open = (a.t / 3) % 2 == 0 && a.t < 12
            frame = open ? "sit_bark" : "sit"
            hop = open ? 5 : 0
        case .howl:
            frame = a.t < 26 ? "sit_bark" : "sit_serene"
            hop = a.t < 26 ? 3 + CGFloat(sin(Double(a.t) / 2)) : 0
        case .pet:
            frame = "sit_happy"
            let phase = a.t % 8
            hop = (phase < 4 ? CGFloat(phase) : CGFloat(8 - phase)) * 1.5
        case .yip:
            frame = (a.t / 2) % 2 == 0 ? "sit_happy" : "sit"
            hop = (a.t / 2) % 2 == 0 ? 6 : 0
        case .cheer:
            frame = "sit_happy"
            hop = CGFloat(abs(sin(Double(a.t) * .pi / 6))) * 7
        case .nudge:
            frame = a.t < 7 ? "sit_bark" : "sit"
            hop = a.t < 7 ? CGFloat(sin(Double(a.t) * .pi / 7)) * 6 : 0
        }
    }

    func debugStepParticles() { stepParticles() }

    private func stepParticles() {
        guard !particles.isEmpty else { return }
        particles = particles.compactMap { p in
            var p = p
            p.age += 1
            p.y -= 1.2
            p.x += p.drift
            return p.age < p.life ? p : nil
        }
    }
}
