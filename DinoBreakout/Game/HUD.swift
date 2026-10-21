import SpriteKit

enum Palette {
    static let groundA = SKColor(red: 0.21, green: 0.34, blue: 0.20, alpha: 1)
    static let groundB = SKColor(red: 0.23, green: 0.37, blue: 0.22, alpha: 1)
    static let gate = SKColor(red: 0.45, green: 0.18, blue: 0.14, alpha: 1)
    static let pad = SKColor(red: 0.35, green: 0.37, blue: 0.38, alpha: 1)
    static let bar = SKColor(red: 0.07, green: 0.11, blue: 0.08, alpha: 1)
    static let panel = SKColor(red: 0.13, green: 0.19, blue: 0.14, alpha: 1)
    static let warning = SKColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1)
    static let danger = SKColor(red: 0.86, green: 0.27, blue: 0.22, alpha: 1)
    static let text = SKColor(white: 0.95, alpha: 1)
    static let muted = SKColor(white: 0.55, alpha: 1)
}

enum Fonts {
    static let heavy = "AvenirNext-Heavy"
    static let bold = "AvenirNext-DemiBold"
}

func makeLabel(_ text: String, size: CGFloat, font: String = Fonts.bold, color: SKColor = Palette.text) -> SKLabelNode {
    let label = SKLabelNode(fontNamed: font)
    label.text = text
    label.fontSize = size
    label.fontColor = color
    label.verticalAlignmentMode = .center
    label.horizontalAlignmentMode = .center
    return label
}

enum Tool: Equatable {
    case build(BuildKind)
    case sell
}

enum HUDAction {
    case pause
    case sendWave
    case pick(Tool)
    case airstrike
}

/// Top bar (lives, cash, wave, Send Wave) and the build bar along the bottom.
final class HUD: SKNode {
    private let livesLabel = makeLabel("", size: 16, font: Fonts.heavy)
    private let cashLabel = makeLabel("", size: 16, font: Fonts.heavy)
    private let waveLabel = makeLabel("", size: 14, font: Fonts.heavy)
    private let sendButton = SKShapeNode(rectOf: CGSize(width: 104, height: 38), cornerRadius: 10)
    private let pauseButton = SKShapeNode(rectOf: CGSize(width: 32, height: 32), cornerRadius: 8)
    private let sendLabel = makeLabel("Send Wave", size: 15, font: Fonts.heavy, color: Palette.bar)
    private let message = makeLabel("", size: 15, font: Fonts.heavy, color: Palette.warning)
    /// Floats over the bottom of the board while a message shows.
    private let messagePill = SKShapeNode()
    private var toolButtons: [(tool: Tool, node: SKShapeNode)] = []
    private var priceLabels: [(cost: Int, label: SKLabelNode, button: SKShapeNode)] = []
    /// The air strike sits in the build bar's last slot, off the board.
    private var strikeButton = SKShapeNode()
    private let strikeStatus = makeLabel("Ready", size: 11, color: Palette.warning)
    private var messageMaxWidth: CGFloat = 300

    init(size: CGSize, topHeight: CGFloat, bottomHeight: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        super.init()
        zPosition = 50

        // Top bar
        let top = SKSpriteNode(color: Palette.bar, size: CGSize(width: size.width, height: topHeight))
        top.position = CGPoint(x: size.width / 2, y: size.height - topHeight / 2)
        addChild(top)

        let midY = size.height - topInset - (topHeight - topInset) / 2
        pauseButton.position = CGPoint(x: 28, y: midY)
        pauseButton.fillColor = Palette.panel
        pauseButton.strokeColor = SKColor(white: 1, alpha: 0.15)
        for x: CGFloat in [-4.5, 4.5] {
            let bar = SKSpriteNode(color: Palette.text, size: CGSize(width: 4, height: 14))
            bar.position = CGPoint(x: x, y: 0)
            pauseButton.addChild(bar)
        }
        addChild(pauseButton)

        let heart = SKSpriteNode(texture: ParkArt.heart(size: 20), size: CGSize(width: 20, height: 20))
        heart.position = CGPoint(x: 62, y: midY)
        addChild(heart)
        let coin = SKSpriteNode(texture: ParkArt.coinIcon(size: 20), size: CGSize(width: 20, height: 20))
        coin.position = CGPoint(x: 112, y: midY)
        addChild(coin)
        for (label, x) in [(livesLabel, 74.0), (cashLabel, 124.0)] {
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: x, y: midY)
            addChild(label)
        }
        // The wave count sits just left of the Send Wave button, clear of the cash
        waveLabel.horizontalAlignmentMode = .right
        waveLabel.position = CGPoint(x: size.width - 12 - 104 - 10, y: midY)
        addChild(waveLabel)

