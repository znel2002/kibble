import CoreGraphics

/// Where the hound parks when it is dropped near a corner of the screen.
enum CornerSnap {
    static let threshold: CGFloat = 120
    static let inset = CGSize(width: 8, height: 4)

    /// The panel origin for each corner of `visible`, for a panel of `size`.
    static func corners(for size: CGSize, in visible: CGRect) -> [CGPoint] {
        let left = visible.minX + inset.width
        let right = visible.maxX - size.width - inset.width
        let bottom = visible.minY + inset.height
        let top = visible.maxY - size.height
        return [CGPoint(x: right, y: bottom), CGPoint(x: left, y: bottom), CGPoint(x: right, y: top), CGPoint(x: left, y: top)]
    }

    /// The corner origin to snap to, or nil if the panel was dropped away from every corner.
    static func target(for frame: CGRect, in visible: CGRect) -> CGPoint? {
        corners(for: frame.size, in: visible)
            .map { ($0, hypot($0.x - frame.minX, $0.y - frame.minY)) }
            .filter { $0.1 < threshold }
            .min { $0.1 < $1.1 }?
            .0
    }
}

/// Where the pet's window goes when Kibble starts or the displays change.
enum PetPlacement {
    /// The saved spot if most of the pet would be visible there (its centre is on
    /// some screen), kept fully on that screen and re-snapped to a nearby corner;
    /// otherwise the bottom-right corner of the main screen. The saved spot itself
    /// is left alone, so a display that comes back gets its pet back too.
    static func origin(saved: CGPoint?, size: CGSize, screens: [CGRect], main: CGRect) -> CGPoint {
        if let saved {
            let rect = CGRect(origin: saved, size: size)
            if let screen = screens.first(where: { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) }) {
                return CornerSnap.target(for: rect, in: screen) ?? inside(rect, screen)
            }
        }
        return CornerSnap.corners(for: size, in: main)[0]
    }

    /// The origin that keeps `frame` entirely within `visible`.
    static func inside(_ frame: CGRect, _ visible: CGRect) -> CGPoint {
        CGPoint(x: min(max(frame.minX, visible.minX), visible.maxX - frame.width),
                y: min(max(frame.minY, visible.minY), visible.maxY - frame.height))
    }
}
