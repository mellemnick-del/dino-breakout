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
                MenuView { level, difficulty in
                    session = GameSession(level: level, difficulty: difficulty)
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
        }
    }
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
                    .ignoresSafeArea()
                if let scene {
                    SpriteView(scene: scene)
                }
            }
            .onAppear {
                guard scene == nil else { return }
                let newScene = GameScene(size: geo.size, level: session.level, difficulty: session.difficulty)
                newScene.scaleMode = .aspectFit
                newScene.onExit = onExit
                scene = newScene
            }
        }
    }
}
