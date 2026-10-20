import SpriteKit

/// The park behind the main menu: grass, a few boulders, and dinos wandering
/// through on their own.
final class MenuBackdrop: SKScene {
    private var cellSize: CGFloat = 56
    private var spawnTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    override func didMove(to view: SKView) {
        let scale = view.contentScaleFactor
        ParkArt.screenScale = scale
        backgroundColor = SKColor(red: 0.07, green: 0.11, blue: 0.08, alpha: 1)
        cellSize = floor(size.width / 9)

        let cols = Int(ceil(size.width / cellSize))
        let rows = Int(ceil(size.height / cellSize))
        let ground = SKSpriteNode(
            texture: ParkArt.ground(cols: cols, rows: rows, cell: cellSize),
            size: CGSize(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize)
        )
        ground.anchorPoint = .zero
        addChild(ground)

        for i in 0..<5 {
            let fi = CGFloat(i)
            let rock = SKSpriteNode(
                texture: ParkArt.boulder(cell: cellSize, variant: i % 3),
                size: CGSize(width: cellSize, height: cellSize)
            )
            rock.position = CGPoint(
                x: size.width * ParkArt.hash(fi, 2),
                y: size.height * (0.1 + 0.8 * ParkArt.hash(5, fi))
            )
            rock.zPosition = 1
            addChild(rock)
        }

        for kind in [DinoKind.compy, .raptor, .triceratops, .rex] {
            _ = DinoArt.bake(kind, cellSize: cellSize, screenScale: scale)
        }
        for _ in 0..<3 {
            wander(startAnywhere: true)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = TimeInterval.random(in: 1.4...2.6)
            wander(startAnywhere: false)
        }
    }

    /// Sends one dino walking across the screen in a gentle line.
    private func wander(startAnywhere: Bool) {
        let kinds: [DinoKind] = [.compy, .compy, .raptor, .raptor, .triceratops, .rex]
        let kind = kinds.randomElement() ?? .raptor
        let baked = DinoArt.bake(kind, cellSize: cellSize, screenScale: ParkArt.screenScale)
        let style = kind.style

        let leftToRight = Bool.random()
        let margin = style.cells * cellSize
        let y0 = CGFloat.random(in: size.height * 0.08...size.height * 0.92)
        let y1 = y0 + CGFloat.random(in: -size.height * 0.15...size.height * 0.15)
        var start = CGPoint(x: leftToRight ? -margin : size.width + margin, y: y0)
        let end = CGPoint(x: leftToRight ? size.width + margin : -margin, y: y1)
        if startAnywhere {
            let f = CGFloat.random(in: 0.2...0.7)
            start = CGPoint(x: start.x + (end.x - start.x) * f, y: start.y + (end.y - start.y) * f)
        }

        let dino = SKNode()
        dino.position = start
        dino.zPosition = kind == .rex ? 6 : 5
        let angle = atan2(end.y - start.y, end.x - start.x)

        let shadow = SKShapeNode(ellipseOf: baked.shadowSize)
        shadow.fillColor = SKColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 0.34)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: cellSize * 0.05, y: -cellSize * 0.08)
        shadow.zRotation = angle
        dino.addChild(shadow)

        let art = SKSpriteNode(texture: baked.frames[0])
        art.anchorPoint = baked.anchor
        art.zRotation = angle
        art.run(.repeatForever(.animate(with: baked.frames, timePerFrame: 1 / (Double(style.rate) * Double(baked.frames.count)))))
        dino.addChild(art)
        addChild(dino)

        let distance = hypot(end.x - start.x, end.y - start.y)
        let speed = kind.moveSpeed * cellSize * 0.8
        dino.run(.sequence([
            .move(to: end, duration: TimeInterval(distance / speed)),
            .removeFromParent()
        ]))
    }
}
