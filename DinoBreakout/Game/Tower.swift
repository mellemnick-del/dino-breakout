import SpriteKit

enum BuildKind: CaseIterable {
    case fence, tranq, turret, flare, flak, shock

    var title: String {
        switch self {
        case .fence: "Fence"
        case .tranq: "Tranq"
        case .turret: "Turret"
        case .flare: "Flare"
        case .flak: "Flak"
        case .shock: "Shock"
        }
    }

    var cost: Int {
        switch self {
        case .fence: 5
        case .tranq: 20
        case .turret: 35
        case .flare: 50
        case .flak: 45
        case .shock: 60
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
        case .shock: 1.8
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .fence: 0
        case .tranq: 0.9
        case .turret: 0.35
        case .flare: 1.4
        case .flak: 0.6
        case .shock: 1.1
        }
    }

    var damage: CGFloat {
        switch self {
        case .fence: 0
        case .tranq: 5
        case .turret: 8
        case .flare: 16
        case .flak: 22
        case .shock: 14
        }
    }

    /// Each tower's special move, triggered from its panel.
    var abilityName: String? {
        switch self {
        case .fence: nil
        case .tranq: "Sleep Gas"
        case .turret: "Overdrive"
        case .flare: "Napalm"
        case .flak: "Barrage"
        case .shock: "Overload"
        }
    }

    var abilityDetail: String {
        switch self {
        case .fence: ""
        case .tranq: "Nearly freezes everything close by for 3 seconds"
        case .turret: "Fires three times as fast for 5 seconds"
        case .flare: "Leaves a burning patch for 4 seconds"
        case .flak: "Blasts every flyer in range at once"
        case .shock: "Zaps every dino in range for 4x damage"
        }
    }

    /// Seconds before the ability can be used again.
    var abilityRecharge: TimeInterval {
        self == .flare ? 30 : 25
    }

    /// Flares burn the ground and lightning needs a ground path, so neither reaches flyers.
    var hitsAir: Bool {
        self != .flare && self != .fence && self != .shock
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
        case .shock: SKColor(red: 0.35, green: 0.75, blue: 0.95, alpha: 1)
        }
    }
}

/// The two ways each tower can specialize when it goes from level 3 to 4.
enum TowerBranch: String, CaseIterable {
    case sedative, sniper, minigun, cannon, inferno, phosphor, hailstorm, skyhammer, storm, arc

    static func options(for kind: BuildKind) -> [TowerBranch] {
        switch kind {
        case .fence: []
        case .tranq: [.sedative, .sniper]
        case .turret: [.minigun, .cannon]
        case .flare: [.inferno, .phosphor]
        case .flak: [.hailstorm, .skyhammer]
        case .shock: [.storm, .arc]
        }
    }

    var title: String {
        switch self {
        case .sedative: "Sedative"
        case .sniper: "Sniper"
        case .minigun: "Minigun"
        case .cannon: "Cannon"
        case .inferno: "Inferno"
        case .phosphor: "Phosphor"
        case .hailstorm: "Hailstorm"
        case .skyhammer: "Skyhammer"
        case .storm: "Storm"
        case .arc: "Arc"
        }
    }

    var detail: String {
        switch self {
        case .sedative: "Darts slow dinos to a crawl, and for longer"
        case .sniper: "Much longer range and harder hits"
        case .minigun: "Fires far faster"
        case .cannon: "Slow, heavy shells that blast nearby dinos too"
        case .inferno: "A much wider ring of fire"
        case .phosphor: "Hotter fire that ignores armor"
        case .hailstorm: "Faster fire and wider bursts"
        case .skyhammer: "Huge shells that can hit ground dinos too"
        case .storm: "Lightning jumps to three more dinos"
        case .arc: "Harder zaps that stun for a moment"
        }
    }

    /// One letter for the badge on the tower.
    var letter: String {
        String(title.prefix(1))
    }

    var color: SKColor {
        switch self {
        case .sedative, .inferno, .hailstorm, .storm, .minigun:
            SKColor(red: 0.35, green: 0.75, blue: 0.95, alpha: 1)
        case .sniper, .cannon, .phosphor, .skyhammer, .arc:
            SKColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1)
        }
    }

    var damageScale: CGFloat {
        switch self {
        case .sniper: 1.6
        case .cannon: 1.9
        case .phosphor: 1.3
        case .skyhammer: 1.7
        case .arc: 1.6
        default: 1
        }
    }

    /// Shots per second, compared with the base tower.
    var rateScale: CGFloat {
        switch self {
        case .minigun: 1.7
        case .cannon: 0.6
        case .hailstorm: 1.5
        default: 1
        }
    }

    var rangeBonus: CGFloat {
        switch self {
        case .sniper: 1.2
        case .inferno: 0.5
        default: 0
        }
    }
}

