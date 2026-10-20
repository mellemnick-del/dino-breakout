# Dino Breakout

**The paddocks are open. Hold the line until the choppers arrive.**

> App Store listing: **Dino Breakout: Tower Defense**, subtitle **Build the maze. Stop the rex.** Leading with "Dino" and "Tower Defense" in the name puts the two terms players actually search for in the field Apple weighs most (30 character limit).

A mazing tower defense game for iPhone. The park's power has failed and the dinosaurs are loose. You're head of park security. There are no fixed paths: every fence and tower you place is a wall, and the dinos always take the shortest route left through your maze to the evac helipad. Build a long, twisting maze and line it with firepower.

> Inspired by the "park gone wrong" genre, with all original names and art. No Jurassic Park names, logos, characters, or music.

## How to play

- Dinos break out of the **paddock gate** 🚧 at the top and run for the **helipad** 🚁 at the bottom.
- Pick something from the build bar, then tap an empty square to place it.
- You can never fully block the path. If a placement would seal the dinos in, it's refused.
- Tap a tower you already built to **upgrade** it (up to level 3, shown by the yellow dots).
- Pick **Sell** and tap a tower to get 70% of what you spent back.
- Tap **Send Wave** when your maze is ready. Clearing a wave pays a bonus.
- Survive 50 waves to win. Every tenth wave is a T-Rex boss wave, with one more T-Rex each time.
- Tap the pause button (top left) to pause, resume, or restart from wave 1.

### Build bar

| Piece | Cost | What it does |
| --- | --- | --- |
| ⚡️ Fence | $5 | Cheap wall. The backbone of your maze. |
| 💉 Tranq | $20 | Darts that slow a dino to half speed. Long range. |
| 🎯 Turret | $35 | Fast, steady damage. Your main killer. |
| 🔥 Flare | $50 | Short range burst that burns every dino around it. |

### Dinos

| Dino | Notes |
| --- | --- |
| Compy | Weak but fast, comes in swarms |
| Raptor | The fastest thing in the park |
| Triceratops | Slow and very tough, costs 2 lives if it gets through |
| T-Rex | Boss. Shakes the screen on arrival, costs 10 lives |

The dinos are cartoon cutouts drawn in code (`DinoArt.swift`): body, tail, legs, and head are drawn separately, then baked into a 16 frame walk cycle for each dino when a game starts. They turn smoothly into corners, and tranqs slow their walk animation along with their speed.

Everything else on the board is drawn the same way (`ParkArt.swift`): towers on concrete pads with rank chevrons for their level, electric fences that wire themselves to neighboring fences, the paddock gate whose doors swing open during a wave, the rescue chopper idling on the helipad (it lifts off when you win), dirt trails that wear in where dinos run, darts, tracers, flare bursts, and fence sparks.

## Run it on your Mac

No terminal needed. Requires Xcode 16 or newer.

1. Open Xcode. On the welcome window, choose **Clone Git Repository** (or **Integrate > Clone** from the menu bar).
2. Paste `https://github.com/mellemnick-del/dino-breakout.git`, pick where to save it, and click **Clone**. Xcode opens the project.
3. Pick an iPhone simulator at the top and press **Cmd + R**.
4. To play on your own iPhone: click the blue DinoBreakout project icon at the top of the file list, select the DinoBreakout target, go to **Signing & Capabilities**, and choose your Apple ID team.

To get new changes later: **Integrate > Pull**.

## Tech

- Swift, SpriteKit, and a thin SwiftUI wrapper. iOS 17 and up, iPhone, portrait.
- Zero third party dependencies.
- The `DinoBreakout` folder is a synced folder in Xcode, so any new Swift file dropped in it is part of the build automatically.

```
DinoBreakout/
  App/   App entry point and the SwiftUI view hosting the game
  Game/
    GameScene.swift   Game loop, input, waves, combat, effects
    Grid.swift        The map and the pathfinding distance field
    Dino.swift        Dino types, stats, and the dino node
    DinoArt.swift     Dino colors and shapes, and the walk cycle renderer
    Tower.swift       Build pieces, stats, and upgrades
    Waves.swift       The 50 waves and difficulty scaling
    ParkArt.swift     Towers, fences, gate, helipad, ground, and effects art
    HUD.swift         Top bar, build bar, colors, fonts
```

### How the pathfinding works

`Grid` keeps a distance map: for every square, how many steps it is to the helipad. Each dino just steps to whichever neighbor is closest. When you place or sell something, the map is rebuilt (a breadth first search, instant on a 7 x 11 board), and every dino reroutes on its next step. Placements are only allowed if the paddock gate, and every square a dino is standing on or heading to, can still reach the helipad.

### Tuning

All the numbers live in a few obvious places:
- Dino health, speed, reward, and lives cost: `DinoKind` in `Dino.swift`
- Dino colors, proportions, and walk speed: `DinoKind.style` in `DinoArt.swift`
- Tower cost, range, fire rate, damage: `BuildKind` in `Tower.swift`
- Upgrade scaling and sell value: `Tower` in `Tower.swift`
- Wave lineups and health scaling per wave: `Waves.swift`
- Starting cash, lives, and board size: top of `GameScene.swift`

## Roadmap

Next up:
- Sound: footsteps, tranq pops, fence hum, the T-Rex roar
- Pteranodons that fly over the maze (and an anti-air tower)
- Raptors that test fences for weak spots, triceratops that smash through them
- A generator that powers fences and turrets and has to be protected
- Park zones as levels: visitor center, raptor pen, jungle river, aviary, lab, helipad
- Flare tower lures dinos toward it

Later:
- Stars per level, saved progress, and an endless mode
- Daily challenge map with a leaderboard (Game Center)
- App icon and App Store listing
