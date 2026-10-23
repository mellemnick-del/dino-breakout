import Foundation

/// A run in progress, saved between waves so closing the app never loses it.
/// There's one slot: starting a new park game replaces it. Daily challenges aren't saved.
struct SavedGame: Codable {
    struct SavedTower: Codable {
        let kind: String
        let col: Int
        let row: Int
        let level: Int
        let targeting: String
        /// Upgrade path picked at level 3, if any.
        var branch: String?
    }

    let levelId: String
    let difficulty: String
    let endless: Bool
    let startedEndless: Bool
    /// Waves cleared so far. The game resumes before the next one.
    let wave: Int
    let cash: Int
    let lives: Int
    let towers: [SavedTower]
    let kills: Int
    let damage: [String: Double]
    let playTime: Double
    let revived: Bool
    let lastAdBonusWave: Int

    private static let key = "savedGame"

    var level: Level? {
        Level.all.first { $0.id == levelId }
    }

    var difficultyLevel: Difficulty {
        Difficulty(rawValue: difficulty) ?? .medium
    }

    static func load() -> SavedGame? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.level != nil else { return nil }
        return saved
    }

    func store() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SavedGame.key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
