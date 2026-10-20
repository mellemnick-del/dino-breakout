import SpriteKit

enum BuildKind: CaseIterable {
    case fence, tranq, turret, flare

    var title: String {
        switch self {
        case .fence: "Fence"
        case .tranq: "Tranq"
        case .turret: "Turret"
        case .flare: "Flare"
        }
    }

    var icon: String {
        switch self {
        case .fence: "⚡️"
        case .tranq: "💉"
        case .turret: "🎯"
        case .flare: "🔥"
        }
    }

    var cost: Int {
        switch self {
        case .fence: 5
        case .tranq: 20
        case .turret: 35
        case .flare: 50
        }
    }

    /// Reach in cells. Fences don't shoot.
    var range: CGFloat {
        switch self {
        case .fence: 0
        case .tranq: 2.6
        case .turret: 2.2
        case .flare: 1.4
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .fence: 0
        case .tranq: 0.9
        case .turret: 0.35
        case .flare: 1.4
        }
    }

    var damage: CGFloat {
        switch self {
        case .fence: 0
        case .tranq: 5
        case .turret: 8
        case .flare: 16
        }
    }

    /// Tranq darts slow dinos to half speed for a moment.
    var slow: (factor: CGFloat, duration: TimeInterval)? {
        self == .tranq ? (0.5, 1.6) : nil
    }

    var color: SKColor {
        switch self {
        case .fence: SKColor(white: 0.3, alpha: 1)
        case .tranq: SKColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1)
        case .turret: SKColor(red: 0.45, green: 0.47, blue: 0.5, alpha: 1)
        case .flare: SKColor(red: 0.9, green: 0.45, blue: 0.15, alpha: 1)
        }
    }

    var shotColor: SKColor {
        self == .tranq ? .cyan : Palette.warning
    }
}

/// Anything you build. Every tower is also a wall, so it shapes the maze.
final class Tower: SKNode {
    static let maxLevel = 3

    let kind: BuildKind
    let cell: Cell
    private(set) var level = 1
    private(set) var invested: Int
    var cooldown: TimeInterval = 0

    private var head: SKNode?
    private var pips: [SKShapeNode] = []

    init(kind: BuildKind, cell: Cell, cellSize: CGFloat) {
        self.kind = kind
        self.cell = cell
        invested = kind.cost
        super.init()
        zPosition = 3

        let side = cellSize * 0.86
        let base = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: 4)
        addChild(base)

        switch kind {
        case .fence:
            base.fillColor = kind.color
            base.strokeColor = Palette.warning
            base.lineWidth = 1.5
            let stripe = SKSpriteNode(color: Palette.warning, size: CGSize(width: side * 0.8, height: 2))
            addChild(stripe)
        case .flare:
            base.fillColor = kind.color.withAlphaComponent(0.35)
            base.strokeColor = kind.color
            base.lineWidth = 2
            let fire = SKLabelNode(text: kind.icon)
            fire.fontSize = cellSize * 0.5
            fire.verticalAlignmentMode = .center
            addChild(fire)
        case .tranq, .turret:
            base.fillColor = kind.color.withAlphaComponent(0.35)
            base.strokeColor = kind.color
            base.lineWidth = 2
            let gun = SKNode()
            let barrel = SKSpriteNode(color: kind.color, size: CGSize(width: cellSize * 0.1, height: cellSize * 0.34))
            barrel.anchorPoint = CGPoint(x: 0.5, y: 0)
            gun.addChild(barrel)
            let hub = SKShapeNode(circleOfRadius: cellSize * 0.2)
            hub.fillColor = kind.color
            hub.strokeColor = .white
            hub.lineWidth = 1
            gun.addChild(hub)
            addChild(gun)
            head = gun
        }

        if kind != .fence {
            for i in 0..<Tower.maxLevel {
                let pip = SKShapeNode(circleOfRadius: cellSize * 0.04)
                pip.position = CGPoint(x: CGFloat(i - 1) * cellSize * 0.12, y: -side / 2 + cellSize * 0.08)
                pip.strokeColor = .clear
                addChild(pip)
                pips.append(pip)
            }
            refreshPips()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Reach in cells, growing with each upgrade.
    var range: CGFloat {
        kind.range + 0.3 * CGFloat(level - 1)
    }

    var damage: CGFloat {
        kind.damage * pow(1.6, CGFloat(level - 1))
    }

    /// Nil for fences and maxed towers.
    var upgradeCost: Int? {
        guard kind != .fence, level < Tower.maxLevel else { return nil }
        return kind.cost * level
    }

    var sellValue: Int {
        invested * 7 / 10
    }

    func upgrade() {
        guard let cost = upgradeCost else { return }
        invested += cost
        level += 1
        refreshPips()
    }

    /// Point the gun at a spot in the same coordinate space as the tower.
    func aim(at point: CGPoint) {
        head?.zRotation = atan2(point.y - position.y, point.x - position.x) - .pi / 2
    }

    private func refreshPips() {
        for (i, pip) in pips.enumerated() {
            pip.fillColor = i < level ? Palette.warning : SKColor(white: 1, alpha: 0.25)
        }
    }
}
