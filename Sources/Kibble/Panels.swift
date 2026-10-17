import AppKit
import SwiftUI

/// A borderless, always-on-top panel that never steals focus.
final class FloatingPanel: NSPanel {
    init(size: CGSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Mouse handling on top of the sprite: click, double-click, drag, right-click.
struct DragCatcher: NSViewRepresentable {
    var onClick: () -> Void
    var onDoubleClick: () -> Void
    var onDrag: () -> Void
    var onDragEnd: () -> Void
    var menu: () -> NSMenu

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        update(v)
        return v
    }

    func updateNSView(_ v: CatcherView, context: Context) { update(v) }

    private func update(_ v: CatcherView) {
        v.onClick = onClick
        v.onDoubleClick = onDoubleClick
        v.onDrag = onDrag
        v.onDragEnd = onDragEnd
        v.menu = nil
        v.menuProvider = menu
    }

    final class CatcherView: NSView {
        var onClick: () -> Void = {}
        var onDoubleClick: () -> Void = {}
        var onDrag: () -> Void = {}
        var onDragEnd: () -> Void = {}
        var menuProvider: () -> NSMenu = { NSMenu() }

        private var startMouse: NSPoint = .zero
        private var startOrigin: NSPoint = .zero
        private var dragging = false
        private var pendingClick: DispatchWorkItem?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

        override func mouseDown(with e: NSEvent) {
            startMouse = NSEvent.mouseLocation
            startOrigin = window?.frame.origin ?? .zero
            dragging = false
            if e.clickCount >= 2 {
                pendingClick?.cancel()
                pendingClick = nil
                onDoubleClick()
            }
        }

        override func mouseDragged(with e: NSEvent) {
            let p = NSEvent.mouseLocation
            let dx = p.x - startMouse.x, dy = p.y - startMouse.y
            if !dragging, hypot(dx, dy) < 3 { return }
            if !dragging { NSCursor.closedHand.push() }
            dragging = true
            window?.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
            onDrag()
        }

        override func mouseUp(with e: NSEvent) {
            if dragging {
                NSCursor.pop()
                dragging = false
                onDragEnd()
                return
            }
            guard e.clickCount == 1 else { return }
            let work = DispatchWorkItem { [weak self] in self?.onClick() }
            pendingClick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + min(NSEvent.doubleClickInterval, 0.28), execute: work)
        }

        override func rightMouseDown(with e: NSEvent) {
            NSMenu.popUpContextMenu(menuProvider(), with: e, for: self)
        }
    }
}

@MainActor
enum AppIcons {
    static let menubar: NSImage = {
        let img = Bundle.main.image(forResource: "menubar") ?? Self.fallback
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
    }()

    /// When run with `swift run` there is no bundle; draw the glyph from the sit frame.
    private static var fallback: NSImage {
        guard let cg = SpriteImages.image("sit") else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: 18, height: 18))
    }
}
