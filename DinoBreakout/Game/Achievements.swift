import Foundation

enum Achievement: String, CaseIterable, Identifiable {
    case firstBite, holdingTheLine, evacuationComplete, hardTarget, parkRanger
    case rexWrangler, flakAce, untouchable, fullyLoaded, mazeMaster
    case neverOff, fastForward, dailyDriver, plateBreaker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstBite: "First Bite"
        case .holdingTheLine: "Holding the Line"
        case .evacuationComplete: "Evacuation Complete"
        case .hardTarget: "Hard Target"
        case .parkRanger: "Park Ranger"
        case .rexWrangler: "Rex Wrangler"
        case .flakAce: "Flak Ace"
        case .untouchable: "Untouchable"
        case .fullyLoaded: "Fully Loaded"
        case .mazeMaster: "Maze Master"
        case .neverOff: "Never Off"
        case .fastForward: "Fast Forward"
        case .dailyDriver: "Daily Driver"
        case .plateBreaker: "Plate Breaker"
        }
    }

    var detail: String {
        switch self {
        case .firstBite: "Take down your first dino."
        case .holdingTheLine: "Clear wave 10 on any park."
        case .evacuationComplete: "Beat all 50 waves on any park."
        case .hardTarget: "Beat a park on Hard."
        case .parkRanger: "Beat every park."
        case .rexWrangler: "Take down 10 T-Rexes."
        case .flakAce: "Shoot down 100 pterodactyls."
        case .untouchable: "Clear a T-Rex boss wave without losing a life."
        case .fullyLoaded: "Upgrade a tower to level 5."
        case .mazeMaster: "Have 40 fences up at once."
        case .neverOff: "Reach wave 75 in endless mode."
        case .fastForward: "Clear a wave at 3x speed."
        case .dailyDriver: "Complete a daily challenge."
        case .plateBreaker: "Take down 25 stegosaurs."
        }
    }

    /// SF Symbol for the trophy room.
    var symbol: String {
        switch self {
        case .firstBite: "flame.fill"
        case .holdingTheLine: "shield.fill"
        case .evacuationComplete: "airplane.departure"
        case .hardTarget: "scope"
        case .parkRanger: "map.fill"
        case .rexWrangler: "crown.fill"
        case .flakAce: "bird.fill"
        case .untouchable: "heart.fill"
        case .fullyLoaded: "star.circle.fill"
        case .mazeMaster: "square.grid.3x3.fill"
        case .neverOff: "infinity"
        case .fastForward: "forward.fill"
        case .dailyDriver: "calendar"
        case .plateBreaker: "hammer.fill"
        }
    }
}

/// Earned achievements and the running tallies behind some of them, saved on the device.
enum Achievements {
    static let rexKills = "tally-rex"
    static let pteroKills = "tally-ptero"
    static let stegoKills = "tally-stego"

    static func isEarned(_ achievement: Achievement) -> Bool {
        UserDefaults.standard.bool(forKey: key(achievement))
    }

    static var earnedCount: Int {
        Achievement.allCases.filter { isEarned($0) }.count
    }

    /// Returns true the first time it's earned, so the game can celebrate.
    /// Nothing is earned in test mode.
    @discardableResult
    static func earn(_ achievement: Achievement) -> Bool {
        guard !Progress.testMode, !isEarned(achievement) else { return false }
        UserDefaults.standard.set(true, forKey: key(achievement))
        GameCenter.report([achievement])
        return true
    }

    /// Adds to a lifetime tally and returns the new total.
    static func tally(_ name: String, by amount: Int = 1) -> Int {
        guard !Progress.testMode else { return 0 }
        let total = UserDefaults.standard.integer(forKey: name) + amount
        UserDefaults.standard.set(total, forKey: name)
        return total
    }

    private static func key(_ achievement: Achievement) -> String {
        "achievement-\(achievement.rawValue)"
    }
}
