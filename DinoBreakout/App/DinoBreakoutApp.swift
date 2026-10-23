import SwiftUI
import SpriteKit

@main
struct DinoBreakoutApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// One run of the game: which park, at which difficulty.
struct GameSession: Identifiable {
    let id = UUID()
    let level: Level
    let difficulty: Difficulty
    var endless = false
    var challenge: DailyChallenge?
    /// A saved run to pick back up.
    var resume: SavedGame?
    /// Which App Store screenshot scene to stage (Xcode builds only), or 0.
    var screenshot = 0
}

/// Shows the main menu, or a game once a park is picked.
struct RootView: View {
    @State private var session: GameSession?

    var body: some View {
        ZStack {
            if let session {
                GameView(session: session) {
                    self.session = nil
                }
                .id(session.id)
                .transition(.opacity)
            } else {
                MenuView { level, difficulty, endless in
                    session = GameSession(level: level, difficulty: difficulty, endless: endless)
                } onDaily: { challenge in
                    session = GameSession(level: challenge.level, difficulty: challenge.difficulty, challenge: challenge)
                } onContinue: { saved in
                    if let level = saved.level {
                        session = GameSession(
                            level: level, difficulty: saved.difficultyLevel,
                            endless: saved.startedEndless, resume: saved
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session?.id)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            SoundBank.shared.start()
            #if DEBUG
            if stageScreenshot() {
                return
            }
            #endif
            GameCenter.signIn()
            RewardedAds.shared.start()
        }
    }

    #if DEBUG
    /// App Store screenshot mode, used by the screenshots workflow. Launching
    /// with `-shot N` jumps straight to a staged scene: 1 to 4 are games, 5 is
    /// the menu with some progress. Returns true when a shot is being staged.
    private func stageScreenshot() -> Bool {
        let shot = UserDefaults.standard.integer(forKey: "shot")
        guard shot > 0 else { return false }
        UserDefaults.standard.set(true, forKey: Tutorial.doneKey)
        SavedGame.clear()
        let parks = ["paddock-b", "mount-ember", "aviary", "paddock-b"]
        if shot <= parks.count, let level = Level.all.first(where: { $0.id == parks[shot - 1] }) {
            session = GameSession(level: level, difficulty: .medium, screenshot: shot)
        } else {
            // The menu, with a few parks beaten so the stars and unlocks show
            let bests = [("paddock-b", 50), ("raptor-ridge", 50), ("jungle-river", 31), ("visitor-center", 12)]
            for (id, wave) in bests {
                if let level = Level.all.first(where: { $0.id == id }) {
                    Progress.record(wave: wave, level: level, difficulty: .medium)
                }
            }
        }
        return true
    }
    #endif
}

/// Hosts the SpriteKit game. The scene is created once, sized to the safe area.
struct GameView: View {
    let session: GameSession
    let onExit: () -> Void

    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.07, green: 0.11, blue: 0.08)
                if let scene {
                    SpriteView(scene: scene)
                }
            }
            .onAppear {
                guard scene == nil else { return }
                // The game fills the whole screen; it keeps its own controls clear of the
                // Dynamic Island and home indicator using these insets
                let windowInsets = UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first?.safeAreaInsets ?? .zero
                let insets = UIEdgeInsets(
                    top: max(geo.safeAreaInsets.top, windowInsets.top),
                    left: 0,
                    bottom: max(geo.safeAreaInsets.bottom, windowInsets.bottom),
                    right: 0
                )
                let newScene = GameScene(
                    size: geo.size, level: session.level, difficulty: session.difficulty,
                    endless: session.endless, challenge: session.challenge, safeInsets: insets,
                    resume: session.resume
                )
                newScene.scaleMode = .aspectFit
                newScene.screenshot = session.screenshot
                newScene.onExit = onExit
                scene = newScene
            }
        }
        .ignoresSafeArea()
    }
}
