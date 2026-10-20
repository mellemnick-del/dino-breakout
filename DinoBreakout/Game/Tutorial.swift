import SpriteKit

/// A short guided first game on Paddock B: build a maze, place a turret,
/// send a wave, and upgrade. Each step waits for the player to do it.
final class Tutorial {
    enum Event {
        case fenceBuilt(total: Int)
        case towerBuilt
        case waveStarted
        case waveCleared
        case upgraded
    }

    enum Step: Int, CaseIterable {
        case welcome, fences, turret, send, firstWave, upgrade, tips

        var text: String {
            switch self {
            case .welcome:
                "Dinos break out of the gate at the top and run for the rescue chopper at the bottom. Every one that gets there costs you lives."
            case .fences:
                "Pick Fence below, then tap empty squares to build walls. Dinos always take the shortest way around, so you're building a maze. Build 4 fences."
            case .turret:
                "Now some firepower. Pick Turret and place one right beside your maze."
            case .send:
                "Ready? Tap Send Wave."
            case .firstWave:
                "Your turret shoots anything in range, and every kill pays cash. Hold the line!"
            case .upgrade:
                "Nice. Tap your turret to open its panel, then tap Upgrade. Each tower also has a special ability in that panel."
            case .tips:
                "Tranqs slow dinos. Flares burn crowds. Flak shoots down pterodactyls. Pause is at the top left. Good luck!"
            }
        }

        /// Steps the player taps through instead of doing something on the board.
        var buttonTitle: String? {
            switch self {
            case .welcome: "Next"
            case .tips: "Let's go"
            default: nil
            }
        }
    }

    static let doneKey = "tutorialDone"

    static var hasFinished: Bool {
        UserDefaults.standard.bool(forKey: doneKey)
    }

    static func reset() {
        UserDefaults.standard.set(false, forKey: doneKey)
    }

    let node = SKNode()
    private(set) var step: Step = .welcome
    private(set) var isDone = false

    private let size: CGSize
    private let topY: CGFloat
    /// Where to draw the attention ring for a step, in scene coordinates.
    private let highlight: (Step) -> CGRect?

    init(size: CGSize, topY: CGFloat, highlight: @escaping (Step) -> CGRect?) {
        self.size = size
        self.topY = topY
        self.highlight = highlight
        node.zPosition = 92
        show()
    }

    func handle(_ event: Event) {
        guard !isDone else { return }
        switch (step, event) {
        case (.fences, .fenceBuilt(let total)):
            if total >= 4 {
                advance()
            }
        case (.turret, .towerBuilt),
             (.send, .waveStarted),
             (.firstWave, .waveCleared),
             (.upgrade, .upgraded):
            advance()
        default:
            break
        }
    }

    /// Returns true when the tap landed on the tutorial card.
    func handleTap(at point: CGPoint) -> Bool {
        guard !isDone else { return false }
        let names = node.nodes(at: point).compactMap { $0.name }
        if names.contains("coach-skip") {
            finish()
            return true
        }
        if names.contains("coach-next") {
            advance()
            return true
        }
        return names.contains("coach-card")
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        step = next
        SoundBank.shared.play(.place)
        show()
    }

    private func finish() {
        isDone = true
        UserDefaults.standard.set(true, forKey: Tutorial.doneKey)
        node.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    private func show() {
        node.removeAllChildren()
        let width = min(size.width - 24, 380)

        let text = SKLabelNode(fontNamed: Fonts.bold)
        text.text = step.text
        text.fontSize = 15
        text.fontColor = Palette.text
        text.numberOfLines = 0
        text.preferredMaxLayoutWidth = width - 32
        text.lineBreakMode = .byWordWrapping
        text.horizontalAlignmentMode = .left
        text.verticalAlignmentMode = .top
        let textHeight = text.frame.height
        let height = textHeight + (step.buttonTitle == nil ? 58 : 100)

        let card = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 16)
        card.name = "coach-card"
        card.fillColor = Palette.bar.withAlphaComponent(0.96)
        card.strokeColor = Palette.warning
        card.lineWidth = 2
        card.position = CGPoint(x: size.width / 2, y: topY - 12 - height / 2)
        node.addChild(card)

        let heading = makeLabel("TUTORIAL  ·  \(step.rawValue + 1) OF \(Step.allCases.count)", size: 11, font: Fonts.heavy, color: Palette.warning)
        heading.name = "coach-card"
        heading.horizontalAlignmentMode = .left
        heading.position = CGPoint(x: -width / 2 + 16, y: height / 2 - 18)
        card.addChild(heading)

        let skip = makeLabel("Skip", size: 13, font: Fonts.heavy, color: Palette.muted)
        skip.name = "coach-skip"
        skip.horizontalAlignmentMode = .right
        skip.position = CGPoint(x: width / 2 - 16, y: height / 2 - 18)
        card.addChild(skip)
        let skipTarget = SKSpriteNode(color: .clear, size: CGSize(width: 64, height: 36))
        skipTarget.name = "coach-skip"
        skipTarget.position = CGPoint(x: width / 2 - 36, y: height / 2 - 18)
        card.addChild(skipTarget)

        text.name = "coach-card"
        text.position = CGPoint(x: -width / 2 + 16, y: height / 2 - 34)
        card.addChild(text)

        if let title = step.buttonTitle {
            let button = SKShapeNode(rectOf: CGSize(width: 140, height: 40), cornerRadius: 12)
            button.name = "coach-next"
            button.fillColor = Palette.warning
            button.lineWidth = 0
            button.position = CGPoint(x: width / 2 - 16 - 70, y: -height / 2 + 16 + 20)
            let label = makeLabel(title, size: 16, font: Fonts.heavy, color: Palette.bar)
            label.name = "coach-next"
            button.addChild(label)
            card.addChild(button)
        }

        if let target = highlight(step) {
            let ring = SKShapeNode(rect: target.insetBy(dx: -5, dy: -5), cornerRadius: 14)
            ring.strokeColor = Palette.warning
            ring.lineWidth = 3
            ring.fillColor = .clear
            ring.glowWidth = 4
            ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.45), .fadeAlpha(to: 1, duration: 0.45)])))
            node.addChild(ring)
        }

        node.alpha = 0
        node.run(.fadeIn(withDuration: 0.2))
    }
}
