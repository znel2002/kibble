import CoreGraphics

/// Where the detail card goes: next to the pet, never over it, always on screen.
///
/// Tries beside the pet on the side facing the middle of the screen, then the
/// other side, then above, then below, and takes the first spot where the whole
/// card fits without covering the pet; the result is clamped inside the visible
/// frame. Both windows carry transparent padding: the card `margin` for its
/// shadow, the pet `petInset` around the sprite and stage.
enum CardPlacement {
    static let margin: CGFloat = 20
    static let gap: CGFloat = 8
    static let petInset: CGFloat = 6
    /// Empty space above the sprite reserved for the speech bubble.
    static let petHeadroom: CGFloat = 40

    enum Spot: Equatable { case beside, otherSide, above, below, clamped }

    static func frame(for size: CGSize, pet: CGRect, visible: CGRect, alignRight: Bool) -> (CGRect, Spot) {
        let bounds = visible.insetBy(dx: gap - margin, dy: gap - margin)
        let w = min(size.width, bounds.width)
        let h = min(size.height, bounds.height)
        func clampX(_ x: CGFloat) -> CGFloat { min(max(x, bounds.minX), bounds.maxX - w) }
        func clampY(_ y: CGFloat) -> CGFloat { min(max(y, bounds.minY), bounds.maxY - h) }
        func fits(_ r: CGRect) -> Bool { bounds.contains(r) }

        // What the pet actually draws, without its transparent padding.
        let body = CGRect(x: pet.minX + petInset, y: pet.minY, width: pet.width - 2 * petInset, height: pet.height - petHeadroom)

        // Beside: bottoms aligned with the stage, a small gap from the pet.
        let bottomY = clampY(body.minY - margin + 6)
        let leftOf = CGRect(x: body.minX - gap - w + margin, y: bottomY, width: w, height: h)
        let rightOf = CGRect(x: body.maxX + gap - margin, y: bottomY, width: w, height: h)
        let (first, second) = alignRight ? (leftOf, rightOf) : (rightOf, leftOf)
        if fits(first) { return (first, .beside) }
        if fits(second) { return (second, .otherSide) }

        // Above or below, aligned to the pet's outer edge.
        let alignedX = clampX(alignRight ? body.maxX - w + margin : body.minX - margin)
        let above = CGRect(x: alignedX, y: body.maxY + gap - margin, width: w, height: h)
        if fits(above) { return (above, .above) }
        let below = CGRect(x: alignedX, y: body.minY - gap - h + margin, width: w, height: h)
        if fits(below) { return (below, .below) }

        // Nowhere fits cleanly (a tiny screen): stay on screen, beside if possible.
        return (CGRect(x: clampX(first.minX), y: bottomY, width: w, height: h), .clamped)
    }
}
