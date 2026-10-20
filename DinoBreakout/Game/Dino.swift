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
        case .rex: 1100
        }
    }

    /// Cells per second.
    var moveSpeed: CGFloat {
        switch self {
        case .compy: 1.7
        case .raptor: 2.3
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

    /// Placeholder art until real sprites are drawn.
    var emoji: String {
        switch self {
        case .compy: "🦎"
        case .raptor, .rex: "🦖"
        case .triceratops: "🦕"
        }
    }

    /// Size relative to one grid cell.
    var scale: CGFloat {
        switch self {
        case .compy: 0.55
        case .raptor: 0.7
        case .triceratops: 0.95
        case .rex: 1.5
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
    private let body: SKLabelNode
    private let sleepy: SKLabelNode
    private let barBack: SKSpriteNode
    private let bar: SKSpriteNode

    init(kind: DinoKind, healthScale: CGFloat, cell: Cell, cellSize: CGFloat) {
        self.kind = kind
        maxHealth = kind.baseHealth * healthScale
        health = maxHealth
        self.cell = cell
        target = cell

        body = SKLabelNode(text: kind.emoji)
        body.fontSize = cellSize * kind.scale
        body.verticalAlignmentMode = .center
        body.horizontalAlignmentMode = .center

        sleepy = SKLabelNode(text: "💤")
        sleepy.fontSize = cellSize * 0.3
        sleepy.position = CGPoint(x: cellSize * kind.scale * 0.35, y: cellSize * kind.scale * 0.3)
        sleepy.isHidden = true

        let barWidth = cellSize * max(0.6, kind.scale * 0.8)
        let barY = cellSize * kind.scale * 0.55
        barBack = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: CGSize(width: barWidth, height: 4))
        barBack.position = CGPoint(x: 0, y: barY)
        bar = SKSpriteNode(color: .green, size: CGSize(width: barWidth, height: 4))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -barWidth / 2, y: barY)
        barBack.isHidden = true
        bar.isHidden = true

        super.init()
        zPosition = kind == .rex ? 6 : 5
        addChild(body)
        addChild(sleepy)
        addChild(barBack)
        addChild(bar)
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
            sleepy.isHidden = true
        }
    }

    func slow(to factor: CGFloat, for duration: TimeInterval) {
        slowFactor = min(slowFactor, factor)
        slowTimeLeft = max(slowTimeLeft, duration)
        sleepy.isHidden = false
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
            return true
        }
        return false
    }

    /// The emoji faces left, so mirror it when walking right.
    func face(right: Bool) {
        body.xScale = right ? -1 : 1
    }
}
