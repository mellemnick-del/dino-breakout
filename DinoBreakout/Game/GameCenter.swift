import GameKit

/// Game Center sign in and leaderboards for endless records and daily challenges.
///
/// The Game Center capability is on (DinoBreakout.entitlements). Scores only
/// show up once the leaderboards below exist in App Store Connect; until then
/// submissions quietly fail, which is harmless.
enum GameCenter {
    static let isConfigured = true

    /// Signed in and ready for leaderboards.
    static var isAvailable: Bool {
        isConfigured && GKLocalPlayer.local.isAuthenticated
    }

    static func showLeaderboards() {
        guard isAvailable else { return }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

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
