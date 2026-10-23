import SpriteKit

/// A dart or bullet in flight. Homes in on its target.
private final class Shot {
    let node: SKSpriteNode
    let target: Dino
    let damage: CGFloat
    let slow: (factor: CGFloat, duration: TimeInterval)?
    /// Flak bursts also hit flyers within this many squares.
    let splash: CGFloat
    /// The kind of tower that fired it, for the end of game stats.
    let source: BuildKind
    /// The tower that fired it, for that tower's kill and damage count.
    weak var tower: Tower?
    /// Cannon shells blast ground dinos; flak bursts catch flyers.
    let splashGround: Bool
    var done = false

    init(
        node: SKSpriteNode, target: Dino, damage: CGFloat, slow: (factor: CGFloat, duration: TimeInterval)?,
        splash: CGFloat = 0, source: BuildKind, tower: Tower? = nil
    ) {
        self.source = source
        self.tower = tower
        splashGround = tower?.splashHitsGround ?? false
        self.node = node
        self.target = target
        self.damage = damage
        self.slow = slow
        self.splash = splash
    }
}

/// A napalm patch: burns ground dinos inside it until it runs out.
private final class Burn {
    let node: SKNode
    let center: CGPoint
    let radius: CGFloat
    let damagePerSecond: CGFloat
    var timeLeft: TimeInterval

    init(node: SKNode, center: CGPoint, radius: CGFloat, damagePerSecond: CGFloat, timeLeft: TimeInterval) {
        self.node = node
        self.center = center
        self.radius = radius
        self.damagePerSecond = damagePerSecond
        self.timeLeft = timeLeft
    }
}

/// Something Undo can take back between waves.
private enum UndoStep {
    case built(Tower)
    case upgraded(Tower, cost: Int)

    var tower: Tower {
        switch self {
        case .built(let tower), .upgraded(let tower, _):
            tower
        }
    }
}

final class GameScene: SKScene {
    // MARK: Tuning

    private let cols = Level.cols
    private let rows = Level.rows
    /// The game runs edge to edge. These insets keep the bars' buttons clear of
    /// the Dynamic Island and the home indicator.
    private let topInset: CGFloat
    private let bottomInset: CGFloat
    private let topHeight: CGFloat
    private let bottomHeight: CGFloat

    let level: Level
    let difficulty: Difficulty
    /// Whether this run started in endless mode from the menu.
    let startedEndless: Bool
    /// Set when this run is today's daily challenge.
    let challenge: DailyChallenge?
    /// Waves never run out. Also switches on when you keep going after wave 50.
    private var endless: Bool
    /// Called when the player leaves for the main menu.
    var onExit: (() -> Void)?
    /// App Store screenshot scene to stage (Xcode builds only), or 0 for a normal game.
    var screenshot = 0

    // MARK: State

    private var grid: Grid
    private var cellSize: CGFloat = 40
    private var origin: CGPoint = .zero

    /// Board, towers, and dinos live here so the T-Rex can shake it all.
    private let world = SKNode()
    private var hud: HUD!

    private var towers: [Cell: Tower] = [:]
    private var dinos: [Dino] = []
    private var shots: [Shot] = []

    private var cash = 0 {
        didSet { hud?.setCash(cash) }
    }
    private var lives = 0 {
        didSet { hud?.setLives(lives) }
    }
    private var wavesStarted = 0
    private var waveActive = false
    private var waveClock: TimeInterval = 0
    private var spawnQueue: [(at: TimeInterval, kind: DinoKind)] = []
    private var tool: Tool? = .build(.fence)
    private var lastUpdate: TimeInterval = 0
    private var isOver = false
    private var screenScale: CGFloat = 3

    /// Live wires between neighboring fences, rebuilt when fences change.
    private let wireLayer = SKNode()
    /// Marching dots along the route dinos will take from the gate.
    private let pathLayer = SKNode()
    private var pathDot: SKTexture?
    /// Research Lab bonuses for this run (none in daily challenges).
    private var research = Research.Bonuses()
    /// Amber earned since this scene started, for the game over screen.
    private var amberThisRun: Double = 0
    /// A saved run to pick up when the scene first starts.
    private var pendingResume: SavedGame?
    /// Whether this run owns the save slot, so ending it clears the save.
    private var hasSaved = false
    /// Builds and upgrades since the last wave, newest last, for Undo.
    private var undoSteps: [UndoStep] = []
    /// Faint marks on squares where building would trap the dinos.
    private let hintLayer = SKNode()
    private var hintTexture: SKTexture?
    private var hintTimer: TimeInterval = 0
    /// How many dino steps each square has taken, and the dirt worn into it.
    private var wear: [Cell: Int] = [:]
    private var dirt: [Cell: SKSpriteNode] = [:]
    private var gateDoors: [(door: SKSpriteNode, closed: CGFloat, open: CGFloat)] = []
    private var chopper: SKNode?
    private var sparkTimer: TimeInterval = 1
    /// Whether this game has warned about flyers yet.
    private var warnedAboutFlyers = false
    /// 1x, 2x, or 3x, toggled with the wave button while a wave is running.
    private var gameSpeed = 1
    /// Where the chopper idles, so it can land again after a win.
    private var chopperHome: CGPoint = .zero
    /// Lives when the current wave started, and whether it had a T-Rex, for Untouchable.
    private var livesAtWaveStart = 0
    private var waveHadRex = false
    /// How many achievement pop-ups are showing, so they stack.
    private var activeToasts = 0
    /// The guided first game, when it's running.
    private var tutorial: Tutorial?
    /// Napalm patches burning on the ground.
    private var burns: [Burn] = []
    /// Numbers for the end of game screen.
    private var stats = GameStats()
    /// Night parks: the darkness overlay.
    private var darkness: SKSpriteNode?
    /// Whether this game has explained venom yet.
    private var warnedAboutSpit = false
    /// Whether this game has explained ankylosaurs and pachys yet.
    private var warnedAboutSmash = false
    private var warnedAboutHeadbutt = false
    /// Optional ad rewards: one revive per game, bonus cash every 5 waves.
    private var revivedThisGame = false
    private var lastAdBonusWave = -99

    /// Cash for watching an optional ad from the pause menu.
    private var adBonusCash: Int {
        40 + 8 * max(1, wavesStarted)
    }

    /// Offered between waves, every 5 waves, never in daily challenges.
    private var canWatchForCash: Bool {
        RewardedAds.shared.isAvailable && challenge == nil && !waveActive && !isOver
            && wavesStarted >= 5 && wavesStarted - lastAdBonusWave >= 5
    }
    /// The game over screen's double amber offer, once per game over.
    private var amberDoubled = false

    private func watchForCash() {
        guard canWatchForCash else { return }
        let bonus = adBonusCash
        RewardedAds.shared.show(.bonusCash) { [weak self] in
            guard let self else { return }
            self.cash += bonus
            self.lastAdBonusWave = self.wavesStarted
            Haptics.success()
            SoundBank.shared.play(.upgrade)
            self.hud.flash("Thanks for watching! +$\(bonus)")
            self.saveProgress()
        } onUnavailable: { [weak self] in
            self?.hud.flash("No ad ready yet. Try again in a moment")
        }
    }
    /// One chopper strafing run per wave.
    private var airstrikeReady = true
    /// Waiting for the player to pick where the strike goes.
    private var airstrikeArmed = false

    /// Waves to win: 50, or 20 for the daily challenge.
    private var waveGoal: Int {
        challenge == nil ? Waves.total : DailyChallenge.waves
    }
    /// Showing while the game is paused.
    private var pauseMenu: SKNode?
    /// Showing once the game is won or lost.
    private var gameOverOverlay: SKNode?
    /// Upgrade and sell panel for the tower you tapped.
    private var towerPanel: SKNode?
    private weak var selectedTower: Tower?
    private var selectedRing: SKShapeNode?
    /// A tower under the player's finger. Lifting opens its panel; moving drags it.
    private weak var pressedTower: Tower?
    private var pressPoint: CGPoint = .zero
    private var pressOpensPanel = true
    private var dragGhost: SKSpriteNode?
    private var dragMarker: SKShapeNode?
    private var dragCell: Cell?

    init(
        size: CGSize, level: Level, difficulty: Difficulty, endless: Bool = false,
        challenge: DailyChallenge? = nil, safeInsets: UIEdgeInsets = .zero, resume: SavedGame? = nil
    ) {
        pendingResume = resume
        topInset = safeInsets.top
        // The home indicator is hidden during play, so the build bar can sit partway into its space
        bottomInset = safeInsets.bottom * 0.5
        topHeight = topInset + 50 + HUD.stripHeight
        bottomHeight = bottomInset + 76
        self.level = level
        self.difficulty = difficulty
        self.challenge = challenge
        startedEndless = endless
        self.endless = endless
        grid = Grid(level: level)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        backgroundColor = Palette.bar
        screenScale = view.contentScaleFactor
        ParkArt.screenScale = screenScale
        startNewGame()
    }

    // MARK: - Setup

    private func startNewGame() {
        // Restarting throws away this run's save; a different park's save is left alone
        if hasSaved {
            SavedGame.clear()
            hasSaved = false
        }
        research = Research.bonuses(dailyChallenge: challenge != nil)
        Tower.rangeScale = research.rangeScale
        amberThisRun = 0
        removeAllChildren()
        world.removeAllChildren()
        world.removeAllActions()
        world.position = .zero
        addChild(world)

        grid = Grid(level: level)
        gameOverOverlay = nil
        warnedAboutFlyers = false
        towerPanel = nil
        selectedTower = nil
        selectedRing = nil
        towers = [:]
        dinos = []
        shots = []
        wavesStarted = 0
        waveActive = false
        spawnQueue = []
        isOver = false
        wear = [:]
        dirt = [:]
        gateDoors = []
        wireLayer.removeAllChildren()
        wireLayer.removeAllActions()
        hintLayer.removeAllChildren()
        pathLayer.removeAllChildren()
        undoSteps = []
        pressedTower = nil
        dragGhost = nil
        dragMarker = nil
        dragCell = nil
        pauseMenu = nil
        world.isPaused = false
        gameSpeed = 1
        world.speed = 1

        let available = size.height - topHeight - bottomHeight
        cellSize = floor(min(size.width / CGFloat(cols), available / CGFloat(rows)))
        origin = CGPoint(
            x: (size.width - cellSize * CGFloat(cols)) / 2,
            y: bottomHeight + (available - cellSize * CGFloat(rows)) / 2
        )
        drawBoard()

        // Bake every dino's walk cycle now so the first spawn doesn't hitch
        for kind in DinoKind.all {
            _ = DinoArt.bake(kind, cellSize: cellSize, screenScale: screenScale)
        }

        hud = HUD(size: size, topHeight: topHeight, bottomHeight: bottomHeight, topInset: topInset, bottomInset: bottomInset)
        addChild(hud)
        hud.setPrice(.fence, to: price(of: .fence))
        cash = Progress.testMode ? 9999 : (challenge?.startingCash ?? difficulty.startingCash) + research.startingCash
        lives = (challenge?.lives ?? difficulty.lives) + research.lives
        activeToasts = 0
        endless = startedEndless
        hud.setWave(0, of: endless ? nil : waveGoal)
        hud.setSendEnabled(true)
        tool = .build(.fence)
        hud.select(tool)
        burns = []
        stats = GameStats()
        warnedAboutSpit = false
        warnedAboutSmash = false
        warnedAboutHeadbutt = false
        revivedThisGame = false
        lastAdBonusWave = -99
        airstrikeReady = true
        airstrikeArmed = false
        updateAirstrikeButton()
        let resumed = pendingResume
        if let resumed {
            pendingResume = nil
            restore(resumed)
        }
        refreshBuildHints()
        refreshPath()
        updatePreview()
        tutorial = nil
        if resumed == nil, level.id == Level.all.first?.id, challenge == nil, !endless, !Tutorial.hasFinished {
            let guide = Tutorial(size: size, topY: size.height - topHeight) { [weak self] step in
                guard let self, let hud = self.hud else { return nil }
                switch step {
                case .fences: return hud.frame(for: .build(.fence))
                case .turret: return hud.frame(for: .build(.turret))
                case .send: return hud.sendButtonFrame
                default: return nil
                }
            }
            addChild(guide.node)
            tutorial = guide
        }
        #if DEBUG
        if screenshot > 0 {
            stageScreenshot()
        }
        #endif
        world.alpha = 0
        world.run(.fadeIn(withDuration: 0.4))
        hud.alpha = 0
        hud.run(.fadeIn(withDuration: 0.25))
        if resumed != nil {
            hud.flash("Welcome back. Wave \(wavesStarted) cleared, wave \(wavesStarted + 1) is next")
        } else if let challenge {
            hud.flash("Daily challenge: \(challenge.twist.title). \(challenge.twist.detail)")
        } else if endless {
            hud.flash("Endless \(level.name). How long can you hold the line?")
        } else {
            hud.flash("\(level.name) · \(difficulty.title). Build a maze, then tap Send Wave")
        }
    }

