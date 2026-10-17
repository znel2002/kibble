#if DEBUG
import AppKit
import SwiftUI

/// `Kibble --desktop-demo <file.mp4>` renders a screen recording of Kibble on a
/// simulated Mac desktop: the real widget, card and menu bar item, driven by a
/// scripted cursor. Demo numbers and made-up tasks only; frames are piped to
/// ffmpeg at 50 fps, 3x the 1440×900 desktop by default (KIBBLE_DESKTOP_SCALE).
/// KIBBLE_WALLPAPER points at a wallpaper image; it is not part of the repo.
@MainActor
enum DesktopDemo {
    static let screen = CGSize(width: 1440, height: 900)
    static let fps = 50.0
    /// KIBBLE_DESKTOP_SCRIPT=voice times every event to Kim's voice-over (10–28 s of the take).
    static let voice = ProcessInfo.processInfo.environment["KIBBLE_DESKTOP_SCRIPT"] == "voice"
    static var duration: Double { voice ? 18.0 : 22.0 }
    /// When the agents start working; the terminal output follows it.
    static var workStart: Double { voice ? 4.6 : 1.6 }
    static let petScale: CGFloat = 3
    static let renderScale = CGFloat(Double(ProcessInfo.processInfo.environment["KIBBLE_DESKTOP_SCALE"] ?? "3") ?? 3)

    static func run(output: String) -> Never {
        let store = UsageStore(history: HistorySeed.temporaryHistory())
        HistorySeed.seed(store)
        store.injectDemo(.claude, used: 62)
        store.injectDemo(.codex, used: 40)
        store.injectDemoAgents(idleAgents)

        let hound = Hound()
        hound.silent = true
        hound.facesLeft = true
        hound.choose(Pets.named("afghan"))
        hound.pose("sit")

        let ffmpeg = Process()
        ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        let w = Int(screen.width * renderScale), h = Int(screen.height * renderScale)
        ffmpeg.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "\(w)x\(h)", "-r", "\(Int(fps))", "-i", "-",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-movflags", "+faststart", output]
        let pipe = Pipe()
        ffmpeg.standardInput = pipe
        try! ffmpeg.run()

        var tick = -1
        let frames = Int(duration * fps)
        for f in 0..<frames {
            let t = Double(f) / fps
            let newTick = Int(t * 10)
            while tick < newTick {
                tick += 1
                script(at: Double(tick) / 10, store: store, hound: hound)
                hound.advance()
            }
            let scene = DesktopScene(store: store, hound: hound, t: t)
            let r = ImageRenderer(content: scene)
            r.scale = renderScale
            guard let cg = r.cgImage else { continue }
            pipe.fileHandleForWriting.write(rgba(cg, w, h))
            if f % 100 == 0 { print("frame \(f)/\(frames)"); fflush(stdout) }
        }
        try? pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        print("desktop demo written to \(output)")
        exit(ffmpeg.terminationStatus)
    }

    /// Events, keyed to the 100 ms animation clock.
    static func script(at s: Double, store: UsageStore, hound: Hound) {
        func at(_ x: Double) -> Bool { abs(s - x) < 0.05 }
        if voice {
            if at(4.6) { store.injectDemoAgents(VideoExport.demoAgents); hound.setMode(.working) }
            if at(10.6) {
                store.injectDemo(.claude, used: 91)
                hound.alert(UsageAlert(provider: .claude, window: UsageWindow(label: "5-hour", usedPercent: 91, resetsAt: .now.addingTimeInterval(7600)), level: .high))
            }
            if at(12.5) { hound.celebrate("Done!", "Fixed the login test", Provider.claude.tint) }
            if at(13.3) { hound.nudge("Needs you", "Approve a migration", Provider.codex.tint, sound: false) }
            return
        }
        if at(1.6) { store.injectDemoAgents(VideoExport.demoAgents); hound.setMode(.working) }
        if at(10.4) {
            store.injectDemo(.claude, used: 91)
            hound.alert(UsageAlert(provider: .claude, window: UsageWindow(label: "5-hour", usedPercent: 91, resetsAt: .now.addingTimeInterval(7600)), level: .high))
        }
        if at(13.6) { hound.celebrate("Done!", "Fixed the login test", Provider.claude.tint) }
        if at(16.0) { hound.nudge("Needs you", "Approve a migration", Provider.codex.tint, sound: false) }
        if at(18.6) { store.injectDemoAgents(idleAgents); hound.setMode(.idle) }
        if at(19.2) { hound.cuddle() }
    }

