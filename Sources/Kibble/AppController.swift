import AppKit
import Combine
import SwiftUI

@MainActor
final class AppController: NSObject, NSMenuDelegate {
    let store = UsageStore()
    let hound = Hound()
    private lazy var announcer = AgentAnnouncer(hound: hound)

    private var dogPanel: FloatingPanel!
    private var cardPanel: FloatingPanel?
    private var statusItem: NSStatusItem!
    private var outsideClickMonitor: Any?
    private var bag = Set<AnyCancellable>()
    private var lastInteraction = Date.now
    private var demoRunning = false

    private var scale: CGFloat {
        get { CGFloat(UserDefaults.standard.object(forKey: "scale") as? Double ?? 2) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "scale") }
    }

    func start() {
        buildDogPanel()
        buildStatusItem()

        store.onAlert = { [weak self] alert in
            guard let self else { return }
            self.hound.alert(alert)
            Notifier.post(alert)
        }
        // Before the mode sink below, so a new wait keeps the pet awake.
        store.$agents
            .sink { [weak self] agents in self?.announcer.update(agents) }
            .store(in: &bag)
        store.$agents
            .combineLatest(store.$lastBusy)
            .sink { [weak self] _, _ in self?.updateMode() }
            .store(in: &bag)
        store.objectWillChange
            .sink { [weak self] in DispatchQueue.main.async { self?.refreshStatusTitle(); self?.positionCard() } }
            .store(in: &bag)

        Notifier.requestPermission()
        hound.start()
        announcer.start()
        store.start()
        refreshStatusTitle()
    }

    // MARK: Dog panel

    private func buildDogPanel() {
        let size = WidgetView.size(scale: scale)
        dogPanel = FloatingPanel(size: size)
        dogPanel.contentView = NSHostingView(rootView: widget())
        ensureOnScreen()
        dogPanel.orderFrontRegardless()

        // Floating panels aren't rescued by macOS when a display goes away, so
        // re-place the pet whenever the screen setup changes or the Mac wakes.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureOnScreen() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureOnScreen() }
        }
    }

    /// Put the pet back on a screen that exists: its saved spot if that is
    /// visible, otherwise the main screen's bottom-right corner.
    func ensureOnScreen() {
        let size = dogPanel.frame.size
        let saved = UserDefaults.standard.string(forKey: "dogOrigin").map(NSPointFromString)
        let main = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let origin = PetPlacement.origin(saved: saved, size: size, screens: NSScreen.screens.map(\.visibleFrame), main: main)
        if dogPanel.frame.origin != origin { dogPanel.setFrameOrigin(origin) }
        positionCard()
        updateFacing()
    }

    /// Opening Kibble.app while it runs calls the pet to the screen under the
    /// mouse: the way back if it is ever lost and the menu bar icon is hidden.
    func summon() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let origin = CornerSnap.corners(for: dogPanel.frame.size, in: screen.visibleFrame)[0]
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: "dogOrigin")
        dogPanel.setFrameOrigin(origin)
        dogPanel.orderFrontRegardless()
        positionCard()
        updateFacing()
        lastInteraction = .now
        updateMode()
        hound.greet()
    }

    private func widget() -> WidgetView {
        WidgetView(store: store, hound: hound, scale: scale, mouse: DragCatcher(
            onClick: { [weak self] in self?.announcer.acknowledge(); self?.toggleCard() },
            onDoubleClick: { [weak self] in self?.announcer.acknowledge(); self?.pet() },
            onDrag: { [weak self] in self?.positionCard(); self?.updateFacing() },
            onDragEnd: { [weak self] in self?.saveOrigin() },
            menu: { [weak self] in self?.makeMenu() ?? NSMenu() }
        ))
    }

    private func defaultOrigin(for size: CGSize) -> NSPoint {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return CornerSnap.corners(for: size, in: vf)[0]
    }

    private func saveOrigin() {
        guard let screen = dogPanel.screen ?? NSScreen.main else { return }
        var f = dogPanel.frame
        let vf = screen.visibleFrame
        f.origin = Self.inside(f, vf)
        if let corner = CornerSnap.target(for: f, in: vf) {
            f.origin = corner
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                dogPanel.animator().setFrame(f, display: true)
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated { self?.positionCard() }
            })
        } else {
            dogPanel.setFrameOrigin(f.origin)
        }
        UserDefaults.standard.set(NSStringFromPoint(f.origin), forKey: "dogOrigin")
        positionCard()
        updateFacing()
    }

    static func inside(_ frame: NSRect, _ visible: NSRect) -> NSPoint { PetPlacement.inside(frame, visible) }

    private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: "dogOrigin")
        dogPanel.setFrameOrigin(defaultOrigin(for: dogPanel.frame.size))
        positionCard()
        updateFacing()
    }

    private func setScale(_ s: CGFloat) {
        let anchor = NSPoint(x: dogPanel.frame.maxX, y: dogPanel.frame.minY)
        scale = s
        let size = WidgetView.size(scale: s)
        (dogPanel.contentView as? NSHostingView<WidgetView>)?.rootView = widget()
        dogPanel.setFrame(NSRect(x: anchor.x - size.width, y: anchor.y, width: size.width, height: size.height), display: true)
        saveOrigin()
    }

    /// Face into the screen: left when parked on the right half.
    private func updateFacing() {
        guard let screen = dogPanel.screen ?? NSScreen.main else { return }
        hound.facesLeft = dogPanel.frame.midX > screen.frame.midX
    }

    private func updateMode() {
        guard !demoRunning else { return }
        let quiet = Date.now.timeIntervalSince(max(store.lastBusy, lastInteraction))
        hound.setMode(store.anyBusy ? .working : quiet > 5 * 60 && !announcer.needsAttention ? .sleeping : .idle)
    }

    private func pet() {
        lastInteraction = .now
        updateMode()
        hound.cuddle()
    }

    // MARK: Card

    private func toggleCard() {
        lastInteraction = .now
        updateMode()
        if cardPanel?.isVisible == true { closeCard() } else { openCard() }
    }

    private func openCard() {
        if cardPanel == nil {
            let host = NSHostingView(rootView: CardView(store: store, hound: hound, onClose: { [weak self] in self?.closeCard() }))
            let panel = FloatingPanel(size: host.fittingSize)
            panel.contentView = host
            cardPanel = panel
        }
        positionCard()
        cardPanel?.alphaValue = 0
        cardPanel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            cardPanel?.animator().alphaValue = 1
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeCard() }
        }
    }

    private func closeCard() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        guard let panel = cardPanel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { MainActor.assumeIsolated { panel.orderOut(nil) } })
    }

    /// Above the hound, aligned to the side it is parked on; below if there is no room.
    private func positionCard() {
        guard let card = cardPanel, let host = card.contentView,
              let screen = dogPanel.screen ?? NSScreen.main else { return }
        // Measure after layout so a list that just grew isn't clipped by a stale size.
        host.layoutSubtreeIfNeeded()
        let (frame, _) = CardPlacement.frame(for: host.fittingSize, pet: dogPanel.frame, visible: screen.visibleFrame, alignRight: hound.facesLeft)
        if card.frame != frame { card.setFrame(frame, display: true) }
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = AppIcons.menubar
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func refreshStatusTitle() {
        let title = NSMutableAttributedString()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        for p in Provider.allCases {
            let left = store.usage(for: p).tightest?.leftPercent
            title.append(NSAttributedString(string: " ●", attributes: [.foregroundColor: NSColor(p.tint), .font: NSFont.systemFont(ofSize: 8)]))
            title.append(NSAttributedString(string: left.map { "\(Int($0.rounded()))%" } ?? "--", attributes: [.font: font]))
        }
        statusItem.button?.attributedTitle = title
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let fresh = makeMenu()
        for item in fresh.items {
            fresh.removeItem(item)
            menu.addItem(item)
        }
    }

    private func makeMenu() -> NSMenu {
        let m = NSMenu()
        for p in Provider.allCases {
            let u = store.usage(for: p)
            let head = NSMenuItem(title: p.name, action: nil, keyEquivalent: "")
            head.isEnabled = false
            m.addItem(head)
            if u.windows.isEmpty {
                m.addItem(disabled("   \(u.error ?? "Loading…")"))
            }
            for w in u.windows {
                var line = "   \(w.label): \(Int(w.leftPercent.rounded()))% left"
                if let r = w.resetsAt { line += " · resets \(Format.relative(r))" }
                if let f = store.forecast(p, w) { line += " · empty around \(f.timeText())" }
                m.addItem(disabled(line))
            }
        }
        let busy = store.agents.filter(\.waiting) + store.agents.filter { $0.busy && !$0.waiting }
        m.addItem(.separator())
        m.addItem(NSMenuItem.sectionHeader(title: busy.isEmpty ? "Nothing in progress" : "Working on"))
        for a in busy.prefix(8) {
            let title = a.title.count > 48 ? String(a.title.prefix(47)) + "…" : a.title
            let row = disabled("\(title)  ·  \(a.provider.name), \(a.waiting ? "needs you" : Format.duration(since: a.since))")
            row.image = Self.dot(a.provider)
            m.addItem(row)
        }
        m.addItem(.separator())

        m.addItem(item(dogPanel.isVisible ? "Hide Kibble" : "Show Kibble", "k") { [weak self] in self?.toggleDog() })
        let mute = item("Mute Sounds", "m") { [weak self] in self?.hound.muted.toggle() }
        mute.state = hound.muted ? .on : .off
        m.addItem(mute)
        let petItem = NSMenuItem(title: "Pet", action: nil, keyEquivalent: "")
        petItem.image = SpriteImages.thumbnail(hound.pet)
        let pets = NSMenu()
        for (title, group) in Pets.groups {
            pets.addItem(NSMenuItem.sectionHeader(title: title))
            for p in group {
                let i = item(p.name, "") { [weak self] in self?.hound.choose(p) }
                i.image = SpriteImages.thumbnail(p)
                i.state = p.id == hound.pet.id ? .on : .off
                pets.addItem(i)
            }
        }
        petItem.submenu = pets
        m.addItem(petItem)

        let size = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizes = NSMenu()
        for (label, s) in [("Small", 2.0), ("Large", 3.0)] {
            let i = item(label, "") { [weak self] in self?.setScale(s) }
            i.state = scale == s ? .on : .off
            sizes.addItem(i)
        }
        size.submenu = sizes
        m.addItem(size)
        m.addItem(item("Reset Position", "") { [weak self] in self?.resetPosition() })
        m.addItem(item("Refresh Now", "r") { [weak self] in self?.store.refreshNow() })

        let demo = NSMenuItem(title: "Demo", action: nil, keyEquivalent: "")
        let dm = NSMenu()
        dm.addItem(item("Alert at 75%", "") { [weak self] in self?.store.injectDemo(.codex, used: 76) })
        dm.addItem(item("Alert at 90%", "") { [weak self] in self?.store.injectDemo(.claude, used: 91) })
        dm.addItem(item("Alert at 100%", "") { [weak self] in self?.store.injectDemo(.claude, used: 100) })
        dm.addItem(item("Pet", "") { [weak self] in self?.pet() })
        dm.addItem(item("Task Done", "") { [weak self] in self?.announcer.demoDone() })
        dm.addItem(item("Needs You", "") { [weak self] in self?.announcer.demoWaiting() })
        dm.addItem(item("Run for 6 s", "") { [weak self] in self?.demo(.working) })
        dm.addItem(item("Sleep for 6 s", "") { [weak self] in self?.demo(.sleeping) })
        dm.addItem(.separator())
        dm.addItem(item("Clear Demo Data", "") { [weak self] in
            UserDefaults.standard.removeObject(forKey: "firedAlerts")
            self?.store.refreshNow()
        })
        demo.submenu = dm
        m.addItem(demo)
        m.addItem(.separator())
        m.addItem(item("Quit Kibble", "q") { NSApp.terminate(nil) })
        return m
    }

    private func demo(_ mode: Hound.Mode) {
        demoRunning = true
        hound.setMode(mode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.demoRunning = false
            self?.lastInteraction = .now
            self?.updateMode()
        }
    }

    private func toggleDog() {
        if dogPanel.isVisible { closeCard(); dogPanel.orderOut(nil) } else { dogPanel.orderFrontRegardless() }
    }

    private static func dot(_ p: Provider) -> NSImage {
        NSImage(size: NSSize(width: 8, height: 8), flipped: false) { r in
            NSColor(p.tint).setFill()
            NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    private func item(_ title: String, _ key: String, _ action: @escaping () -> Void) -> NSMenuItem {
        let i = ClosureMenuItem(title: title, keyEquivalent: key, action: action)
        return i
    }
}

final class ClosureMenuItem: NSMenuItem {
    private var handler: () -> Void = {}

    convenience init(title: String, keyEquivalent: String, action: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        handler = action
        target = self
    }

    @objc private func fire() { handler() }
}