    private func drawBoard() {
        let boardSize = CGSize(width: cellSize * CGFloat(cols), height: cellSize * CGFloat(rows))
        let ground = SKSpriteNode(texture: ParkArt.ground(cols: cols, rows: rows, cell: cellSize, ash: level.ash), size: boardSize)
        ground.anchorPoint = .zero
        ground.position = origin
        world.addChild(ground)

        wireLayer.zPosition = 2.5
        world.addChild(wireLayer)
        hintLayer.zPosition = 2.4
        world.addChild(hintLayer)
        pathLayer.zPosition = 2.45
        world.addChild(pathLayer)
        wireLayer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.5),
            .fadeAlpha(to: 1, duration: 0.5)
        ])))

        buildTerrain()
        rebuildDarkness()
        buildGate()
        buildHelipad()
    }

    /// Boulders, river, and bridges for this park.
    private func buildTerrain() {
        let square = CGSize(width: cellSize, height: cellSize)
        for cell in level.water {
            let frames = (0..<3).map { ParkArt.water(cell: cellSize, frame: $0) }
            let water = SKSpriteNode(texture: frames[0], size: square)
            water.position = point(for: cell)
            water.zPosition = 0.3
            water.run(.repeatForever(.animate(with: frames, timePerFrame: 0.4)))
            world.addChild(water)
        }
        for cell in level.bridges {
            let bridge = SKSpriteNode(texture: ParkArt.bridge(cell: cellSize), size: square)
            bridge.position = point(for: cell)
            bridge.zPosition = 0.3
            world.addChild(bridge)
        }
        for cell in level.lava {
            let frames = (0..<3).map { ParkArt.lava(cell: cellSize, frame: $0) }
            let lava = SKSpriteNode(texture: frames[0], size: square)
            lava.position = point(for: cell)
            lava.zPosition = 0.3
            lava.run(.repeatForever(.animate(with: frames, timePerFrame: 0.35)))
            world.addChild(lava)
        }
        for cell in level.buildings {
            let variant = Int(ParkArt.hash(CGFloat(cell.col) + 1, CGFloat(cell.row) + 2) * 3)
            let roof = SKSpriteNode(texture: ParkArt.building(cell: cellSize, variant: variant), size: square)
            roof.position = point(for: cell)
            roof.zPosition = 2
            world.addChild(roof)
        }
        for cell in level.rocks {
            let variant = Int(ParkArt.hash(CGFloat(cell.col) + 3, CGFloat(cell.row)) * 3)
            let rock = SKSpriteNode(texture: ParkArt.boulder(cell: cellSize, variant: variant), size: square)
            rock.position = point(for: cell)
            rock.zPosition = 2
            world.addChild(rock)
        }
    }

    /// Steel paddock gate on the spawn square. Doors swing open while a wave is on.
    private func buildGate() {
        let gate = SKNode()
        gate.position = point(for: grid.spawn)
        gate.zPosition = 2
        world.addChild(gate)
        let c = cellSize
        gate.addChild(SKSpriteNode(texture: ParkArt.gateBase(cell: c), size: CGSize(width: c, height: c)))

        let doorSize = CGSize(width: c * ParkArt.doorLength, height: c * 0.12)
        let hinges: [(x: CGFloat, closed: CGFloat, open: CGFloat)] = [
            (-c * 0.33, 0, -1.35),
            (c * 0.33, .pi, .pi + 1.35)
        ]
        for hinge in hinges {
            let door = SKSpriteNode(texture: ParkArt.gateDoor(cell: c), size: doorSize)
            door.anchorPoint = CGPoint(x: 0, y: 0.5)
            door.position = CGPoint(x: hinge.x, y: c * 0.3)
            door.zRotation = hinge.closed
            door.zPosition = 1
            gate.addChild(door)
            gateDoors.append((door, hinge.closed, hinge.open))
        }

        let red = UIColor(hex: 0xFF5A3A)
        let dim = UIColor(hex: 0x7A2418)
        let on = ParkArt.light(cell: c, color: red, dim: dim, on: true, radius: 0.055)
        let off = ParkArt.light(cell: c, color: red, dim: dim, on: false, radius: 0.055)
        let lightSize = CGSize(width: c * 0.055 * 4.6, height: c * 0.055 * 4.6)
        for (i, x) in [-c * 0.42, c * 0.42].enumerated() {
            let light = SKSpriteNode(texture: off, size: lightSize)
            light.position = CGPoint(x: x, y: c * 0.3)
            light.zPosition = 2
            gate.addChild(light)
            let blink = SKAction.repeatForever(.animate(with: i == 0 ? [on, off] : [off, on], timePerFrame: 0.4))
            light.run(blink)
        }
    }

    private func setGate(open: Bool) {
        for (door, closed, opened) in gateDoors {
            door.removeAllActions()
            let action = SKAction.rotate(toAngle: open ? opened : closed, duration: 0.5, shortestUnitArc: true)
            action.timingMode = .easeInEaseOut
            door.run(action)
        }
    }

    /// Helipad on the exit square with the rescue chopper idling on it.
    private func buildHelipad() {
        let c = cellSize
        let pad = SKSpriteNode(texture: ParkArt.helipad(cell: c), size: CGSize(width: c, height: c))
        pad.position = point(for: grid.exit)
        pad.zPosition = 1
        world.addChild(pad)

        let green = UIColor(hex: 0x7DFF8A)
        let dim = UIColor(hex: 0x2C5A31)
        let on = ParkArt.light(cell: c, color: green, dim: dim, on: true, radius: 0.045)
        let off = ParkArt.light(cell: c, color: green, dim: dim, on: false, radius: 0.045)
        let lightSize = CGSize(width: c * 0.045 * 4.6, height: c * 0.045 * 4.6)
        let corners: [(CGFloat, CGFloat)] = [(-0.36, 0.36), (0.36, 0.36), (0.36, -0.36), (-0.36, -0.36)]
        for (i, corner) in corners.enumerated() {
            let light = SKSpriteNode(texture: off, size: lightSize)
            light.position = CGPoint(x: corner.0 * c, y: corner.1 * c)
            light.zPosition = 1
            pad.addChild(light)
            var frames = [off, off, off, off]
            frames[i] = on
            light.run(.repeatForever(.animate(with: frames, timePerFrame: 0.25)))
        }

        let s = c * 1.15
        let heli = SKNode()
        heli.position = CGPoint(x: pad.position.x, y: pad.position.y + c * 0.05)
        heli.zPosition = 9
        heli.zRotation = .pi / 2
        chopperHome = heli.position
        world.addChild(heli)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: s * 0.66, height: s * 0.38))
        shadow.fillColor = SKColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: -s * 0.08, y: -s * 0.06)
        heli.addChild(shadow)
        heli.addChild(SKSpriteNode(texture: ParkArt.chopperBody(size: s), size: CGSize(width: s * 1.4, height: s * 0.5)))

        let tail = SKSpriteNode(texture: ParkArt.tailRotor(size: s), size: CGSize(width: s * 0.18, height: s * 0.18))
        tail.position = CGPoint(x: -s * 0.62, y: -s * 0.12)
        tail.zPosition = 1
        tail.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.15)))
        heli.addChild(tail)

        let rotor = SKSpriteNode(texture: ParkArt.rotor(size: s), size: CGSize(width: s * 1.16, height: s * 1.16))
        rotor.zPosition = 2
        rotor.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.28)))
        heli.addChild(rotor)
        chopper = heli
    }

    /// Connects every pair of neighboring fences with live wire.
    private func rebuildWires() {
        wireLayer.removeAllChildren()
        let fences = Set(towers.values.filter { $0.kind == .fence }.map { $0.cell })
        let wireTexture = ParkArt.wire(cell: cellSize)
        let wireSize = ParkArt.wireSize(cell: cellSize)
        let signTexture = ParkArt.warningSign(cell: cellSize)
        for cell in fences {
            for (dc, dr) in [(1, 0), (0, 1)] {
                let other = Cell(col: cell.col + dc, row: cell.row + dr)
                guard fences.contains(other) else { continue }
                let a = point(for: cell)
                let b = point(for: other)
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let wire = SKSpriteNode(texture: wireTexture, size: wireSize)
                wire.position = mid
                wire.zRotation = dc == 1 ? 0 : .pi / 2
                wireLayer.addChild(wire)
                if ParkArt.hash(CGFloat(cell.col * 13 + dc), CGFloat(cell.row * 7 + dr)) > 0.55 {
                    let sign = SKSpriteNode(texture: signTexture, size: CGSize(width: cellSize * 0.34, height: cellSize * 0.34))
                    sign.position = mid
                    sign.zPosition = 0.1
                    wireLayer.addChild(sign)
                }
            }
        }
    }

    /// Dinos wear a dirt trail into the grass as they run the maze.
    private func addWear(at cell: Cell) {
        guard cell != grid.spawn, cell != grid.exit, !grid.water.contains(cell) else { return }
        let count = (wear[cell] ?? 0) + 1
        wear[cell] = count
        let patch: SKSpriteNode
        if let existing = dirt[cell] {
            patch = existing
        } else {
            let variant = Int(ParkArt.hash(CGFloat(cell.col), CGFloat(cell.row)) * 4)
            patch = SKSpriteNode(texture: ParkArt.dirt(cell: cellSize, variant: variant), size: CGSize(width: cellSize, height: cellSize))
            patch.position = point(for: cell)
            patch.zPosition = 0.5
            patch.alpha = 0
            world.addChild(patch)
            dirt[cell] = patch
        }
        patch.alpha = min(0.85, 0.1 + CGFloat(count) * 0.02)
    }

    // MARK: - Grid math

    private func point(for cell: Cell) -> CGPoint {
        CGPoint(
            x: origin.x + (CGFloat(cell.col) + 0.5) * cellSize,
            y: origin.y + (CGFloat(cell.row) + 0.5) * cellSize
        )
    }

    private func cell(at point: CGPoint) -> Cell? {
        let cell = Cell(
            col: Int(floor((point.x - origin.x) / cellSize)),
            row: Int(floor((point.y - origin.y) / cellSize))
        )
        return grid.contains(cell) ? cell : nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard dragGhost == nil else { return }
        pressedTower = nil
        if let overlay = gameOverOverlay {
            let hits = overlay.nodes(at: touch.location(in: overlay)).compactMap { $0.name }
            if hits.contains("endless") {
                keepGoing()
            } else if hits.contains("revive") {
                RewardedAds.shared.show(.revive) { [weak self] in
                    self?.revive()
                } onUnavailable: { [weak overlay] in
                    (overlay?.childNode(withName: "//reviveLabel") as? SKLabelNode)?.text = "No ad ready, try again"
                }
            } else if hits.contains("amber"), !amberDoubled {
                let bonus = amberThisRun
                RewardedAds.shared.show(.doubleAmber) { [weak self, weak overlay] in
                    guard let self else { return }
                    self.amberDoubled = true
                    Research.earn(bonus)
                    self.amberThisRun += bonus
                    Haptics.success()
                    SoundBank.shared.play(.upgrade)
                    (overlay?.childNode(withName: "//amberLabel") as? SKLabelNode)?.text = "Amber doubled! +\(Int(bonus)) more"
                } onUnavailable: { [weak overlay] in
                    (overlay?.childNode(withName: "//amberLabel") as? SKLabelNode)?.text = "No ad ready, try again"
                }
            } else if hits.contains("restart") {
                startNewGame()
            } else if hits.contains("menu") {
                onExit?()
            }
            return
        }
        if let menu = pauseMenu {
            let hits = menu.nodes(at: touch.location(in: menu)).compactMap { $0.name }
            if hits.contains("restart") {
                startNewGame()
            } else if hits.contains("resume") {
                closePauseMenu()
            } else if hits.contains("menu") {
                onExit?()
            }
            return
        }
        if let tutorial, tutorial.handleTap(at: touch.location(in: self)) {
            return
        }
        if airstrikeArmed {
            let point = touch.location(in: world)
            if point.y > origin.y && point.y < origin.y + cellSize * CGFloat(rows) {
                launchAirstrike(atY: point.y)
                return
            }
        }
        if let panel = towerPanel {
            let hits = panel.nodes(at: touch.location(in: panel)).compactMap { $0.name }
            if hits.contains("target"), let tower = selectedTower {
                tower.targeting = tower.targeting.next
                Haptics.tap()
                showPanel(for: tower)
                return
            }
            if hits.contains("ability"), let tower = selectedTower {
                useAbility(tower)
                showPanel(for: tower)
                return
            }
            if hits.contains("upgrade"), let tower = selectedTower {
                if tower.needsBranch {
                    showBranchChoice(for: tower)
                } else {
                    upgrade(tower)
                    showPanel(for: tower)
                }
                return
            }
            if let picked = hits.first(where: { $0.hasPrefix("pick-") }),
               let branch = TowerBranch(rawValue: String(picked.dropFirst(5))), let tower = selectedTower {
                upgrade(tower, branch: branch)
                showPanel(for: tower)
                return
            }
            if hits.contains("sell"), let tower = selectedTower {
                closePanel()
                sell(tower)
                return
            }
            if hits.contains("panel") {
                return
            }
            let previous = selectedTower?.cell
            closePanel()
            if let tapped = cell(at: touch.location(in: world)), tapped == previous {
                // Tapping the open tower closes its panel, but it can still be dragged
                pressedTower = towers[tapped]
                pressPoint = touch.location(in: world)
                pressOpensPanel = false
                return
            }
        }
        if let action = hud.action(at: touch.location(in: self)) {
            switch action {
            case .pause:
                openPauseMenu()
            case .sendWave:
                if waveActive {
                    cycleSpeed()
                } else {
                    sendWave()
                }
            case .pick(let picked):
                tool = picked
                hud.select(tool)
            case .airstrike:
                toggleAirstrike()
            case .undo:
                undo()
            case .adCash:
                watchForCash()
            }
            return
        }
        if let tapped = cell(at: touch.location(in: world)) {
            if let tower = towers[tapped], tool != .sell {
                // Decide on lift: a tap opens the panel, a drag moves the tower
                pressedTower = tower
                pressPoint = touch.location(in: world)
                pressOpensPanel = true
                return
            }
            tap(tapped)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tower = pressedTower, !isOver, pauseMenu == nil else { return }
        let location = touch.location(in: world)
        if dragGhost == nil {
            guard distance(location, pressPoint) > cellSize * 0.35 else { return }
            startDrag(tower)
        }
        updateDrag(tower, to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tower = pressedTower else { return }
        pressedTower = nil
        if dragGhost != nil {
            finishDrag(tower, at: touches.first.flatMap { cell(at: $0.location(in: world)) })
        } else if pressOpensPanel, !isOver, towers[tower.cell] === tower {
            tap(tower.cell)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tower = pressedTower else { return }
        pressedTower = nil
        if dragGhost != nil {
            finishDrag(tower, at: nil)
        }
    }

    private func tap(_ cell: Cell) {
        if let tower = towers[cell] {
            if tool == .sell {
                sell(tower)
            } else {
                showPanel(for: tower)
            }
            return
        }

        if tool == .build(.fence), challenge?.allowsFences == false {
            refuse(cell, "No fences", detail: "No fences today. Build your maze from towers")
            return
        }
        guard case .build(let kind)? = tool else {
            hud.flash("Pick something to build")
            return
        }
        if let problem = siteProblem(at: cell) {
            refuse(cell, problem.short, detail: problem.detail)
            return
        }
        let cost = price(of: kind)
        guard cash >= cost else {
            refuse(cell, "Need $\(cost)", detail: "\(kind.title) costs $\(cost). You have $\(cash)")
            return
        }
        let (walkers, swimmers) = dinoCells()
        guard grid.block(cell, keeping: walkers, keepingSwimmers: swimmers) else {
            refuse(cell, "Blocks the path", detail: "That would trap the dinos. They need a way through!")
            return
        }

        cash -= cost
        SoundBank.shared.play(.place)
        Haptics.tap()
        let tower = Tower(kind: kind, cell: cell, cellSize: cellSize, paid: cost)
        tower.position = point(for: cell)
        tower.setScale(0.6)
        tower.run(.scale(to: 1, duration: 0.12))
        world.addChild(tower)
        towers[cell] = tower
        if !waveActive {
            undoSteps.append(.built(tower))
        }
        if kind == .fence {
            rebuildWires()
            let fenceCount = towers.values.filter({ $0.kind == .fence }).count
            if fenceCount >= 40 {
                award(.mazeMaster)
            }
            tutorial?.handle(.fenceBuilt(total: fenceCount))
        } else {
            tutorial?.handle(.towerBuilt)
            showRange(of: tower)
            hud.flash("Tap a tower to upgrade it, or drag it to move it")
        }
        rebuildDarkness()
        refreshBuildHints()
        refreshPath()
        saveProgress()
    }

    /// What a piece costs after research.
    private func price(of kind: BuildKind) -> Int {
        kind == .fence ? max(2, kind.cost - research.fenceDiscount) : kind.cost
    }

    /// Why a square can't be built on, money and the dinos' path aside.
    private func siteProblem(at cell: Cell) -> (short: String, detail: String)? {
        if towers[cell] != nil {
            return ("Taken", "Something is already built there")
        }
        if grid.terrain.contains(cell) {
            if level.water.contains(cell) {
                return ("River", "Can't build in the river")
            } else if level.lava.contains(cell) {
                return ("Lava", "Can't build on lava")
            } else if level.buildings.contains(cell) {
                return ("Building", "Can't build on a building")
            }
            return ("Boulder", "Can't build on a boulder")
        }
        if cell == grid.spawn || cell == grid.exit {
            return ("Keep clear", "The gate and the helipad have to stay open")
        }
        let (walkers, swimmers) = dinoCells()
        if (walkers + swimmers).contains(cell) {
            return ("Dino in the way", "Too close to a dino")
        }
        return nil
    }

    /// Squares dinos on the ground are standing on or heading to, which must stay reachable.
    private func dinoCells() -> (walkers: [Cell], swimmers: [Cell]) {
        let walkers = dinos.filter { !$0.kind.flies && !$0.kind.swims }.flatMap { [$0.cell, $0.target] }
        let swimmers = dinos.filter { $0.kind.swims }.flatMap { [$0.cell, $0.target] }
        return (walkers, swimmers)
    }

    /// Flashes a red X on the square and says why right there on the board.
    private func refuse(_ cell: Cell, _ reason: String, detail: String) {
        Haptics.failure()
        hud.flash(detail)
        let center = point(for: cell)

        let mark = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4), cornerRadius: 6)
        mark.fillColor = Palette.danger.withAlphaComponent(0.35)
        mark.strokeColor = Palette.danger
        mark.lineWidth = 2
        mark.position = center
        mark.zPosition = 19
        let reach = cellSize * 0.2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -reach, y: -reach))
        path.addLine(to: CGPoint(x: reach, y: reach))
        path.move(to: CGPoint(x: -reach, y: reach))
        path.addLine(to: CGPoint(x: reach, y: -reach))
        let cross = SKShapeNode(path: path)
        cross.strokeColor = Palette.text
        cross.lineWidth = 3
        cross.lineCap = .round
        mark.addChild(cross)
        world.addChild(mark)
        mark.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.35, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)]), count: 2),
            .wait(forDuration: 0.4),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))

        let label = makeLabel(reason, size: 13, font: Fonts.heavy)
        let tag = SKShapeNode(rectOf: CGSize(width: label.frame.width + 16, height: 24), cornerRadius: 12)
        tag.fillColor = Palette.danger
        tag.strokeColor = Palette.bar
        tag.lineWidth = 1.5
        tag.addChild(label)
        tag.zPosition = 21
        // Keep the tag on the board, above the square unless that's off the top
        let half = tag.frame.width / 2 + 4
        let boardTop = origin.y + cellSize * CGFloat(rows)
        let y = center.y + cellSize * 0.8 > boardTop - 12 ? center.y - cellSize * 0.8 : center.y + cellSize * 0.8
        tag.position = CGPoint(x: min(max(center.x, origin.x + half), origin.x + cellSize * CGFloat(cols) - half), y: y)
        world.addChild(tag)
        tag.setScale(0.6)
        tag.run(.sequence([
            .scale(to: 1, duration: 0.1),
            .wait(forDuration: 1.1),
            .group([.moveBy(x: 0, y: cellSize * 0.3, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent()
        ]))
    }

    /// Marks every open square where a build would seal the dinos in.
    private func refreshBuildHints() {
        hintLayer.removeAllChildren()
        guard !isOver else { return }
        if hintTexture == nil {
            let size = CGSize(width: cellSize, height: cellSize)
            hintTexture = SKTexture(image: UIGraphicsImageRenderer(size: size).image { context in
                let gc = context.cgContext
                let inset = CGRect(origin: .zero, size: size).insetBy(dx: cellSize * 0.32, dy: cellSize * 0.32)
                gc.setStrokeColor(Palette.danger.withAlphaComponent(0.75).cgColor)
                gc.setLineWidth(max(2, cellSize * 0.07))
                gc.setLineCap(.round)
                gc.move(to: CGPoint(x: inset.minX, y: inset.minY))
                gc.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                gc.move(to: CGPoint(x: inset.minX, y: inset.maxY))
                gc.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
                gc.strokePath()
            })
        }
        let (walkers, swimmers) = dinoCells()
        let occupied = Set(walkers + swimmers)
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = Cell(col: col, row: row)
                guard !grid.blocked.contains(cell), cell != grid.spawn, cell != grid.exit, !occupied.contains(cell),
                      !grid.canBlock(cell, keeping: walkers, keepingSwimmers: swimmers) else { continue }
                let mark = SKSpriteNode(texture: hintTexture, size: CGSize(width: cellSize, height: cellSize))
                mark.position = point(for: cell)
                mark.alpha = 0.7
                hintLayer.addChild(mark)
            }
        }
    }

    /// Dotted route from the gate to the helipad, so you can see your maze working.
    private func refreshPath() {
        pathLayer.removeAllChildren()
        guard !isOver else { return }
        if pathDot == nil {
            let side = max(4, cellSize * 0.16)
            pathDot = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
                context.cgContext.setFillColor(Palette.warning.cgColor)
                context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            })
        }
        var route = [grid.spawn]
        var here = grid.spawn
        while let next = grid.nextStep(from: here), route.count <= cols * rows {
            route.append(next)
            here = next
        }
        let dotSize = pathDot?.size() ?? .zero
        let period: TimeInterval = 1.2
        var index = 0
        for (a, b) in zip(route, route.dropFirst()) {
            let from = point(for: a)
            let to = point(for: b)
            for step in 0..<3 where !(a == grid.spawn && step == 0) {
                let f = CGFloat(step) / 3
                let dot = SKSpriteNode(texture: pathDot, size: dotSize)
                dot.position = CGPoint(x: from.x + (to.x - from.x) * f, y: from.y + (to.y - from.y) * f)
                dot.alpha = 0.25
                // Each dot lights a moment after the one before, so the line marches toward the helipad
                let delay = (Double(index) * 0.05).truncatingRemainder(dividingBy: period)
                dot.run(.sequence([
                    .wait(forDuration: delay),
                    .repeatForever(.sequence([
                        .fadeAlpha(to: 0.9, duration: 0.15),
                        .fadeAlpha(to: 0.25, duration: 0.45),
                        .wait(forDuration: period - 0.6)
                    ]))
                ]))
                pathLayer.addChild(dot)
                index += 1
            }
        }
        pathLayer.alpha = waveActive ? 0.5 : 1
    }

    /// Shows the next wave's dinos in the strip under the top bar.
    private func updatePreview() {
        let next = wavesStarted + 1
        guard endless || next <= waveGoal else {
            hud.setPreview(title: "LAST WAVE", items: [])
            return
        }
        var counts: [(kind: DinoKind, count: Int)] = []
        for group in Waves.groups(forWave: next, flyerHeavy: flyerHeavy) {
            if let i = counts.firstIndex(where: { $0.kind == group.kind }) {
                counts[i].count += group.count
            } else {
                counts.append((group.kind, group.count))
            }
        }
        let items = counts.compactMap { entry -> WavePreviewItem? in
            guard let frame = DinoArt.bake(entry.kind, cellSize: cellSize, screenScale: screenScale).frames.first else { return nil }
            return WavePreviewItem(texture: frame, count: entry.count)
        }
        hud.setPreview(title: waveActive ? "NEXT · \(next)" : "WAVE \(next)", items: items)
    }

    private var flyerHeavy: Bool {
        level.flyerHeavy || challenge?.flyerHeavy == true
    }

    // MARK: - Save and resume

    /// Saves the run between waves. Mid-wave quits resume from the last save.
    private func saveProgress() {
        guard challenge == nil, !isOver, !waveActive, wavesStarted > 0 else { return }
        let saved = SavedGame(
            levelId: level.id,
            difficulty: difficulty.rawValue,
            endless: endless,
            startedEndless: startedEndless,
            wave: wavesStarted,
            cash: cash,
            lives: lives,
            towers: towers.values.map {
                SavedGame.SavedTower(
                    kind: "\($0.kind)", col: $0.cell.col, row: $0.cell.row,
                    level: $0.level, targeting: "\($0.targeting)", branch: $0.branch?.rawValue
                )
            },
            kills: stats.kills,
            damage: stats.damage.mapValues { Double($0) },
            playTime: stats.playTime,
            revived: revivedThisGame,
            lastAdBonusWave: lastAdBonusWave
        )
        saved.store()
        hasSaved = true
    }

    private func restore(_ save: SavedGame) {
        hasSaved = true
        endless = save.endless
        wavesStarted = save.wave
        cash = save.cash
        lives = save.lives
        revivedThisGame = save.revived
        lastAdBonusWave = save.lastAdBonusWave
        stats.kills = save.kills
        stats.damage = save.damage.mapValues { CGFloat($0) }
        stats.playTime = save.playTime
        warnedAboutFlyers = save.wave >= 11
        warnedAboutSpit = save.wave >= 19
        for saved in save.towers {
            guard let kind = BuildKind.allCases.first(where: { "\($0)" == saved.kind }) else { continue }
            let cell = Cell(col: saved.col, row: saved.row)
            guard towers[cell] == nil, grid.block(cell, keeping: []) else { continue }
            let tower = Tower(kind: kind, cell: cell, cellSize: cellSize)
            tower.position = point(for: cell)
            while tower.level < saved.level, tower.upgradeCost != nil {
                tower.upgrade(branch: saved.branch.flatMap { TowerBranch(rawValue: $0) })
            }
            tower.targeting = Targeting.allCases.first { "\($0)" == saved.targeting } ?? .first
            world.addChild(tower)
            towers[cell] = tower
        }
        rebuildWires()
        rebuildDarkness()
        hud.setWave(wavesStarted, of: endless ? nil : waveGoal)
    }

    /// Takes back the last build or upgrade since the wave ended, for a full refund.
    private func undo() {
        guard !waveActive, let step = undoSteps.popLast() else {
            hud.flash("Nothing to undo. Undo works on builds and upgrades since the last wave")
            return
        }
        closePanel()
        let tower = step.tower
        guard towers[tower.cell] === tower else { return }
        switch step {
        case .built:
            cash += tower.invested
            floatText("+$\(tower.invested)", at: tower.position)
            undoSteps.removeAll { $0.tower === tower }
            removeTower(tower)
        case .upgraded(_, let cost):
            tower.downgrade(refunding: cost)
            cash += cost
            floatText("+$\(cost)", at: tower.position)
            saveProgress()
        }
        SoundBank.shared.play(.sell)
        Haptics.tap()
    }

    // MARK: - Moving towers

    private func startDrag(_ tower: Tower) {
        closePanel()
        guard let texture = view?.texture(from: tower) else { return }
        let ghost = SKSpriteNode(texture: texture)
        ghost.alpha = 0.85
        ghost.setScale(1.15)
        ghost.zPosition = 30
        world.addChild(ghost)
        dragGhost = ghost

        let marker = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 6)
        marker.lineWidth = 2.5
        marker.zPosition = 29
        world.addChild(marker)
        dragMarker = marker
        dragCell = nil
        tower.alpha = 0.35
        Haptics.tap()
        if tower.kind != .fence {
            // The range travels with the ghost, so you can see what it will cover
            let ring = SKShapeNode(circleOfRadius: tower.range * cellSize / ghost.xScale)
            ring.strokeColor = SKColor(white: 1, alpha: 0.5)
            ring.fillColor = SKColor(white: 1, alpha: 0.06)
            ring.zPosition = -1
            ghost.addChild(ring)
        }
    }

    private func updateDrag(_ tower: Tower, to location: CGPoint) {
        dragGhost?.position = location
        guard let marker = dragMarker else { return }
        let target = cell(at: location)
        marker.isHidden = target == nil
        guard let target, target != dragCell else { return }
        dragCell = target
        marker.position = point(for: target)
        let ok = target == tower.cell || moveProblem(tower, to: target) == nil
        marker.strokeColor = ok ? SKColor(red: 0.45, green: 0.9, blue: 0.4, alpha: 1) : Palette.danger
        marker.fillColor = (ok ? SKColor(red: 0.45, green: 0.9, blue: 0.4, alpha: 1) : Palette.danger).withAlphaComponent(0.25)
        if target != tower.cell {
            Haptics.tap()
        }
    }

    private func moveProblem(_ tower: Tower, to cell: Cell) -> (short: String, detail: String)? {
        if let problem = siteProblem(at: cell) {
            return problem
        }
        let (walkers, swimmers) = dinoCells()
        if !grid.canMove(from: tower.cell, to: cell, keeping: walkers, keepingSwimmers: swimmers) {
            return ("Blocks the path", "That would trap the dinos. They need a way through!")
        }
        return nil
    }

    private func finishDrag(_ tower: Tower, at target: Cell?) {
        dragGhost?.removeFromParent()
        dragMarker?.removeFromParent()
        dragGhost = nil
        dragMarker = nil
        dragCell = nil
        tower.alpha = 1
        guard !isOver, towers[tower.cell] === tower, let target, target != tower.cell else { return }
        if let problem = moveProblem(tower, to: target) {
            refuse(target, problem.short, detail: problem.detail)
            return
        }
        let (walkers, swimmers) = dinoCells()
        guard grid.move(from: tower.cell, to: target, keeping: walkers, keepingSwimmers: swimmers) else { return }
        towers[tower.cell] = nil
        towers[target] = tower
        tower.cell = target
        tower.position = point(for: target)
        // A moved tower takes a second to set up before it fires again
        tower.cooldown = max(tower.cooldown, 1)
        tower.setScale(0.8)
        tower.run(.scale(to: 1, duration: 0.12))
        SoundBank.shared.play(.place)
        Haptics.tap()
        if tower.kind == .fence {
            rebuildWires()
        } else {
            showRange(of: tower)
        }
        rebuildDarkness()
        refreshBuildHints()
        refreshPath()
        saveProgress()
    }

    private func upgrade(_ tower: Tower, branch: TowerBranch? = nil) {
        guard let cost = tower.upgradeCost else {
            hud.flash(tower.kind == .fence ? "Fences can't be upgraded" : "Already max level")
            return
        }
        guard cash >= cost else {
            hud.flash("Upgrade costs $\(cost)")
            return
        }
        cash -= cost
        tower.upgrade(branch: branch)
        if !waveActive {
            undoSteps.append(.upgraded(tower, cost: cost))
        }
        saveProgress()
        SoundBank.shared.play(.upgrade)
        Haptics.punch()
        tutorial?.handle(.upgraded)
        hud.flash("\(tower.title) level \(tower.level)")
        if tower.level == Tower.maxLevel {
            award(.fullyLoaded)
        }
        showRange(of: tower)
    }

    private func sell(_ tower: Tower) {
        SoundBank.shared.play(.sell)
        Haptics.tap()
        cash += tower.sellValue
        floatText("+$\(tower.sellValue)", at: tower.position)
        undoSteps.removeAll { $0.tower === tower }
        removeTower(tower)
    }

    private func removeTower(_ tower: Tower) {
        towers[tower.cell] = nil
        grid.unblock(tower.cell)
        tower.removeFromParent()
        if tower.kind == .fence {
            rebuildWires()
        }
        rebuildDarkness()
        refreshBuildHints()
        refreshPath()
        saveProgress()
    }

    // MARK: - Waves

    private func sendWave() {
        guard !waveActive, !isOver, endless || wavesStarted < waveGoal else { return }
        let wave = Waves.groups(forWave: wavesStarted + 1, flyerHeavy: flyerHeavy)
        livesAtWaveStart = lives
        waveHadRex = false
        wavesStarted += 1
        spawnQueue = Waves.schedule(wave)
        waveClock = 0
        waveActive = true
        undoSteps = []
        pathLayer.alpha = 0.5
        updatePreview()
        hud.setWave(wavesStarted, of: endless ? nil : waveGoal)
        hud.setSpeed(gameSpeed)
        setGate(open: true)
        SoundBank.shared.play(.alarm)
        tutorial?.handle(.waveStarted)
        if wave.contains(where: { $0.kind == .rex }) {
            banner("BOSS WAVE \(wavesStarted)", subtitle: "Something big is coming", color: Palette.danger)
        } else {
            banner("WAVE \(wavesStarted)", subtitle: nil)
        }
        if wave.contains(where: { $0.kind.flies }) {
            hud.flash("Wave \(wavesStarted): pterodactyls incoming! Flak hits them hardest")
            SoundBank.shared.play(.screech)
        } else {
            hud.flash("Wave \(wavesStarted): \(Waves.summary(wave))")
        }
    }

    private func cycleSpeed() {
        gameSpeed = gameSpeed % 3 + 1
        world.speed = CGFloat(gameSpeed)
        hud.setSpeed(gameSpeed)
    }

    private func spawnDue(_ dt: TimeInterval) {
        guard waveActive else { return }
        waveClock += dt
        while let next = spawnQueue.first, next.at <= waveClock {
            spawnQueue.removeFirst()
            spawn(next.kind)
        }
    }

    private func spawn(_ kind: DinoKind) {
        let dino = Dino(
            kind: kind,
            healthScale: Waves.healthScale(forWave: wavesStarted - 1) * difficulty.health * (challenge?.healthScale ?? 1),
            cell: grid.spawn,
            cellSize: cellSize,
            screenScale: screenScale
        )
        dino.target = grid.nextStep(from: grid.spawn, swims: kind.swims) ?? grid.spawn
        dino.position = point(for: grid.spawn)
        // Late waves move a little faster, so a long maze buys less time
        let lateWaveSpeed = 1 + 0.004 * CGFloat(min(max(wavesStarted - 1, 0), 60))
        dino.speedScale = (challenge?.speedScale ?? 1) * lateWaveSpeed
        if kind == .rex {
            waveHadRex = true
        }
        world.addChild(dino)
        dinos.append(dino)

        if kind.flies {
            dino.flight = Flight(start: point(for: grid.spawn), end: point(for: grid.exit), weave: Bool.random() ? 1 : -1)
            SoundBank.shared.play(.screech)
            if !warnedAboutFlyers {
                warnedAboutFlyers = true
                hud.flash("Pterodactyls fly over fences. Turrets and tranqs do half damage; Flak does full")
            }
        }

        if kind == .rex {
            hud.flash("🦖 The ground is shaking...")
            shakeWorld()
            SoundBank.shared.play(.roar)
            Haptics.stomp()
        }
    }

    private func checkWaveEnd() {
        guard waveActive, spawnQueue.isEmpty, dinos.isEmpty else { return }
        waveActive = false
        setGate(open: false)
        if let challenge {
            challenge.record(wave: wavesStarted)
            GameCenter.submitDaily(wave: wavesStarted)
        } else {
            if wavesStarted <= Waves.total {
                Progress.record(wave: wavesStarted, level: level, difficulty: difficulty)
            }
            if endless {
                Progress.recordEndless(wave: wavesStarted, level: level, difficulty: difficulty)
                GameCenter.submitEndless(wave: wavesStarted, level: level)
            }
            if wavesStarted >= 10 {
                award(.holdingTheLine)
            }
            if endless && wavesStarted >= 75 {
                award(.neverOff)
            }
        }
        if waveHadRex && lives == livesAtWaveStart {
            award(.untouchable)
        }
        if gameSpeed == 3 {
            award(.fastForward)
        }
        let bonus = 5 + min(wavesStarted, Waves.total)
        // 5% interest on cash you saved, up to $50, rewards banking for a big upgrade
        let interest = min(50 + research.interestCapBonus, cash / 20)
        // Perfect wave: nothing reached the helipad
        let perfect = lives == livesAtWaveStart
        let perfectBonus = perfect ? 5 + wavesStarted / 2 : 0
        cash += bonus + interest + perfectBonus
        if !Progress.testMode {
            Research.earn(Research.amberPerWave(difficulty))
            amberThisRun += Research.amberPerWave(difficulty)
        }
        if endless || wavesStarted < waveGoal {
            saveProgress()
        }
        airstrikeReady = true
        updateAirstrikeButton()
        refreshBuildHints()
        pathLayer.alpha = 1
        updatePreview()
        tutorial?.handle(.waveCleared)
        if !endless && wavesStarted == waveGoal {
            endGame(won: true)
        } else {
            hud.setSendEnabled(true)
            hud.flash(interest > 0 ? "Wave cleared! +$\(bonus), +$\(interest) interest" : "Wave cleared! +$\(bonus)")
            if perfect {
                banner("PERFECT WAVE", subtitle: "Nothing got through · +$\(perfectBonus)")
                Haptics.success()
            } else {
                banner("WAVE \(wavesStarted) CLEARED", subtitle: "+$\(bonus + interest)", color: Palette.text)
            }
        }
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard !isOver, pauseMenu == nil, dt > 0 else { return }
        stats.playTime += dt
        hud.setRemaining(waveActive ? spawnQueue.count + dinos.count : nil, canUndo: !undoSteps.isEmpty)
        hud.setAdOffer(cash: canWatchForCash ? adBonusCash : nil)
        let rexes = dinos.filter { $0.kind == .rex && !$0.isDead }
        if rexes.isEmpty {
            hud.setBoss(health: nil, count: 0)
        } else {
            let left = rexes.reduce(CGFloat(0)) { $0 + $1.health }
            let full = rexes.reduce(CGFloat(0)) { $0 + $1.maxHealth }
            hud.setBoss(health: left / max(1, full), count: rexes.count)
        }
        if waveActive {
            hintTimer -= dt
            if hintTimer <= 0 {
                hintTimer = 0.4
                refreshBuildHints()
            }
        }

        // Faster speeds run extra steps so nothing skips past a tower
        for _ in 0..<gameSpeed where !isOver {
            spawnDue(dt)
            moveDinos(dt)
            fireTowers(dt)
            moveShots(dt)
            burnGround(dt)
            sparkFences(dt)
            spitVenom(dt)
            dinoTricks(dt)
            checkWaveEnd()
        }
    }

    private func moveDinos(_ dt: TimeInterval) {
        var escaped: [Dino] = []
        for dino in dinos {
            dino.tick(dt)
            if dino.flight != nil {
                if fly(dino, dt) {
                    escaped.append(dino)
                }
                continue
            }
            var budget = dino.currentSpeed * cellSize * CGFloat(dt)
            while budget > 0 {
                let dest = point(for: dino.target)
                let dx = dest.x - dino.position.x
                let dy = dest.y - dino.position.y
                let dist = hypot(dx, dy)
                if dist > budget {
                    dino.position.x += dx / dist * budget
                    dino.position.y += dy / dist * budget
                    break
                }
                dino.position = dest
                budget -= dist
                dino.cell = dino.target
                addWear(at: dino.cell)
                if dino.cell == grid.exit {
                    escaped.append(dino)
                    break
                }
                guard let next = grid.nextStep(from: dino.cell, swims: dino.kind.swims) else { break }
                dino.target = next
            }

            let ahead = point(for: dino.target)
            if hypot(ahead.x - dino.position.x, ahead.y - dino.position.y) > 0.5 {
                dino.steer(toward: atan2(ahead.y - dino.position.y, ahead.x - dino.position.x), dt: dt)
            }
        }

        for dino in escaped {
            dinos.removeAll { $0 === dino }
            dino.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
            lives = max(0, lives - dino.kind.damage)
            SoundBank.shared.play(.escape)
            Haptics.warning()
            hud.flash("\(dino.kind.name) reached the helipad!")
            flashDanger()
            if lives == 0 {
                endGame(won: false)
                return
            }
        }
    }

    /// Moves a flyer along its weaving line. Returns true when it reaches the helipad.
    private func fly(_ dino: Dino, _ dt: TimeInterval) -> Bool {
        guard var flight = dino.flight else { return false }
        flight.travelled += dino.currentSpeed * cellSize * CGFloat(dt)
        dino.flight = flight
        let dx = flight.end.x - flight.start.x
        let dy = flight.end.y - flight.start.y
        let total = max(1, hypot(dx, dy))
        let f = min(1, flight.travelled / total)
        let swoop = sin(f * .pi * 3) * sin(f * .pi) * cellSize * 0.9 * flight.weave
        let next = CGPoint(
            x: flight.start.x + dx * f - dy / total * swoop,
            y: flight.start.y + dy * f + dx / total * swoop
        )
        let moved = hypot(next.x - dino.position.x, next.y - dino.position.y)
        if moved > 0.01 {
            dino.steer(toward: atan2(next.y - dino.position.y, next.x - dino.position.x), dt: dt)
        }
        dino.position = next
        return f >= 1
    }

    private func pickTarget(from candidates: [Dino], for tower: Tower) -> Dino? {
        switch tower.targeting {
        case .first:
            return candidates.min { stepsLeft($0) < stepsLeft($1) }
        case .strongest:
            return candidates.max { $0.health < $1.health }
        case .closest:
            return candidates.min { distance($0.position, tower.position) < distance($1.position, tower.position) }
        case .flyers:
            let flyers = candidates.filter { $0.kind.flies }
            return (flyers.isEmpty ? candidates : flyers).min { stepsLeft($0) < stepsLeft($1) }
        }
    }

    /// How close a dino is to the helipad, in squares. Towers shoot the closest first.
    private func stepsLeft(_ dino: Dino) -> CGFloat {
        if let flight = dino.flight {
            let total = hypot(flight.end.x - flight.start.x, flight.end.y - flight.start.y)
            return max(0, total - flight.travelled) / cellSize
        }
        return CGFloat(grid.distance(at: dino.target, swims: dino.kind.swims))
    }

    private func fireTowers(_ dt: TimeInterval) {
        for tower in towers.values where tower.kind != .fence {
            tower.tickAbility(dt)
            // Gummed up with venom: no firing until it wears off
            guard tower.disabledLeft <= 0 else { continue }
            tower.cooldown -= dt
            guard tower.cooldown <= 0 else { continue }
            let reach = tower.range * cellSize
            let inRange = dinos.filter {
                !$0.isDead
                    && ($0.kind.flies ? tower.hitsAir : tower.hitsGround)
                    && distance($0.position, tower.position) <= reach
            }
            guard !inRange.isEmpty else { continue }
            tower.cooldown = tower.fireInterval / (tower.overdriveLeft > 0 ? 3 : 1)

            if tower.kind == .flare {
                tower.showFire()
                pulse(from: tower, radius: reach)
                SoundBank.shared.play(.flare)
                for dino in inRange {
                    hit(dino, for: tower.damage, armorApplies: !tower.ignoresArmor, source: .flare, by: tower)
                }
            } else if let target = pickTarget(from: inRange, for: tower) {
                if tower.kind == .shock {
                    tower.showFire()
                    zap(from: tower, first: target)
                } else {
                    tower.aim(at: target.position)
                    fire(from: tower, at: target)
                }
            }
        }
    }

    /// Lightning from a shock pylon, jumping from dino to nearby dino.
    private func zap(from tower: Tower, first: Dino) {
        var struck = [first]
        var current = first
        let jump = cellSize * 1.3
        while struck.count <= tower.chain {
            let from = current
            let candidates = dinos.filter { candidate in
                !candidate.isDead && !candidate.kind.flies && !struck.contains { $0 === candidate }
                    && distance(candidate.position, from.position) <= jump
            }
            guard let next = candidates.min(by: { distance($0.position, from.position) < distance($1.position, from.position) }) else { break }
            struck.append(next)
            current = next
        }
        bolt(through: [tower.position] + struck.map { $0.position })
        SoundBank.shared.play(.zap, volume: 1)
        var damage = tower.damage
        for dino in struck {
            if tower.branch == .arc {
                dino.slow(to: 0.15, for: 0.4)
            }
            hit(dino, for: damage, source: .shock, by: tower)
            // Each jump loses a little punch
            damage *= 0.8
        }
    }

    /// A jagged lightning bolt through the points, gone in a flash.
    private func bolt(through points: [CGPoint]) {
        guard points.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: points[0])
        for (a, b) in zip(points, points.dropFirst()) {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = max(1, hypot(dx, dy))
            for step in 1...4 {
                let f = CGFloat(step) / 4
                let jitter = step == 4 ? 0 : CGFloat.random(in: -1...1) * cellSize * 0.14
                path.addLine(to: CGPoint(x: a.x + dx * f - dy / length * jitter, y: a.y + dy * f + dx / length * jitter))
            }
        }
        for (width, color) in [(CGFloat(5), ParkArt.shock.withAlphaComponent(0.6)), (CGFloat(2), ParkArt.shockLight)] {
            let line = SKShapeNode(path: path)
            line.strokeColor = color
            line.lineWidth = width
            line.lineCap = .round
            line.lineJoin = .round
            line.zPosition = 7.5
            world.addChild(line)
            line.run(.sequence([.wait(forDuration: 0.06), .fadeOut(withDuration: 0.12), .removeFromParent()]))
        }
    }

    private func fire(from tower: Tower, at target: Dino) {
        tower.showFire()
        let node: SKSpriteNode
        switch tower.kind {
        case .tranq:
            SoundBank.shared.play(.tranq)
            node = SKSpriteNode(texture: ParkArt.dart(cell: cellSize), size: CGSize(width: cellSize * 0.26, height: cellSize * 0.1))
        case .flak:
            SoundBank.shared.play(.flak)
            node = SKSpriteNode(texture: ParkArt.flakShell(cell: cellSize), size: CGSize(width: cellSize * 0.22, height: cellSize * 0.12))
        default:
            SoundBank.shared.play(.turret)
            node = SKSpriteNode(texture: ParkArt.tracer(cell: cellSize), size: CGSize(width: cellSize * 0.3, height: cellSize * 0.1))
        }
        let angle = atan2(target.position.y - tower.position.y, target.position.x - tower.position.x)
        node.zRotation = angle
        node.position = CGPoint(x: tower.position.x + cos(angle) * cellSize * 0.45, y: tower.position.y + sin(angle) * cellSize * 0.45)
        node.zPosition = 7
        world.addChild(node)
        shots.append(Shot(node: node, target: target, damage: tower.damage, slow: tower.slow, splash: tower.splash, source: tower.kind, tower: tower))
    }

    private func moveShots(_ dt: TimeInterval) {
        let step = cellSize * 10 * CGFloat(dt)
        for shot in shots {
            if shot.target.isDead {
                shot.node.removeFromParent()
                shot.done = true
                continue
            }
            let dx = shot.target.position.x - shot.node.position.x
            let dy = shot.target.position.y - shot.node.position.y
            let dist = hypot(dx, dy)
            shot.node.zRotation = atan2(dy, dx)
            if dist <= step {
                if shot.splash > 0 {
                    flakBurst(at: shot.target.position)
                    let reach = shot.splash * cellSize
                    let center = shot.target.position
                    for other in dinos where other !== shot.target
                        && other.kind.flies != shot.splashGround && distance(other.position, center) <= reach {
                        hit(other, for: shot.damage * 0.5, source: shot.source, by: shot.tower)
                    }
                } else {
                    puff(at: shot.target.position, color: shot.slow == nil ? UIColor(hex: 0xFFE27A) : ParkArt.tranqLight)
                    SoundBank.shared.play(.hit)
                }
                // Only flak is built for the sky; everything else does half damage to flyers
                // Skyhammer flak can hit the ground, but at half damage
                let airPenalty: CGFloat = shot.target.kind.flies != (shot.source == .flak) ? 0.5 : 1
                hit(shot.target, for: shot.damage * airPenalty, slow: shot.slow, source: shot.source, by: shot.tower)
                shot.node.removeFromParent()
                shot.done = true
            } else {
                shot.node.position.x += dx / dist * step
                shot.node.position.y += dy / dist * step
            }
        }
        shots.removeAll { $0.done }
    }

    private func hit(
        _ dino: Dino, for amount: CGFloat,
        slow: (factor: CGFloat, duration: TimeInterval)? = nil, armorApplies: Bool = true, source: BuildKind? = nil,
        by tower: Tower? = nil
    ) {
        guard !dino.isDead else { return }
        defer {
            let dealt = armorApplies ? max(1, amount - dino.kind.armor) : amount
            stats.damage[source.map { "\($0)" } ?? "airstrike", default: 0] += dealt
        }
        if let slow {
            dino.slow(to: slow.factor, for: slow.duration)
        }
        // Armor soaks a flat amount from every hit, but something always gets through
        let dealt = armorApplies ? max(1, amount - dino.kind.armor) : amount
        tower?.damageDealt += min(dealt, dino.health)
        if dino.takeDamage(dealt) {
            tower?.kills += 1
            kill(dino)
        }
    }

    private func kill(_ dino: Dino) {
        stats.kills += 1
        award(.firstBite)
        switch dino.kind {
        case .rex:
            if Achievements.tally(Achievements.rexKills) >= 10 { award(.rexWrangler) }
        case .pterodactyl:
            if Achievements.tally(Achievements.pteroKills) >= 100 { award(.flakAce) }
        case .stegosaurus:
            if Achievements.tally(Achievements.stegoKills) >= 25 { award(.plateBreaker) }
        default:
            break
        }
        let scale = Waves.rewardScale(forWave: max(0, wavesStarted - 1)) * difficulty.bounty * (challenge?.bountyScale ?? 1)
        let reward = max(1, Int((CGFloat(dino.kind.reward) * scale * research.bountyScale).rounded()))
        cash += reward
        floatText("+$\(reward)", at: dino.position)
        SoundBank.shared.play(.dinoDown, volume: dino.kind == .compy ? 0.5 : 1)
        dinos.removeAll { $0 === dino }
        dino.run(.sequence([
            .group([.fadeOut(withDuration: 0.25), .scale(to: 1.4, duration: 0.25)]),
            .removeFromParent()
        ]))
    }

    private func endGame(won: Bool) {
        isOver = true
        waveActive = false
        if hasSaved {
            SavedGame.clear()
            hasSaved = false
        }
        if won && !Progress.testMode {
            Research.earn(Research.winBonus)
            amberThisRun += Research.winBonus
        }
        if won, let chopper {
            let lift = SKAction.group([
                .scale(to: 1.7, duration: 1.4),
                .moveBy(x: 0, y: cellSize * 3, duration: 1.4),
                .sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.6)])
            ])
            lift.timingMode = .easeIn
            chopper.run(lift)
        }

        let overlay = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 100
        addChild(overlay)

        if won {
            if challenge != nil {
                award(.dailyDriver)
            } else {
                award(.evacuationComplete)
                if difficulty == .hard {
                    award(.hardTarget)
                }
                if Level.all.allSatisfy({ Progress.hasBeaten($0) }) {
                    award(.parkRanger)
                }
            }
        }

        let endlessBest = Progress.endlessBest(level: level, difficulty: difficulty)
        let titleText: String
        if challenge != nil {
            titleText = won ? "CHALLENGE COMPLETE" : "CHALLENGE FAILED"
        } else {
            titleText = won ? "EVACUATION COMPLETE" : (endless ? "ENDLESS RUN OVER" : "PARK LOST")
        }
        let title = makeLabel(
            titleText,
            size: 28,
            font: Fonts.heavy,
            color: won ? Palette.warning : Palette.danger
        )
        title.position = CGPoint(x: 0, y: 30)
        overlay.addChild(title)

        let detailText: String
        if let challenge {
            detailText = won
                ? "You survived all \(DailyChallenge.waves) waves of today's challenge."
                : "You reached wave \(wavesStarted) of \(DailyChallenge.waves). Best today: wave \(challenge.best)."
        } else if won {
            detailText = "Everyone made it out of \(level.name). \(lives) lives left."
        } else if endless {
            detailText = "You held to wave \(wavesStarted). Endless record: wave \(max(endlessBest, wavesStarted))."
        } else {
            detailText = "The dinos overran \(level.name) on wave \(wavesStarted)."
        }
        let detail = makeLabel(detailText, size: 15)
        detail.position = CGPoint(x: 0, y: -8)
        overlay.addChild(detail)

        let amberNote = amberThisRun >= 1 ? "  ·  +\(Int(amberThisRun)) amber" : ""
        let summary = makeLabel(stats.summary + amberNote, size: 13, color: Palette.muted)
        summary.position = CGPoint(x: 0, y: -34)
        summary.setScale(min(1, (size.width - 24) / max(1, summary.frame.width)))
        overlay.addChild(summary)

        if won && challenge == nil {
            overlay.addChild(menuButton("Keep Going ∞", name: "endless", fill: Palette.warning, text: Palette.bar, outlined: false, y: -80))
            overlay.addChild(menuButton("Play Again", name: "restart", fill: Palette.panel, text: Palette.text, outlined: true, y: -140))
            overlay.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -200))
        } else {
            if RewardedAds.shared.isAvailable && !revivedThisGame && challenge == nil {
                let revive = menuButton("▶ Watch an ad to revive", name: "revive", fill: Palette.warning, text: Palette.bar, outlined: false, y: -80)
                revive.children.first?.name = "reviveLabel"
                overlay.addChild(revive)
                overlay.addChild(menuButton("Play Again", name: "restart", fill: Palette.panel, text: Palette.text, outlined: true, y: -140))
                overlay.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -200))
            } else {
                overlay.addChild(menuButton("Play Again", name: "restart", fill: Palette.warning, text: Palette.bar, outlined: false, y: -80))
                overlay.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -140))
            }
        }
        // Double the run's amber for an ad, under the other buttons
        amberDoubled = false
        if RewardedAds.shared.isAvailable && amberThisRun >= 1 {
            let showsRevive = !won && RewardedAds.shared.isAvailable && !revivedThisGame && challenge == nil
            let lowest: CGFloat = (won && challenge == nil) || showsRevive ? -200 : -140
            let amber = menuButton("▶ Watch: double your \(Int(amberThisRun)) amber", name: "amber",
                                   fill: Palette.panel, text: Palette.warning, outlined: true, y: lowest - 60)
            amber.children.first?.name = "amberLabel"
            overlay.addChild(amber)
        }
        gameOverOverlay = overlay
        SoundBank.shared.play(won ? .win : .lose)
        if won {
            Haptics.success()
        } else {
            Haptics.failure()
        }

        overlay.alpha = 0
        overlay.run(.sequence([.wait(forDuration: won ? 1.2 : 0), .fadeIn(withDuration: 0.3)]))
    }

    // MARK: - Dilophosaurus venom

    /// Spitters lob venom at the nearest working tower, gumming it up for 3 seconds.
    private func spitVenom(_ dt: TimeInterval) {
        for dino in dinos where dino.kind.spits && !dino.isDead {
            dino.spitTimer -= dt
            guard dino.spitTimer <= 0 else { continue }
            let reach = cellSize * 2
            let target = towers.values
                .filter { $0.kind != .fence && $0.disabledLeft <= 0 && distance($0.position, dino.position) <= reach }
                .min { distance($0.position, dino.position) < distance($1.position, dino.position) }
            guard let tower = target else {
                dino.spitTimer = 0.5
                continue
            }
            dino.spitTimer = 4
            let glob = SKShapeNode(circleOfRadius: cellSize * 0.09)
            glob.fillColor = SKColor(red: 0.5, green: 0.9, blue: 0.2, alpha: 1)
            glob.strokeColor = SKColor(red: 0.2, green: 0.45, blue: 0.08, alpha: 1)
            glob.position = dino.position
            glob.zPosition = 9
            world.addChild(glob)
            glob.run(.sequence([.move(to: tower.position, duration: 0.3), .removeFromParent()])) { [weak self, weak tower] in
                guard let self, let tower, tower.parent != nil else { return }
                tower.disable(for: 3)
                self.puff(at: tower.position, color: UIColor(red: 0.5, green: 0.9, blue: 0.2, alpha: 1))
                if !self.warnedAboutSpit {
                    self.warnedAboutSpit = true
                    self.hud.flash("Dilophosaurus venom! That tower can't fire for 3 seconds")
                }
            }
        }
    }

    // MARK: - Ankylosaurs and pachys

    /// Ankylosaurs club down fences next to them; pachys charge and headbutt towers.
    private func dinoTricks(_ dt: TimeInterval) {
        for dino in dinos where !dino.isDead && dino.flight == nil {
            if dino.kind.smashesFences {
                dino.actionTimer -= dt
                guard dino.actionTimer <= 0 else { continue }
                let around = [(1, 0), (-1, 0), (0, 1), (0, -1)].map { Cell(col: dino.cell.col + $0.0, row: dino.cell.row + $0.1) }
                if let fence = around.compactMap({ towers[$0] }).first(where: { $0.kind == .fence }) {
                    dino.actionTimer = 5
                    smash(fence)
                } else {
                    dino.actionTimer = 0.5
                }
            } else if dino.kind.headbutts {
                dino.chargeLeft = max(0, dino.chargeLeft - dt)
                dino.headbuttCooldown = max(0, dino.headbuttCooldown - dt)
                dino.actionTimer -= dt
                if dino.actionTimer <= 0 {
                    dino.actionTimer = 5
                    dino.chargeLeft = 1.2
                }
                guard dino.headbuttCooldown <= 0 else { continue }
                let reach = cellSize * 1.1
                guard let tower = towers.values.first(where: {
                    $0.kind != .fence && $0.disabledLeft <= 0 && distance($0.position, dino.position) <= reach
                }) else { continue }
                dino.headbuttCooldown = 6
                tower.stun(for: 2)
                puff(at: tower.position, color: Palette.warning)
                SoundBank.shared.play(.hit)
                if !warnedAboutHeadbutt {
                    warnedAboutHeadbutt = true
                    hud.flash("Pachys headbutt towers, stunning them for 2 seconds")
                }
            }
        }
    }

    /// An ankylosaur's tail club knocks a fence flat, opening a gap in the maze.
    private func smash(_ fence: Tower) {
        undoSteps.removeAll { $0.tower === fence }
        puff(at: fence.position, color: UIColor(hex: 0xC3C8BB))
        floatText("SMASH!", at: fence.position)
        SoundBank.shared.play(.hit)
        Haptics.tap()
        removeTower(fence)
        if !warnedAboutSmash {
            warnedAboutSmash = true
            hud.flash("Ankylosaurs smash fences! Back your walls with towers")
        }
    }

    // MARK: - Night

    /// For night parks: darkness over the board with soft pools of light around
    /// towers, the gate, and the helipad. Redrawn when you build or sell.
    private func rebuildDarkness() {
        darkness?.removeFromParent()
        darkness = nil
        guard level.night else { return }
        let boardSize = CGSize(width: cellSize * CGFloat(cols), height: cellSize * CGFloat(rows))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        var lights: [(CGPoint, CGFloat)] = [
            (point(for: grid.spawn), cellSize * 1.4),
            (point(for: grid.exit), cellSize * 1.8)
        ]
        for tower in towers.values {
            lights.append((tower.position, cellSize * (tower.kind == .fence ? 0.7 : 1.9)))
        }
        let image = UIGraphicsImageRenderer(size: boardSize, format: format).image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 0.82).cgColor)
            ctx.fill(CGRect(origin: .zero, size: boardSize))
            ctx.setBlendMode(.destinationOut)
            let colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.35, 1]) else { return }
            for (spot, radius) in lights {
                // Image space runs top down; the board runs bottom up
                let center = CGPoint(x: spot.x - origin.x, y: boardSize.height - (spot.y - origin.y))
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }
        }
        let overlay = SKSpriteNode(texture: SKTexture(image: image), size: boardSize)
        overlay.anchorPoint = .zero
        overlay.position = origin
        overlay.zPosition = 8.8
        world.addChild(overlay)
        darkness = overlay
    }

    // MARK: - Air strike

    private func updateAirstrikeButton() {
        hud?.setStrike(ready: airstrikeReady, armed: airstrikeArmed)
    }

    private func toggleAirstrike() {
        guard airstrikeReady else {
            hud.flash("Air strike is back after this wave")
            return
        }
        airstrikeArmed.toggle()
        Haptics.tap()
        updateAirstrikeButton()
        if airstrikeArmed {
            hud.flash("Tap the board where the chopper should strafe")
        }
    }

    /// The rescue chopper strafes a line straight across the board, hitting everything in it.
    private func launchAirstrike(atY y: CGFloat) {
        airstrikeArmed = false
        airstrikeReady = false
        updateAirstrikeButton()
        Haptics.stomp()
        SoundBank.shared.play(.alarm, volume: 0.6)

        let left = origin.x - cellSize * 1.5
        let right = origin.x + cellSize * CGFloat(cols) + cellSize * 1.5
        let band = cellSize * 0.75
        let heli = SKNode()
        heli.zPosition = 12
        heli.position = CGPoint(x: left, y: y)
        let s = cellSize * 1.2
        heli.addChild(SKSpriteNode(texture: ParkArt.chopperBody(size: s), size: CGSize(width: s * 1.4, height: s * 0.5)))
        let rotor = SKSpriteNode(texture: ParkArt.rotor(size: s), size: CGSize(width: s * 1.16, height: s * 1.16))
        rotor.zPosition = 1
        rotor.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.2)))
        heli.addChild(rotor)
        world.addChild(heli)

        let line = SKShapeNode(rectOf: CGSize(width: right - left, height: band * 2))
        line.position = CGPoint(x: (left + right) / 2, y: y)
        line.fillColor = SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.12)
        line.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.5)
        line.zPosition = 7
        world.addChild(line)
        line.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))

        let duration: TimeInterval = 1.1
        heli.run(.sequence([.moveTo(x: right, duration: duration), .removeFromParent()]))
        let damage = 45 * Waves.healthScale(forWave: max(0, wavesStarted - 1)) * difficulty.health * research.strikeScale
        let steps = 10
        for i in 0..<steps {
            let x = left + (right - left) * CGFloat(i) / CGFloat(steps - 1)
            run(.wait(forDuration: duration * Double(i) / Double(steps))) { [weak self] in
                guard let self else { return }
                SoundBank.shared.play(.turret)
                self.puff(at: CGPoint(x: x, y: y + CGFloat.random(in: -band...band)), color: UIColor(hex: 0xFFE27A))
                let sliceWidth = (right - left) / CGFloat(steps)
                for dino in self.dinos where abs(dino.position.y - y) <= band && abs(dino.position.x - x) <= sliceWidth {
                    self.hit(dino, for: damage / 2)
                }
            }
        }
    }

    // MARK: - Tower abilities

    private func useAbility(_ tower: Tower) {
        guard let name = tower.kind.abilityName else { return }
        guard tower.abilityCooldown <= 0 else {
            hud.flash("\(name) recharging: \(Int(tower.abilityCooldown.rounded(.up)))s")
            return
        }
        tower.abilityCooldown = tower.kind.abilityRecharge
        Haptics.punch()
        hud.flash("\(name)!")
        tutorial?.handle(.upgraded)
        let reach = tower.range * cellSize
        switch tower.kind {
        case .tranq:
            sleepGas(at: tower.position, radius: reach * 1.2)
        case .turret:
            tower.startOverdrive(for: 5)
            SoundBank.shared.play(.turret)
        case .flare:
            napalm(at: tower.position, radius: reach * 1.1, damagePerSecond: tower.damage * 1.5)
        case .flak:
            barrage(from: tower, radius: reach * 1.3)
        case .shock:
            let targets = dinos.filter { !$0.isDead && !$0.kind.flies && distance($0.position, tower.position) <= reach * 1.2 }
            for dino in targets {
                bolt(through: [tower.position, dino.position])
                hit(dino, for: tower.damage * 4, source: .shock, by: tower)
            }
            SoundBank.shared.play(.zap, volume: 1)
            shakeWorld()
        case .fence:
            break
        }
    }

    /// A gas cloud that nearly freezes every dino inside it.
    private func sleepGas(at center: CGPoint, radius: CGFloat) {
        SoundBank.shared.play(.tranq)
        let cloud = SKShapeNode(circleOfRadius: radius)
        cloud.position = center
        cloud.fillColor = SKColor(red: 0.45, green: 0.85, blue: 0.8, alpha: 0.35)
        cloud.strokeColor = SKColor(red: 0.6, green: 0.95, blue: 0.9, alpha: 0.8)
        cloud.lineWidth = 2
        cloud.zPosition = 8
        cloud.setScale(0.2)
        world.addChild(cloud)
        cloud.run(.sequence([
            .scale(to: 1, duration: 0.3),
            .wait(forDuration: 1.2),
            .fadeOut(withDuration: 0.8),
            .removeFromParent()
        ]))
        for dino in dinos where distance(dino.position, center) <= radius {
            dino.slow(to: 0.1, for: 3)
        }
    }

    /// A burning patch that hurts ground dinos for a few seconds. Armor doesn't help.
    private func napalm(at center: CGPoint, radius: CGFloat, damagePerSecond: CGFloat) {
        SoundBank.shared.play(.flare)
        let patch = SKShapeNode(circleOfRadius: radius)
        patch.position = center
        patch.fillColor = SKColor(red: 1, green: 0.45, blue: 0.1, alpha: 0.35)
        patch.strokeColor = SKColor(red: 1, green: 0.75, blue: 0.35, alpha: 0.9)
        patch.lineWidth = 2
        patch.zPosition = 0.8
        patch.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
        world.addChild(patch)
        burns.append(Burn(node: patch, center: center, radius: radius, damagePerSecond: damagePerSecond, timeLeft: 4))
    }

    private func burnGround(_ dt: TimeInterval) {
        for burn in burns {
            burn.timeLeft -= dt
            for dino in dinos where !dino.kind.flies && distance(dino.position, burn.center) <= burn.radius {
                hit(dino, for: burn.damagePerSecond * CGFloat(dt), armorApplies: false, source: .flare)
            }
            if burn.timeLeft <= 0 {
                burn.node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            }
        }
        burns.removeAll { $0.timeLeft <= 0 }
    }

    /// Flak fires a shell into every flyer in range at once.
    private func barrage(from tower: Tower, radius: CGFloat) {
        tower.showFire()
        let targets = dinos.filter { $0.kind.flies && !$0.isDead && distance($0.position, tower.position) <= radius }
        guard !targets.isEmpty else {
            hud.flash("Barrage: no flyers in range")
            return
        }
        for (i, dino) in targets.enumerated() {
            run(.wait(forDuration: Double(i) * 0.08)) { [weak self, weak dino] in
                guard let self, let dino, !dino.isDead else { return }
                self.flakBurst(at: dino.position)
                SoundBank.shared.play(.flak)
                self.hit(dino, for: tower.damage * 3, source: .flak, by: tower)
            }
        }
    }

    // MARK: - Achievements

    private func award(_ achievement: Achievement) {
        guard Achievements.earn(achievement) else { return }
        showAchievement(achievement)
    }

    /// Slides a trophy banner in under the top bar for a few seconds.
    private func showAchievement(_ achievement: Achievement) {
        let width = min(size.width - 24, 320)
        let toast = SKNode()
        toast.zPosition = 95
        let y = size.height - topHeight - 40 - CGFloat(activeToasts) * 62
        toast.position = CGPoint(x: size.width / 2, y: y + 30)
        toast.alpha = 0
        activeToasts += 1

        let background = SKShapeNode(rectOf: CGSize(width: width, height: 54), cornerRadius: 14)
        background.fillColor = Palette.bar.withAlphaComponent(0.96)
        background.strokeColor = Palette.warning
        background.lineWidth = 2
        toast.addChild(background)

        let badge = SKShapeNode(circleOfRadius: 17)
        badge.fillColor = Palette.warning
        badge.strokeColor = .clear
        badge.position = CGPoint(x: -width / 2 + 30, y: 0)
        toast.addChild(badge)
        let trophy = makeLabel("★", size: 20, font: Fonts.heavy, color: Palette.bar)
        trophy.position = badge.position
        toast.addChild(trophy)

        let heading = makeLabel("ACHIEVEMENT UNLOCKED", size: 10, font: Fonts.heavy, color: Palette.warning)
        heading.horizontalAlignmentMode = .left
        heading.position = CGPoint(x: -width / 2 + 56, y: 10)
        toast.addChild(heading)
        let name = makeLabel(achievement.title, size: 17, font: Fonts.heavy)
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -width / 2 + 56, y: -9)
        toast.addChild(name)

        addChild(toast)
        SoundBank.shared.play(.upgrade)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.25), .moveTo(y: y, duration: 0.25)]),
            .wait(forDuration: 2.6),
            .fadeOut(withDuration: 0.4),
            .run { [weak self] in self?.activeToasts = max(0, (self?.activeToasts ?? 1) - 1) },
            .removeFromParent()
        ]))
    }

    /// Ad revive: back in the fight with 5 lives, and the dinos on the board cleared.
    private func revive() {
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil
        revivedThisGame = true
        isOver = false
        for dino in dinos {
            dino.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        }
        dinos.removeAll()
        for shot in shots {
            shot.node.removeFromParent()
        }
        shots.removeAll()
        lives = 5
        Haptics.success()
        SoundBank.shared.play(.upgrade)
        hud.flash("Revived! 5 lives. Hold the line")
        if !waveActive {
            hud.setSendEnabled(true)
        }
    }

    /// After winning, bring the chopper back down and keep the waves coming.
    private func keepGoing() {
        gameOverOverlay?.removeFromParent()
        gameOverOverlay = nil
        endless = true
        isOver = false
        if let chopper {
            chopper.removeAllActions()
            chopper.position = chopperHome
            chopper.setScale(1.6)
            chopper.alpha = 0
            let land = SKAction.group([.scale(to: 1, duration: 1), .fadeIn(withDuration: 0.5)])
            land.timingMode = .easeOut
            chopper.run(land)
        }
        Progress.recordEndless(wave: wavesStarted, level: level, difficulty: difficulty)
        hud.setWave(wavesStarted, of: nil)
        hud.setSendEnabled(true)
        updatePreview()
        saveProgress()
        hud.flash("Endless mode. The dinos keep coming. How long can you hold?")
    }

    // MARK: - Tower panel

    /// Shows a tower's level with Upgrade and Sell buttons, plus its range.
    private func showPanel(for tower: Tower) {
        closePanel()
        selectedTower = tower

        if tower.kind != .fence {
            let ring = SKShapeNode(circleOfRadius: tower.range * cellSize)
            ring.position = tower.position
            ring.strokeColor = SKColor(white: 1, alpha: 0.6)
            ring.fillColor = SKColor(white: 1, alpha: 0.08)
            ring.lineWidth = 1.5
            ring.zPosition = 2.8
            world.addChild(ring)
            selectedRing = ring
        }

        let width: CGFloat = 230
        let hasAbility = tower.kind.abilityName != nil
        let showsStats = tower.kind != .fence
        let height: CGFloat = (hasAbility ? 152 : 100) + (showsStats ? 20 : 0)
        let rowY: CGFloat = hasAbility ? (showsStats ? 2 : 12) : (showsStats ? -24 : -14)
        let panel = SKNode()
        panel.zPosition = 90

        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14)
        background.name = "panel"
        background.fillColor = Palette.bar.withAlphaComponent(0.96)
        background.strokeColor = Palette.warning.withAlphaComponent(0.55)
        background.lineWidth = 1.5
        panel.addChild(background)

        let title = tower.kind == .fence
            ? "Electric fence"
            : "\(tower.kind.title)  ·  Level \(tower.level) of \(Tower.maxLevel)"
        let titleY: CGFloat = height / 2 - 24
        let aims = tower.kind != .fence && tower.kind != .flare
        let titleLabel = makeLabel(aims ? "\(tower.title) · Lv \(tower.level)/\(Tower.maxLevel)" : title, size: aims ? 14 : 15, font: Fonts.heavy)
        titleLabel.name = "panel"
        if aims {
            titleLabel.horizontalAlignmentMode = .left
            titleLabel.position = CGPoint(x: -width / 2 + 14, y: titleY)
            panel.addChild(menuButton("Aim: \(tower.targeting.title)", name: "target", fill: Palette.panel, text: Palette.warning,
                                      outlined: true, x: width / 2 - 12 - 46, y: titleY, width: 92, height: 28, fontSize: 11))
        } else {
            titleLabel.position = CGPoint(x: 0, y: titleY)
        }
        panel.addChild(titleLabel)
        if showsStats {
            let damage = tower.damageDealt >= 1000
                ? String(format: "%.1fk", Double(tower.damageDealt) / 1000)
                : "\(Int(tower.damageDealt))"
            let statsLabel = makeLabel("\(tower.kills) kills  ·  \(damage) damage", size: 11, color: Palette.muted)
            statsLabel.name = "panel"
            statsLabel.horizontalAlignmentMode = .left
            statsLabel.position = CGPoint(x: -width / 2 + 14, y: titleY - 21)
            panel.addChild(statsLabel)
        }

        let sellTitle = "Sell $\(tower.sellValue)"
        if tower.kind == .fence {
            panel.addChild(menuButton(sellTitle, name: "sell", fill: Palette.panel, text: Palette.text, outlined: true,
                                      y: rowY, width: width - 24, height: 42, fontSize: 15))
        } else {
            let upgradeTitle: String
            let canAfford: Bool
            if let cost = tower.upgradeCost {
                upgradeTitle = tower.needsBranch ? "Pick path $\(cost)" : "Upgrade $\(cost)"
                canAfford = cash >= cost
            } else {
                upgradeTitle = "Max level"
                canAfford = false
            }
            panel.addChild(menuButton(upgradeTitle, name: "upgrade",
                                      fill: canAfford ? Palette.warning : Palette.panel,
                                      text: canAfford ? Palette.bar : Palette.muted,
                                      outlined: !canAfford,
                                      x: -width / 2 + 12 + 63, y: rowY, width: 126, height: 42, fontSize: 15))
            panel.addChild(menuButton(sellTitle, name: "sell", fill: Palette.panel, text: Palette.text, outlined: true,
                                      x: width / 2 - 12 - 38, y: rowY, width: 76, height: 42, fontSize: 14))
            if let abilityName = tower.kind.abilityName {
                let ready = tower.abilityCooldown <= 0
                let abilityTitle = ready ? "⚡ \(abilityName)" : "\(abilityName)  ·  \(Int(tower.abilityCooldown.rounded(.up)))s"
                panel.addChild(menuButton(abilityTitle, name: "ability",
                                          fill: ready ? SKColor(red: 0.25, green: 0.53, blue: 0.79, alpha: 1) : Palette.panel,
                                          text: ready ? Palette.text : Palette.muted,
                                          outlined: !ready,
                                          y: showsStats ? -50 : -40, width: width - 24, height: 42, fontSize: 15))
                let hint = makeLabel(tower.kind.abilityDetail, size: 11, color: Palette.muted)
                hint.name = "panel"
                hint.position = CGPoint(x: 0, y: showsStats ? -76 : -66)
                hint.setScale(min(1, (width - 16) / max(1, hint.frame.width)))
                panel.addChild(hint)
            }
        }

        let towerPoint = convert(tower.position, from: world)
        var y = towerPoint.y + cellSize * 0.6 + height / 2 + 6
        if y + height / 2 > size.height - topHeight - 4 {
            y = towerPoint.y - cellSize * 0.6 - height / 2 - 6
        }
        let x = min(max(towerPoint.x, width / 2 + 8), size.width - width / 2 - 8)
        panel.position = CGPoint(x: x, y: y)
        panel.setScale(0.85)
        panel.run(.scale(to: 1, duration: 0.1))
        addChild(panel)
        towerPanel = panel
    }

    /// Level 3 to 4: two cards, one for each way the tower can specialize.
    #if DEBUG
    // MARK: - App Store screenshots

    /// Builds a serpentine maze lined with upgraded towers, then stages a scene:
    /// 1 a mid-game wave, 2 a T-Rex boss wave, 3 a crowded wave with flyers,
    /// 4 the upgrade path picker between waves.
    private func stageScreenshot() {
        tutorial?.node.removeFromParent()
        tutorial = nil
        let walls: [(row: Int, gapOnLeft: Bool)] = [(12, false), (9, true), (6, false), (3, true)]
        let pattern: [BuildKind] = flyerHeavy
            ? [.fence, .turret, .fence, .flak, .fence, .shock, .fence, .flak, .fence]
            : [.fence, .turret, .fence, .tranq, .fence, .shock, .fence, .flare, .fence]
        var picker: Tower?
        for (i, wall) in walls.enumerated() {
            for col in 0..<cols where col != (wall.gapOnLeft ? 0 : cols - 1) {
                let kind = pattern[(col + i * 2) % pattern.count]
                var level = kind == .fence ? 1 : 2 + (col + i) % 4
                if screenshot == 4 && kind == .turret && picker == nil {
                    level = 3
                }
                let branch = TowerBranch.options(for: kind).isEmpty ? nil : TowerBranch.options(for: kind)[(col + i) % 2]
                let tower = placeForScreenshot(kind, at: Cell(col: col, row: wall.row), level: level, branch: branch)
                if screenshot == 4 && kind == .turret && picker == nil {
                    picker = tower
                }
            }
        }
        rebuildWires()
        rebuildDarkness()
        refreshBuildHints()
        refreshPath()

        let setups: [Int: (wave: Int, cash: Int, lives: Int)] = [
            1: (9, 1385, 20), 2: (20, 2210, 17), 3: (22, 1890, 18), 4: (12, 640, 20)
        ]
        guard let setup = setups[screenshot] else { return }
        wavesStarted = setup.wave - 1
        cash = setup.cash
        lives = setup.lives
        hud.setWave(wavesStarted, of: waveGoal)
        if screenshot == 4 {
            updatePreview()
            if let picker {
                showBranchChoice(for: picker)
            }
        } else {
            sendWave()
        }
    }

    @discardableResult
    private func placeForScreenshot(_ kind: BuildKind, at cell: Cell, level: Int, branch: TowerBranch?) -> Tower? {
        guard !grid.terrain.contains(cell), cell != grid.spawn, cell != grid.exit, towers[cell] == nil,
              grid.block(cell, keeping: []) else { return nil }
        let tower = Tower(kind: kind, cell: cell, cellSize: cellSize)
        tower.position = point(for: cell)
        while tower.level < level, tower.upgradeCost != nil {
            tower.upgrade(branch: branch)
        }
        world.addChild(tower)
        towers[cell] = tower
        return tower
    }
    #endif

    private func showBranchChoice(for tower: Tower) {
        guard let cost = tower.upgradeCost else { return }
        closePanel()
        selectedTower = tower
        let width: CGFloat = min(size.width - 16, 310)
        let height: CGFloat = 190
        let panel = SKNode()
        panel.zPosition = 90

        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14)
        background.name = "panel"
        background.fillColor = Palette.bar.withAlphaComponent(0.97)
        background.strokeColor = Palette.warning.withAlphaComponent(0.55)
        background.lineWidth = 1.5
        panel.addChild(background)

        let heading = makeLabel("LEVEL 4: PICK A PATH FOR THIS \(tower.kind.title.uppercased())", size: 12, font: Fonts.heavy, color: Palette.warning)
        heading.name = "panel"
        heading.position = CGPoint(x: 0, y: height / 2 - 20)
        heading.setScale(min(1, (width - 24) / max(1, heading.frame.width)))
        panel.addChild(heading)

        let options = TowerBranch.options(for: tower.kind)
        let cardWidth: CGFloat = (width - 36) / 2
        let cardHeight: CGFloat = 140
        for (i, option) in options.enumerated() {
            let name = "pick-\(option.rawValue)"
            let card = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 12)
            card.name = name
            card.fillColor = Palette.panel
            card.strokeColor = option.color
            card.lineWidth = 2
            let firstX: CGFloat = -width / 2 + 12 + cardWidth / 2
            let step: CGFloat = cardWidth + 12
            card.position = CGPoint(x: firstX + CGFloat(i) * step, y: -12)

            let title = makeLabel(option.title, size: 17, font: Fonts.heavy, color: option.color)
            title.name = name
            title.position = CGPoint(x: 0, y: cardHeight / 2 - 22)
            card.addChild(title)

            let detail = SKLabelNode(fontNamed: Fonts.bold)
            detail.name = name
            detail.text = option.detail
            detail.fontSize = 12
            detail.fontColor = Palette.text
            detail.numberOfLines = 0
            detail.preferredMaxLayoutWidth = cardWidth - 16
            detail.lineBreakMode = .byWordWrapping
            detail.horizontalAlignmentMode = .center
            detail.verticalAlignmentMode = .top
            detail.position = CGPoint(x: 0, y: cardHeight / 2 - 40)
            card.addChild(detail)

            let price = makeLabel("$\(cost)", size: 15, font: Fonts.heavy, color: cash >= cost ? Palette.warning : Palette.danger)
            price.name = name
            price.position = CGPoint(x: 0, y: -cardHeight / 2 + 18)
            card.addChild(price)
            panel.addChild(card)
        }

        let towerPoint = convert(tower.position, from: world)
        var y = towerPoint.y + cellSize * 0.6 + height / 2 + 6
        if y + height / 2 > size.height - topHeight - 4 {
            y = towerPoint.y - cellSize * 0.6 - height / 2 - 6
        }
        panel.position = CGPoint(x: size.width / 2, y: max(bottomHeight + height / 2 + 4, y))
        panel.setScale(0.85)
        panel.run(.scale(to: 1, duration: 0.1))
        addChild(panel)
        towerPanel = panel
    }

    private func closePanel() {
        towerPanel?.removeFromParent()
        towerPanel = nil
        selectedRing?.removeFromParent()
        selectedRing = nil
        selectedTower = nil
    }

    // MARK: - Pause menu

    private func openPauseMenu() {
        guard pauseMenu == nil, !isOver else { return }
        closePanel()
        world.isPaused = true

        let menu = SKNode()
        menu.zPosition = 100
        menu.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(menu)
        pauseMenu = menu

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.72), size: size)
        menu.addChild(dim)

        let title = makeLabel("PAUSED", size: 30, font: Fonts.heavy, color: Palette.warning)
        title.position = CGPoint(x: 0, y: 96)
        menu.addChild(title)

        let waveText = endless ? "Wave \(wavesStarted) ∞" : "Wave \(wavesStarted) of \(waveGoal)"
        let status = makeLabel("\(waveText)  ·  \(lives) lives  ·  $\(cash)", size: 14, color: Palette.muted)
        status.position = CGPoint(x: 0, y: 64)
        menu.addChild(status)

        menu.addChild(menuButton("Resume", name: "resume", fill: Palette.warning, text: Palette.bar, outlined: false, y: 10))
        menu.addChild(menuButton("Restart", name: "restart", fill: Palette.panel, text: Palette.danger, outlined: true, y: -50))
        menu.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -110))

        let note = makeLabel("Restart and Main Menu end this run", size: 13, color: Palette.muted)
        note.position = CGPoint(x: 0, y: -156)
        menu.addChild(note)
    }

    private func closePauseMenu() {
        pauseMenu?.removeFromParent()
        pauseMenu = nil
        world.isPaused = false
    }

    private func menuButton(
        _ title: String, name: String, fill: SKColor, text: SKColor, outlined: Bool,
        x: CGFloat = 0, y: CGFloat, width: CGFloat = 200, height: CGFloat = 48, fontSize: CGFloat = 18
    ) -> SKNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 12)
        button.name = name
        button.fillColor = fill
        button.strokeColor = text.withAlphaComponent(0.6)
        button.lineWidth = outlined ? 2 : 0
        button.position = CGPoint(x: x, y: y)
        let label = makeLabel(title, size: fontSize, font: Fonts.heavy, color: text)
        label.name = name
        button.addChild(label)
        return button
    }

    // MARK: - Effects

    private func showRange(of tower: Tower) {
        let ring = SKShapeNode(circleOfRadius: tower.range * cellSize)
        ring.position = tower.position
        ring.strokeColor = SKColor(white: 1, alpha: 0.5)
        ring.fillColor = SKColor(white: 1, alpha: 0.06)
        ring.zPosition = 2
        world.addChild(ring)
        ring.run(.sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func pulse(from tower: Tower, radius: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = tower.position
        ring.strokeColor = UIColor(red: 1, green: 0.78, blue: 0.43, alpha: 0.9)
        ring.fillColor = UIColor(red: 1, green: 0.55, blue: 0.24, alpha: 0.3)
        ring.lineWidth = 3
        ring.zPosition = 4
        ring.setScale(0.3)
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1, duration: 0.3), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 + CGFloat.random(in: 0...0.3)
            let ember = SKShapeNode(circleOfRadius: cellSize * 0.045)
            ember.fillColor = i % 2 == 0 ? ParkArt.flareLight : ParkArt.ember
            ember.strokeColor = .clear
            ember.position = tower.position
            ember.zPosition = 4.1
            world.addChild(ember)
            let reach = radius * CGFloat.random(in: 0.7...0.95)
            ember.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(a) * reach, dy: sin(a) * reach), duration: 0.4),
                    .scale(to: 0.2, duration: 0.4),
                    .fadeOut(withDuration: 0.4)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// A flak shell going off: an orange flash inside a dark smoke ball.
    private func flakBurst(at point: CGPoint) {
        let smoke = SKShapeNode(circleOfRadius: cellSize * 0.35)
        smoke.fillColor = SKColor(white: 0.18, alpha: 0.75)
        smoke.strokeColor = SKColor(white: 0.08, alpha: 0.8)
        smoke.lineWidth = 2
        smoke.position = point
        smoke.zPosition = 9.5
        smoke.setScale(0.3)
        world.addChild(smoke)
        smoke.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.35), .sequence([.wait(forDuration: 0.15), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent()
        ]))
        let flash = SKShapeNode(circleOfRadius: cellSize * 0.18)
        flash.fillColor = ParkArt.flareLight
        flash.strokeColor = .clear
        flash.position = point
        flash.zPosition = 9.6
        world.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.6, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
    }

    private func puff(at point: CGPoint, color: UIColor) {
        let spark = SKSpriteNode(texture: ParkArt.spark(cell: cellSize, color: color), size: CGSize(width: cellSize * 0.4, height: cellSize * 0.4))
        spark.position = point
        spark.zPosition = 8
        spark.setScale(0.6)
        world.addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
    }

    /// Now and then a fence post throws a spark.
    private func sparkFences(_ dt: TimeInterval) {
        sparkTimer -= dt
        guard sparkTimer <= 0 else { return }
        sparkTimer = TimeInterval.random(in: 0.3...1.0)
        guard let post = towers.values.filter({ $0.kind == .fence }).randomElement() else { return }
        if Int.random(in: 0..<3) == 0 {
            SoundBank.shared.play(.zap)
        }
        let offset = CGPoint(x: cellSize * 0.1, y: cellSize * 0.1)
        puff(at: CGPoint(x: post.position.x + offset.x, y: post.position.y + offset.y), color: UIColor(hex: 0xE8F6FF))
    }

    private func floatText(_ text: String, at point: CGPoint) {
        let label = makeLabel(text, size: 13, font: Fonts.heavy, color: Palette.warning)
        label.position = point
        label.zPosition = 20
        world.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: cellSize * 0.6, duration: 0.6), .fadeOut(withDuration: 0.6)]),
            .removeFromParent()
        ]))
    }

    /// A big centered banner over the board for wave starts and clears.
    private func banner(_ title: String, subtitle: String?, color: SKColor = Palette.warning) {
        childNode(withName: "banner")?.removeFromParent()
        let node = SKNode()
        node.name = "banner"
        node.zPosition = 60
        node.position = CGPoint(x: size.width / 2, y: origin.y + cellSize * CGFloat(rows) * 0.6)
        for (offset, tint) in [(CGPoint(x: 2, y: -2), SKColor.black.withAlphaComponent(0.6)), (CGPoint.zero, color)] {
            let label = makeLabel(title, size: 32, font: Fonts.heavy, color: tint)
            label.position = offset
            node.addChild(label)
        }
        if let subtitle {
            let detail = makeLabel(subtitle, size: 15, font: Fonts.heavy, color: Palette.text)
            detail.position = CGPoint(x: 0, y: -30)
            let backing = SKShapeNode(rectOf: CGSize(width: detail.frame.width + 20, height: 24), cornerRadius: 12)
            backing.fillColor = Palette.bar.withAlphaComponent(0.75)
            backing.strokeColor = .clear
            backing.position = detail.position
            node.addChild(backing)
            node.addChild(detail)
        }
        let fit = min(1, (size.width - 24) / max(1, node.calculateAccumulatedFrame().width))
        node.setScale(fit * 0.6)
        node.alpha = 0
        addChild(node)
        node.run(.sequence([
            .group([.fadeIn(withDuration: 0.15), .scale(to: fit * 1.05, duration: 0.15)]),
            .scale(to: fit, duration: 0.1),
            .wait(forDuration: 1.0),
            .group([.fadeOut(withDuration: 0.35), .moveBy(x: 0, y: 24, duration: 0.35)]),
            .removeFromParent()
        ]))
    }

    private func flashDanger() {
        let flash = SKSpriteNode(color: Palette.danger, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 40
        flash.alpha = 0.25
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func shakeWorld() {
        var steps: [SKAction] = []
        for _ in 0..<14 {
            let dx = CGFloat.random(in: -6...6)
            let dy = CGFloat.random(in: -6...6)
            steps.append(.move(to: CGPoint(x: dx, y: dy), duration: 0.05))
        }
        steps.append(.move(to: .zero, duration: 0.05))
        world.run(.sequence(steps), withKey: "shake")
    }
}
