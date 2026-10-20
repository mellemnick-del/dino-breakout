import SpriteKit

/// A dart or bullet in flight. Homes in on its target.
private final class Shot {
    let node: SKSpriteNode
    let target: Dino
    let damage: CGFloat
    let slow: (factor: CGFloat, duration: TimeInterval)?
    var done = false

    init(node: SKSpriteNode, target: Dino, damage: CGFloat, slow: (factor: CGFloat, duration: TimeInterval)?) {
        self.node = node
        self.target = target
        self.damage = damage
        self.slow = slow
    }
}

final class GameScene: SKScene {
    // MARK: Tuning

    private let cols = 7
    private let rows = 11
    private let startingCash = 100
    private let startingLives = 20
    private let topHeight: CGFloat = 60
    private let bottomHeight: CGFloat = 120

    // MARK: State

    private var grid = Grid(cols: 7, rows: 11)
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
    /// Showing while the game is paused.
    private var pauseMenu: SKNode?

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

        grid = Grid(cols: cols, rows: rows)
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

        let available = size.height - topHeight - bottomHeight
        cellSize = floor(min(size.width / CGFloat(cols), available / CGFloat(rows)))
        origin = CGPoint(
            x: (size.width - cellSize * CGFloat(cols)) / 2,
            y: bottomHeight + (available - cellSize * CGFloat(rows)) / 2
        )
        drawBoard()

        // Bake every dino's walk cycle now so the first spawn doesn't hitch
        for kind in [DinoKind.compy, .raptor, .triceratops, .rex] {
            _ = DinoArt.bake(kind, cellSize: cellSize, screenScale: screenScale)
        }

