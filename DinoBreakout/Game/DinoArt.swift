import SpriteKit
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct DinoLeg {
    let x: CGFloat
    let side: CGFloat
    let spread: CGFloat
    let rx: CGFloat
    let ry: CGFloat
    let off: CGFloat
    var sickle = false
}

struct DinoArm {
    let x: CGFloat
    let spread: CGFloat
    let rx: CGFloat
    let ry: CGFloat
}

/// Shape and color of one dino, in art units with the neck at the origin
/// and the dino facing +x. Matches the round one roster designs.
struct DinoStyle {
    enum Head {
        case theropod(length: CGFloat, widths: [CGFloat], teeth: Int, brow: Bool)
        case trike(length: CGFloat)
    }

    enum Marks {
        case spots, stripes, ridge, blotches
    }

    let skin: UIColor
    let light: UIColor
    let dark: UIColor
    let eye: UIColor
    var frill: UIColor = .clear
    var frillLight: UIColor = .clear
    /// Neck to tail tip: x (zero or negative) and body width there.
    let spine: [(x: CGFloat, w: CGFloat)]
    /// Distance back from the neck where the tail starts to swing.
    let hip: CGFloat
    let sway: CGFloat
    let wag: CGFloat
    let wave: CGFloat
    let stride: CGFloat
    /// Walk cycles per second at full speed.
    let rate: CGFloat
    let legs: [DinoLeg]
    let arms: [DinoArm]
    let head: Head
    let marks: Marks
    /// Length on the board, in grid cells.
    let cells: CGFloat

    var length: CGFloat { -(spine.last?.x ?? 0) }

    var headLength: CGFloat {
        switch head {
        case .theropod(let length, _, _, _): length
        case .trike(let length): length
        }
    }

    var total: CGFloat { length + headLength }

    var isTrike: Bool {
        if case .trike = head {
            return true
        }
        return false
    }

    /// Middle of the dino along its length, so it turns around its belly.
    var center: CGFloat { (headLength - length) / 2 }
}

