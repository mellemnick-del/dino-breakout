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
    case sendWave
    case pick(Tool)
}

/// Top bar (lives, cash, wave, Send Wave) and the build bar along the bottom.
final class HUD: SKNode {
    private let livesLabel = makeLabel("", size: 16, font: Fonts.heavy)
    private let cashLabel = makeLabel("", size: 16, font: Fonts.heavy)
    private let waveLabel = makeLabel("", size: 16, font: Fonts.heavy)
    private let sendButton = SKShapeNode(rectOf: CGSize(width: 118, height: 38), cornerRadius: 10)
    private let sendLabel = makeLabel("Send Wave", size: 15, font: Fonts.heavy, color: Palette.bar)
    private let message = makeLabel("", size: 15, font: Fonts.heavy, color: Palette.warning)
    private var toolButtons: [(tool: Tool, node: SKShapeNode)] = []

    init(size: CGSize, topHeight: CGFloat, bottomHeight: CGFloat) {
        super.init()
        zPosition = 50

        // Top bar
        let top = SKSpriteNode(color: Palette.bar, size: CGSize(width: size.width, height: topHeight))
        top.position = CGPoint(x: size.width / 2, y: size.height - topHeight / 2)
        addChild(top)

        let midY = size.height - topHeight / 2
        for (label, x) in [(livesLabel, 14.0), (cashLabel, 76.0), (waveLabel, 152.0)] {
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: x, y: midY)
            addChild(label)
        }

        sendButton.position = CGPoint(x: size.width - 14 - 59, y: midY)
        sendButton.lineWidth = 0
        sendButton.addChild(sendLabel)
        addChild(sendButton)

        // Bottom bar
        let bottom = SKSpriteNode(color: Palette.bar, size: CGSize(width: size.width, height: bottomHeight))
        bottom.position = CGPoint(x: size.width / 2, y: bottomHeight / 2)
        addChild(bottom)

        message.position = CGPoint(x: size.width / 2, y: bottomHeight - 16)
        addChild(message)

        let tools: [Tool] = BuildKind.allCases.map { .build($0) } + [.sell]
        let gap: CGFloat = 6
        let pad: CGFloat = 10
        let width = (size.width - pad * 2 - gap * CGFloat(tools.count - 1)) / CGFloat(tools.count)
        let height = bottomHeight - 40
        for (i, tool) in tools.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
            button.fillColor = Palette.panel
            button.position = CGPoint(x: pad + width / 2 + CGFloat(i) * (width + gap), y: 8 + height / 2)

            let icon: String
            let title: String
            let price: String
            switch tool {
            case .build(let kind):
                icon = kind.icon
                title = kind.title
                price = "$\(kind.cost)"
            case .sell:
                icon = "💲"
                title = "Sell"
                price = "70%"
            }
            let iconLabel = makeLabel(icon, size: 22)
            iconLabel.position = CGPoint(x: 0, y: 12)
            let titleLabel = makeLabel(title, size: 12)
            titleLabel.position = CGPoint(x: 0, y: -10)
            let priceLabel = makeLabel(price, size: 11, color: Palette.warning)
            priceLabel.position = CGPoint(x: 0, y: -24)
            button.addChild(iconLabel)
            button.addChild(titleLabel)
            button.addChild(priceLabel)

            addChild(button)
            toolButtons.append((tool, button))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func setLives(_ lives: Int) {
        livesLabel.text = "❤️ \(lives)"
    }

    func setCash(_ cash: Int) {
        cashLabel.text = "💰 \(cash)"
    }

    func setWave(_ wave: Int, of total: Int) {
        waveLabel.text = "Wave \(wave)/\(total)"
    }

    func setSendEnabled(_ enabled: Bool, title: String = "Send Wave") {
        sendLabel.text = title
        sendButton.fillColor = enabled ? Palette.warning : Palette.panel
        sendLabel.fontColor = enabled ? Palette.bar : Palette.muted
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
        message.removeAllActions()
        message.alpha = 1
        message.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.4)]))
    }

    /// Which control, if any, sits under a point in scene coordinates.
    func action(at point: CGPoint) -> HUDAction? {
        if sendButton.contains(point) {
            return .sendWave
        }
        if let hit = toolButtons.first(where: { $0.node.contains(point) }) {
            return .pick(hit.tool)
        }
        return nil
    }
}
