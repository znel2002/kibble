import AppKit
import SwiftUI

/// `Kibble --snapshot <dir>` renders the widget and card with live data to PNGs.
/// Used for the README and for checking layout without screen recording.
/// Add `--demo` (debug builds) for made-up usage and tasks: always use it for
/// images that get published, since live data shows your real session titles.
@MainActor
enum Snapshot {
    static func run(into dir: URL) -> Never {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #if DEBUG
        let store = HistorySeed.requested || CommandLine.arguments.contains("--demo") ? UsageStore(history: HistorySeed.temporaryHistory()) : UsageStore()
        #else
        let store = UsageStore()
        #endif
        let hound = Hound()
        hound.facesLeft = true
        hound.silent = true
        if let i = CommandLine.arguments.firstIndex(of: "--pet"), CommandLine.arguments.indices.contains(i + 1) {
            hound.choose(Pets.named(CommandLine.arguments[i + 1]))
        }
        #if DEBUG
        let demo = CommandLine.arguments.contains("--demo")
        #else
        let demo = false
        #endif
        if !demo {
            store.start()
            // Let the Claude fetch land.
            let deadline = Date.now.addingTimeInterval(8)
            while store.claude.windows.isEmpty, store.claude.error == nil, Date.now < deadline {
                RunLoop.main.run(until: .now.addingTimeInterval(0.2))
            }
        }
        #if DEBUG
        if HistorySeed.requested || demo { HistorySeed.seed(store) }
        if demo {
            store.injectDemo(.claude, used: 42)
            store.injectDemo(.codex, used: 65)
            store.injectDemoAgents(VideoExport.demoAgents)
        }
        #endif

        let poses: [(String, String, Hound.Bubble?, CGFloat)] = [
            ("widget-sit", "sit", nil, 0),
            ("widget-bark", "sit_bark", .init(title: hound.pet.voice.high, subtitle: "Claude is at 90%", tint: Provider.claude.tint), 5),
            ("widget-run", "run1", nil, 0),
            ("widget-sleep", "sleep", nil, 0),
            ("widget-pet", "sit_happy", nil, 3),
        ]
        for (name, frame, bubble, hop) in poses {
            hound.pose(frame, bubble: bubble, hop: hop)
            if name == "widget-pet" {
                hound.cuddle()
                for _ in 0..<6 { hound.debugStepParticles() }
                hound.pose(frame, bubble: bubble, hop: hop)
            }
            write(WidgetView(store: store, hound: hound, scale: 3).background(Backdrop()), to: dir.appending(path: "\(name).png"))
        }
        write(CardView(store: store, hound: hound, onClose: {}).background(Backdrop()), to: dir.appending(path: "card.png"))
        write(CardView(store: store, hound: hound, onClose: {}).background(Backdrop()).environment(\.colorScheme, .dark), to: dir.appending(path: "card-dark.png"))
        hound.pose("sit")
        write(WidgetView(store: store, hound: hound, scale: 3).background(Backdrop()).environment(\.colorScheme, .dark), to: dir.appending(path: "widget-dark.png"))
        // The scrolling fallback a short screen gets.
        write(CardView(store: store, hound: hound, onClose: {}).frame(height: 460).background(Backdrop()), to: dir.appending(path: "card-short.png"))
        write(PetGallery().background(Backdrop()), to: dir.appending(path: "pets.png"))
        if CommandLine.arguments.contains("--frames") { renderDemo(store: store, into: dir.appending(path: "frames")) }
        print("snapshots written to \(dir.path)")
        exit(0)
    }

    /// A scripted 14-second loop: idle, bark at 90%, pet, work, nap.
    static func renderDemo(store: UsageStore, into dir: URL) {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let hound = Hound()
        hound.silent = true
        hound.facesLeft = true
        let window = UsageWindow(label: "5-hour", usedPercent: 91, resetsAt: .now.addingTimeInterval(8000))
        var n = 0
        func capture(_ ticks: Int, _ before: (Int) -> Void = { _ in }) {
            for t in 0..<ticks {
                before(t)
                hound.advance()
                let view = WidgetView(store: store, hound: hound, scale: 3)
                    .frame(width: 300, height: 350, alignment: .bottom)
                    .background(Backdrop())
                write(view, to: dir.appending(path: String(format: "%04d.png", n)))
                n += 1
            }
        }
        hound.setMode(.idle)
        capture(28)
        capture(40) { t in if t == 0 { store.injectDemo(.claude, used: 91); hound.alert(UsageAlert(provider: .claude, window: window, level: .high)) } }
        capture(30) { t in if t == 0 { hound.cuddle() } }
        hound.setMode(.working)
        capture(26)
        hound.setMode(.sleeping)
        capture(36)
        hound.setMode(.idle)
        capture(10)
    }

    private static func write(_ view: some View, to url: URL) {
        let r = ImageRenderer(content: view)
        r.scale = 2
        guard let cg = r.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Every pet, sitting in a row with its name: the README's line-up.
private struct PetGallery: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(Pets.all, id: \.id) { pet in
                VStack(spacing: 8) {
                    SpriteView(frame: "sit", pet: pet, scale: 2)
                    Text(pet.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .padding(24)
    }
}

/// A soft desktop-ish gradient so the transparent widget is visible in PNGs.
private struct Backdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 0.62), Color(red: 0.58, green: 0.45, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
