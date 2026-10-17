import AVFoundation
import Foundation

/// 8-bit dog and cat noises, synthesised at launch so the repo ships no audio files.
@MainActor
final class SoundBank {
    enum Kind: CaseIterable { case woof, bark, howl, yip, mew, meow, yowl, chirp, purr, squeak, squeaks, scream, eep, chitter, chime }

    static let shared = SoundBank()
    private var players: [Kind: AVAudioPlayer] = [:]

    private init() {
        for kind in Kind.allCases {
            if let p = try? AVAudioPlayer(data: Synth.wav(Synth.samples(for: kind))) {
                p.volume = 0.55
                p.prepareToPlay()
                players[kind] = p
            }
        }
    }

    func play(_ kind: Kind) {
        guard let p = players[kind] else { return }
        p.currentTime = 0
        p.play()
    }
}

enum Synth {
    static let rate = 22_050.0

    static func samples(for kind: SoundBank.Kind) -> [Float] {
        switch kind {
        case .woof: return bark(from: 210, to: 120, length: 0.22, grit: 0.25)
        case .bark: return bark(from: 380, to: 190, length: 0.13, grit: 0.35) + silence(0.07) + bark(from: 400, to: 200, length: 0.15, grit: 0.35)
        case .yip: return bark(from: 700, to: 900, length: 0.08, grit: 0.1) + silence(0.05) + bark(from: 760, to: 980, length: 0.09, grit: 0.1)
        case .howl: return howl()
        case .mew: return meow(length: 0.28, contour: [(0, 720), (0.4, 900), (1, 760)], loud: 0.4)
        case .meow: return meow(length: 0.55, contour: [(0, 460), (0.35, 820), (1, 520)], loud: 0.55)
        case .yowl: return meow(length: 1.4, contour: [(0, 380), (0.3, 700), (0.7, 640), (1, 420)], loud: 0.5, wobble: 0.05)
        case .chirp: return meow(length: 0.08, contour: [(0, 650), (1, 1050)], loud: 0.4) + silence(0.04) + meow(length: 0.1, contour: [(0, 700), (1, 1150)], loud: 0.4)
        case .purr: return purr()
        case .squeak: return meow(length: 0.09, contour: [(0, 1500), (0.5, 1900), (1, 1650)], loud: 0.35)
        case .squeaks: return meow(length: 0.08, contour: [(0, 1550), (1, 1950)], loud: 0.4) + silence(0.05) + meow(length: 0.1, contour: [(0, 1650), (0.5, 2050), (1, 1800)], loud: 0.4)
        case .scream: return scream()
        case .eep: return meow(length: 0.14, contour: [(0, 1200), (1, 2100)], loud: 0.35)
        case .chitter: return (0..<6).flatMap { i in meow(length: 0.035, contour: [(0, 1700 + Double(i % 2) * 250), (1, 1900)], loud: 0.25) + silence(0.03) }
        case .chime: return chime()
        }
    }

    /// A soft two-note "ding-ding" for a finished task: E6 then B6, a rounded
    /// triangle with a little pulse for the 8-bit edge, quantised like the howl.
    static func chime() -> [Float] {
        func note(_ f: Double, _ length: Double, _ loud: Double) -> [Float] {
            let n = Int(length * rate)
            return (0..<n).map { i in
                let t = Double(i) / Double(n)
                let p = (Double(i) * f / rate).truncatingRemainder(dividingBy: 1)
                let tri = 4 * abs(p - 0.5) - 1
                let pulse = p < 0.25 ? 1.0 : -1.0
                let env = min(1, t * 40) * pow(1 - t, 2.2)
                let q = ((tri * 0.8 + pulse * 0.2) * env * 8).rounded() / 8
                return Float(q * loud)
            }
        }
        return note(1318.5, 0.08, 0.3) + note(1975.5, 0.26, 0.28)
    }

