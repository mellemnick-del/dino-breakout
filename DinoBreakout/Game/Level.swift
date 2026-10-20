import Foundation

/// One park to defend. Every park uses the same size board; what changes is
/// where the dinos break out, where the chopper waits, and the terrain in the way.
struct Level: Identifiable, Hashable {
    static let cols = 9
    static let rows = 13

    let id: String
    let name: String
    let blurb: String
    /// Paddock gate, where dinos break out.
    let spawn: Cell
    /// Helipad, what you're defending.
    let exit: Cell
    /// Boulders. Nothing can walk through or build on them.
    var rocks: [Cell] = []
    /// River squares. Nothing can walk through or build on them.
    var water: [Cell] = []
    /// Ground squares drawn as planks across the river. You can build on them.
    var bridges: [Cell] = []
    /// Lava pools. Nothing can walk through or build on them.
    var lava: [Cell] = []
    /// Park buildings. Nothing can walk through or build on them.
    var buildings: [Cell] = []
    /// Volcanic ash instead of grass.
    var ash = false
    /// Pterodactyls on almost every wave, starting early.
    var flyerHeavy = false

    var terrain: Set<Cell> {
        Set(rocks + water + lava + buildings)
    }

    /// The park before this one in the list, which unlocks it.
    var previous: Level? {
        guard let index = Level.all.firstIndex(of: self), index > 0 else { return nil }
        return Level.all[index - 1]
    }

    static let all: [Level] = [
        Level(
            id: "paddock-b",
            name: "Paddock B",
            blurb: "Open field, gate to helipad. The classic breakout.",
            spawn: Cell(col: 4, row: 12),
            exit: Cell(col: 4, row: 0)
        ),
        Level(
            id: "raptor-ridge",
            name: "Raptor Ridge",
            blurb: "Boulders everywhere, and the chopper's in the far corner.",
            spawn: Cell(col: 0, row: 12),
            exit: Cell(col: 8, row: 0),
            rocks: [
                Cell(col: 2, row: 10), Cell(col: 3, row: 10), Cell(col: 6, row: 9),
                Cell(col: 1, row: 8), Cell(col: 4, row: 7), Cell(col: 7, row: 6),
                Cell(col: 2, row: 5), Cell(col: 5, row: 4), Cell(col: 0, row: 3),
                Cell(col: 3, row: 2), Cell(col: 6, row: 2), Cell(col: 5, row: 1)
            ]
        ),
        Level(
            id: "jungle-river",
            name: "Jungle River",
            blurb: "A river splits the park. Two bridges, and the dinos know it.",
            spawn: Cell(col: 4, row: 12),
            exit: Cell(col: 4, row: 0),
            water: [0, 2, 3, 4, 5, 6, 8].map { Cell(col: $0, row: 6) },
            bridges: [Cell(col: 1, row: 6), Cell(col: 7, row: 6)]
        ),
        Level(
            id: "visitor-center",
            name: "Visitor Center",
            blurb: "The dinos are loose in the tourist area. Maze them around the buildings.",
            spawn: Cell(col: 0, row: 12),
            exit: Cell(col: 8, row: 0),
            buildings: [
                Cell(col: 2, row: 9), Cell(col: 3, row: 9), Cell(col: 2, row: 8), Cell(col: 3, row: 8),
                Cell(col: 6, row: 10), Cell(col: 7, row: 10),
                Cell(col: 5, row: 6), Cell(col: 6, row: 6), Cell(col: 5, row: 5), Cell(col: 6, row: 5),
                Cell(col: 1, row: 4), Cell(col: 1, row: 3),
                Cell(col: 3, row: 2), Cell(col: 4, row: 2)
            ]
        ),
        Level(
            id: "aviary",
            name: "The Aviary",
            blurb: "Someone left the aviary open. Pterodactyls from wave 3.",
            spawn: Cell(col: 4, row: 12),
            exit: Cell(col: 4, row: 0),
            rocks: [Cell(col: 1, row: 10), Cell(col: 7, row: 10), Cell(col: 4, row: 6), Cell(col: 1, row: 2), Cell(col: 7, row: 2)],
            flyerHeavy: true
        ),
        Level(
            id: "mount-ember",
            name: "Mount Ember",
            blurb: "Lava pools on the slopes of a waking volcano. The hardest park.",
            spawn: Cell(col: 4, row: 12),
            exit: Cell(col: 4, row: 0),
            lava: [
                Cell(col: 1, row: 9), Cell(col: 2, row: 9), Cell(col: 6, row: 9), Cell(col: 7, row: 9),
                Cell(col: 3, row: 6), Cell(col: 4, row: 6), Cell(col: 5, row: 6),
                Cell(col: 0, row: 3), Cell(col: 1, row: 3), Cell(col: 7, row: 3), Cell(col: 8, row: 3)
            ],
            ash: true
        )
    ]
}

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var blurb: String {
        switch self {
        case .easy: "30 lives, $150 to start, softer dinos."
        case .medium: "20 lives, $100 to start. The intended fight."
        case .hard: "10 lives, $80 to start, tougher dinos, smaller bounties."
        }
    }

    var lives: Int {
        switch self {
        case .easy: 30
        case .medium: 20
        case .hard: 10
        }
    }

    var startingCash: Int {
        switch self {
        case .easy: 150
        case .medium: 100
        case .hard: 80
        }
    }

    /// Multiplies every dino's health.
    var health: CGFloat {
        switch self {
        case .easy: 0.7
        case .medium: 1
        case .hard: 1.35
        }
    }

    /// Multiplies every bounty.
    var bounty: CGFloat {
        switch self {
        case .easy: 1.15
        case .medium: 1
        case .hard: 0.9
        }
    }
}

/// Best wave cleared, per park and difficulty, saved on the device.
enum Progress {
    /// Wave you need to reach on a park to unlock the next one.
    static let unlockWave = 10

    /// One star at wave 10, two at wave 25, three for beating all 50.
    static func stars(forBest wave: Int) -> Int {
        if wave >= Waves.total { return 3 }
        if wave >= 25 { return 2 }
        if wave >= 10 { return 1 }
        return 0
    }

    /// A park unlocks once you reach wave 10 on the park before it, on any difficulty.
    static func isUnlocked(_ level: Level) -> Bool {
        guard let previous = level.previous else { return true }
        return Difficulty.allCases.contains { best(level: previous, difficulty: $0) >= unlockWave }
    }

    static func totalStars(difficulty: Difficulty) -> Int {
        Level.all.reduce(0) { $0 + stars(forBest: best(level: $1, difficulty: difficulty)) }
    }

    static func best(level: Level, difficulty: Difficulty) -> Int {
        UserDefaults.standard.integer(forKey: key(level, difficulty))
    }

    static func record(wave: Int, level: Level, difficulty: Difficulty) {
        guard wave > best(level: level, difficulty: difficulty) else { return }
        UserDefaults.standard.set(wave, forKey: key(level, difficulty))
    }

    private static func key(_ level: Level, _ difficulty: Difficulty) -> String {
        "best-\(level.id)-\(difficulty.rawValue)"
    }
}
