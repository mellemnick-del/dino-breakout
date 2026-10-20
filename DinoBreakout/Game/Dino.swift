import SpriteKit

enum DinoKind {
    case compy, raptor, triceratops, rex

    var name: String {
        switch self {
        case .compy: "Compy"
        case .raptor: "Raptor"
        case .triceratops: "Triceratops"
        case .rex: "T-Rex"
        }
    }

    var plural: String {
        switch self {
        case .compy: "compies"
        case .raptor: "raptors"
        case .triceratops: "triceratops"
        case .rex: "T-Rex"
        }
    }

    var baseHealth: CGFloat {
        switch self {
        case .compy: 18
        case .raptor: 40
        case .triceratops: 200
        case .rex: 1300
        }
    }

    /// Cells per second.
    var moveSpeed: CGFloat {
        switch self {
        case .compy: 1.7
        case .raptor: 2.5
        case .triceratops: 0.85
        case .rex: 0.6
        }
    }

    /// Cash for taking one down.
    var reward: Int {
        switch self {
        case .compy: 2
        case .raptor: 4
        case .triceratops: 12
        case .rex: 80
        }
    }

    /// Lives lost if it reaches the helipad.
    var damage: Int {
        switch self {
        case .compy: 1
        case .raptor: 1
        case .triceratops: 2
        case .rex: 10
        }
    }
}

final class Dino: SKNode {
    let kind: DinoKind
    let maxHealth: CGFloat
    private(set) var health: CGFloat
    private(set) var isDead = false
    /// The cell it last stood on, and the one it's walking toward.
    var cell: Cell
    var target: Cell

    private var slowFactor: CGFloat = 1
    private var slowTimeLeft: TimeInterval = 0
    private var heading: CGFloat = -.pi / 2
    private let art: SKSpriteNode
    private let shadow: SKShapeNode
    private let shadowOffset: CGPoint
    private let sleepy: SKLabelNode
    private let barBack: SKSpriteNode
    private let bar: SKSpriteNode

    init(kind: DinoKind, healthScale: CGFloat, cell: Cell, cellSize: CGFloat, screenScale: CGFloat) {
        self.kind = kind
        maxHealth = kind.baseHealth * healthScale
        health = maxHealth
        self.cell = cell
        target = cell

        let baked = DinoArt.bake(kind, cellSize: cellSize, screenScale: screenScale)
        art = SKSpriteNode(texture: baked.frames[0])
        art.anchorPoint = baked.anchor
        art.zRotation = heading

        shadow = SKShapeNode(ellipseOf: baked.shadowSize)
        shadow.fillColor = SKColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 0.34)
        shadow.strokeColor = .clear
        shadowOffset = CGPoint(x: cellSize * 0.05, y: -cellSize * 0.08)
        shadow.position = shadowOffset
        shadow.zRotation = heading

        let style = kind.style
        let reach = style.cells * cellSize * 0.5

        sleepy = SKLabelNode(text: "💤")
        sleepy.fontSize = cellSize * 0.3
        sleepy.position = CGPoint(x: reach * 0.5, y: reach * 0.4)
        sleepy.isHidden = true

        let barWidth = cellSize * max(0.6, style.cells * 0.55)
        let barY = reach * 0.75 + cellSize * 0.1
        barBack = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: CGSize(width: barWidth, height: 4))
        barBack.position = CGPoint(x: 0, y: barY)
        bar = SKSpriteNode(color: .green, size: CGSize(width: barWidth, height: 4))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -barWidth / 2, y: barY)
        barBack.isHidden = true
        bar.isHidden = true

        super.init()
        zPosition = kind == .rex ? 6 : 5
        addChild(shadow)
        addChild(art)
        addChild(sleepy)
        addChild(barBack)
        addChild(bar)

        // Walk cycle, starting at a random step so a pack doesn't march in lockstep
        let frames = baked.frames
        let start = Int.random(in: 0..<frames.count)
        let cycle = Array(frames[start...] + frames[..<start])
        let timePerFrame = 1 / (Double(style.rate) * Double(frames.count))
        art.run(.repeatForever(.animate(with: cycle, timePerFrame: timePerFrame)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Cells per second right now, after tranquilizers.
    var currentSpeed: CGFloat {
        kind.moveSpeed * slowFactor
    }

    func tick(_ dt: TimeInterval) {
        guard slowTimeLeft > 0 else { return }
        slowTimeLeft -= dt
        if slowTimeLeft <= 0 {
            slowFactor = 1
            art.speed = 1
            sleepy.isHidden = true
        }
    }

    func slow(to factor: CGFloat, for duration: TimeInterval) {
        slowFactor = min(slowFactor, factor)
        slowTimeLeft = max(slowTimeLeft, duration)
        art.speed = slowFactor
        sleepy.isHidden = false
    }

    /// Turns smoothly toward the direction it's walking.
    func steer(toward angle: CGFloat, dt: TimeInterval) {
        var diff = angle - heading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let maxTurn = CGFloat(dt) * 9
        heading += max(-maxTurn, min(maxTurn, diff))
        art.zRotation = heading
        shadow.zRotation = heading
    }

    /// Returns true if this hit took it down.
    func takeDamage(_ amount: CGFloat) -> Bool {
        guard !isDead else { return false }
        health -= amount
        let fraction = max(0, health / maxHealth)
        bar.xScale = fraction
        bar.color = fraction < 0.35 ? .red : (fraction < 0.65 ? .yellow : .green)
        bar.isHidden = false
        barBack.isHidden = false
        if health <= 0 {
            isDead = true
            art.removeAllActions()
            return true
        }
        let flash = SKAction.sequence([
            .colorize(with: .white, colorBlendFactor: 0.6, duration: 0.03),
            .colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        art.run(flash, withKey: "flash")
        return false
    }
}