    static var idleAgents: [Agent] {
        VideoExport.demoAgents.map { Agent(id: $0.id, provider: $0.provider, title: $0.title, project: $0.project, busy: false, since: $0.since) }
    }

    private static func rgba(_ cg: CGImage, _ w: Int, _ h: Int) -> Data {
        var data = Data(count: w * h * 4)
        data.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return data
    }
}

// MARK: - Layout and cursor

@MainActor
private enum Layout {
    static let widget = WidgetView.size(scale: DesktopDemo.petScale)
    /// The visible frame stops above the Dock, as on a real Mac.
    static let dockHeight: CGFloat = 76
    static let widgetOrigin = CGPoint(x: DesktopDemo.screen.width - widget.width - 12, y: DesktopDemo.screen.height - dockHeight - widget.height - 8)
    static var pet: CGPoint { CGPoint(x: widgetOrigin.x + widget.width / 2 + 4, y: widgetOrigin.y + widget.height - 120) }
    static let card = CGSize(width: 324, height: 680)
    static var cardOrigin: CGPoint { CGPoint(x: widgetOrigin.x - card.width - 10, y: widgetOrigin.y + widget.height - card.height - 6) }
    static var close: CGPoint { CGPoint(x: cardOrigin.x + card.width - 44, y: cardOrigin.y + card.height - 26) }
}

/// Cursor path: (time, point), eased between keys; clicks are times.
@MainActor
private enum Cursor {
    static var keys: [(Double, CGPoint)] {
        let p = Layout.pet, c = Layout.cardOrigin, close = Layout.close
        if DesktopDemo.voice {
            return [(0, CGPoint(x: 640, y: 520)), (6.3, CGPoint(x: 640, y: 520)), (7.1, p), (7.4, p),
                    (8.0, CGPoint(x: c.x + 170, y: c.y + 470)), (8.9, CGPoint(x: c.x + 160, y: c.y + 540)),
                    (9.3, close), (9.5, close), (10.0, CGPoint(x: 1000, y: 520)), (13.7, CGPoint(x: 1000, y: 520)),
                    (14.45, p), (14.75, p), (15.4, CGPoint(x: c.x + 120, y: c.y + 168)), (16.6, CGPoint(x: c.x + 150, y: c.y + 600)), (18, CGPoint(x: c.x + 150, y: c.y + 600))]
        }
        return [(0, CGPoint(x: 640, y: 520)), (3.3, CGPoint(x: 640, y: 520)), (4.4, p), (4.9, p),
                (5.9, CGPoint(x: c.x + 170, y: c.y + 120)), (6.9, CGPoint(x: c.x + 150, y: c.y + 320)),
                (7.9, CGPoint(x: c.x + 160, y: c.y + 470)), (8.3, CGPoint(x: c.x + 160, y: c.y + 520)),
                (8.9, close), (9.2, close), (10.0, CGPoint(x: 900, y: 430)), (17.9, CGPoint(x: 900, y: 430)),
                (18.9, p), (22, p)]
    }
    static var clicks: [Double] { DesktopDemo.voice ? [7.3, 9.45, 14.6] : [4.6, 9.0, 19.2, 19.35] }
    /// (open, close) times of the card.
    static var cardWindows: [(Double, Double)] { DesktopDemo.voice ? [(7.32, 9.47), (14.62, 99)] : [(4.62, 9.02)] }

    static func position(_ t: Double) -> CGPoint {
        let k = keys
        guard let i = k.lastIndex(where: { $0.0 <= t }), i + 1 < k.count else { return k.last!.1 }
        let (t0, a) = k[i], (t1, b) = k[i + 1]
        var u = (t - t0) / (t1 - t0)
        u = u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
        return CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
    }

    /// 0…1 while a click ripple plays.
    static func click(_ t: Double) -> Double? {
        clicks.compactMap { c in t >= c && t < c + 0.35 ? (t - c) / 0.35 : nil }.first
    }

    /// Card visibility: opens on the first click, closes on the second.
    static func card(_ t: Double) -> Double {
        for (open, shut) in cardWindows where t >= open && t < shut + 0.18 {
            if t < open + 0.22 { return (t - open) / 0.22 }
            if t < shut { return 1 }
            return max(0, 1 - (t - shut) / 0.18)
        }
        return 0
    }
}

// MARK: - Scene

private struct DesktopScene: View {
    let store: UsageStore
    let hound: Hound
    let t: Double

