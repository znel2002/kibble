import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }

    /// Opening Kibble again (Finder, Spotlight, Dock) brings the pet back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.summon()
        return false
    }
}

MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--agents") {
        // Debug: what Kibble detects right now.
        let now = Date.now
        for a in ClaudeSource().agents() + CodexSource().agents(now: now) {
            print(a.provider.name, a.waiting ? "WAITING" : a.busy ? "WORKING" : "idle   ", "since", Format.duration(since: a.since, now: now), "|", a.title, "|", a.project)
        }
        exit(0)
    }
#if DEBUG
    if let i = CommandLine.arguments.firstIndex(of: "--video-assets") {
        let dir = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "video-assets"
        VideoExport.run(into: URL(fileURLWithPath: dir))
    }
    if let i = CommandLine.arguments.firstIndex(of: "--desktop-demo") {
        let out = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "desktop-demo.mp4"
        DesktopDemo.run(output: out)
    }
#endif
    if let i = CommandLine.arguments.firstIndex(of: "--snapshot") {
        let dir = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "docs"
        Snapshot.run(into: URL(fileURLWithPath: dir))
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
