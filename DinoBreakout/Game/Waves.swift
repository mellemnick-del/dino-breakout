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
        [SpawnGroup(kind: .compy, count: 12, every: 0.8)],
        [SpawnGroup(kind: .compy, count: 20, every: 0.5)],
        [
            SpawnGroup(kind: .compy, count: 14, every: 0.5),
            SpawnGroup(kind: .raptor, count: 6, every: 1.0, startAt: 6)
        ],
        [SpawnGroup(kind: .raptor, count: 14, every: 0.75)],
        [
            SpawnGroup(kind: .triceratops, count: 4, every: 2.5),
            SpawnGroup(kind: .compy, count: 18, every: 0.4, startAt: 2)
        ],
        [
            SpawnGroup(kind: .raptor, count: 16, every: 0.6),
            SpawnGroup(kind: .compy, count: 14, every: 0.35, startAt: 4)
        ],
        [
            SpawnGroup(kind: .triceratops, count: 7, every: 2.0),
            SpawnGroup(kind: .raptor, count: 10, every: 0.7, startAt: 3)
        ],
        [
            SpawnGroup(kind: .compy, count: 32, every: 0.25),
            SpawnGroup(kind: .raptor, count: 14, every: 0.5, startAt: 4)
        ],
        [
            SpawnGroup(kind: .triceratops, count: 10, every: 1.5),
            SpawnGroup(kind: .raptor, count: 16, every: 0.5, startAt: 3)
        ],
        [
            SpawnGroup(kind: .raptor, count: 10, every: 0.6),
            SpawnGroup(kind: .triceratops, count: 6, every: 1.8, startAt: 3),
            SpawnGroup(kind: .rex, count: 1, every: 0, startAt: 10),
            SpawnGroup(kind: .compy, count: 16, every: 0.3, startAt: 12)
        ]
    ]

    /// Dinos get tougher every wave, ramping up harder late. `index` is zero based.
    static func healthScale(forWave index: Int) -> CGFloat {
        let i = CGFloat(index)
        return 1 + 0.16 * i + 0.012 * i * i
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