    var body: some View {
        let size = DesktopDemo.screen
        let card = Cursor.card(t)
        ZStack(alignment: .topLeading) {
            Wallpaper()
            EditorWindow().frame(width: 760, height: 520).offset(x: 96, y: 96)
            TerminalWindow(t: t).frame(width: 660, height: 430).offset(x: 330, y: 250)
            MenuBar(store: store)
            Dock().frame(width: DesktopDemo.screen.width, height: DesktopDemo.screen.height, alignment: .bottom)

            if card > 0 {
                CardView(store: store, hound: hound, onClose: {})
                    .frame(width: Layout.card.width, height: Layout.card.height)
                    .scaleEffect(0.96 + 0.04 * card, anchor: .bottomTrailing)
                    .opacity(card)
                    .offset(x: Layout.cardOrigin.x, y: Layout.cardOrigin.y)
            }
            WidgetView(store: store, hound: hound, scale: DesktopDemo.petScale)
                .offset(x: Layout.widgetOrigin.x, y: Layout.widgetOrigin.y)

            ClickRipple(progress: Cursor.click(t)).offset(x: Cursor.position(t).x - 18, y: Cursor.position(t).y - 18)
            Arrow().offset(x: Cursor.position(t).x, y: Cursor.position(t).y)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

private struct Wallpaper: View {
    static let image: NSImage? = ProcessInfo.processInfo.environment["KIBBLE_WALLPAPER"].flatMap { NSImage(contentsOfFile: $0) }

    var body: some View {
        if let img = Self.image {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                .frame(width: DesktopDemo.screen.width, height: DesktopDemo.screen.height).clipped()
        } else {
            gradient
        }
    }

    private var gradient: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.50, blue: 0.72), Color(red: 0.70, green: 0.56, blue: 0.70), Color(red: 0.95, green: 0.74, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.28), .clear], center: UnitPoint(x: 0.78, y: 0.25), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.25, green: 0.30, blue: 0.55).opacity(0.45), .clear], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 10, endRadius: 600)
        }
    }
}

private struct MenuBar: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
            Text("Terminal").fontWeight(.bold)
            ForEach(["Shell", "Edit", "View", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            HStack(spacing: 3) {
                if let icon = menubarIcon { Image(nsImage: icon).resizable().renderingMode(.template).frame(width: 16, height: 16) }
                ForEach(Provider.allCases) { p in
                    Text("●").font(.system(size: 7)).foregroundStyle(p.tint)
                    Text(store.usage(for: p).tightest.map { "\(Int($0.leftPercent.rounded()))%" } ?? "--")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            }
            Image(systemName: "battery.75percent")
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text("Wed 14 Oct  16:42")
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.black.opacity(0.85))
        .padding(.horizontal, 18)
        .frame(width: DesktopDemo.screen.width, height: 28)
        .background(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.18)], startPoint: .top, endPoint: .bottom))
    }

    private var menubarIcon: NSImage? {
        NSImage(contentsOfFile: FileManager.default.currentDirectoryPath + "/Resources/menubar@2x.png")
    }
}

private struct Dock: View {
    static let apps = [
        "/System/Library/CoreServices/Finder.app", "/Applications/Safari.app", "/System/Applications/Messages.app",
        "/System/Applications/Mail.app", "/System/Applications/Calendar.app", "/System/Applications/Notes.app",
        "/System/Applications/Music.app", "/Applications/Slack.app", "/Applications/Google Chrome.app",
        "/Applications/Cursor.app", "/System/Applications/Utilities/Terminal.app", "/Applications/Claude.app",
        "/Applications/ChatGPT.app", "/System/Applications/System Settings.app",
    ]
    static let icons: [NSImage] = apps.filter { FileManager.default.fileExists(atPath: $0) }.map { NSWorkspace.shared.icon(forFile: $0) }
    static let trash: NSImage = NSWorkspace.shared.icon(forFile: NSHomeDirectory() + "/.Trash")

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Self.icons.enumerated()), id: \.offset) { i, icon in
                VStack(spacing: 2) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 52, height: 52)
                    Circle().fill(Color.black.opacity(i == 0 || i == 10 || i == 11 ? 0.55 : 0)).frame(width: 4, height: 4)
                }
            }
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1, height: 44).padding(.horizontal, 6)
            Image(nsImage: Self.trash).resizable().interpolation(.high).frame(width: 52, height: 52).padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 3)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.32)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.45), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .padding(.bottom, 6)
    }
}

