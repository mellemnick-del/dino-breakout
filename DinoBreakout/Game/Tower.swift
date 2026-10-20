import SpriteKit

enum BuildKind: CaseIterable {
    case fence, tranq, turret, flare, flak

    var title: String {
        switch self {
        case .fence: "Fence"
        case .tranq: "Tranq"
        case .turret: "Turret"
        case .flare: "Flare"
        case .flak: "Flak"
        }
    }

    var cost: Int {
        switch self {
        case .fence: 5
        case .tranq: 20
        case .turret: 35
        case .flare: 50
        case .flak: 45
        }
    }

    /// Reach in cells. Fences don't shoot.
    var range: CGFloat {
        switch self {
        case .fence: 0
        case .tranq: 2.6
        case .turret: 2.2
        case .flare: 1.4
        case .flak: 3.2
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .fence: 0
        case .tranq: 0.9
        case .turret: 0.35
        case .flare: 1.4
        case .flak: 0.6
        }
    }

    var damage: CGFloat {
        switch self {
        case .fence: 0
        case .tranq: 5
        case .turret: 8
        case .flare: 16
        case .flak: 22
        }
    }

    /// Flares burn the ground, so they can't reach flyers.
    var hitsAir: Bool {
        self != .flare && self != .fence
    }

    /// Flak is built for the sky and can't hit anything walking.
    var hitsGround: Bool {
        self != .flak && self != .fence
    }

    /// Flak shells burst and also hit flyers this close to the target, in squares.
    var splash: CGFloat {
        self == .flak ? 0.9 : 0
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
        case .flak: SKColor(red: 0.36, green: 0.42, blue: 0.21, alpha: 1)
        }
    }
}

/// Anything you build. Every tower is also a wall, so it shapes the maze.
final class Tower: SKNode {
    static let maxLevel = 5

    let kind: BuildKind
    let cell: Cell
    private(set) var level = 1
    private(set) var invested: Int
    var cooldown: TimeInterval = 0

    private let cellSize: CGFloat
    private let base: SKSpriteNode
    /// Turns to aim. Holds the gun, which kicks back when it fires.
    private let head = SKNode()
    private var gun: SKSpriteNode?
    private var flashes: [SKSpriteNode] = []

    init(kind: BuildKind, cell: Cell, cellSize: CGFloat) {
        self.kind = kind
        self.cell = cell
        self.cellSize = cellSize
        invested = kind.cost
        if kind == .fence {
            base = SKSpriteNode(texture: ParkArt.fencePost(cell: cellSize), size: CGSize(width: cellSize * 0.6, height: cellSize * 0.6))
        } else {
            base = SKSpriteNode(texture: ParkArt.pad(kind, level: 1, cell: cellSize), size: CGSize(width: cellSize, height: cellSize))
        }
        super.init()
        zPosition = 3
        addChild(base)
        if kind != .fence {
            head.zRotation = .pi / 2
            head.zPosition = 1
            addChild(head)
            buildGun()
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
        base.texture = ParkArt.pad(kind, level: level, cell: cellSize)
        buildGun()
        run(.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1, duration: 0.12)]))
    }

    /// Point the gun at a spot in the same coordinate space as the tower.
    func aim(at point: CGPoint) {
        head.zRotation = atan2(point.y - position.y, point.x - position.x)
    }

    /// Recoil and muzzle flash, or a flare's flare up.
    func showFire() {
        guard let gun else { return }
        if kind == .flare {
            gun.run(.sequence([.scale(to: 1.12, duration: 0.06), .scale(to: 1, duration: 0.15)]), withKey: "fire")
            return
        }
        gun.removeAction(forKey: "fire")
        gun.position = .zero
        gun.run(.sequence([
            .moveBy(x: -cellSize * 0.05, y: 0, duration: 0.03),
            .move(to: .zero, duration: 0.09)
        ]), withKey: "fire")
        for flash in flashes {
            flash.removeAllActions()
            flash.isHidden = false
            flash.run(.sequence([.wait(forDuration: 0.05), .hide()]))
        }
    }

    private func buildGun() {
        head.removeAllChildren()
        flashes = []
        let side = cellSize * ParkArt.headScale
        let size = CGSize(width: side, height: side)
        let sprite: SKSpriteNode
        if kind == .flare {
            let frames = (0..<3).map { ParkArt.head(kind, level: level, cell: cellSize, frame: $0) }
            sprite = SKSpriteNode(texture: frames[0], size: size)
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            sprite = SKSpriteNode(texture: ParkArt.head(kind, level: level, cell: cellSize), size: size)
            let flashSize = CGSize(width: cellSize * 0.3, height: cellSize * 0.3)
            for y in ParkArt.muzzles(kind, level: level, cell: cellSize) {
                let flash = SKSpriteNode(texture: ParkArt.muzzleFlash(cell: cellSize), size: flashSize)
                flash.position = CGPoint(x: cellSize * 0.5, y: -y)
                flash.zPosition = 1
                flash.isHidden = true
                sprite.addChild(flash)
                flashes.append(flash)
            }
        }
        head.addChild(sprite)
        gun = sprite
    }
}
