import Foundation

/// Permanent upgrades bought with amber, which every run earns as it goes.
/// Research applies to park games and endless runs, never to daily challenges,
/// so every player meets the daily on the same footing.
enum ResearchProject: String, CaseIterable, Identifiable {
    case cheapFences, startingCash, extraLives, optics, bounty, savings, chopperFuel

    var id: String { rawValue }

    static let maxLevel = 3

    var title: String {
        switch self {
        case .cheapFences: "Surplus Fencing"
        case .startingCash: "Bigger Budget"
        case .extraLives: "Reinforced Helipad"
        case .optics: "Better Optics"
        case .bounty: "Bounty Hunters"
        case .savings: "Savings Account"
        case .chopperFuel: "Chopper Fuel"
        }
    }

    /// What one level does.
    var detail: String {
        switch self {
        case .cheapFences: "Fences cost $1 less"
        case .startingCash: "Start every park with $25 more"
        case .extraLives: "Start with 2 more lives"
        case .optics: "Every tower reaches 6% farther"
        case .bounty: "Dinos pay 6% more cash"
        case .savings: "Interest can pay up to $15 more per wave"
        case .chopperFuel: "Air strikes hit 30% harder"
        }
    }

    var symbol: String {
        switch self {
        case .cheapFences: "bolt.horizontal.fill"
        case .startingCash: "dollarsign.circle.fill"
        case .extraLives: "heart.fill"
        case .optics: "scope"
        case .bounty: "star.circle.fill"
        case .savings: "building.columns.fill"
        case .chopperFuel: "fuelpump.fill"
        }
    }

    /// Amber for the next level, or nil when maxed.
    var nextCost: Int? {
        let costs = [10, 25, 50]
        let level = Research.level(self)
        return level < costs.count ? costs[level] : nil
    }
}

enum Research {
    private static let amberKey = "research-amber"

    /// Amber on hand. Fractions carry over between waves.
    static var amberExact: Double {
        UserDefaults.standard.double(forKey: amberKey)
    }

    static var amber: Int {
        Int(amberExact)
    }

    /// Nothing is earned in test mode.
    static func earn(_ amount: Double) {
        guard !Progress.testMode, amount > 0 else { return }
        UserDefaults.standard.set(amberExact + amount, forKey: amberKey)
    }

    static func level(_ project: ResearchProject) -> Int {
        min(ResearchProject.maxLevel, UserDefaults.standard.integer(forKey: "research-\(project.rawValue)"))
    }

    /// Returns false if it's maxed or there isn't enough amber.
    @discardableResult
    static func buy(_ project: ResearchProject) -> Bool {
        guard let cost = project.nextCost, amber >= cost else { return false }
        UserDefaults.standard.set(amberExact - Double(cost), forKey: amberKey)
        UserDefaults.standard.set(level(project) + 1, forKey: "research-\(project.rawValue)")
        return true
    }

    /// The bonuses for one run. Daily challenges get none.
    struct Bonuses {
        var fenceDiscount = 0
        var startingCash = 0
        var lives = 0
        var rangeScale: CGFloat = 1
        var bountyScale: CGFloat = 1
        var interestCapBonus = 0
        var strikeScale: CGFloat = 1
    }

    static func bonuses(dailyChallenge: Bool) -> Bonuses {
        guard !dailyChallenge else { return Bonuses() }
        return Bonuses(
            fenceDiscount: level(.cheapFences),
            startingCash: 25 * level(.startingCash),
            lives: 2 * level(.extraLives),
            rangeScale: 1 + 0.06 * CGFloat(level(.optics)),
            bountyScale: 1 + 0.06 * CGFloat(level(.bounty)),
            interestCapBonus: 15 * level(.savings),
            strikeScale: 1 + 0.3 * CGFloat(level(.chopperFuel))
        )
    }

    /// Amber for clearing a wave: harder difficulties pay more.
    static func amberPerWave(_ difficulty: Difficulty) -> Double {
        switch difficulty {
        case .easy: 0.75
        case .medium: 1
        case .hard: 1.5
        }
    }

    /// Bonus amber for beating all 50 waves or finishing the daily challenge.
    static let winBonus: Double = 15
}
