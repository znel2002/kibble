import AppKit
import CoreGraphics

/// The pets compiled in from tools/pets/, and which one is chosen.
@MainActor
enum Pets {
    static var all: [PetArt] { SpriteData.pets }
    /// Menu sections, in order; kinds without pets are left out.
    static var groups: [(title: String, pets: [PetArt])] {
        [("Dogs", "dog"), ("Cats", "cat"), ("Hamsters", "hamster")]
            .map { title, kind in (title, all.filter { $0.kind == kind }) }
            .filter { !$0.pets.isEmpty }
    }

    static func named(_ id: String?) -> PetArt {
        all.first { $0.id == id } ?? all[0]
    }

    static var saved: PetArt {
        get { named(UserDefaults.standard.string(forKey: "pet")) }
        set { UserDefaults.standard.set(newValue.id, forKey: "pet") }
    }
}

/// What a species says and sounds like, per alert.
struct Voice {
    let hello: String, low: String, high: String, empty: String, reset: String
    let greet: SoundBank.Kind, lowSound: SoundBank.Kind, highSound: SoundBank.Kind
    let emptySound: SoundBank.Kind, resetSound: SoundBank.Kind, petSound: SoundBank.Kind

    static let dog = Voice(hello: "Hi!", low: "Woof", high: "Woof! Woof!", empty: "Awooooo", reset: "Yip!",
                           greet: .yip, lowSound: .woof, highSound: .bark, emptySound: .howl, resetSound: .yip, petSound: .yip)
    static let cat = Voice(hello: "Mrrp?", low: "Mew", high: "Meow!", empty: "Mrrrooow", reset: "Prrrp!",
                           greet: .chirp, lowSound: .mew, highSound: .meow, emptySound: .yowl, resetSound: .chirp, petSound: .purr)
    static let hamster = Voice(hello: "Eep!", low: "Squeak", high: "Squeak! Squeak!", empty: "AAAAAAA", reset: "Eep!",
                               greet: .eep, lowSound: .squeak, highSound: .squeaks, emptySound: .scream, resetSound: .eep, petSound: .chitter)
}

extension PetArt {
    var voice: Voice {
        switch kind {
        case "cat": .cat
        case "hamster": .hamster
        default: .dog
        }
    }
}

/// Turns the generated ASCII frames into CGImages once, then serves them from a cache.
@MainActor
enum SpriteImages {
    private static var cache: [String: CGImage] = [:]

    /// A pet frame ("sit", "run0", "avatar" …), or an effect glyph when `pet` is nil.
    static func image(_ frame: String, pet: PetArt? = nil, flipped: Bool = false, scale: Int = 1) -> CGImage? {
        let key = "\(pet?.id ?? "fx")/\(frame)\(flipped ? "~" : "")@\(scale)"
        if let img = cache[key] { return img }
        let rows: [String]?
        let palette: [Character: UInt32]
        if let pet {
            rows = frame == "avatar" ? pet.avatar : pet.frames[frame]
            palette = pet.palette
        } else {
            rows = Glyphs.all[frame]
            palette = Glyphs.palette
        }
        guard let rows, let img = render(rows, palette: palette, flipped: flipped, scale: scale) else { return nil }
        cache[key] = img
        return img
    }

    /// A pixel-doubled thumbnail for menus, which would otherwise smooth a 1x image.
    static func thumbnail(_ pet: PetArt) -> NSImage {
        guard let cg = image("avatar", pet: pet, scale: 2) else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width / 2, height: cg.height / 2))
    }

    static func render(_ rows: [String], palette: [Character: UInt32], flipped: Bool, scale: Int = 1) -> CGImage? {
        let h = rows.count * scale
        let w = (rows.map(\.count).max() ?? 0) * scale
        guard w > 0, h > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let rgb = palette[ch] else { continue }
                let col = flipped ? (w / scale - 1 - x) : x
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        let i = ((y * scale + dy) * w + col * scale + dx) * 4
                        buf[i] = UInt8((rgb >> 16) & 0xFF)
                        buf[i + 1] = UInt8((rgb >> 8) & 0xFF)
                        buf[i + 2] = UInt8(rgb & 0xFF)
                        buf[i + 3] = 255
                    }
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(buf) as CFData) else { return nil }
        return CGImage(
            width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}

/// Small effect sprites: hearts, sleep z's and the "!" of a task that needs you.
enum Glyphs {
    static let palette: [Character: UInt32] = ["o": 0x3A3346, "p": 0xE9677F, "W": 0xFFFDF8, "a": 0xF4B740]

    static let all: [String: [String]] = [
        "heart": [
            " oo oo ",
            "oppoppo",
            "opppppo",
            " opppo ",
            "  opo  ",
            "   o   ",
        ],
        "z": [
            "ooooooo",
            "oWWWWWo",
            "ooooWWo",
            "  oWWo ",
            " oWWo  ",
            "oWWoooo",
            "oWWWWWo",
            "ooooooo",
        ],
        "bang": [
            "oooo",
            "oaao",
            "oaao",
            "oaao",
            "oaao",
            "oooo",
            "    ",
            "oooo",
            "oaao",
            "oooo",
        ],
    ]
}
