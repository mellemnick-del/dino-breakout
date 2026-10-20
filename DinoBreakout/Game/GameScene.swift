import SpriteKit

/// A dart or bullet in flight. Homes in on its target.
private final class Shot {
    let node: SKSpriteNode
    let target: Dino
    let damage: CGFloat
    let slow: (factor: CGFloat, duration: TimeInterval)?
    /// Flak bursts also hit flyers within this many squares.
    let splash: CGFloat
    var done = false

    init(node: SKSpriteNode, target: Dino, damage: CGFloat, slow: (factor: CGFloat, duration: TimeInterval)?, splash: CGFloat = 0) {
        self.node = node
        self.target = target
        self.damage = damage
        self.slow = slow
        self.splash = splash
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

    init(
        size: CGSize, level: Level, difficulty: Difficulty, endless: Bool = false,
        challenge: DailyChallenge? = nil, safeInsets: UIEdgeInsets = .zero
    ) {
        topInset = safeInsets.top
        // The home indicator is hidden during play, so the build bar can sit partway into its space
        bottomInset = safeInsets.bottom * 0.5
        topHeight = topInset + 50
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
        for kind in [DinoKind.compy, .raptor, .triceratops, .stegosaurus, .rex, .pterodactyl] {
            _ = DinoArt.bake(kind, cellSize: cellSize, screenScale: screenScale)
        }

        hud = HUD(size: size, topHeight: topHeight, bottomHeight: bottomHeight, topInset: topInset, bottomInset: bottomInset)
        addChild(hud)
        cash = Progress.testMode ? 9999 : (challenge?.startingCash ?? difficulty.startingCash)
        lives = challenge?.lives ?? difficulty.lives
        activeToasts = 0
        endless = startedEndless
        hud.setWave(0, of: endless ? nil : waveGoal)
        hud.setSendEnabled(true)
        tool = .build(.fence)
        hud.select(tool)
        if let challenge {
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
        wireLayer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.5),
            .fadeAlpha(to: 1, duration: 0.5)
        ])))

        buildTerrain()
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
        guard cell != grid.spawn, cell != grid.exit else { return }
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
        if let overlay = gameOverOverlay {
            let hits = overlay.nodes(at: touch.location(in: overlay)).compactMap { $0.name }
            if hits.contains("endless") {
                keepGoing()
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
        if let panel = towerPanel {
            let hits = panel.nodes(at: touch.location(in: panel)).compactMap { $0.name }
            if hits.contains("upgrade"), let tower = selectedTower {
                upgrade(tower)
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
            }
            return
        }
        if let tapped = cell(at: touch.location(in: world)) {
            tap(tapped)
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
            hud.flash("No fences today. Build your maze from towers")
            return
        }
        guard case .build(let kind)? = tool else {
            hud.flash("Pick something to build")
            return
        }
        if grid.terrain.contains(cell) {
            if level.water.contains(cell) {
                hud.flash("Can't build in the river")
            } else if level.lava.contains(cell) {
                hud.flash("Can't build on lava")
            } else if level.buildings.contains(cell) {
                hud.flash("Can't build on a building")
            } else {
                hud.flash("Can't build on a boulder")
            }
            return
        }
        if cell == grid.spawn || cell == grid.exit {
            hud.flash("Can't build there")
            return
        }
        guard cash >= kind.cost else {
            hud.flash("Need $\(kind.cost)")
            return
        }
        let occupied = dinos.filter { !$0.kind.flies }.flatMap { [$0.cell, $0.target] }
        if occupied.contains(cell) {
            hud.flash("Too close to a dino")
            return
        }
        guard grid.block(cell, keeping: occupied) else {
            hud.flash("Dinos need a way through!")
            return
        }

        cash -= kind.cost
        SoundBank.shared.play(.place)
        let tower = Tower(kind: kind, cell: cell, cellSize: cellSize)
        tower.position = point(for: cell)
        tower.setScale(0.6)
        tower.run(.scale(to: 1, duration: 0.12))
        world.addChild(tower)
        towers[cell] = tower
        if kind == .fence {
            rebuildWires()
            if towers.values.filter({ $0.kind == .fence }).count >= 40 {
                award(.mazeMaster)
            }
        } else {
            showRange(of: tower)
            hud.flash("Tap any tower to upgrade or sell it")
        }
    }

    private func upgrade(_ tower: Tower) {
        guard let cost = tower.upgradeCost else {
            hud.flash(tower.kind == .fence ? "Fences can't be upgraded" : "Already max level")
            return
        }
        guard cash >= cost else {
            hud.flash("Upgrade costs $\(cost)")
            return
        }
        cash -= cost
        tower.upgrade()
        SoundBank.shared.play(.upgrade)
        hud.flash("\(tower.kind.title) level \(tower.level)")
        if tower.level == Tower.maxLevel {
            award(.fullyLoaded)
        }
        showRange(of: tower)
    }

    private func sell(_ tower: Tower) {
        SoundBank.shared.play(.sell)
        cash += tower.sellValue
        floatText("+$\(tower.sellValue)", at: tower.position)
        towers[tower.cell] = nil
        grid.unblock(tower.cell)
        tower.removeFromParent()
        if tower.kind == .fence {
            rebuildWires()
        }
    }

    // MARK: - Waves

    private func sendWave() {
        guard !waveActive, !isOver, endless || wavesStarted < waveGoal else { return }
        let flyerHeavy = level.flyerHeavy || challenge?.flyerHeavy == true
        let wave = Waves.groups(forWave: wavesStarted + 1, flyerHeavy: flyerHeavy)
        livesAtWaveStart = lives
        waveHadRex = false
        wavesStarted += 1
        spawnQueue = Waves.schedule(wave)
        waveClock = 0
        waveActive = true
        hud.setWave(wavesStarted, of: endless ? nil : waveGoal)
        hud.setSpeed(gameSpeed)
        setGate(open: true)
        SoundBank.shared.play(.alarm)
        hud.flash("Wave \(wavesStarted): \(Waves.summary(wave))")
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
        dino.target = grid.nextStep(from: grid.spawn) ?? grid.spawn
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
                hud.flash("Pterodactyls! They fly over fences. Build Flak to shoot them down")
            }
        }

        if kind == .rex {
            hud.flash("🦖 The ground is shaking...")
            shakeWorld()
            SoundBank.shared.play(.roar)
        }
    }

    private func checkWaveEnd() {
        guard waveActive, spawnQueue.isEmpty, dinos.isEmpty else { return }
        waveActive = false
        setGate(open: false)
        if let challenge {
            challenge.record(wave: wavesStarted)
        } else {
            if wavesStarted <= Waves.total {
                Progress.record(wave: wavesStarted, level: level, difficulty: difficulty)
            }
            if endless {
                Progress.recordEndless(wave: wavesStarted, level: level, difficulty: difficulty)
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
        cash += bonus
        if !endless && wavesStarted == waveGoal {
            endGame(won: true)
        } else {
            hud.setSendEnabled(true)
            hud.flash("Wave cleared! +$\(bonus)")
        }
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard !isOver, pauseMenu == nil, dt > 0 else { return }

        // Faster speeds run extra steps so nothing skips past a tower
        for _ in 0..<gameSpeed where !isOver {
            spawnDue(dt)
            moveDinos(dt)
            fireTowers(dt)
            moveShots(dt)
            sparkFences(dt)
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
                guard let next = grid.nextStep(from: dino.cell) else { break }
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

    /// How close a dino is to the helipad, in squares. Towers shoot the closest first.
    private func stepsLeft(_ dino: Dino) -> CGFloat {
        if let flight = dino.flight {
            let total = hypot(flight.end.x - flight.start.x, flight.end.y - flight.start.y)
            return max(0, total - flight.travelled) / cellSize
        }
        return CGFloat(grid.distance(at: dino.target))
    }

    private func fireTowers(_ dt: TimeInterval) {
        for tower in towers.values where tower.kind != .fence {
            tower.cooldown -= dt
            guard tower.cooldown <= 0 else { continue }
            let reach = tower.range * cellSize
            let inRange = dinos.filter {
                !$0.isDead
                    && ($0.kind.flies ? tower.kind.hitsAir : tower.kind.hitsGround)
                    && distance($0.position, tower.position) <= reach
            }
            guard !inRange.isEmpty else { continue }
            tower.cooldown = tower.kind.fireInterval

            if tower.kind == .flare {
                tower.showFire()
                pulse(from: tower, radius: reach)
                SoundBank.shared.play(.flare)
                for dino in inRange {
                    hit(dino, for: tower.damage)
                }
            } else if let target = inRange.min(by: { stepsLeft($0) < stepsLeft($1) }) {
                // Shoot whichever dino is closest to escaping.
                tower.aim(at: target.position)
                fire(from: tower, at: target)
            }
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
        shots.append(Shot(node: node, target: target, damage: tower.damage, slow: tower.kind.slow, splash: tower.kind.splash))
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
                    for other in dinos where other !== shot.target && other.kind.flies && distance(other.position, center) <= reach {
                        hit(other, for: shot.damage * 0.5)
                    }
                } else {
                    puff(at: shot.target.position, color: shot.slow == nil ? UIColor(hex: 0xFFE27A) : ParkArt.tranqLight)
                    SoundBank.shared.play(.hit)
                }
                hit(shot.target, for: shot.damage, slow: shot.slow)
                shot.node.removeFromParent()
                shot.done = true
            } else {
                shot.node.position.x += dx / dist * step
                shot.node.position.y += dy / dist * step
            }
        }
        shots.removeAll { $0.done }
    }

    private func hit(_ dino: Dino, for amount: CGFloat, slow: (factor: CGFloat, duration: TimeInterval)? = nil) {
        guard !dino.isDead else { return }
        if let slow {
            dino.slow(to: slow.factor, for: slow.duration)
        }
        // Armor soaks a flat amount from every hit, but something always gets through
        let dealt = max(1, amount - dino.kind.armor)
        if dino.takeDamage(dealt) {
            kill(dino)
        }
    }

    private func kill(_ dino: Dino) {
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
        let reward = max(1, Int((CGFloat(dino.kind.reward) * scale).rounded()))
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

        if won && challenge == nil {
            overlay.addChild(menuButton("Keep Going ∞", name: "endless", fill: Palette.warning, text: Palette.bar, outlined: false, y: -60))
            overlay.addChild(menuButton("Play Again", name: "restart", fill: Palette.panel, text: Palette.text, outlined: true, y: -120))
            overlay.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -180))
        } else {
            overlay.addChild(menuButton("Play Again", name: "restart", fill: Palette.warning, text: Palette.bar, outlined: false, y: -60))
            overlay.addChild(menuButton("Main Menu", name: "menu", fill: Palette.panel, text: Palette.text, outlined: true, y: -120))
        }
        gameOverOverlay = overlay
        SoundBank.shared.play(won ? .win : .lose)

        overlay.alpha = 0
        overlay.run(.sequence([.wait(forDuration: won ? 1.2 : 0), .fadeIn(withDuration: 0.3)]))
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
        let height: CGFloat = 100
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
        let titleLabel = makeLabel(title, size: 15, font: Fonts.heavy)
        titleLabel.name = "panel"
        titleLabel.position = CGPoint(x: 0, y: 26)
        panel.addChild(titleLabel)

        let sellTitle = "Sell $\(tower.sellValue)"
        if tower.kind == .fence {
            panel.addChild(menuButton(sellTitle, name: "sell", fill: Palette.panel, text: Palette.text, outlined: true,
                                      y: -14, width: width - 24, height: 42, fontSize: 15))
        } else {
            let upgradeTitle: String
            let canAfford: Bool
            if let cost = tower.upgradeCost {
                upgradeTitle = "Upgrade $\(cost)"
                canAfford = cash >= cost
            } else {
                upgradeTitle = "Max level"
                canAfford = false
            }
            panel.addChild(menuButton(upgradeTitle, name: "upgrade",
                                      fill: canAfford ? Palette.warning : Palette.panel,
                                      text: canAfford ? Palette.bar : Palette.muted,
                                      outlined: !canAfford,
                                      x: -width / 2 + 12 + 63, y: -14, width: 126, height: 42, fontSize: 15))
            panel.addChild(menuButton(sellTitle, name: "sell", fill: Palette.panel, text: Palette.text, outlined: true,
                                      x: width / 2 - 12 - 38, y: -14, width: 76, height: 42, fontSize: 14))
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