extension DinoKind {
    var style: DinoStyle {
        switch self {
        case .compy:
            DinoStyle(
                skin: UIColor(hex: 0x7FA33A), light: UIColor(hex: 0xB2D062), dark: UIColor(hex: 0x3C561A), eye: UIColor(hex: 0x1A1A10),
                spine: [(0, 9), (-4, 13), (-11, 17), (-18, 16), (-24, 11), (-32, 7), (-40, 4), (-48, 2), (-53, 0.8)],
                hip: 20, sway: 1, wag: 4.5, wave: 0.09, stride: 4.5, rate: 2.4,
                legs: [
                    DinoLeg(x: -18, side: 1, spread: 9.5, rx: 6.5, ry: 4, off: 0),
                    DinoLeg(x: -18, side: -1, spread: 9.5, rx: 6.5, ry: 4, off: .pi)
                ],
                arms: [DinoArm(x: -5, spread: 7.5, rx: 2.8, ry: 1.8)],
                head: .theropod(length: 16, widths: [10, 12, 11, 8, 5], teeth: 0, brow: false),
                marks: .spots, cells: 0.62
            )
        case .raptor:
            DinoStyle(
                skin: UIColor(hex: 0xC97F35), light: UIColor(hex: 0xEEAE62), dark: UIColor(hex: 0x56300F), eye: UIColor(hex: 0xF5D343),
                spine: [(0, 13), (-6, 20), (-16, 27), (-26, 27), (-34, 20), (-44, 12), (-56, 8), (-68, 5), (-80, 2.5), (-88, 1)],
                hip: 30, sway: 1.5, wag: 4, wave: 0.05, stride: 7, rate: 1.7,
                legs: [
                    DinoLeg(x: -26, side: 1, spread: 15, rx: 10, ry: 6, off: 0, sickle: true),
                    DinoLeg(x: -26, side: -1, spread: 15, rx: 10, ry: 6, off: .pi, sickle: true)
                ],
                arms: [DinoArm(x: -6, spread: 12, rx: 5, ry: 2.6)],
                head: .theropod(length: 28, widths: [15, 19, 17, 12, 7], teeth: 4, brow: true),
                marks: .stripes, cells: 1.0
            )
        case .triceratops:
            DinoStyle(
                skin: UIColor(hex: 0x9A7446), light: UIColor(hex: 0xC79F68), dark: UIColor(hex: 0x5C4022), eye: UIColor(hex: 0x1A1208),
                frill: UIColor(hex: 0xD9772F), frillLight: UIColor(hex: 0xF0A75A),
                spine: [(0, 36), (-10, 52), (-26, 62), (-42, 62), (-54, 54), (-64, 38), (-72, 20), (-80, 8), (-84, 1.5)],
                hip: 56, sway: 1.2, wag: 3.5, wave: 0.06, stride: 6, rate: 0.85,
                legs: [
                    DinoLeg(x: -14, side: 1, spread: 31, rx: 12, ry: 11, off: 0),
                    DinoLeg(x: -14, side: -1, spread: 31, rx: 12, ry: 11, off: .pi),
                    DinoLeg(x: -46, side: 1, spread: 33, rx: 13, ry: 12, off: .pi),
                    DinoLeg(x: -46, side: -1, spread: 33, rx: 13, ry: 12, off: 0)
                ],
                arms: [],
                head: .trike(length: 36),
                marks: .blotches, cells: 1.45
            )
        case .rex:
            DinoStyle(
                skin: UIColor(hex: 0x5D6C2C), light: UIColor(hex: 0x8C9D48), dark: UIColor(hex: 0x323D14), eye: UIColor(hex: 0xF2B92A),
                spine: [(0, 30), (-10, 44), (-24, 56), (-38, 58), (-50, 48), (-62, 34), (-76, 22), (-90, 12), (-102, 5), (-110, 1.5)],
                hip: 46, sway: 2.5, wag: 8, wave: 0.035, stride: 9, rate: 0.9,
                legs: [
                    DinoLeg(x: -40, side: 1, spread: 28, rx: 17, ry: 11, off: 0),
                    DinoLeg(x: -40, side: -1, spread: 28, rx: 17, ry: 11, off: .pi)
                ],
                arms: [DinoArm(x: -12, spread: 23, rx: 6, ry: 3.5)],
                head: .theropod(length: 50, widths: [32, 40, 38, 30, 20], teeth: 7, brow: true),
                marks: .ridge, cells: 1.85
            )
        }
    }
}

/// Draws the dinos with Core Graphics and bakes each walk cycle into textures.
enum DinoArt {
    static let framesPerCycle = 16

    private static let outline = UIColor(hex: 0x16200F)
    private static let claw = UIColor(hex: 0xF1E8CF)
    private static let eyeWhite = UIColor(hex: 0xFFFBE8)
    private static var cache: [String: Baked] = [:]

    struct Baked {
        let frames: [SKTexture]
        /// Where the dino's middle sits inside each texture.
        let anchor: CGPoint
        /// Size of the shadow under it, in points.
        let shadowSize: CGSize
    }

    static func bake(_ kind: DinoKind, cellSize: CGFloat, screenScale: CGFloat) -> Baked {
        let key = "\(kind)-\(Int(cellSize))-\(Int(screenScale))"
        if let hit = cache[key] {
            return hit
        }

        let style = kind.style
        let s = style.cells * cellSize / style.total
        let maxWidth = style.spine.map { $0.w }.max() ?? 10
        let legReach = style.legs.map { $0.spread + $0.ry * 1.2 }.max() ?? 0
        let trikeReach: CGFloat = style.isTrike ? 38 : 0
        let halfHeight = max(maxWidth / 2, legReach, trikeReach) + style.wag + 6
        let left = style.length + 6
        let right = style.headLength * 1.2 + 6
        let size = CGSize(width: ceil((left + right) * s), height: ceil(halfHeight * 2 * s))

        let format = UIGraphicsImageRendererFormat()
        format.scale = screenScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        var frames: [SKTexture] = []
        for i in 0..<framesPerCycle {
            let phase = CGFloat(i) / CGFloat(framesPerCycle) * .pi * 2
            let image = renderer.image { context in
                let ctx = context.cgContext
                ctx.translateBy(x: left * s, y: size.height / 2)
                ctx.scaleBy(x: s, y: s)
                draw(style, phase: phase, scale: s, in: ctx)
            }
            frames.append(SKTexture(image: image))
        }

        let baked = Baked(
            frames: frames,
            anchor: CGPoint(x: (left + style.center) * s / size.width, y: 0.5),
            shadowSize: CGSize(width: style.total * 0.88 * s, height: max(maxWidth, trikeReach * 1.8) * 1.2 * s)
        )
        cache[key] = baked
        return baked
    }

