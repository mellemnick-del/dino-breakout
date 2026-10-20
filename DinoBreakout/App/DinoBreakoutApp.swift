import SwiftUI
import SpriteKit

@main
struct DinoBreakoutApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

/// Hosts the SpriteKit scene. The scene is created once, sized to the safe area.
struct GameView: View {
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
                let newScene = GameScene(size: geo.size)
                newScene.scaleMode = .aspectFit
                scene = newScene
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
