import SpriteKit

enum DinoKind {
    case compy, raptor, dilophosaurus, triceratops, stegosaurus, spinosaurus, rex, pterodactyl
    case ankylosaurus, pachycephalosaurus

    static let all: [DinoKind] = [
        .compy, .raptor, .dilophosaurus, .triceratops, .stegosaurus, .spinosaurus, .rex, .pterodactyl,
        .ankylosaurus, .pachycephalosaurus
    ]

    var name: String {
        switch self {
        case .compy: "Compy"
        case .raptor: "Raptor"
        case .triceratops: "Triceratops"
        case .stegosaurus: "Stegosaurus"
        case .dilophosaurus: "Dilophosaurus"
        case .spinosaurus: "Spinosaurus"
        case .rex: "T-Rex"
        case .pterodactyl: "Pterodactyl"
        case .ankylosaurus: "Ankylosaurus"
        case .pachycephalosaurus: "Pachycephalosaurus"
        }
    }

    /// Clubs a fence next to it every few seconds, knocking it down.
    var smashesFences: Bool {
        self == .ankylosaurus
    }

    /// Charges in bursts and headbutts towers it passes, stunning them.
    var headbutts: Bool {
        self == .pachycephalosaurus
    }

    /// Flyers go straight over the maze and can't be reached by flares.
    var flies: Bool {
        self == .pterodactyl
    }

    /// Swimmers cut straight across rivers.
    var swims: Bool {
        self == .spinosaurus
    }

    /// Spitters disable towers for a moment.
    var spits: Bool {
        self == .dilophosaurus
    }

    /// Flat damage soaked from every hit. Weak, fast shots barely scratch armor.
    var armor: CGFloat {
        switch self {
        case .stegosaurus: 5
        case .ankylosaurus: 4
        default: 0
        }
    }

    var plural: String {
        switch self {
        case .compy: "compies"
        case .raptor: "raptors"
        case .triceratops: "triceratops"
        case .stegosaurus: "stegosaurs"
        case .dilophosaurus: "dilophosaurs"
        case .spinosaurus: "spinosaurs"
        case .rex: "T-Rex"
        case .pterodactyl: "pterodactyls"
        case .ankylosaurus: "ankylosaurs"
        case .pachycephalosaurus: "pachys"
        }
    }

    var baseHealth: CGFloat {
        switch self {
        case .compy: 18
        case .raptor: 40
        case .triceratops: 200
        case .stegosaurus: 160
        case .dilophosaurus: 70
        case .spinosaurus: 400
        case .rex: 1300
        case .pterodactyl: 40
        case .ankylosaurus: 280
        case .pachycephalosaurus: 110
        }
    }

    /// Cells per second.
    var moveSpeed: CGFloat {
        switch self {
        case .compy: 1.7
        case .raptor: 2.5
        case .triceratops: 0.85
        case .stegosaurus: 0.75
        case .dilophosaurus: 1.4
        case .spinosaurus: 0.9
        case .rex: 0.6
        case .pterodactyl: 1.3
        case .ankylosaurus: 0.7
        case .pachycephalosaurus: 1.3
        }
    }

    /// Cash for taking one down.
    var reward: Int {
        switch self {
        case .compy: 2
        case .raptor: 4
        case .triceratops: 12
        case .stegosaurus: 11
        case .dilophosaurus: 7
        case .spinosaurus: 20
        case .rex: 80
        case .pterodactyl: 5
        case .ankylosaurus: 16
        case .pachycephalosaurus: 9
        }
    }

    /// Lives lost if it reaches the helipad.
    var damage: Int {
        switch self {
        case .compy: 1
        case .raptor: 1
        case .triceratops: 2
        case .stegosaurus: 2
        case .dilophosaurus: 1
        case .spinosaurus: 3
        case .rex: 10
        case .pterodactyl: 1
        case .ankylosaurus: 2
        case .pachycephalosaurus: 1
        }
    }
}

/// A flyer's straight line from the gate to the helipad, with a weave.
struct Flight {
    let start: CGPoint
    let end: CGPoint
    /// Which way it swoops first.
    let weave: CGFloat
    var travelled: CGFloat = 0
}

final class Dino: SKNode {
    let kind: DinoKind
    let maxHealth: CGFloat
    private(set) var health: CGFloat
    private(set) var isDead = false
    /// The cell it last stood on, and the one it's walking toward.
    var cell: Cell
    var target: Cell
    /// Set for flyers, which ignore the grid.
    var flight: Flight?

    private var slowFactor: CGFloat = 1
    /// Seconds until a spitter can spit again.
    var spitTimer: TimeInterval = 2
    /// Daily challenge speed boost.
    var speedScale: CGFloat = 1
    /// Seconds until an ankylosaur smashes or a pachy charges again.
    var actionTimer: TimeInterval = 3
    /// A pachy's charge: faster for a moment.
    var chargeLeft: TimeInterval = 0
    /// Seconds until a pachy can headbutt another tower.
    var headbuttCooldown: TimeInterval = 0
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
        if kind.flies {
            // High up: the shadow lands well below and under the towers
            shadowOffset = CGPoint(x: cellSize * 0.35, y: -cellSize * 0.55)
            shadow.fillColor = SKColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 0.22)
            shadow.zPosition = -6
        } else {
            shadowOffset = CGPoint(x: cellSize * 0.05, y: -cellSize * 0.08)
        }
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
        zPosition = kind.flies ? 8.5 : (kind == .rex ? 6 : 5)
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
        kind.moveSpeed * slowFactor * speedScale * (chargeLeft > 0 ? 2.2 : 1)
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