        sendButton.position = CGPoint(x: size.width - 12 - 52, y: midY)
        sendButton.lineWidth = 0
        sendButton.addChild(sendLabel)
        addChild(sendButton)

        // Bottom bar
        let bottom = SKSpriteNode(color: Palette.bar, size: CGSize(width: size.width, height: bottomHeight))
        bottom.position = CGPoint(x: size.width / 2, y: bottomHeight / 2)
        addChild(bottom)

        messagePill.fillColor = Palette.bar.withAlphaComponent(0.88)
        messagePill.strokeColor = Palette.warning.withAlphaComponent(0.4)
        messagePill.lineWidth = 1
        messagePill.position = CGPoint(x: size.width / 2, y: bottomHeight + 24)
        messagePill.alpha = 0
        messagePill.zPosition = 1
        addChild(messagePill)
        message.position = .zero
        messagePill.addChild(message)
        messageMaxWidth = size.width - 24

        // Five build buttons, then the air strike. Selling lives in each tower's panel.
        let tools: [Tool] = BuildKind.allCases.map { .build($0) }
        let slots = tools.count + 1
        let gap: CGFloat = 6
        let pad: CGFloat = 10
        let width = (size.width - pad * 2 - gap * CGFloat(slots - 1)) / CGFloat(slots)
        let height = bottomHeight - bottomInset - 12
        for (i, tool) in tools.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
            button.fillColor = Palette.panel
            button.position = CGPoint(x: pad + width / 2 + CGFloat(i) * (width + gap), y: bottomInset + 6 + height / 2)

            let title: String
            let price: String
            switch tool {
            case .build(let kind):
                title = kind.title
                price = "$\(kind.cost)"
            case .sell:
                title = "Sell"
                price = "70%"
            }
            let iconSprite = SKSpriteNode(texture: ParkArt.icon(for: tool, size: 34), size: CGSize(width: 34, height: 34))
            iconSprite.position = CGPoint(x: 0, y: 12)
            let titleLabel = makeLabel(title, size: 12)
            titleLabel.position = CGPoint(x: 0, y: -12)
            let priceLabel = makeLabel(price, size: 11, color: Palette.warning)
            priceLabel.position = CGPoint(x: 0, y: -25)
            button.addChild(iconSprite)
            button.addChild(titleLabel)
            button.addChild(priceLabel)
            if case .build(let kind) = tool {
                priceLabels.append((kind.cost, priceLabel, button))
            }

