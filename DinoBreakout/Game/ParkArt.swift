import SpriteKit
import UIKit

/// Cartoon art for everything on the board that isn't a dino: tower pads and
/// guns, fences, the paddock gate, the helipad and rescue chopper, the ground,
/// projectiles, and effects. Matches the round two park kit designs. All of it
/// is drawn with Core Graphics once and cached as textures.
enum ParkArt {
    /// Set by the scene before any art is requested.
    static var screenScale: CGFloat = 3
    private static var cache: [String: SKTexture] = [:]

    static let outline = UIColor(hex: 0x16200F)
    static let concrete = UIColor(hex: 0x8F948A)
    static let concreteLight = UIColor(hex: 0xC3C8BB)
    static let concreteDark = UIColor(hex: 0x61665D)
    static let steel = UIColor(hex: 0x6C757B)
    static let steelLight = UIColor(hex: 0xA3ACB2)
    static let steelDark = UIColor(hex: 0x3C4348)
    static let hazard = UIColor(hex: 0xF3C64A)
    static let hazardInk = UIColor(hex: 0x241D05)
    static let tranq = UIColor(hex: 0x3F86C9)
    static let tranqLight = UIColor(hex: 0x8CC5F0)
    static let flare = UIColor(hex: 0xE2742A)
    static let flareLight = UIColor(hex: 0xFFB35C)
    static let ember = UIColor(hex: 0xFF6A2A)
    static let tube = UIColor(hex: 0xA8301C)
    static let wire = UIColor(hex: 0xD6DEE2)
    static let olive = UIColor(hex: 0x5B6A35)
    static let glass = UIColor(hex: 0x9FD3F0)
    static let hull = UIColor(hex: 0xECE8DC)
    static let rescue = UIColor(hex: 0xE2593F)
    static let dirt = UIColor(hex: 0x8A6A3C)
    static let grassA = UIColor(hex: 0x355A2E)
    static let grassB = UIColor(hex: 0x3B6333)
    static let tuft = UIColor(hex: 0x5F8D44)
    private static let shadow = UIColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 1)

    /// Stable pseudo random number in 0..<1 for decorating a spot.
    static func hash(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let s = sin(a * 127.1 + b * 311.7) * 43758.5453
        return s - floor(s)
    }

    // MARK: - Textures

    static func ground(cols: Int, rows: Int, cell c: CGFloat) -> SKTexture {
        let size = CGSize(width: CGFloat(cols) * c, height: CGFloat(rows) * c)
        return texture("ground-\(cols)-\(rows)-\(Int(c))", size: size, centered: false) { ctx in
            for col in 0..<cols {
                for row in 0..<rows {
                    drawGrassTile(ctx, col: CGFloat(col), row: CGFloat(row), cell: c, odd: (col + row) % 2 == 1)
                }
            }
        }
    }

    /// Worn dirt for a square dinos keep walking over. Four variations.
    static func dirt(cell c: CGFloat, variant: Int) -> SKTexture {
        texture("dirt-\(variant)-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            for k in 0..<3 {
                let fk = CGFloat(k) + CGFloat(variant) * 3
                let x = (hash(fk, 1) - 0.5) * c * 0.4
                let y = (hash(2, fk) - 0.5) * c * 0.4
                let rx = c * (0.2 + hash(fk, 3) * 0.14)
                let ry = c * (0.15 + hash(4, fk) * 0.1)
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: hash(fk, fk) * .pi)
                ctx.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                fill(ctx, dirt, 0.55)
                ctx.restoreGState()
            }
        }
    }

    static func pad(_ kind: BuildKind, level: Int, cell c: CGFloat) -> SKTexture {
        texture("pad-\(kind)-\(level)-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            drawPad(ctx, kind, level: level, cell: c)
        }
    }

    static let headScale: CGFloat = 1.1

    /// The part of a tower that turns to aim, facing +x. Flares have three ember frames.
    static func head(_ kind: BuildKind, level: Int, cell c: CGFloat, frame: Int = 0) -> SKTexture {
        let side = c * headScale
        return texture("head-\(kind)-\(level)-\(frame)-\(Int(c))", size: CGSize(width: side, height: side)) { ctx in
            drawHead(ctx, kind, level: level, cell: c, frame: frame)
        }
    }

    /// Where each barrel ends, along the head's local y axis.
    static func muzzles(_ kind: BuildKind, level: Int, cell c: CGFloat) -> [CGFloat] {
        switch (kind, level) {
        case (.tranq, 3): [-c * 0.045, c * 0.045]
        case (.turret, 2): [-c * 0.07, c * 0.07]
        case (.tranq, _), (.turret, _): [0]
        default: []
        }
    }

    static func muzzleFlash(cell c: CGFloat) -> SKTexture {
        let size = c * 0.3
        return texture("flash-\(Int(c))", size: CGSize(width: size, height: size)) { ctx in
            ctx.move(to: CGPoint(x: size * 0.45, y: 0))
            for i in 1..<10 {
                let a = CGFloat(i) * .pi * 2 / 10
                let r = i % 2 == 1 ? size * 0.18 : size * 0.45
                ctx.addLine(to: CGPoint(x: cos(a) * r, y: sin(a) * r * 0.75))
            }
            ctx.closePath()
            fill(ctx, UIColor(hex: 0xFFE27A))
            circle(ctx, 0, 0, size * 0.14)
            fill(ctx, UIColor(hex: 0xFFF8D8))
        }
    }

    static func fencePost(cell c: CGFloat) -> SKTexture {
        texture("post-\(Int(c))", size: CGSize(width: c * 0.6, height: c * 0.6)) { ctx in
            let s = c * 0.36
            let lw = lineWidth(c)
            rr(ctx, -s / 2 + c * 0.04, -s / 2 + c * 0.06, s, s, c * 0.06)
            fill(ctx, shadow, 0.32)
            rr(ctx, -s / 2, -s / 2, s, s, c * 0.06)
            ink(ctx, concrete, lw)
            rr(ctx, -s / 2 + s * 0.12, -s / 2 + s * 0.12, s * 0.76, s * 0.3, c * 0.03)
            fill(ctx, concreteLight, 0.45)
            circle(ctx, 0, 0, c * 0.09)
            ink(ctx, hazard, lw)
            circle(ctx, 0, 0, c * 0.025)
            fill(ctx, outline)
        }
    }

    static func wireSize(cell c: CGFloat) -> CGSize {
        CGSize(width: c, height: c * 0.44)
    }

    /// Three live wires spanning post to post, horizontal.
    static func wire(cell c: CGFloat) -> SKTexture {
        texture("wire-\(Int(c))", size: wireSize(cell: c)) { ctx in
            let lw = lineWidth(c)
            for o: CGFloat in [-0.13, 0, 0.13] {
                let y = o * c
                line(ctx, CGPoint(x: -c / 2, y: y), CGPoint(x: c / 2, y: y), UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 0.3), lw * 4)
                line(ctx, CGPoint(x: -c / 2, y: y), CGPoint(x: c / 2, y: y), outline, lw * 1.9)
                line(ctx, CGPoint(x: -c / 2, y: y), CGPoint(x: c / 2, y: y), wire, lw * 0.8)
            }
        }
    }

    static func warningSign(cell c: CGFloat) -> SKTexture {
        let size = c * 0.34
        return texture("sign-\(Int(c))", size: CGSize(width: size, height: size)) { ctx in
            let s = c * 0.13
            let lw = lineWidth(c)
            ctx.move(to: CGPoint(x: 0, y: -s))
            ctx.addLine(to: CGPoint(x: s * 1.05, y: s * 0.8))
            ctx.addLine(to: CGPoint(x: -s * 1.05, y: s * 0.8))
            ctx.closePath()
            ink(ctx, hazard, lw)
            ctx.setFillColor(outline.cgColor)
            ctx.fill(CGRect(x: -s * 0.08, y: -s * 0.35, width: s * 0.16, height: s * 0.65))
            circle(ctx, 0, s * 0.5, s * 0.09)
            fill(ctx, outline)
        }
    }

    static func spark(cell c: CGFloat, color: UIColor) -> SKTexture {
        let size = c * 0.4
        return texture("spark-\(color.hashValue)-\(Int(c))", size: CGSize(width: size, height: size)) { ctx in
            let r = size * 0.45
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(max(1, r * 0.18))
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 + 0.3
                let len = i % 2 == 1 ? r : r * 0.55
                ctx.move(to: CGPoint(x: cos(a) * r * 0.2, y: sin(a) * r * 0.2))
                ctx.addLine(to: CGPoint(x: cos(a) * len, y: sin(a) * len))
            }
            ctx.strokePath()
        }
    }

    static func dart(cell c: CGFloat) -> SKTexture {
        texture("dart-\(Int(c))", size: CGSize(width: c * 0.26, height: c * 0.1)) { ctx in
            let len = c * 0.2
            line(ctx, CGPoint(x: -len / 2, y: 0), CGPoint(x: len / 2, y: 0), outline, 4)
            line(ctx, CGPoint(x: -len / 2, y: 0), CGPoint(x: len / 2, y: 0), UIColor(hex: 0xF4F6F2), 2)
            circle(ctx, -len / 2, 0, c * 0.04)
            fill(ctx, tranq)
        }
    }

    static func tracer(cell c: CGFloat) -> SKTexture {
        texture("tracer-\(Int(c))", size: CGSize(width: c * 0.3, height: c * 0.1)) { ctx in
            let len = c * 0.24
            line(ctx, CGPoint(x: -len / 2, y: 0), CGPoint(x: len / 2, y: 0), UIColor(red: 1, green: 0.82, blue: 0.35, alpha: 0.35), 5)
            line(ctx, CGPoint(x: -len / 2, y: 0), CGPoint(x: len / 2, y: 0), UIColor(hex: 0xFFE98F), 2)
        }
    }

    // MARK: Gate

    static func gateBase(cell c: CGFloat) -> SKTexture {
        texture("gate-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            let lw = lineWidth(c)
            ctx.setFillColor(UIColor(hex: 0x4A2A1E).cgColor)
            ctx.fill(CGRect(x: -c / 2, y: -c / 2, width: c, height: c))
            ctx.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
            ctx.fill(CGRect(x: -c / 2, y: -c / 2, width: c, height: c * 0.25))
            for x in [-c * 0.42, c * 0.42] {
                rr(ctx, x - c * 0.11, -c * 0.42, c * 0.22, c * 0.24, c * 0.04)
                ink(ctx, concrete, lw)
            }
        }
    }

    static let doorLength: CGFloat = 0.34

    /// One gate door, drawn from its hinge (left middle) outward.
    static func gateDoor(cell c: CGFloat) -> SKTexture {
        let size = CGSize(width: c * doorLength, height: c * 0.12)
        return texture("door-\(Int(c))", size: size, centered: false) { ctx in
            let lw = lineWidth(c)
            let body = CGRect(x: lw, y: (size.height - c * 0.1) / 2, width: size.width - lw * 2, height: c * 0.1)
            ctx.addPath(UIBezierPath(roundedRect: body, cornerRadius: c * 0.02).cgPath)
            fill(ctx, steel)
            ctx.saveGState()
            ctx.addPath(UIBezierPath(roundedRect: body, cornerRadius: c * 0.02).cgPath)
            ctx.clip()
            ctx.setFillColor(hazard.cgColor)
            var s = body.minX - c * 0.1
            while s < body.maxX {
                ctx.move(to: CGPoint(x: s, y: body.maxY))
                ctx.addLine(to: CGPoint(x: s + c * 0.045, y: body.maxY))
                ctx.addLine(to: CGPoint(x: s + c * 0.09, y: body.minY))
                ctx.addLine(to: CGPoint(x: s + c * 0.045, y: body.minY))
                ctx.closePath()
                ctx.fillPath()
                s += c * 0.09
            }
            ctx.restoreGState()
            ctx.addPath(UIBezierPath(roundedRect: body, cornerRadius: c * 0.02).cgPath)
            ctx.setStrokeColor(outline.cgColor)
            ctx.setLineWidth(lw)
            ctx.strokePath()
        }
    }

    /// A round signal light, lit or dark.
    static func light(cell c: CGFloat, color: UIColor, dim: UIColor, on: Bool, radius: CGFloat) -> SKTexture {
        let size = c * radius * 4.6
        return texture("light-\(color.hashValue)-\(on)-\(radius)-\(Int(c))", size: CGSize(width: size, height: size)) { ctx in
            if on {
                circle(ctx, 0, 0, c * radius * 2.2)
                fill(ctx, color, 0.35)
            }
            circle(ctx, 0, 0, c * radius)
            ink(ctx, on ? color : dim, lineWidth(c) * 0.8)
        }
    }

    // MARK: Helipad and chopper

    static func helipad(cell c: CGFloat) -> SKTexture {
        texture("pad-h-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            let lw = lineWidth(c)
            rr(ctx, -c * 0.47, -c * 0.47, c * 0.94, c * 0.94, c * 0.08)
            ink(ctx, UIColor(hex: 0x6B7069), lw)
            circle(ctx, 0, 0, c * 0.36)
            ctx.setStrokeColor(hazard.cgColor)
            ctx.setLineWidth(max(2, c * 0.05))
            ctx.strokePath()
            let font = UIFont.systemFont(ofSize: c * 0.4, weight: .black)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(hex: 0xF3F0E4)]
            let text = "H" as NSString
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        }
    }

    /// Fuselage, tail, and skids, facing +x. `s` is the chopper's overall size.
    static func chopperBody(size s: CGFloat) -> SKTexture {
        texture("chopper-\(Int(s))", size: CGSize(width: s * 1.4, height: s * 0.5)) { ctx in
            let lw = max(1.2, s * 0.025)
            for side: CGFloat in [-1, 1] {
                line(ctx, CGPoint(x: -s * 0.2, y: side * s * 0.19), CGPoint(x: s * 0.24, y: side * s * 0.19), outline, lw * 2.6)
                line(ctx, CGPoint(x: -s * 0.2, y: side * s * 0.19), CGPoint(x: s * 0.24, y: side * s * 0.19), steelDark, lw * 1.2)
            }
            rr(ctx, -s * 0.64, -s * 0.035, s * 0.5, s * 0.07, s * 0.03)
            ink(ctx, hull, lw)
            rr(ctx, -s * 0.66, -s * 0.11, s * 0.08, s * 0.22, s * 0.03)
            ink(ctx, rescue, lw)
            let bodyRect = CGRect(x: -s * 0.31, y: -s * 0.17, width: s * 0.62, height: s * 0.34)
            ctx.addEllipse(in: bodyRect)
            ink(ctx, hull, lw)
            ctx.saveGState()
            ctx.addEllipse(in: bodyRect)
            ctx.clip()
            ctx.setFillColor(rescue.cgColor)
            ctx.fill(CGRect(x: -s * 0.12, y: -s * 0.2, width: s * 0.08, height: s * 0.4))
            ctx.restoreGState()
            ctx.addArc(center: CGPoint(x: s * 0.17, y: 0), radius: s * 0.12, startAngle: -1.25, endAngle: 1.25, clockwise: false)
            ctx.closePath()
            ink(ctx, glass, lw)
            ctx.addEllipse(in: CGRect(x: s * 0.14, y: -s * 0.065, width: s * 0.1, height: s * 0.05))
            fill(ctx, .white, 0.7)
        }
    }

    static func rotor(size s: CGFloat) -> SKTexture {
        texture("rotor-\(Int(s))", size: CGSize(width: s * 1.16, height: s * 1.16)) { ctx in
            circle(ctx, 0, 0, s * 0.56)
            fill(ctx, UIColor(red: 0.08, green: 0.1, blue: 0.09, alpha: 1), 0.13)
            line(ctx, CGPoint(x: -s * 0.56, y: 0), CGPoint(x: s * 0.56, y: 0), UIColor(red: 0.09, green: 0.13, blue: 0.06, alpha: 0.75), s * 0.04)
            circle(ctx, 0, 0, s * 0.05)
            ink(ctx, steelDark, max(1.2, s * 0.025))
        }
    }

    static func tailRotor(size s: CGFloat) -> SKTexture {
        texture("tail-\(Int(s))", size: CGSize(width: s * 0.18, height: s * 0.18)) { ctx in
            line(ctx, CGPoint(x: -s * 0.07, y: 0), CGPoint(x: s * 0.07, y: 0), outline, max(1.4, s * 0.035))
        }
    }

    // MARK: Terrain

    /// A mossy boulder filling a square. Three shapes.
    static func boulder(cell c: CGFloat, variant: Int) -> SKTexture {
        texture("boulder-\(variant)-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            let lw = lineWidth(c)
            let points = 9
            var outlinePoints: [CGPoint] = []
            for i in 0..<points {
                let a = CGFloat(i) / CGFloat(points) * .pi * 2
                let r = c * (0.36 + hash(CGFloat(i), CGFloat(variant) + 1) * 0.08)
                outlinePoints.append(CGPoint(x: cos(a) * r, y: sin(a) * r * 0.9))
            }
            func addBlob(offset: CGPoint, scale: CGFloat) {
                let pts = outlinePoints.map { CGPoint(x: $0.x * scale + offset.x, y: $0.y * scale + offset.y) }
                ctx.move(to: CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2))
                for i in 1...pts.count {
                    let p = pts[i % pts.count]
                    let q = pts[(i + 1) % pts.count]
                    ctx.addQuadCurve(to: CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2), control: p)
                }
                ctx.closePath()
            }
            addBlob(offset: CGPoint(x: c * 0.04, y: c * 0.06), scale: 1)
            fill(ctx, shadow, 0.32)
            addBlob(offset: .zero, scale: 1)
            ink(ctx, UIColor(hex: 0x7B8073), lw)
            addBlob(offset: CGPoint(x: -c * 0.06, y: -c * 0.07), scale: 0.6)
            fill(ctx, UIColor(hex: 0x9DA293))
            ctx.move(to: CGPoint(x: -c * 0.05, y: c * 0.05))
            ctx.addLine(to: CGPoint(x: c * 0.12, y: c * 0.16))
            ctx.setStrokeColor(UIColor(hex: 0x5D6257).cgColor)
            ctx.setLineWidth(lw)
            ctx.strokePath()
            for i in 0..<3 {
                let fi = CGFloat(i)
                circle(ctx, c * (0.1 - 0.08 * fi), -c * (0.2 - 0.05 * fi), c * (0.06 - 0.01 * fi))
                fill(ctx, UIColor(hex: 0x5C8F3E))
            }
        }
    }

    /// A river square. Tiles cleanly next to other river squares.
    static func water(cell c: CGFloat, frame: Int) -> SKTexture {
        texture("water-\(frame)-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            ctx.setFillColor(UIColor(hex: 0x2E6E8E).cgColor)
            ctx.fill(CGRect(x: -c / 2, y: -c / 2, width: c + 0.5, height: c + 0.5))
            ctx.setFillColor(UIColor(hex: 0x245A75).cgColor)
            ctx.fill(CGRect(x: -c / 2, y: -c / 2, width: c + 0.5, height: c * 0.12))
            ctx.fill(CGRect(x: -c / 2, y: c / 2 - c * 0.12, width: c + 0.5, height: c * 0.12))
            let shift = CGFloat(frame) * c * 0.12
            ctx.setStrokeColor(UIColor(hex: 0x7FC3DE).withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(max(1.2, c * 0.025))
            for (i, y) in [-c * 0.18, c * 0.04, c * 0.24].enumerated() {
                let x = -c * 0.35 + shift + CGFloat(i) * c * 0.12
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addQuadCurve(to: CGPoint(x: x + c * 0.2, y: y), control: CGPoint(x: x + c * 0.1, y: y - c * 0.05))
            }
            ctx.strokePath()
        }
    }

    /// Wooden planks laid over a river crossing.
    static func bridge(cell c: CGFloat) -> SKTexture {
        texture("bridge-\(Int(c))", size: CGSize(width: c, height: c)) { ctx in
            let lw = lineWidth(c)
            ctx.setFillColor(UIColor(hex: 0x2E6E8E).cgColor)
            ctx.fill(CGRect(x: -c / 2, y: -c / 2, width: c + 0.5, height: c + 0.5))
            let plank = c * 0.16
            var y = -c / 2 + c * 0.02
            var i = 0
            while y < c / 2 - plank * 0.5 {
                rr(ctx, -c * 0.4, y, c * 0.8, plank * 0.86, c * 0.02)
                ink(ctx, i % 2 == 0 ? UIColor(hex: 0x9A7446) : UIColor(hex: 0x8A6640), lw)
                y += plank
                i += 1
            }
            for x in [-c * 0.42, c * 0.42] {
                line(ctx, CGPoint(x: x, y: -c / 2), CGPoint(x: x, y: c / 2), outline, lw * 3)
                line(ctx, CGPoint(x: x, y: -c / 2), CGPoint(x: x, y: c / 2), UIColor(hex: 0x6B4E2E), lw * 1.6)
            }
        }
    }

    // MARK: HUD icons

    static func icon(for tool: Tool, size: CGFloat) -> SKTexture {
        let key: String
        switch tool {
        case .build(let kind): key = "icon-\(kind)-\(Int(size))"
        case .sell: key = "icon-sell-\(Int(size))"
        }
        return texture(key, size: CGSize(width: size, height: size)) { ctx in
            let c = size * 0.95
            switch tool {
            case .build(.fence):
                let lw = lineWidth(c)
                for o: CGFloat in [-0.13, 0, 0.13] {
                    line(ctx, CGPoint(x: -c * 0.45, y: o * c * 0.6), CGPoint(x: c * 0.45, y: o * c * 0.6), outline, lw * 1.9)
                    line(ctx, CGPoint(x: -c * 0.45, y: o * c * 0.6), CGPoint(x: c * 0.45, y: o * c * 0.6), wire, lw * 0.8)
                }
                for x in [-c * 0.25, c * 0.25] {
                    rr(ctx, x - c * 0.14, -c * 0.14, c * 0.28, c * 0.28, c * 0.05)
                    ink(ctx, concrete, lw)
                    circle(ctx, x, 0, c * 0.07)
                    ink(ctx, hazard, lw)
                }
            case .build(let kind):
                drawPad(ctx, kind, level: 1, cell: c)
                ctx.rotate(by: -.pi / 2)
                drawHead(ctx, kind, level: 1, cell: c, frame: 0)
            case .sell:
                coin(ctx, radius: size * 0.3, symbol: true)
            }
        }
    }

    static func heart(size: CGFloat) -> SKTexture {
        texture("heart-\(Int(size))", size: CGSize(width: size, height: size)) { ctx in
            let s = size * 0.42
            ctx.move(to: CGPoint(x: 0, y: s * 0.85))
            ctx.addCurve(to: CGPoint(x: -s, y: -s * 0.2), control1: CGPoint(x: -s * 0.5, y: s * 0.5), control2: CGPoint(x: -s, y: s * 0.2))
            ctx.addCurve(to: CGPoint(x: 0, y: -s * 0.45), control1: CGPoint(x: -s, y: -s * 0.85), control2: CGPoint(x: -s * 0.2, y: -s * 0.95))
            ctx.addCurve(to: CGPoint(x: s, y: -s * 0.2), control1: CGPoint(x: s * 0.2, y: -s * 0.95), control2: CGPoint(x: s, y: -s * 0.85))
            ctx.addCurve(to: CGPoint(x: 0, y: s * 0.85), control1: CGPoint(x: s, y: s * 0.2), control2: CGPoint(x: s * 0.5, y: s * 0.5))
            ctx.closePath()
            ink(ctx, rescue, 1.6)
        }
    }

    static func coinIcon(size: CGFloat) -> SKTexture {
        texture("coin-\(Int(size))", size: CGSize(width: size, height: size)) { ctx in
            coin(ctx, radius: size * 0.4, symbol: true)
        }
    }

    // MARK: - Drawing

    private static func texture(_ key: String, size: CGSize, centered: Bool = true, _ draw: (CGContext) -> Void) -> SKTexture {
        let fullKey = "\(key)@\(screenScale)"
        if let hit = cache[fullKey] {
            return hit
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = screenScale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            if centered {
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
            }
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            draw(ctx)
        }
        let made = SKTexture(image: image)
        cache[fullKey] = made
        return made
    }

    private static func lineWidth(_ c: CGFloat) -> CGFloat {
        max(1.2, c * 0.03)
    }

    private static func rr(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
        let rect = CGRect(x: x, y: y, width: w, height: h)
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: min(r, min(w, h) / 2)).cgPath)
    }

    private static func circle(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        let r = max(0.1, r)
        ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func ink(_ ctx: CGContext, _ color: UIColor, _ lw: CGFloat) {
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(lw)
        ctx.drawPath(using: .fillStroke)
    }

    private static func fill(_ ctx: CGContext, _ color: UIColor, _ alpha: CGFloat = 1) {
        ctx.setAlpha(alpha)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.setAlpha(1)
    }

    private static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ color: UIColor, _ width: CGFloat) {
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }

    private static func coin(_ ctx: CGContext, radius r: CGFloat, symbol: Bool) {
        circle(ctx, 0, 0, r)
        ink(ctx, hazard, max(1.4, r * 0.12))
        guard symbol else { return }
        let font = UIFont.systemFont(ofSize: r * 1.3, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: outline]
        let text = "$" as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
    }

    private static func drawGrassTile(_ ctx: CGContext, col: CGFloat, row: CGFloat, cell c: CGFloat, odd: Bool) {
        ctx.setFillColor((odd ? grassA : grassB).cgColor)
        ctx.fill(CGRect(x: col * c, y: row * c, width: c + 0.5, height: c + 0.5))
        ctx.setStrokeColor(tuft.cgColor)
        ctx.setLineWidth(max(1.2, c * 0.016))
        for k in 0..<2 {
            let fk = CGFloat(k)
            let x = (col + 0.2 + hash(col * 3 + fk, row) * 0.6) * c
            let y = (row + 0.3 + hash(row * 5 + fk, col) * 0.6) * c
            let size = c * 0.09
            for a: CGFloat in [-0.5, 0, 0.5] {
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + sin(a) * size, y: y - cos(a) * size))
            }
            ctx.strokePath()
        }
        let roll = hash(col * 7, row * 11)
        if roll > 0.86 {
            circle(ctx, (col + 0.3 + hash(row, col * 2) * 0.4) * c, (row + 0.3 + hash(col, row) * 0.4) * c, c * 0.05)
            fill(ctx, UIColor(hex: 0x8B9184))
        } else if roll > 0.78 {
            let fx = (col + 0.25 + hash(col, row * 3) * 0.5) * c
            let fy = (row + 0.25 + hash(row, col * 5) * 0.5) * c
            for i in 0..<4 {
                let a = CGFloat(i) * .pi / 2
                circle(ctx, fx + cos(a) * c * 0.035, fy + sin(a) * c * 0.035, c * 0.03)
                fill(ctx, UIColor(hex: 0xF2E6A8))
            }
            circle(ctx, fx, fy, c * 0.02)
            fill(ctx, UIColor(hex: 0xE0912F))
        }
    }

    private static func drawPad(_ ctx: CGContext, _ kind: BuildKind, level: Int, cell c: CGFloat) {
        let p = c * 0.84
        let h = p / 2
        let lw = lineWidth(c)
        let rad = c * 0.12
        rr(ctx, -h + c * 0.04, -h + c * 0.06, p, p, rad)
        fill(ctx, shadow, 0.32)
        rr(ctx, -h, -h, p, p, rad)
        fill(ctx, concrete)

        ctx.saveGState()
        rr(ctx, -h, -h, p, p, rad)
        ctx.clip()
        rr(ctx, -h + p * 0.07, -h + p * 0.07, p * 0.86, p * 0.36, c * 0.08)
        fill(ctx, concreteLight, 0.4)
        switch kind {
        case .turret:
            let band = p * 0.15
            ctx.setFillColor(hazard.cgColor)
            ctx.fill(CGRect(x: -h, y: h - band, width: p, height: band))
            ctx.setFillColor(hazardInk.cgColor)
            var x = -h - band
            while x < h + band {
                ctx.move(to: CGPoint(x: x, y: h))
                ctx.addLine(to: CGPoint(x: x + band * 0.6, y: h))
                ctx.addLine(to: CGPoint(x: x + band * 1.2, y: h - band))
                ctx.addLine(to: CGPoint(x: x + band * 0.6, y: h - band))
                ctx.closePath()
                ctx.fillPath()
                x += band * 1.2
            }
        case .tranq:
            ctx.setFillColor(tranq.cgColor)
            for (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
                let sx = CGFloat(dx)
                let sy = CGFloat(dy)
                ctx.move(to: CGPoint(x: sx * h, y: sy * h))
                ctx.addLine(to: CGPoint(x: sx * (h - p * 0.26), y: sy * h))
                ctx.addLine(to: CGPoint(x: sx * h, y: sy * (h - p * 0.26)))
                ctx.closePath()
                ctx.fillPath()
            }
        case .flare:
            let colors = [UIColor(red: 0.16, green: 0.09, blue: 0.05, alpha: 0.75).cgColor,
                          UIColor(red: 0.16, green: 0.09, blue: 0.05, alpha: 0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: p * 0.1, endCenter: .zero, endRadius: p * 0.62, options: [])
            }
            ctx.setFillColor(flare.cgColor)
            ctx.fill(CGRect(x: -h, y: -h, width: p, height: p * 0.07))
            ctx.fill(CGRect(x: -h, y: h - p * 0.07, width: p, height: p * 0.07))
        case .fence:
            break
        }
        ctx.restoreGState()

        rr(ctx, -h, -h, p, p, rad)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(lw)
        ctx.strokePath()
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0)] {
            circle(ctx, CGFloat(sx) * (h - p * 0.1), CGFloat(sy) * (h - p * 0.1), c * 0.028)
            fill(ctx, concreteDark)
        }

        // Rank chevrons, one per level, like sergeant stripes
        let w = c * 0.075
        let gap = c * 0.055
        let rankWidth = max(1.4, c * 0.035)
        let x = c * 0.32
        for i in 0..<level {
            let y = c * 0.34 - CGFloat(i) * gap
            for (color, width) in [(outline, rankWidth * 2.2), (hazard, rankWidth)] {
                ctx.move(to: CGPoint(x: x - w, y: y))
                ctx.addLine(to: CGPoint(x: x, y: y - w * 0.75))
                ctx.addLine(to: CGPoint(x: x + w, y: y))
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(width)
                ctx.strokePath()
            }
        }
    }

    private static func drawHead(_ ctx: CGContext, _ kind: BuildKind, level: Int, cell c: CGFloat, frame: Int) {
        switch kind {
        case .tranq: drawTranqHead(ctx, level: level, cell: c)
        case .turret: drawTurretHead(ctx, level: level, cell: c)
        case .flare: drawFlareHead(ctx, level: level, cell: c, frame: frame)
        case .fence: break
        }
    }

    private static func drawTranqHead(_ ctx: CGContext, level: Int, cell c: CGFloat) {
        let lw = lineWidth(c)
        for i in 0..<3 {
            let a = CGFloat(i) * .pi * 2 / 3 + .pi / 6
            let end = CGPoint(x: cos(a) * c * 0.27, y: sin(a) * c * 0.27)
            line(ctx, .zero, end, outline, lw * 3)
            line(ctx, .zero, end, steelDark, lw * 1.4)
        }
        circle(ctx, 0, 0, c * 0.15)
        ink(ctx, steel, lw)
        circle(ctx, -c * 0.15, 0, c * 0.085)
        ink(ctx, tranqLight, lw)
        for i in 0..<3 {
            let a = CGFloat(i) * .pi * 2 / 3
            circle(ctx, -c * 0.15 + cos(a) * c * 0.04, sin(a) * c * 0.04, c * 0.018)
            fill(ctx, rescue)
        }
        let tip = c * 0.47
        for y in muzzles(.tranq, level: level, cell: c) {
            rr(ctx, c * 0.12, y - c * 0.026, tip - c * 0.12, c * 0.052, c * 0.02)
            ink(ctx, steelDark, lw)
        }
        rr(ctx, -c * 0.1, -c * 0.08, c * 0.28, c * 0.16, c * 0.05)
        ink(ctx, tranq, lw)
        rr(ctx, -c * 0.07, -c * 0.06, c * 0.2, c * 0.05, c * 0.025)
        fill(ctx, tranqLight, 0.6)
        if level >= 2 {
            rr(ctx, -c * 0.04, -c * 0.035, c * 0.22, c * 0.07, c * 0.03)
            ink(ctx, steelDark, lw)
            circle(ctx, c * 0.17, 0, c * 0.022)
            fill(ctx, tranqLight)
        }
    }

    private static func drawTurretHead(_ ctx: CGContext, level: Int, cell c: CGFloat) {
        let lw = lineWidth(c)
        let tip = c * 0.48
        switch level {
        case 1:
            rr(ctx, c * 0.12, -c * 0.035, tip - c * 0.12, c * 0.07, c * 0.025)
            ink(ctx, steelDark, lw)
        case 2:
            for y in [-c * 0.07, c * 0.07] {
                rr(ctx, c * 0.12, y - c * 0.03, tip - c * 0.12, c * 0.06, c * 0.022)
                ink(ctx, steelDark, lw)
            }
        default:
            rr(ctx, c * 0.18, -c * 0.085, tip - c * 0.18, c * 0.17, c * 0.04)
            ink(ctx, steelDark, lw)
            for i in 0..<3 {
                let a = CGFloat(i) * .pi * 2 / 3 + 0.4
                let y = sin(a) * c * 0.055
                line(ctx, CGPoint(x: c * 0.2, y: y), CGPoint(x: tip - c * 0.01, y: y), cos(a) > 0 ? steelLight : steel, c * 0.03)
            }
            rr(ctx, tip - c * 0.06, -c * 0.095, c * 0.06, c * 0.19, c * 0.03)
            ink(ctx, steel, lw)
        }
        if level >= 2 {
            rr(ctx, -c * 0.14, c * 0.14, c * 0.2, c * 0.12, c * 0.03)
            ink(ctx, olive, lw)
            ctx.setLineDash(phase: 0, lengths: [c * 0.02, c * 0.02])
            ctx.move(to: CGPoint(x: -c * 0.04, y: c * 0.14))
            ctx.addQuadCurve(to: CGPoint(x: c * 0.08, y: c * 0.1), control: CGPoint(x: c * 0.02, y: c * 0.08))
            ctx.setStrokeColor(UIColor(hex: 0xC9A646).cgColor)
            ctx.setLineWidth(c * 0.025)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }
        let housing = CGRect(x: -c * 0.19, y: -c * 0.17, width: c * 0.34, height: c * 0.34)
        rr(ctx, housing.minX, housing.minY, housing.width, housing.height, c * 0.08)
        fill(ctx, steel)
        ctx.saveGState()
        rr(ctx, housing.minX, housing.minY, housing.width, housing.height, c * 0.08)
        ctx.clip()
        rr(ctx, -c * 0.14, -c * 0.13, c * 0.22, c * 0.11, c * 0.04)
        fill(ctx, steelLight, 0.55)
        ctx.setFillColor(hazard.cgColor)
        ctx.fill(CGRect(x: housing.minX, y: housing.minY, width: c * 0.06, height: housing.height))
        ctx.setFillColor(hazardInk.cgColor)
        var y = -c * 0.2
        while y < c * 0.2 {
            ctx.move(to: CGPoint(x: housing.minX, y: y))
            ctx.addLine(to: CGPoint(x: housing.minX + c * 0.06, y: y + c * 0.04))
            ctx.addLine(to: CGPoint(x: housing.minX + c * 0.06, y: y + c * 0.08))
            ctx.addLine(to: CGPoint(x: housing.minX, y: y + c * 0.04))
            ctx.closePath()
            ctx.fillPath()
            y += c * 0.08
        }
        ctx.restoreGState()
        rr(ctx, housing.minX, housing.minY, housing.width, housing.height, c * 0.08)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(lw)
        ctx.strokePath()
        circle(ctx, c * 0.07, 0, c * 0.035)
        fill(ctx, rescue)
    }

    private static func drawFlareHead(_ ctx: CGContext, level: Int, cell c: CGFloat, frame: Int) {
        let lw = lineWidth(c)
        if level >= 3 {
            circle(ctx, 0, 0, c * 0.33)
            ctx.setStrokeColor(outline.cgColor)
            ctx.setLineWidth(c * 0.05)
            ctx.strokePath()
            circle(ctx, 0, 0, c * 0.33)
            ctx.setStrokeColor(steelLight.cgColor)
            ctx.setLineWidth(c * 0.025)
            ctx.strokePath()
        }
        circle(ctx, 0, 0, c * 0.27)
        ink(ctx, steelDark, lw)
        circle(ctx, 0, 0, c * 0.22)
        fill(ctx, UIColor(hex: 0x262B2D))

        let count = [3, 5, 7][min(2, max(0, level - 1))]
        var spots: [CGPoint] = []
        if count == 7 {
            spots.append(.zero)
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                spots.append(CGPoint(x: cos(a) * c * 0.13, y: sin(a) * c * 0.13))
            }
        } else {
            for i in 0..<count {
                let a = CGFloat(i) * .pi * 2 / CGFloat(count) - .pi / 2
                spots.append(CGPoint(x: cos(a) * c * 0.11, y: sin(a) * c * 0.11))
            }
        }
        for (i, spot) in spots.enumerated() {
            circle(ctx, spot.x, spot.y, c * 0.055)
            ink(ctx, tube, lw * 0.8)
            let flick = 0.5 + 0.5 * sin(CGFloat(frame) * 2.1 + CGFloat(i) * 1.7)
            circle(ctx, spot.x, spot.y, c * (0.022 + 0.012 * flick))
            fill(ctx, flick > 0.5 ? flareLight : ember)
        }
        if level >= 3 {
            for i in 0..<4 {
                let a = CGFloat(i) * .pi / 2 + .pi / 4
                rr(ctx, cos(a) * c * 0.3 - c * 0.035, sin(a) * c * 0.3 - c * 0.035, c * 0.07, c * 0.07, c * 0.015)
                ink(ctx, flare, lw)
            }
        }
    }
}