/// Which dino in range a tower shoots first.
enum Targeting: CaseIterable {
    case first, strongest, closest, flyers

    var title: String {
        switch self {
        case .first: "First"
        case .strongest: "Strongest"
        case .closest: "Closest"
        case .flyers: "Flyers"
        }
    }

    var next: Targeting {
        let all = Targeting.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Anything you build. Every tower is also a wall, so it shapes the maze.
final class Tower: SKNode {
    static let maxLevel = 5
    /// Better Optics research, set when a game starts.
    static var rangeScale: CGFloat = 1

    let kind: BuildKind
    var cell: Cell
    private(set) var level = 1
    /// Picked on the way to level 4.
    private(set) var branch: TowerBranch?
    private var badge: SKNode?
    private var dizzy: SKNode?
    private(set) var invested: Int
    var cooldown: TimeInterval = 0
    /// Dinos this tower finished off, and the damage it's dealt, for its panel.
    var kills = 0
    var damageDealt: CGFloat = 0
    /// Which dino in range this tower shoots first.
    var targeting: Targeting = .first
    /// Seconds until the special ability is ready again.
    var abilityCooldown: TimeInterval = 0
    /// Seconds this tower is gummed up by venom and can't fire.
    private(set) var disabledLeft: TimeInterval = 0
    private var goo: SKNode?
    /// Seconds of turret overdrive left.
    private(set) var overdriveLeft: TimeInterval = 0
    private var overdriveGlow: SKShapeNode?

    private let cellSize: CGFloat
    private let base: SKSpriteNode
    /// Turns to aim. Holds the gun, which kicks back when it fires.
    private let head = SKNode()
    private var gun: SKSpriteNode?
    private var flashes: [SKSpriteNode] = []

    /// `paid` is what the player actually spent, when research made it cheaper.
    init(kind: BuildKind, cell: Cell, cellSize: CGFloat, paid: Int? = nil) {
        self.kind = kind
        self.cell = cell
        self.cellSize = cellSize
        invested = paid ?? kind.cost
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
        (kind.range + 0.3 * CGFloat(level - 1) + (branch?.rangeBonus ?? 0)) * Tower.rangeScale
    }

    /// The branch name once picked, otherwise the tower's own name.
    var title: String {
        branch?.title ?? kind.title
    }

    /// Level 3 towers pick a branch before they reach level 4.
    var needsBranch: Bool {
        level == 3 && branch == nil && !TowerBranch.options(for: kind).isEmpty
    }

    var fireInterval: TimeInterval {
        kind.fireInterval / TimeInterval(branch?.rateScale ?? 1)
    }

    var slow: (factor: CGFloat, duration: TimeInterval)? {
        if branch == .sedative {
            return (factor: 0.3, duration: 2.4)
        }
        return kind.slow
    }

    /// Cannon shells blast ground dinos nearby; flak bursts catch other flyers.
    var splash: CGFloat {
        if branch == .cannon {
            return 0.75
        }
        return kind.splash + (branch == .hailstorm ? 0.5 : 0)
    }

    var splashHitsGround: Bool {
        branch == .cannon
    }

    var hitsAir: Bool {
        kind.hitsAir
    }

    var hitsGround: Bool {
        kind.hitsGround || branch == .skyhammer
    }

    var ignoresArmor: Bool {
        branch == .phosphor
    }

    /// How many more dinos a shock pylon's lightning jumps to after the first.
    var chain: Int {
        guard kind == .shock else { return 0 }
        return 1 + level / 2 + (branch == .storm ? 3 : 0)
    }

    /// Each level hits harder, but levels 4 and 5 add less than the first upgrades.
    var damage: CGFloat {
        let multipliers: [CGFloat] = [1, 1.6, 2.5, 3.6, 5]
        return kind.damage * multipliers[min(max(level, 1), multipliers.count) - 1] * (branch?.damageScale ?? 1)
    }

    /// Nil for fences and maxed towers.
    var upgradeCost: Int? {
        guard kind != .fence, level < Tower.maxLevel else { return nil }
        return kind.cost * level
    }

    var sellValue: Int {
        invested * 7 / 10
    }

    func upgrade(branch picked: TowerBranch? = nil) {
        guard let cost = upgradeCost else { return }
        if level == 3, let picked {
            branch = picked
        }
        invested += cost
        level += 1
        updateBadge()
        base.texture = ParkArt.pad(kind, level: level, cell: cellSize)
        buildGun()
        run(.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1, duration: 0.12)]))
    }

    /// Undoes the last upgrade, for Undo between waves.
    func downgrade(refunding cost: Int) {
        guard level > 1 else { return }
        invested -= cost
        level -= 1
        if level < 4 {
            branch = nil
        }
        updateBadge()
        base.texture = ParkArt.pad(kind, level: level, cell: cellSize)
        buildGun()
    }

    /// A colored letter in the corner showing which branch this tower took.
    private func updateBadge() {
        badge?.removeFromParent()
        badge = nil
        guard let branch else { return }
        let dot = SKShapeNode(circleOfRadius: cellSize * 0.15)
        dot.fillColor = branch.color
        dot.strokeColor = ParkArt.outline
        dot.lineWidth = 1.5
        dot.position = CGPoint(x: -cellSize * 0.3, y: cellSize * 0.3)
        dot.zPosition = 3
        let letter = makeLabel(branch.letter, size: cellSize * 0.2, font: Fonts.heavy, color: ParkArt.outline)
        dot.addChild(letter)
        addChild(dot)
        badge = dot
    }

    /// Headbutted by a pachy: can't fire for a moment, with stars circling.
    func stun(for duration: TimeInterval) {
        disabledLeft = max(disabledLeft, duration)
        guard dizzy == nil else { return }
        let ring = SKNode()
        ring.zPosition = 4
        for i in 0..<3 {
            let a = CGFloat(i) * .pi * 2 / 3
            let star = makeLabel("★", size: cellSize * 0.24, font: Fonts.heavy, color: Palette.warning)
            star.position = CGPoint(x: cos(a) * cellSize * 0.25, y: sin(a) * cellSize * 0.25)
            ring.addChild(star)
        }
        ring.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.8)))
        addChild(ring)
        dizzy = ring
    }

    /// Counts down the ability recharge and any overdrive.
    func tickAbility(_ dt: TimeInterval) {
        abilityCooldown = max(0, abilityCooldown - dt)
        if disabledLeft > 0 {
            disabledLeft -= dt
            if disabledLeft <= 0 {
                goo?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                goo = nil
                dizzy?.removeFromParent()
                dizzy = nil
            }
        }
        guard overdriveLeft > 0 else { return }
        overdriveLeft -= dt
        if overdriveLeft <= 0 {
            overdriveGlow?.removeFromParent()
            overdriveGlow = nil
        }
    }

    /// Venom: the tower can't fire for a few seconds.
    func disable(for duration: TimeInterval) {
        disabledLeft = max(disabledLeft, duration)
        guard goo == nil else { return }
        let blob = SKNode()
        blob.zPosition = 2
        for i in 0..<5 {
            let drop = SKShapeNode(circleOfRadius: cellSize * (0.12 + 0.05 * CGFloat(i % 3)))
            drop.fillColor = SKColor(red: 0.45, green: 0.85, blue: 0.2, alpha: 0.8)
            drop.strokeColor = SKColor(red: 0.2, green: 0.45, blue: 0.08, alpha: 1)
            drop.lineWidth = 1.5
            let a = CGFloat(i) * 1.3
            drop.position = CGPoint(x: cos(a) * cellSize * 0.16, y: sin(a) * cellSize * 0.16)
            blob.addChild(drop)
        }
        blob.setScale(0.3)
        blob.run(.scale(to: 1, duration: 0.15))
        addChild(blob)
        goo = blob
    }

    func startOverdrive(for duration: TimeInterval) {
        overdriveLeft = duration
        guard overdriveGlow == nil else { return }
        let glow = SKShapeNode(circleOfRadius: cellSize * 0.47)
        glow.strokeColor = SKColor(red: 1, green: 0.35, blue: 0.2, alpha: 0.9)
        glow.fillColor = SKColor(red: 1, green: 0.3, blue: 0.1, alpha: 0.15)
        glow.lineWidth = 3
        glow.zPosition = 0.5
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)])))
        addChild(glow)
        overdriveGlow = glow
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
