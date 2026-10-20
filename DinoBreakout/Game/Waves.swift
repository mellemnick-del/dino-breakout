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
    static let total = 50

    /// The first ten waves, hand built to teach each dino.
    private static let opening: [[SpawnGroup]] = [
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

    /// The lineup for a wave, numbered from 1. After the opening ten, waves
    /// rotate through swarms, raptor rushes, triceratops columns, and mixed
    /// packs, growing as they go. Every tenth wave is a T-Rex boss wave.
    static func groups(forWave number: Int, flyerHeavy: Bool = false) -> [SpawnGroup] {
        var groups = baseGroups(forWave: number)
        // Parks like the Aviary add a flock to nearly every wave from wave 3
        if flyerHeavy && number >= 3 && !groups.contains(where: { $0.kind == .pterodactyl }) {
            groups.append(SpawnGroup(kind: .pterodactyl, count: 2 + number / 3, every: 1.0, startAt: 3))
        }
        return groups
    }

    private static func baseGroups(forWave number: Int) -> [SpawnGroup] {
        if number <= opening.count {
            return opening[max(0, number - 1)]
        }
        let growth = 1 + CGFloat(number - 10) * 0.04
        func n(_ base: Int) -> Int { Int((CGFloat(base) * growth).rounded()) }
        let pace = max(0.6, 1 - CGFloat(number - 10) * 0.01)
        func every(_ base: TimeInterval) -> TimeInterval { base * TimeInterval(pace) }

        return lineup(forWave: number, n: n, every: every) + flyers(forWave: number, n: n, every: every)
    }

    private static func lineup(forWave number: Int, n: (Int) -> Int, every: (TimeInterval) -> TimeInterval) -> [SpawnGroup] {
        if number % 10 == 0 {
            let rexes = number / 10
            return [
                SpawnGroup(kind: .raptor, count: n(10), every: every(0.6)),
                SpawnGroup(kind: .triceratops, count: n(5), every: every(1.8), startAt: 3),
                SpawnGroup(kind: .rex, count: rexes, every: 6, startAt: 10),
                SpawnGroup(kind: .compy, count: n(20), every: every(0.25), startAt: 12)
            ]
        }
        switch number % 4 {
        case 0:
            return [
                SpawnGroup(kind: .compy, count: n(36), every: every(0.22)),
                SpawnGroup(kind: .raptor, count: n(8), every: every(0.6), startAt: 5)
            ]
        case 1:
            return [
                SpawnGroup(kind: .raptor, count: n(20), every: every(0.45)),
                SpawnGroup(kind: .compy, count: n(12), every: every(0.3), startAt: 6)
            ]
        case 2:
            return [
                SpawnGroup(kind: .triceratops, count: n(10), every: every(1.4)),
                SpawnGroup(kind: .raptor, count: n(10), every: every(0.6), startAt: 4)
            ]
        default:
            return [
                SpawnGroup(kind: .compy, count: n(16), every: every(0.3)),
                SpawnGroup(kind: .raptor, count: n(12), every: every(0.5), startAt: 3),
                SpawnGroup(kind: .triceratops, count: n(5), every: every(1.6), startAt: 6)
            ]
        }
    }

    /// Pterodactyls: a first flock on wave 11, then every third wave, a big
    /// flock on boss waves, and a few on most waves from 30 on.
    private static func flyers(forWave number: Int, n: (Int) -> Int, every: (TimeInterval) -> TimeInterval) -> [SpawnGroup] {
        if number == 11 {
            return [SpawnGroup(kind: .pterodactyl, count: 6, every: 1.2, startAt: 5)]
        }
        if number % 10 == 0 {
            return [SpawnGroup(kind: .pterodactyl, count: n(7), every: every(0.8), startAt: 15)]
        }
        if number >= 12 && number % 3 == 0 {
            return [SpawnGroup(kind: .pterodactyl, count: n(6), every: every(1.0), startAt: 4)]
        }
        if number >= 30 {
            return [SpawnGroup(kind: .pterodactyl, count: n(3), every: every(1.4), startAt: 8)]
        }
        return []
    }

    /// Dinos get tougher every wave. `index` is zero based.
    static func healthScale(forWave index: Int) -> CGFloat {
        let i = CGFloat(index)
        return 1 + 0.14 * i + 0.003 * i * i
    }

    /// Bounties grow too, so the economy keeps up with the dinos.
    static func rewardScale(forWave index: Int) -> CGFloat {
        1 + 0.04 * CGFloat(index)
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
