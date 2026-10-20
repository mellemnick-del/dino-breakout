import Foundation

/// One day's challenge: the same park, difficulty, and twist for everyone on
/// that date. Survive the waves to complete it.
struct DailyChallenge: Hashable {
    enum Twist: CaseIterable {
        case skyswarm, noFences, richButStingy, fastDinos, fiveLives, armored

        var title: String {
            switch self {
            case .skyswarm: "Sky Swarm"
            case .noFences: "No Fences"
            case .richButStingy: "Rich but Stingy"
            case .fastDinos: "Fast Dinos"
            case .fiveLives: "Five Lives"
            case .armored: "Armored Up"
            }
        }

        var detail: String {
            switch self {
            case .skyswarm: "Pterodactyls on almost every wave."
            case .noFences: "Fences are off limits. Build your maze from towers."
            case .richButStingy: "Start with $300, but bounties are halved."
            case .fastDinos: "Every dino moves 25% faster."
            case .fiveLives: "Only 5 lives. Nothing gets through."
            case .armored: "Dinos have 50% more health, and pay double."
            }
        }
    }

    static let waves = 20

    let dateKey: String
    let level: Level
    let difficulty: Difficulty
    let twist: Twist

    static var today: DailyChallenge {
        challenge(for: Date())
    }

    static func challenge(for date: Date) -> DailyChallenge {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)

        // A small seeded generator, so the pick is the same all day on every device
        var seed: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            seed = (seed ^ UInt64(byte)) &* 1099511628211
        }
        func next(_ count: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(count))
        }
        let difficulties: [Difficulty] = [.easy, .medium, .medium, .hard]
        return DailyChallenge(
            dateKey: key,
            level: Level.all[next(Level.all.count)],
            difficulty: difficulties[next(difficulties.count)],
            twist: Twist.allCases[next(Twist.allCases.count)]
        )
    }

    var displayDate: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateKey) else { return dateKey }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Rules

    var lives: Int {
        twist == .fiveLives ? 5 : difficulty.lives
    }

    var startingCash: Int {
        twist == .richButStingy ? 300 : difficulty.startingCash
    }

    var healthScale: CGFloat {
        twist == .armored ? 1.5 : 1
    }

    var bountyScale: CGFloat {
        switch twist {
        case .richButStingy: 0.5
        case .armored: 2
        default: 1
        }
    }

    var speedScale: CGFloat {
        twist == .fastDinos ? 1.25 : 1
    }

    var flyerHeavy: Bool {
        twist == .skyswarm
    }

    var allowsFences: Bool {
        twist != .noFences
    }

    // MARK: Results

    var best: Int {
        UserDefaults.standard.integer(forKey: "daily-\(dateKey)")
    }

    var isComplete: Bool {
        best >= DailyChallenge.waves
    }

    func record(wave: Int) {
        guard !Progress.testMode, wave > best else { return }
        UserDefaults.standard.set(wave, forKey: "daily-\(dateKey)")
    }
}
