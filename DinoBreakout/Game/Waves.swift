import Foundation

struct SpawnGroup {
    let kind: DinoKind
    let count: Int
    /// Seconds between each dino in the group.
    let every: TimeInterval
    /// Seconds after the wave starts that the group begins.
    var startAt: TimeInterval = 0
}

enum Waves {
    static let all: [[SpawnGroup]] = [
        [SpawnGroup(kind: .compy, count: 10, every: 0.9)],
        [SpawnGroup(kind: .compy, count: 16, every: 0.6)],
        [
            SpawnGroup(kind: .compy, count: 10, every: 0.6),
            SpawnGroup(kind: .raptor, count: 4, every: 1.2, startAt: 7)
        ],
        [SpawnGroup(kind: .raptor, count: 10, every: 0.9)],
        [
            SpawnGroup(kind: .triceratops, count: 3, every: 3),
            SpawnGroup(kind: .compy, count: 12, every: 0.5, startAt: 2)
        ],
        [
            SpawnGroup(kind: .raptor, count: 12, every: 0.7),
            SpawnGroup(kind: .compy, count: 10, every: 0.4, startAt: 4)
        ],
        [
            SpawnGroup(kind: .triceratops, count: 5, every: 2.4),
            SpawnGroup(kind: .raptor, count: 8, every: 0.8, startAt: 3)
        ],
        [
            SpawnGroup(kind: .compy, count: 24, every: 0.3),
            SpawnGroup(kind: .raptor, count: 10, every: 0.6, startAt: 5)
        ],
        [
            SpawnGroup(kind: .triceratops, count: 8, every: 1.8),
            SpawnGroup(kind: .raptor, count: 12, every: 0.6, startAt: 4)
        ],
        [
            SpawnGroup(kind: .raptor, count: 6, every: 0.7),
            SpawnGroup(kind: .triceratops, count: 4, every: 2, startAt: 3),
            SpawnGroup(kind: .rex, count: 1, every: 0, startAt: 10)
        ]
    ]

    /// Dinos get tougher every wave. `index` is zero based.
    static func healthScale(forWave index: Int) -> CGFloat {
        1 + 0.12 * CGFloat(index)
    }

    /// Flattens a wave into spawn times, earliest first.
    static func schedule(_ groups: [SpawnGroup]) -> [(at: TimeInterval, kind: DinoKind)] {
        groups
            .flatMap { group in
                (0..<group.count).map { (at: group.startAt + Double($0) * group.every, kind: group.kind) }
            }
            .sorted { $0.at < $1.at }
    }

    /// "compies and raptors" for the wave banner.
    static func summary(_ groups: [SpawnGroup]) -> String {
        var names: [String] = []
        for group in groups where !names.contains(group.kind.plural) {
            names.append(group.kind.plural)
        }
        return ListFormatter.localizedString(byJoining: names)
    }
}
