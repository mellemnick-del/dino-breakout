import Foundation

/// Numbers for the end of game screen: kills, who did the damage, and time played.
struct GameStats {
    var kills = 0
    /// Damage dealt, keyed by tower kind name, or "airstrike".
    var damage: [String: CGFloat] = [:]
    var playTime: TimeInterval = 0

    var summary: String {
        var parts = ["\(kills) dinos down"]
        let total = damage.values.reduce(0, +)
        if total > 0, let top = damage.max(by: { $0.value < $1.value }) {
            let name = BuildKind.allCases.first { "\($0)" == top.key }?.title ?? "Air strike"
            parts.append("MVP: \(name) \(Int((top.value / total * 100).rounded()))%")
        }
        let minutes = Int(playTime) / 60
        let seconds = Int(playTime) % 60
        parts.append(String(format: "%d:%02d", minutes, seconds))
        return parts.joined(separator: "  ·  ")
    }
}