    /// A tonal "mee-ow": a few harmonics following a pitch contour, opening up
    /// in the middle (the "e" to "ow" brightness change).
    static func meow(length: Double, contour: [(Double, Double)], loud: Double, wobble: Double = 0.015) -> [Float] {
        let n = Int(length * rate)
        var phase = 0.0
        func pitch(_ t: Double) -> Double {
            for i in 1..<contour.count where t <= contour[i].0 {
                let (t0, f0) = contour[i - 1], (t1, f1) = contour[i]
                let u = (t - t0) / max(t1 - t0, 0.0001)
                return f0 + (f1 - f0) * (0.5 - cos(.pi * u) / 2)
            }
            return contour.last!.1
        }
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let f = pitch(t) * (1 + wobble * sin(2 * .pi * 5.5 * Double(i) / rate))
            phase += f / rate
            let p = 2 * .pi * phase
            let bright = sin(.pi * t)
            let tone = sin(p) + 0.45 * bright * sin(2 * p) + 0.2 * bright * sin(3 * p)
            let env = min(1, t * 10) * pow(1 - t, 0.7)
            let q = (tone / 1.65 * env * 12).rounded() / 12
            return Float(q * loud)
        }
    }

    /// The happy hamster's open-mouthed "AAAAAA": a bright square-ish tone with a
    /// fast, wide vibrato, rising slightly as it goes.
    static func scream() -> [Float] {
        let n = Int(1.2 * rate)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let f = (820 + 160 * t) * (1 + 0.06 * sin(2 * .pi * 9 * Double(i) / rate))
            phase += f / rate
            let p = phase.truncatingRemainder(dividingBy: 1)
            let tone = (p < 0.42 ? 1.0 : -1.0) * 0.7 + sin(2 * .pi * phase) * 0.3
            let env = min(1, t * 14) * pow(1 - t, 0.5)
            return Float(tone * env * 0.32)
        }
    }

    /// Low rumbling noise pulsed about 25 times a second.
    static func purr() -> [Float] {
        let n = Int(0.9 * rate)
        var low = 0.0
        var rng = SystemRandomNumberGenerator()
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            low += (Double.random(in: -1...1, using: &rng) - low) * 0.06
            let pulse = pow(max(0, sin(2 * .pi * 25 * Double(i) / rate)), 2)
            let env = min(1, t * 6) * min(1, (1 - t) * 6)
            return Float(low * pulse * env * 2.2)
        }
    }

    /// A pulse wave with a falling pitch, a bit of noise and a fast decay.
    static func bark(from f0: Double, to f1: Double, length: Double, grit: Double) -> [Float] {
        let n = Int(length * rate)
        var phase = 0.0
        var rng = SystemRandomNumberGenerator()
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let f = f0 + (f1 - f0) * pow(t, 0.6)
            phase += f / rate
            let pulse = (phase.truncatingRemainder(dividingBy: 1) < 0.35) ? 1.0 : -1.0
            let noise = Double.random(in: -1...1, using: &rng)
            let env = min(1, t * 25) * pow(1 - t, 1.8)
            return Float((pulse * (1 - grit) + noise * grit) * env * 0.6)
        }
    }

    /// A rising, wavering triangle wave: "awoooo".
    static func howl() -> [Float] {
        let length = 1.5
        let n = Int(length * rate)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / Double(n)
            let glide = t < 0.25 ? 330 + 260 * (t / 0.25) : 590 - 120 * ((t - 0.25) / 0.75)
            let vibrato = 1 + 0.03 * sin(2 * .pi * 6 * Double(i) / rate) * min(1, t * 3)
            phase += glide * vibrato / rate
            let p = phase.truncatingRemainder(dividingBy: 1)
            let tri = 4 * abs(p - 0.5) - 1
            let env = min(1, t * 8) * pow(1 - t, 0.9)
            // 4-bit-ish quantisation for the chiptune edge
            let q = (tri * env * 8).rounded() / 8
            return Float(q * 0.5)
        }
    }

    static func silence(_ s: Double) -> [Float] { Array(repeating: 0, count: Int(s * rate)) }

    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        for s in samples {
            u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * Float(Int16.max))))
        }
        return d
    }
}