            addChild(button)
            toolButtons.append((tool, button))
        }

        strikeButton = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        strikeButton.fillColor = Palette.panel
        strikeButton.strokeColor = SKColor(white: 1, alpha: 0.15)
        strikeButton.position = CGPoint(x: pad + width / 2 + CGFloat(tools.count) * (width + gap), y: bottomInset + 6 + height / 2)
        let chopper = SKSpriteNode(texture: ParkArt.chopperBody(size: 26), size: CGSize(width: 36, height: 13))
        chopper.zRotation = .pi / 2
        chopper.position = CGPoint(x: 0, y: 12)
        strikeButton.addChild(chopper)
        let strikeTitle = makeLabel("Strike", size: 12)
        strikeTitle.position = CGPoint(x: 0, y: -12)
        strikeButton.addChild(strikeTitle)
        strikeStatus.position = CGPoint(x: 0, y: -25)
        strikeButton.addChild(strikeStatus)
        addChild(strikeButton)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func setLives(_ lives: Int) {
        livesLabel.text = "\(lives)"
    }

    func setCash(_ cash: Int) {
        cashLabel.text = "\(cash)"
        // Anything you can't afford dims, with its price in red
        for (cost, label, button) in priceLabels {
            let affordable = cash >= cost
            label.fontColor = affordable ? Palette.warning : Palette.danger
            button.alpha = affordable ? 1 : 0.55
        }
    }

    /// Pass nil for endless mode.
    func setWave(_ wave: Int, of total: Int?) {
        if let total {
            waveLabel.text = "Wave \(wave)/\(total)"
        } else {
            waveLabel.text = "Wave \(wave) ∞"
        }
    }

    func setSendEnabled(_ enabled: Bool, title: String = "Send Wave") {
        sendLabel.text = title
        sendButton.fillColor = enabled ? Palette.warning : Palette.panel
        sendLabel.fontColor = enabled ? Palette.bar : Palette.muted
    }

    /// During a wave the Send Wave button becomes the speed toggle.
    func setSpeed(_ speed: Int) {
        sendLabel.text = "Speed \(speed)x"
        sendButton.fillColor = speed == 1 ? Palette.panel : SKColor(red: 0.25, green: 0.53, blue: 0.79, alpha: 1)
        sendLabel.fontColor = Palette.text
    }

    /// Ready, armed (waiting for a tap on the board), or used until the next wave.
    func setStrike(ready: Bool, armed: Bool) {
        if armed {
            strikeButton.fillColor = Palette.danger
            strikeButton.strokeColor = .white
            strikeButton.lineWidth = 3
            strikeStatus.text = "Tap board"
            strikeStatus.fontColor = Palette.text
            strikeButton.alpha = 1
        } else if ready {
            strikeButton.fillColor = Palette.panel
            strikeButton.strokeColor = Palette.warning.withAlphaComponent(0.6)
            strikeButton.lineWidth = 1.5
            strikeStatus.text = "Ready"
            strikeStatus.fontColor = Palette.warning
            strikeButton.alpha = 1
        } else {
            strikeButton.fillColor = Palette.panel
            strikeButton.strokeColor = SKColor(white: 1, alpha: 0.15)
            strikeButton.lineWidth = 1
            strikeStatus.text = "Next wave"
            strikeStatus.fontColor = Palette.muted
            strikeButton.alpha = 0.55
        }
    }

    func select(_ tool: Tool?) {
        for (buttonTool, node) in toolButtons {
            let isOn = buttonTool == tool
            node.strokeColor = isOn ? Palette.warning : SKColor(white: 1, alpha: 0.15)
            node.lineWidth = isOn ? 3 : 1
        }
    }

    func flash(_ text: String) {
        message.text = text
        // Long messages shrink to fit the screen
        message.setScale(1)
        let textWidth = message.frame.width
        if textWidth > messageMaxWidth - 28 {
            message.setScale((messageMaxWidth - 28) / textWidth)
        }
        let pillWidth = min(messageMaxWidth, message.frame.width + 28)
        messagePill.path = CGPath(
            roundedRect: CGRect(x: -pillWidth / 2, y: -15, width: pillWidth, height: 30),
            cornerWidth: 15, cornerHeight: 15, transform: nil
        )
        messagePill.removeAllActions()
        messagePill.alpha = 1
        messagePill.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.4)]))
    }

    /// Where a build bar button sits, for the tutorial's attention ring.
    func frame(for tool: Tool) -> CGRect? {
        toolButtons.first(where: { $0.tool == tool })?.node.frame
    }

    var sendButtonFrame: CGRect {
        sendButton.frame
    }

    /// Which control, if any, sits under a point in scene coordinates.
    func action(at point: CGPoint) -> HUDAction? {
        if pauseButton.contains(point) {
            return .pause
        }
        if sendButton.contains(point) {
            return .sendWave
        }
        if let hit = toolButtons.first(where: { $0.node.contains(point) }) {
            return .pick(hit.tool)
        }
        if strikeButton.contains(point) {
            return .airstrike
        }
        return nil
    }
}
