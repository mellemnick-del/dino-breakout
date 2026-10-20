import GameKit

/// Game Center sign in and leaderboards for endless records and daily challenges.
///
/// Off until the app is set up in App Store Connect: Game Center needs a paid
/// Apple Developer account, the Game Center capability on the target, and
/// leaderboards created with the IDs below. Then flip `isConfigured` to true.
enum GameCenter {
    static let isConfigured = false

    /// Leaderboard IDs to create in App Store Connect (one per park, plus daily).
    static func endlessLeaderboard(for level: Level) -> String {
        "endless.\(level.id)"
    }

    static let dailyLeaderboard = "daily.waves"

    static func signIn() {
        guard isConfigured else { return }
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            guard let viewController else { return }
            let root = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.rootViewController
            root?.present(viewController, animated: true)
        }
    }

    static func submitEndless(wave: Int, level: Level) {
        submit(wave, to: endlessLeaderboard(for: level))
    }

    static func submitDaily(wave: Int) {
        submit(wave, to: dailyLeaderboard)
    }

    private static func submit(_ score: Int, to leaderboard: String) {
        guard isConfigured, GKLocalPlayer.local.isAuthenticated, !Progress.testMode else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard]) { _ in }
    }
}
