import AppKit
import SwiftUI

/// Full-resolution frames from original artwork, used at the Large size when a
/// pet has them (Resources/HD/<pet>/sit.png and run.png). They are built locally
/// by tools/hd_build.py and are not part of the repository.
@MainActor
enum HDArt {
    private static var cache: [String: CGImage?] = [:]

    /// Which HD image stands in for a frame: running frames ride, everything else sits.
    static func name(for frame: String) -> String { frame.hasPrefix("run") ? "run" : "sit" }

    static func has(_ pet: PetArt) -> Bool { image(pet, "sit") != nil && image(pet, "run") != nil }

    static func image(_ pet: PetArt, _ name: String) -> CGImage? {
        let key = "\(pet.id)/\(name)"
        if let hit = cache[key] { return hit }
        let img = locations(pet.id, name).lazy
            .compactMap { NSImage(contentsOf: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            .first
        cache[key] = img
        return img
    }

    /// In the app bundle, or under Resources/ when run from the repo (`swift run`, snapshots).
    private static func locations(_ pet: String, _ name: String) -> [URL] {
        var urls: [URL] = []
        if let res = Bundle.main.resourceURL { urls.append(res.appending(path: "HD/\(pet)/\(name).png")) }
        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Resources/HD/\(pet)/\(name).png"))
        return urls
    }
}

/// An HD frame drawn into the same box the pixel sprite would fill.
struct HDSpriteView: View {
    let image: CGImage
    let frame: String
    var flipped = false
    let box: CGSize

    var body: some View {
        let running = frame.hasPrefix("run")
        // The rider bounces with the gallop: the pixel run cycle's 4 frames, as a bob.
        let bob: CGFloat = running ? [0, -4, -1, -3][Int(frame.dropFirst(3)) ?? 0] : 0
        // The idle picture is cropped flat at the bottom; tuck that edge behind
        // the usage stage so it never shows, even mid-hop.
        let tuck: CGFloat = running ? 0 : 5
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .scaleEffect(x: running && flipped ? -1 : 1, y: 1)
            .frame(width: box.width, height: box.height, alignment: .bottom)
            .offset(y: bob + tuck)
            .shadow(color: .black.opacity(0.25), radius: 2.5, y: 1.5)
    }
}