private struct WindowChrome<Content: View>: View {
    let title: String
    let dark: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                        Circle().fill($0).frame(width: 12, height: 12)
                    }
                    Spacer()
                }
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(dark ? Color(white: 0.17) : Color(white: 0.94))
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(dark ? Color(white: 0.11) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.black.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }
}

private struct TerminalWindow: View {
    let t: Double
    private let spinner = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    var body: some View {
        let t = self.t - (DesktopDemo.workStart - 1.6)
        return WindowChrome(title: "payments — claude", dark: true) {
            VStack(alignment: .leading, spacing: 7) {
                line("~/code/payments", "main", .gray)
                line("$ claude", nil, .white)
                line("> Refactor the billing service to use the new invoices API", nil, Color(red: 0.85, green: 0.6, blue: 0.48))
                if t > 1.7 { line("● Read src/billing/invoice.ts", nil, .white.opacity(0.8)) }
                if t > 3.0 { line("● Update src/billing/charge.ts  (+42 −17)", nil, .white.opacity(0.8)) }
                if t > 6.0 { line("● Update src/billing/webhooks.ts  (+18 −9)", nil, .white.opacity(0.8)) }
                if t > 9.5 { line("● Run npm test", nil, .white.opacity(0.8)) }
                if t > 1.7 && t < 18.6 {
                    line("\(spinner[Int(t * 12) % spinner.count]) Working…  (\(Int(t * 3) + 14)s · esc to interrupt)", nil, Color(red: 0.85, green: 0.6, blue: 0.48))
                }
                if t >= 18.6 { line("✓ Done. 3 files changed, all tests pass.", nil, Color(red: 0.4, green: 0.8, blue: 0.5)) }
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(16)
        }
    }

    private func line(_ text: String, _ tag: String?, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(text).foregroundStyle(color)
            if let tag { Text(tag).foregroundStyle(Color(red: 0.5, green: 0.75, blue: 0.95)) }
        }
    }
}

private struct EditorWindow: View {
    private let code = [
        "import { Invoice, createInvoice } from \"./invoices\";", "",
        "export async function charge(customer: Customer, amount: number) {",
        "  const invoice: Invoice = await createInvoice({", "    customerId: customer.id,", "    amount,",
        "    currency: customer.currency,", "  });", "",
        "  await invoice.finalize();", "  return invoice.pay({ method: customer.defaultMethod });", "}",
    ]

    var body: some View {
        WindowChrome(title: "charge.ts — payments", dark: false) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(["billing", "  charge.ts", "  invoice.ts", "  webhooks.ts", "tests", "package.json"], id: \.self) {
                        Text($0).font(.system(size: 12)).foregroundStyle(Color.black.opacity(0.6))
                    }
                }
                .padding(14)
                .frame(width: 170, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color(white: 0.965))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(code.enumerated()), id: \.offset) { i, l in
                        HStack(spacing: 14) {
                            Text("\(i + 1)").foregroundStyle(Color.black.opacity(0.3)).frame(width: 18, alignment: .trailing)
                            Text(l).foregroundStyle(Color.black.opacity(0.78))
                        }
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

private struct Arrow: View {
    var body: some View {
        Path { p in
            p.move(to: .zero); p.addLine(to: CGPoint(x: 0, y: 21)); p.addLine(to: CGPoint(x: 5, y: 16))
            p.addLine(to: CGPoint(x: 9, y: 25)); p.addLine(to: CGPoint(x: 12.5, y: 23.5)); p.addLine(to: CGPoint(x: 8.5, y: 15))
            p.addLine(to: CGPoint(x: 15, y: 15)); p.closeSubpath()
        }
        .fill(Color.black)
        .overlay(Path { p in
            p.move(to: .zero); p.addLine(to: CGPoint(x: 0, y: 21)); p.addLine(to: CGPoint(x: 5, y: 16))
            p.addLine(to: CGPoint(x: 9, y: 25)); p.addLine(to: CGPoint(x: 12.5, y: 23.5)); p.addLine(to: CGPoint(x: 8.5, y: 15))
            p.addLine(to: CGPoint(x: 15, y: 15)); p.closeSubpath()
        }.stroke(Color.white, lineWidth: 1.5))
        .frame(width: 16, height: 26, alignment: .topLeading)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

private struct ClickRipple: View {
    let progress: Double?

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(progress.map { 0.9 * (1 - $0) } ?? 0), lineWidth: 2.5)
            .frame(width: 36, height: 36)
            .scaleEffect(progress.map { 0.4 + 0.9 * $0 } ?? 0)
    }
}
#endif