    // MARK: - Drawing

    private struct SpinePoint {
        var x: CGFloat
        var y: CGFloat
        var w: CGFloat
    }

    private static func spine(_ style: DinoStyle, phase: CGFloat) -> [SpinePoint] {
        style.spine.map { point in
            let back = -point.x
            let tail = max(0, (back - style.hip) / (style.length - style.hip))
            let y = style.sway * sin(phase) + style.wag * sin(phase - back * style.wave) * pow(tail, 1.3)
            return SpinePoint(x: point.x, y: y, w: point.w)
        }
    }

    private static func bodyY(_ pts: [SpinePoint], at x: CGFloat) -> CGFloat {
        for i in 0..<(pts.count - 1) where x <= pts[i].x && x >= pts[i + 1].x {
            let span = pts[i].x - pts[i + 1].x
            let f = span == 0 ? 0 : (pts[i].x - x) / span
            return pts[i].y + (pts[i + 1].y - pts[i].y) * f
        }
        return pts.last?.y ?? 0
    }

    private static func ellipse(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) {
        var transform = CGAffineTransform(translationX: x, y: y).rotated(by: rotation)
        let rect = CGRect(x: -max(0.1, rx), y: -max(0.1, ry), width: max(0.2, rx * 2), height: max(0.2, ry * 2))
        ctx.addPath(CGPath(ellipseIn: rect, transform: &transform))
    }

