import SpriteKit

/// A dart or bullet in flight. Homes in on its target.
private final class Shot {
    let node: SKShapeNode
    let target: Dino
    let damage: CGFloat
    let slow: (factor: CGFloat, duration: TimeInterval)?
    var done = false

    init(node: SKShapeNode, target: Dino, damage: CGFloat, slow: (factor: CGFloat, duration: TimeInterval)?) {
        self.node = node
        self.target = target
        self.damage = damage
        self.slow = slow
    }
}

final class GameScene: SKScene {
    // MARK: Tuning

    private let cols = 9
    private let rows = 13
    private let startingCash = 120
    private let startingLives = 20
    private let topHeight: CGFloat = 60
    private let bottomHeight: CGFloat = 120

    // MARK: State

    private var grid = Grid(cols: 9, rows: 13)
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

    override func didMove(to view: SKView) {
        backgroundColor = Palette.bar
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

        let available = size.height - topHeight - bottomHeight
        cellSize = floor(min(size.width / CGFloat(cols), available / CGFloat(rows)))
        origin = CGPoint(
            x: (size.width - cellSize * CGFloat(cols)) / 2,
            y: bottomHeight + (available - cellSize * CGFloat(rows)) / 2
        )
        drawBoard()

        hud = HUD(size: size, topHeight: topHeight, bottomHeight: bottomHeight)
        addChild(hud)
        cash = startingCash
        lives = startingLives
        hud.setWave(0, of: Waves.all.count)
        hud.setSendEnabled(true)
        tool = .build(.fence)
        hud.select(tool)
        hud.flash("Build a maze, then tap Send Wave")
    }

    private func drawBoard() {
        let tileSize = CGSize(width: cellSize, height: cellSize)
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = Cell(col: col, row: row)
                let color: SKColor
                if cell == grid.spawn {
                    color = Palette.gate
                } else if cell == grid.exit {
                    color = Palette.pad
                } else {
                    color = (row + col).isMultiple(of: 2) ? Palette.groundA : Palette.groundB
                }
                let tile = SKSpriteNode(color: color, size: tileSize)
                tile.position = point(for: cell)
                world.addChild(tile)
            }
        }

        let gate = makeLabel("🚧", size: cellSize * 0.6)
        gate.position = point(for: grid.spawn)
        gate.zPosition = 1
        world.addChild(gate)

        let pad = makeLabel("🚁", size: cellSize * 0.6)
        pad.position = point(for: grid.exit)
        pad.zPosition = 1
        world.addChild(pad)
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
        if let action = hud.action(at: touch.location(in: self)) {
            switch action {
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
        if kind != .fence {
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
    }

    // MARK: - Waves

    private func sendWave() {
        guard !waveActive, !isOver, wavesStarted < Waves.all.count else { return }
        let wave = Waves.all[wavesStarted]
        wavesStarted += 1
        spawnQueue = Waves.schedule(wave)
        waveClock = 0
        waveActive = true
        hud.setWave(wavesStarted, of: Waves.all.count)
        hud.setSendEnabled(false, title: "Incoming")
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
            cellSize: cellSize
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
        let bonus = 10 + 3 * wavesStarted
        cash += bonus
        if wavesStarted == Waves.all.count {
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
        guard !isOver, dt > 0 else { return }

        spawnDue(dt)
        moveDinos(dt)
        fireTowers(dt)
        moveShots(dt)
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
                if abs(dx) > 0.5 {
                    dino.face(right: dx > 0)
                }
                if dist > budget {
                    dino.position.x += dx / dist * budget
                    dino.position.y += dy / dist * budget
                    break
                }
                dino.position = dest
                budget -= dist
                dino.cell = dino.target
                if dino.cell == grid.exit {
                    escaped.append(dino)
                    break
                }
                guard let next = grid.nextStep(from: dino.cell) else { break }
                dino.target = next
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
        let node = SKShapeNode(circleOfRadius: cellSize * 0.07)
        node.fillColor = tower.kind.shotColor
        node.strokeColor = .clear
        node.position = tower.position
        node.zPosition = 7
        world.addChild(node)
        shots.append(Shot(node: node, target: target, damage: tower.damage, slow: tower.kind.slow))
    }

    private func moveShots(_ dt: TimeInterval) {
        let step = cellSize * 9 * CGFloat(dt)
        for shot in shots {
            if shot.target.isDead {
                shot.node.removeFromParent()
                shot.done = true
                continue
            }
            let dx = shot.target.position.x - shot.node.position.x
            let dy = shot.target.position.y - shot.node.position.y
            let dist = hypot(dx, dy)
            if dist <= step {
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
        cash += dino.kind.reward
        floatText("+$\(dino.kind.reward)", at: dino.position)
        dinos.removeAll { $0 === dino }
        dino.run(.sequence([
            .group([.fadeOut(withDuration: 0.25), .scale(to: 1.4, duration: 0.25)]),
            .removeFromParent()
        ]))
    }

    private func endGame(won: Bool) {
        isOver = true
        waveActive = false

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
        overlay.run(.fadeIn(withDuration: 0.3))
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
        ring.strokeColor = tower.kind.color
        ring.fillColor = tower.kind.color.withAlphaComponent(0.2)
        ring.lineWidth = 2
        ring.zPosition = 4
        ring.setScale(0.3)
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1, duration: 0.25), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
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
