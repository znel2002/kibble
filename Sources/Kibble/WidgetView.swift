import AppKit
import SwiftUI

enum Theme {
    /// Card and stage background, following the system appearance.
    static let surface = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 0.96)
            : NSColor(calibratedWhite: 0.995, alpha: 0.96)
    })
    static let hairline = Color.primary.opacity(0.09)
    static let track = Color.primary.opacity(0.08)
    static let danger = Color(red: 0.90, green: 0.30, blue: 0.27)
    static let warn = Color(red: 0.93, green: 0.62, blue: 0.20)

    static func barColor(left: Double, tint: Color) -> Color {
        left <= 10 ? danger : left <= 25 ? warn : tint
    }
}

/// The always-visible part: speech bubble, pet, and the two usage bars.
struct WidgetView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var hound: Hound
    let scale: CGFloat
    var mouse: DragCatcher?
    /// Video exports render the pet alone, without the usage stage.
    var showsStage = true
    /// Video exports enlarge speech bubbles along with the pet.
    var bubbleScale: CGFloat = 1

    static func size(scale: CGFloat) -> CGSize {
        CGSize(width: max(190, SpriteMetrics.width * scale + 30), height: SpriteMetrics.height * scale + 104)
    }

    var body: some View {
        VStack(spacing: -2) {
            ZStack(alignment: .bottom) {
                petSprite
                    // Original artwork hops half as high, so its cropped edge stays tucked away.
                    .offset(y: -hound.hop * (usesHD ? 0.5 : 1))
                    .overlay { if let mouse { mouse } }
                    .help("Click for details, double-click to pet, drag to move")
                ParticlesView(particles: hound.particles, scale: scale)
                    .offset(y: -SpriteMetrics.height * scale * 0.78)
            }
            .frame(height: SpriteMetrics.height * scale + 40, alignment: .bottom)
            .overlay(alignment: .top) {
                if let b = hound.bubble {
                    BubbleView(bubble: b)
                        .scaleEffect(bubbleScale, anchor: .bottom)
                        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hound.bubble)

            if showsStage { StageView(store: store) }
        }
        .padding(.bottom, 6)
        .frame(width: Self.size(scale: scale).width, height: Self.size(scale: scale).height, alignment: .bottom)
    }
}

extension WidgetView {
    var usesHD: Bool { scale >= 3 && HDArt.has(hound.pet) }

    /// At the Large size a pet with original artwork shows that instead of pixels.
    @ViewBuilder var petSprite: some View {
        if usesHD, let img = HDArt.image(hound.pet, HDArt.name(for: hound.frame)) {
            HDSpriteView(image: img, frame: hound.frame, flipped: hound.facesLeft,
                         box: CGSize(width: SpriteMetrics.width * scale + 10, height: SpriteMetrics.height * scale))
        } else {
            SpriteView(frame: hound.frame, pet: hound.pet, flipped: hound.facesLeft, scale: scale)
        }
    }
}

enum SpriteMetrics {
    static let width = CGFloat(SpriteData.width)
    static let height = CGFloat(SpriteData.height)
}

struct SpriteView: View {
    let frame: String
    var pet: PetArt?
    var flipped = false
    let scale: CGFloat

    var body: some View {
        if let img = SpriteImages.image(frame, pet: pet, flipped: flipped) {
            Image(decorative: img, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: CGFloat(img.width) * scale, height: CGFloat(img.height) * scale)
                .shadow(color: .black.opacity(0.25), radius: 2.5, y: 1.5)
        }
    }
}

struct ParticlesView: View {
    let particles: [Hound.Particle]
    let scale: CGFloat

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                SpriteView(frame: p.glyph, scale: scale)
                    .opacity(1 - Double(p.age) / Double(p.life) * 0.8)
                    .offset(x: p.x * scale / 2, y: p.y * scale / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

struct BubbleView: View {
    let bubble: Hound.Bubble

    var body: some View {
        VStack(spacing: 1) {
            Text(bubble.title)
                .font(.system(size: 13, weight: .semibold))
            if let s = bubble.subtitle {
                Text(s)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.surface)
                        .frame(width: 9, height: 9)
                        .rotationEffect(.degrees(45))
                        .offset(y: 4)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .fixedSize()
        .allowsHitTesting(false)
    }
}

/// The small stage the hound sits on: one line per provider.
struct StageView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Provider.allCases) { p in
                UsageLine(usage: store.usage(for: p), busy: store.busy(p))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
        .allowsHitTesting(false)
    }
}

struct UsageLine: View {
    let usage: ProviderUsage
    let busy: Bool

    var body: some View {
        let left = usage.tightest?.leftPercent
        HStack(spacing: 7) {
            HStack(spacing: 4) {
                Text(usage.provider.name)
                    .font(.system(size: 11, weight: .medium))
                WorkingDot(tint: usage.provider.tint, active: busy)
            }
            .frame(width: 50, alignment: .leading)
            LevelBar(fraction: (left ?? 0) / 100, color: left.map { Theme.barColor(left: $0, tint: usage.provider.tint) } ?? .clear)
                .frame(width: 62)
            Text(left.map { "\(Int($0.rounded()))%" } ?? "–")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(left.map { $0 <= 10 ? Theme.danger : .primary } ?? .secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

/// A thin capsule bar.
struct LevelBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(color)
                    .frame(width: max(fraction > 0 ? height : 0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

/// A small dot that pulses gently while an agent of that provider is working.
/// Driven by the clock rather than a repeating animation, so the pet's 10 fps
/// redraws can't restart it and make it flicker.
struct WorkingDot: View {
    let tint: Color
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.7 + 0.3 * cos(t * 2 * .pi / 1.8)
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .opacity(active ? pulse : 0)
        }
        .frame(width: 5, height: 5)
    }
}