    private static func smoothThrough(_ ctx: CGContext, _ points: [CGPoint]) {
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            ctx.addQuadCurve(to: mid, control: points[i])
        }
        if let end = points.last {
            ctx.addLine(to: end)
        }
    }

    /// Closed outline around a spine of points, tail tip first.
    private static func ribbon(_ ctx: CGContext, _ pts: [SpinePoint]) {
        var lefts: [CGPoint] = []
        var rights: [CGPoint] = []
        for i in pts.indices {
            let a = pts[max(0, i - 1)]
            let b = pts[min(pts.count - 1, i + 1)]
            var tx = b.x - a.x
            var ty = b.y - a.y
            let m = max(0.0001, hypot(tx, ty))
            tx /= m
            ty /= m
            let h = pts[i].w / 2
            lefts.append(CGPoint(x: pts[i].x - ty * h, y: pts[i].y + tx * h))
            rights.append(CGPoint(x: pts[i].x + ty * h, y: pts[i].y - tx * h))
        }
        ctx.move(to: lefts[0])
        smoothThrough(ctx, lefts)
        let back = Array(rights.reversed())
        ctx.addLine(to: back[0])
        smoothThrough(ctx, back)
        ctx.closePath()
    }

    private static func paint(_ ctx: CGContext, _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.drawPath(using: .fillStroke)
    }

    private static func fill(_ ctx: CGContext, _ color: UIColor, alpha: CGFloat = 1) {
        ctx.setAlpha(alpha)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.setAlpha(1)
    }

    private static func draw(_ style: DinoStyle, phase: CGFloat, scale s: CGFloat, in ctx: CGContext) {
        let pts = spine(style, phase: phase)
        let lw = min(2.4, max(1.3, s * 3)) / s
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(lw)

        // Legs, under the body
        for leg in style.legs {
            let a = phase + leg.off
            let swing = sin(a) * style.stride
            let lift = max(0, cos(a))
            ctx.saveGState()
            ctx.translateBy(x: leg.x + swing, y: bodyY(pts, at: leg.x) + leg.side * leg.spread)
            ctx.rotate(by: leg.side * 0.2)
            let grow = 1 + 0.14 * lift
            ctx.scaleBy(x: grow, y: grow)
            for t: CGFloat in [-1, 0, 1] {
                let big = leg.sickle && t == -leg.side
                ctx.move(to: CGPoint(x: leg.rx * 0.55, y: t * leg.ry * 0.45))
                ctx.addLine(to: CGPoint(x: leg.rx * (big ? 1.45 : 1.25), y: t * leg.ry * (big ? 0.9 : 0.62)))
                ctx.setLineWidth(lw * 2.6)
                ctx.setStrokeColor(outline.cgColor)
                ctx.replacePathWithStrokedPath()
                ctx.setFillColor(outline.cgColor)
                ctx.fillPath()
                ctx.move(to: CGPoint(x: leg.rx * 0.55, y: t * leg.ry * 0.45))
                ctx.addLine(to: CGPoint(x: leg.rx * (big ? 1.45 : 1.25), y: t * leg.ry * (big ? 0.9 : 0.62)))
                ctx.setLineWidth(lw * 1.1)
                ctx.setStrokeColor(claw.cgColor)
                ctx.strokePath()
            }
            ctx.setLineWidth(lw)
            ctx.setStrokeColor(outline.cgColor)
            ellipse(ctx, 0, 0, leg.rx, leg.ry)
            paint(ctx, style.skin)
            ellipse(ctx, -leg.rx * 0.15, -leg.ry * 0.2, leg.rx * 0.55, leg.ry * 0.4)
            fill(ctx, style.light, alpha: 0.55)
            ctx.restoreGState()
        }

        // Little arms
        for arm in style.arms {
            for side: CGFloat in [1, -1] {
                let reach = sin(phase * 2 + side) * 1.2
                ellipse(ctx, arm.x + reach, bodyY(pts, at: arm.x) + side * arm.spread, arm.rx, arm.ry, rotation: side * 0.5)
                paint(ctx, style.skin)
            }
        }

        // Body and tail, then light along the back
        let tailFirst = Array(pts.reversed())
        ribbon(ctx, tailFirst)
        paint(ctx, style.skin)
        ribbon(ctx, tailFirst.map { SpinePoint(x: $0.x, y: $0.y - $0.w * 0.1, w: $0.w * 0.46) })
        fill(ctx, style.light, alpha: 0.6)

        drawMarks(style, pts, lineWidth: lw, in: ctx)

        // Head
        let angle = atan2(pts[0].y - pts[1].y, pts[0].x - pts[1].x) - style.sway * 0.03 * sin(phase)
        ctx.saveGState()
        ctx.translateBy(x: pts[0].x, y: pts[0].y)
        ctx.rotate(by: angle)
        switch style.head {
        case .theropod(let length, let widths, let teeth, let brow):
            drawTheropodHead(style, length: length, widths: widths, teeth: teeth, brow: brow, lineWidth: lw, in: ctx)
        case .trike(let length):
            drawTrikeHead(style, length: length, in: ctx)
        }
        ctx.restoreGState()
    }

    private static func frameAt(_ pts: [SpinePoint], _ i: Int) -> (p: SpinePoint, tx: CGFloat, ty: CGFloat, nx: CGFloat, ny: CGFloat) {
        let a = pts[max(0, i - 1)]
        let b = pts[min(pts.count - 1, i + 1)]
        var tx = a.x - b.x
        var ty = a.y - b.y
        let m = max(0.0001, hypot(tx, ty))
        tx /= m
        ty /= m
        return (pts[i], tx, ty, -ty, tx)
    }

    private static func drawMarks(_ style: DinoStyle, _ pts: [SpinePoint], lineWidth lw: CGFloat, in ctx: CGContext) {
        switch style.marks {
        case .stripes, .ridge:
            let isRidge = style.marks == .ridge
            let indices = isRidge ? [5, 6, 7, 8] : [1, 2, 3, 4, 5, 6, 7]
            ctx.setAlpha(isRidge ? 0.55 : 0.9)
            ctx.setStrokeColor(style.dark.cgColor)
            for i in indices where i < pts.count {
                let f = frameAt(pts, i)
                let w = f.p.w
                ctx.setLineWidth(max(lw * 1.2, w * 0.13))
                ctx.move(to: CGPoint(x: f.p.x + f.nx * w * 0.4 - f.tx * w * 0.18, y: f.p.y + f.ny * w * 0.4 - f.ty * w * 0.18))
                ctx.addQuadCurve(
                    to: CGPoint(x: f.p.x - f.nx * w * 0.4 - f.tx * w * 0.18, y: f.p.y - f.ny * w * 0.4 - f.ty * w * 0.18),
                    control: CGPoint(x: f.p.x + f.tx * w * 0.12, y: f.p.y + f.ty * w * 0.12)
                )
                ctx.strokePath()
            }
            ctx.setAlpha(1)
            ctx.setLineWidth(lw)
            ctx.setStrokeColor(outline.cgColor)
            if isRidge {
                for i in 0..<min(8, pts.count) {
                    let f = frameAt(pts, i)
                    ellipse(ctx, f.p.x, f.p.y, f.p.w * 0.09, f.p.w * 0.06, rotation: atan2(f.ty, f.tx))
                    fill(ctx, style.dark)
                }
            }
        case .spots:
            for i in 1..<min(7, pts.count) {
                let f = frameAt(pts, i)
                let side: CGFloat = i % 2 == 1 ? 1 : -1
                ellipse(ctx, f.p.x + f.nx * f.p.w * 0.2 * side, f.p.y + f.ny * f.p.w * 0.2 * side, f.p.w * 0.12, f.p.w * 0.1)
                fill(ctx, style.dark)
            }
        case .blotches:
            for i in 1...5 where i < pts.count {
                let f = frameAt(pts, i)
                ellipse(ctx, f.p.x, f.p.y, f.p.w * 0.12, f.p.w * 0.08, rotation: atan2(f.ty, f.tx))
                fill(ctx, style.dark, alpha: 0.55)
            }
        }
    }

    private static func headProfile(_ length: CGFloat, _ widths: [CGFloat]) -> [SpinePoint] {
        let stops: [CGFloat] = [0, 0.25, 0.55, 0.85, 1]
        var pts = zip(stops, widths).map { SpinePoint(x: $0 * length, y: 0, w: $1) }
        pts.append(SpinePoint(x: length * 1.06, y: 0, w: widths[4] * 0.3))
        return pts
    }

    private static func width(_ pts: [SpinePoint], at x: CGFloat) -> CGFloat {
        for i in 0..<(pts.count - 1) where x >= pts[i].x && x <= pts[i + 1].x {
            let span = pts[i + 1].x - pts[i].x
            let f = span == 0 ? 0 : (x - pts[i].x) / span
            return pts[i].w + (pts[i + 1].w - pts[i].w) * f
        }
        return pts.last?.w ?? 0
    }

    private static func drawHeadShape(_ style: DinoStyle, _ hp: [SpinePoint], in ctx: CGContext) {
        ribbon(ctx, hp)
        paint(ctx, style.skin)
        ribbon(ctx, hp.map { SpinePoint(x: $0.x, y: $0.y - $0.w * 0.08, w: $0.w * 0.42) })
        fill(ctx, style.light, alpha: 0.6)
    }

    private static func drawTheropodHead(
        _ style: DinoStyle, length L: CGFloat, widths W: [CGFloat], teeth: Int, brow: Bool,
        lineWidth lw: CGFloat, in ctx: CGContext
    ) {
        let hp = headProfile(L, W)

        // Teeth poke out past the jaw line
        if teeth > 0 {
            ctx.setLineWidth(lw * 0.7)
            for j in 0..<teeth {
                let x = L * (0.5 + 0.44 * CGFloat(j) / CGFloat(max(1, teeth - 1)))
                let half = width(hp, at: x) / 2
                let size = max(1.4, L * 0.04)
                for side: CGFloat in [1, -1] {
                    ctx.move(to: CGPoint(x: x - size, y: side * half * 0.9))
                    ctx.addLine(to: CGPoint(x: x + size, y: side * half * 0.9))
                    ctx.addLine(to: CGPoint(x: x + size * 0.3, y: side * (half + size * 1.6)))
                    ctx.closePath()
                    paint(ctx, claw)
                }
            }
            ctx.setLineWidth(lw)
        }

        drawHeadShape(style, hp, in: ctx)

        // Nostrils
        for side: CGFloat in [1, -1] {
            ellipse(ctx, L * 0.93, side * W[4] * 0.22, L * 0.025, L * 0.018)
            fill(ctx, outline)
        }

        // Eyes and brows
        let ex = L * 0.32
        let ey = width(hp, at: ex) / 2 * 0.62
        let r = max(1.5, L * 0.06)
        for side: CGFloat in [1, -1] {
            ellipse(ctx, ex, side * ey, r * 1.1, r)
            paint(ctx, eyeWhite)
            ellipse(ctx, ex + r * 0.25, side * ey, r * 0.62, r * 0.62)
            fill(ctx, style.eye)
            ellipse(ctx, ex + r * 0.3, side * ey, r * 0.16, r * 0.5)
            fill(ctx, outline)
            if brow {
                ctx.setLineWidth(max(lw * 1.6, r * 0.55))
                ctx.setStrokeColor(style.dark.cgColor)
                ctx.move(to: CGPoint(x: ex - r * 1.3, y: side * (ey - r * 0.2)))
                ctx.addLine(to: CGPoint(x: ex + r * 1.2, y: side * (ey - r * 1.05)))
                ctx.strokePath()
                ctx.setLineWidth(lw)
                ctx.setStrokeColor(outline.cgColor)
            }
        }
    }

    private static func drawTrikeHead(_ style: DinoStyle, length L: CGFloat, in ctx: CGContext) {
        // Frill shield with knobs around the back edge
        ellipse(ctx, -4, 0, 17, 33)
        paint(ctx, style.frill)
        ellipse(ctx, -2, 0, 11, 25)
        fill(ctx, style.frillLight, alpha: 0.85)
        var a: CGFloat = 1.75
        while a <= .pi * 2 - 1.75 + 0.001 {
            ellipse(ctx, -4 + cos(a) * 17, sin(a) * 33, 3.2, 3.2)
            paint(ctx, style.dark)
            a += 0.34
        }

        drawHeadShape(style, headProfile(L, [22, 23, 20, 13, 7]), in: ctx)

        // Beak
        ellipse(ctx, L * 0.98, 0, L * 0.09, 3)
        paint(ctx, style.dark)

        // Eyes
        for side: CGFloat in [1, -1] {
            ellipse(ctx, L * 0.36, side * 8.5, 2.6, 2.3)
            paint(ctx, eyeWhite)
            ellipse(ctx, L * 0.37, side * 8.5, 1.3, 1.3)
            fill(ctx, style.eye)
        }

        // Three horns
        func horn(from base: CGPoint, to tip: CGPoint, half: CGFloat) {
            let dx = tip.x - base.x
            let dy = tip.y - base.y
            let m = max(0.0001, hypot(dx, dy))
            let nx = -dy / m * half
            let ny = dx / m * half
            let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
            ctx.move(to: CGPoint(x: base.x + nx, y: base.y + ny))
            ctx.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx * 0.6, y: mid.y + ny * 0.6))
            ctx.addQuadCurve(to: CGPoint(x: base.x - nx, y: base.y - ny), control: CGPoint(x: mid.x - nx * 0.6, y: mid.y - ny * 0.6))
            ctx.closePath()
            paint(ctx, claw)
        }
        for side: CGFloat in [1, -1] {
            horn(from: CGPoint(x: L * 0.3, y: side * 6.5), to: CGPoint(x: L * 1.12, y: side * 15), half: 3.2)
        }
        horn(from: CGPoint(x: L * 0.74, y: 0), to: CGPoint(x: L * 0.98, y: 0), half: 2.4)
    }
}