        hud = HUD(size: size, topHeight: topHeight, bottomHeight: bottomHeight)
        addChild(hud)
        cash = startingCash
        lives = startingLives
        hud.setWave(0, of: Waves.total)
        hud.setSendEnabled(true)
        tool = .build(.fence)
        hud.select(tool)
        hud.flash("Build a maze, then tap Send Wave")
    }

    private func drawBoard() {
        let boardSize = CGSize(width: cellSize * CGFloat(cols), height: cellSize * CGFloat(rows))
        let ground = SKSpriteNode(texture: ParkArt.ground(cols: cols, rows: rows, cell: cellSize), size: boardSize)
        ground.anchorPoint = .zero
        ground.position = origin
        world.addChild(ground)

        wireLayer.zPosition = 2.5
        world.addChild(wireLayer)
        wireLayer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.5),
            .fadeAlpha(to: 1, duration: 0.5)
        ])))

        buildGate()
        buildHelipad()
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
        if isOver {
            startNewGame()
            return
        }
        if let menu = pauseMenu {
            let hits = menu.nodes(at: touch.location(in: menu)).compactMap { $0.name }
            if hits.contains("restart") {
                startNewGame()
            } else if hits.contains("resume") {
                closePauseMenu()
            }
            return
        }
        if let action = hud.action(at: touch.location(in: self)) {
            switch action {
            case .pause:
                openPauseMenu()
            case .sendWave:
                sendWave()
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
                upgrade(tower)
            }
            return
        }

        guard case .build(let kind)? = tool else {
            hud.flash("Pick something to build")
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
        let occupied = dinos.flatMap { [$0.cell, $0.target] }
        if occupied.contains(cell) {
            hud.flash("Too close to a dino")
            return
        }
        guard grid.block(cell, keeping: occupied) else {
            hud.flash("Dinos need a way through!")
            return
        }

        cash -= kind.cost
        let tower = Tower(kind: kind, cell: cell, cellSize: cellSize)
        tower.position = point(for: cell)
        tower.setScale(0.6)
        tower.run(.scale(to: 1, duration: 0.12))
        world.addChild(tower)
        towers[cell] = tower
        if kind == .fence {
            rebuildWires()
        } else {
            showRange(of: tower)
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
        hud.flash("\(tower.kind.title) level \(tower.level)")
        showRange(of: tower)
    }

    private func sell(_ tower: Tower) {
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
        guard !waveActive, !isOver, wavesStarted < Waves.total else { return }
        let wave = Waves.groups(forWave: wavesStarted + 1)
        wavesStarted += 1
        spawnQueue = Waves.schedule(wave)
        waveClock = 0
        waveActive = true
        hud.setWave(wavesStarted, of: Waves.total)
        hud.setSendEnabled(false, title: "Incoming")
        setGate(open: true)
        hud.flash("Wave \(wavesStarted): \(Waves.summary(wave))")
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
            healthScale: Waves.healthScale(forWave: wavesStarted - 1),
            cell: grid.spawn,
            cellSize: cellSize,
            screenScale: screenScale
        )
        dino.target = grid.nextStep(from: grid.spawn) ?? grid.spawn
        dino.position = point(for: grid.spawn)
        world.addChild(dino)
        dinos.append(dino)

        if kind == .rex {
            hud.flash("🦖 The ground is shaking...")
            shakeWorld()
        }
    }

    private func checkWaveEnd() {
        guard waveActive, spawnQueue.isEmpty, dinos.isEmpty else { return }
        waveActive = false
        setGate(open: false)
        let bonus = 8 + 2 * wavesStarted
        cash += bonus
        if wavesStarted == Waves.total {
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

        spawnDue(dt)
        moveDinos(dt)
        fireTowers(dt)
        moveShots(dt)
        sparkFences(dt)
        checkWaveEnd()
    }

    private func moveDinos(_ dt: TimeInterval) {
        var escaped: [Dino] = []
        for dino in dinos {
            dino.tick(dt)
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
            hud.flash("\(dino.kind.name) reached the helipad!")
            flashDanger()
            if lives == 0 {
                endGame(won: false)
                return
            }
        }
    }

    private func fireTowers(_ dt: TimeInterval) {
        for tower in towers.values where tower.kind != .fence {
            tower.cooldown -= dt
            guard tower.cooldown <= 0 else { continue }
            let reach = tower.range * cellSize
            let inRange = dinos.filter { !$0.isDead && distance($0.position, tower.position) <= reach }
            guard !inRange.isEmpty else { continue }
            tower.cooldown = tower.kind.fireInterval

            if tower.kind == .flare {
                tower.showFire()
                pulse(from: tower, radius: reach)
                for dino in inRange {
                    hit(dino, for: tower.damage)
                }
            } else if let target = inRange.min(by: { grid.distance(at: $0.target) < grid.distance(at: $1.target) }) {
                // Shoot whichever dino is closest to escaping.
                tower.aim(at: target.position)
                fire(from: tower, at: target)
            }
        }
    }

    private func fire(from tower: Tower, at target: Dino) {
        tower.showFire()
        let isDart = tower.kind == .tranq
        let node = isDart
            ? SKSpriteNode(texture: ParkArt.dart(cell: cellSize), size: CGSize(width: cellSize * 0.26, height: cellSize * 0.1))
            : SKSpriteNode(texture: ParkArt.tracer(cell: cellSize), size: CGSize(width: cellSize * 0.3, height: cellSize * 0.1))
        let angle = atan2(target.position.y - tower.position.y, target.position.x - tower.position.x)
        node.zRotation = angle
        node.position = CGPoint(x: tower.position.x + cos(angle) * cellSize * 0.45, y: tower.position.y + sin(angle) * cellSize * 0.45)
        node.zPosition = 7
        world.addChild(node)
        shots.append(Shot(node: node, target: target, damage: tower.damage, slow: tower.kind.slow))
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
                puff(at: shot.target.position, color: shot.slow == nil ? UIColor(hex: 0xFFE27A) : ParkArt.tranqLight)
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
        if dino.takeDamage(amount) {
            kill(dino)
        }
    }

    private func kill(_ dino: Dino) {
        let reward = Int((CGFloat(dino.kind.reward) * Waves.rewardScale(forWave: max(0, wavesStarted - 1))).rounded())
        cash += reward
        floatText("+$\(reward)", at: dino.position)
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

        let title = makeLabel(
            won ? "EVACUATION COMPLETE" : "PARK LOST",
            size: 28,
            font: Fonts.heavy,
            color: won ? Palette.warning : Palette.danger
        )
        title.position = CGPoint(x: 0, y: 30)
        overlay.addChild(title)

        let detail = makeLabel(
            won ? "Everyone made it out. \(lives) lives left." : "The dinos overran the helipad on wave \(wavesStarted).",
            size: 15
        )
        detail.position = CGPoint(x: 0, y: -8)
        overlay.addChild(detail)

        let again = makeLabel("Tap to play again", size: 15, color: Palette.muted)
        again.position = CGPoint(x: 0, y: -44)
        overlay.addChild(again)

        overlay.alpha = 0
        overlay.run(.sequence([.wait(forDuration: won ? 1.2 : 0), .fadeIn(withDuration: 0.3)]))
    }

    // MARK: - Pause menu

    private func openPauseMenu() {
        guard pauseMenu == nil, !isOver else { return }
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

        let status = makeLabel("Wave \(wavesStarted) of \(Waves.total)  ·  \(lives) lives  ·  $\(cash)", size: 14, color: Palette.muted)
        status.position = CGPoint(x: 0, y: 64)
        menu.addChild(status)

        menu.addChild(menuButton("Resume", name: "resume", fill: Palette.warning, text: Palette.bar, outlined: false, y: 10))
        menu.addChild(menuButton("Restart", name: "restart", fill: Palette.panel, text: Palette.danger, outlined: true, y: -50))

        let note = makeLabel("Restarting starts over from wave 1", size: 13, color: Palette.muted)
        note.position = CGPoint(x: 0, y: -94)
        menu.addChild(note)
    }

    private func closePauseMenu() {
        pauseMenu?.removeFromParent()
        pauseMenu = nil
        world.isPaused = false
    }

    private func menuButton(_ title: String, name: String, fill: SKColor, text: SKColor, outlined: Bool, y: CGFloat) -> SKNode {
        let button = SKShapeNode(rectOf: CGSize(width: 200, height: 48), cornerRadius: 12)
        button.name = name
        button.fillColor = fill
        button.strokeColor = text.withAlphaComponent(0.6)
        button.lineWidth = outlined ? 2 : 0
        button.position = CGPoint(x: 0, y: y)
        let label = makeLabel(title, size: 18, font: Fonts.heavy, color: text)
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
