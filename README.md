# Dino Breakout

**The paddocks are open. Hold the line until the choppers arrive.**

> App Store listing: **Dino Breakout: Tower Defense**, subtitle **Build the maze. Stop the rex.** Leading with "Dino" and "Tower Defense" in the name puts the two terms players actually search for in the field Apple weighs most (30 character limit).

A mazing tower defense game for iPhone. The park's power has failed and the dinosaurs are loose. You're head of park security. There are no fixed paths: every fence and tower you place is a wall, and the dinos always take the shortest route left through your maze to the evac helipad. Build a long, twisting maze and line it with firepower.

> Inspired by the "park gone wrong" genre, with all original names and art. No Jurassic Park names, logos, characters, or music.

## Menu

The game opens on a title screen with dinos roaming the park behind it.

- **Difficulty:** Easy (30 lives, $150), Medium (20 lives, $100), or Hard (10 lives, $80, tougher dinos, smaller bounties).
- **Parks**, in unlock order: Paddock B (open field), Raptor Ridge (boulders, gate and helipad in opposite corners), Jungle River (a river with two bridges), Visitor Center (buildings to maze around), The Aviary (pterodactyls from wave 3), and Night Shift (dark except where your towers light it up), Mount Ember (lava pools on volcanic ash). Each park unlocks when you reach wave 10 on the one before it, on any difficulty.
- **Daily challenge:** the card at the top of the menu. Every date picks a park, difficulty, and twist (Sky Swarm, No Fences, Rich but Stingy, Fast Dinos, Five Lives, or Armored Up), the same on every device. Survive 20 waves to complete it.
- **Achievements** (trophy button): 14 to earn, from First Bite to Never Off (wave 75 in endless). A banner pops up in game when you earn one.
- **Test mode** (builds run from Xcode only): tap the big DINO title 7 times. Every park and endless mode unlock, you start with $9,999, and nothing counts toward stars, records, or achievements. Tap 7 more times to turn it off.
- **Endless mode:** beat all 50 waves on a park (any difficulty) and its card gets an Endless button. Waves never stop: crowds grow until wave 60, then health keeps climbing, with a T-Rex boss wave every 10 (up to 6 T-Rexes) and pterodactyl flocks. You can also tap **Keep Going** on the victory screen to carry your towers straight into endless. Your endless record is saved per park and difficulty.
- **Stars:** one at wave 10, two at wave 25, three for beating all 50, tracked per park and difficulty. Each card shows its stars and best wave, and the header shows your total.
- **Research Lab** (flask button): every wave you clear earns amber (0.75 on Easy, 1 on Medium, 1.5 on Hard, plus 15 for a full win or a daily challenge). Spend it on permanent upgrades, three levels each: cheaper fences, more starting cash, extra lives, longer tower range, bigger bounties, a higher interest cap, and stronger air strikes. Research never applies to daily challenges.
- **Game Center:** achievements are also reported to Game Center (IDs in `docs/ReleaseChecklist.md`).
- **Settings** (gear): separate Music and Sound effects volume. All audio is synthesized in code (`Sound.swift`), and it follows the phone's silent switch.

New parks are added in `Level.swift`: a gate square, a helipad square, and any boulders, river squares, and bridges.

## How to play

- Dinos break out of the **paddock gate** 🚧 at the top and run for the **helipad** 🚁 at the bottom.
- Pick something from the build bar, then tap an empty square to place it.
- You can never fully block the path. Squares where a build would seal the dinos in are marked with a faint red X, and if you try one anyway it flashes red and says why right on the board (blocks the path, not enough cash, dino in the way, and so on). Build bar pieces you can't afford dim, with the price in red.
- **Path preview:** a marching dotted line shows the route dinos will take from the gate, and it updates the moment you build, sell, or move anything.
- **Next wave preview:** the strip under the top bar shows the next wave's dinos and how many of each. During a wave it shows how many dinos are left.
- **Save and resume:** the game saves itself between waves and after every build. Close the app any time, and a **Continue** card on the menu picks up where you left off (mid-wave quits go back to the start of that wave). One save slot; daily challenges aren't saved.
- **Undo:** between waves, the Undo button in that strip takes back your last build or upgrade for a full refund, all the way back to the end of the last wave.
- **Move towers:** press on any tower or fence and drag it to a new square. The target square glows green if it's allowed and red if not, and towers show their range while you drag. Moving is free, and a moved tower takes a second to set up before it fires.
- Tap any tower you built to open its panel: its level (1 of 5, also shown as rank chevrons; levels 4 and 5 add gold trim, and level 5 a gold star), an **Upgrade** button with the price, **Sell** for 70% back, and its range.
- **Abilities:** every tower's panel has a special move that recharges (25 seconds, 30 for napalm): Tranq **Sleep Gas** nearly freezes everything close by for 3 seconds, Turret **Overdrive** fires three times as fast for 5 seconds, Flare **Napalm** leaves a burning patch that ignores armor, and Flak **Barrage** blasts every flyer in range.
- **Aim:** towers that shoot have an Aim chip in their panel: First (closest to the helipad), Strongest, Closest, or Flyers.
- **Air strike:** the last button in the build bar. Tap it, then tap the board, and the rescue chopper strafes that whole row. Once per wave.
- **Boss bar:** while a T-Rex is loose, its health shows in a red bar across the top of the board.
- **Tower stats:** each tower's panel shows its kills and total damage, so you can see who's pulling their weight.
- **Perfect wave:** clear a wave without anything reaching the helipad for bonus cash. Big banners announce each wave, boss waves, and clears.
- **Interest:** clearing a wave pays 5% interest on the cash you saved, up to $50.
- **Stats:** the game over screen shows dinos taken down, your MVP tower's share of the damage, and time played.
- **Tutorial:** the first game on Paddock B walks you through fences, a turret, a wave, and an upgrade. Replay it from Settings.
- **Optional ads:** after losing, "Watch an ad to revive" brings you back with 5 lives (once per game), and the pause menu offers bonus cash for an ad every 5 waves. Not in version 1.0: off until the AdMob package and IDs are added in 1.1 (see `docs/ReleaseChecklist.md`).
- **Vibration:** taps when you build, a punch on upgrades and abilities, a stomp when a T-Rex arrives. Turn it off in Settings.
- Tap **Send Wave** when your maze is ready. Clearing a wave pays a bonus.
- While a wave is running, the same button is the speed toggle: 1x, 2x, 3x.
- Survive 50 waves to win. Every tenth wave is a T-Rex boss wave, with one more T-Rex each time.
- Tap the pause button (top left) to pause, resume, or restart from wave 1.

### Build bar

| Piece | Cost | What it does |
| --- | --- | --- |
| ⚡️ Fence | $5 | Cheap wall. The backbone of your maze. |
| 💉 Tranq | $20 | Darts that slow a dino to half speed. Long range. |
| 🎯 Turret | $35 | Fast, steady damage. Your main killer. |
| 🔥 Flare | $50 | Short range burst that burns every dino around it. |
| Flak | $45 | Anti-air only. Longest range of any tower, and each shell bursts to hit nearby flyers too. Can't hit anything on the ground. |
| ⚡ Shock | $60 | Lightning that jumps from dino to dino (2 to 4 targets, more with upgrades). Ground only. Ability: **Overload** zaps everything in range for 4x damage. |

**Branching upgrades:** going from level 3 to 4, every tower picks one of two paths, shown as a colored letter badge on the tower: Tranq (Sedative or Sniper), Turret (Minigun or Cannon), Flare (Inferno or Phosphor), Flak (Hailstorm or Skyhammer), Shock (Storm or Arc).

### Dinos

| Dino | Notes |
| --- | --- |
| Compy | Weak but fast, comes in swarms |
| Raptor | The fastest thing in the park |
| Triceratops | Slow and very tough, costs 2 lives if it gets through |
| T-Rex | Boss. Shakes the screen on arrival, costs 10 lives |
| Stegosaurus | Armored: every hit loses 5 damage (always at least 1 gets through), so weak, fast shots barely scratch it. Upgrade your towers. Joins mixed waves from 13 and triceratops columns from 14 |
| Dilophosaurus | Yellow-green with a fanned orange frill and red crests. Every 4 seconds it spits venom at the nearest tower within 2 squares, which can't fire for 3 seconds. From wave 19 |
| Spinosaurus | Teal with a red back sail, 400 health. It swims, so on Jungle River it cuts straight across the river instead of using the bridges. From wave 17 |
| Pterodactyl | Flies straight over the maze from the gate to the chopper, weaving as it goes. Flak hits it at full damage; turrets and tranqs only do half, and flares can't reach it. First flock on wave 11, then every third wave, a big flock on boss waves, and a few on most waves from 30 on |
| Ankylosaurus | Armored tank with a tail club. Every few seconds it smashes a fence next to it, opening a gap in your maze. Back key walls with towers. From wave 22 |
| Pachycephalosaurus | Domed head, charges in bursts, and headbutts towers it passes, stunning them for 2 seconds. From wave 24 |

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

- Swift, SpriteKit, and a thin SwiftUI wrapper. iOS 17 and up, iPhone and iPad, portrait.
- Zero third party dependencies.
- The `DinoBreakout` folder is a synced folder in Xcode, so any new Swift file dropped in it is part of the build automatically.

```
DinoBreakout/
  App/   App entry point, main menu, settings, and the menu's backdrop scene
  Game/
    GameScene.swift   Game loop, input, waves, combat, effects
    Grid.swift        The map and the pathfinding distance field
    Dino.swift        Dino types, stats, and the dino node
    DinoArt.swift     Dino colors and shapes, and the walk cycle renderer
    Tower.swift       Build pieces, stats, and upgrades
    Waves.swift       The 50 waves and difficulty scaling
    Level.swift       Parks, difficulty settings, and saved best waves
    Sound.swift       Synthesized sound effects and music
    ParkArt.swift     Towers, fences, gate, helipad, ground, and effects art
    HUD.swift         Top bar, build bar, colors, fonts
```

### How the pathfinding works

`Grid` keeps a distance map: for every square, how many steps it is to the helipad. Each dino just steps to whichever neighbor is closest. When you place or sell something, the map is rebuilt (a breadth first search, instant on a 9 x 15 board), and every dino reroutes on its next step. Placements are only allowed if the paddock gate, and every square a dino is standing on or heading to, can still reach the helipad.

### Tuning

All the numbers live in a few obvious places:
- Dino health, speed, reward, and lives cost: `DinoKind` in `Dino.swift`
- Dino colors, proportions, and walk speed: `DinoKind.style` in `DinoArt.swift`
- Tower cost, range, fire rate, damage: `BuildKind` in `Tower.swift`
- Upgrade scaling and sell value: `Tower` in `Tower.swift`
- Wave lineups and health scaling per wave: `Waves.swift`
- Starting cash, lives, and board size: top of `GameScene.swift`

## Get it on TestFlight

TestFlight lets you (and your family) install the game from Apple's TestFlight app instead of plugging a phone into Xcode. The app icon, bundle ID (`com.nickmellem.dinobreakout`), and export compliance answer are already set up.

1. **Join the Apple Developer Program** at developer.apple.com/programs ($99 a year). Approval can take up to 48 hours.
2. **Sign in to Xcode** with that Apple ID: Xcode, Settings, Accounts, then the + button.
3. **Pick your team:** click the blue DinoBreakout project icon, select the DinoBreakout target, open **Signing & Capabilities**, and choose your team. If Xcode says the bundle ID is taken, change it (for example to `com.nickmellem.dinobreakout2`).
4. **Create the app record** at appstoreconnect.apple.com: Apps, the + button, New App. Platform iOS, name **Dino Breakout: Tower Defense** (if the name is taken, try another), your bundle ID from step 3, and any SKU such as `dinobreakout`.
5. **Upload a build:** in Xcode, set the run destination at the top to **Any iOS Device (arm64)**, then Product, Archive. When the Organizer window opens, click **Distribute App**, choose **App Store Connect**, and follow the prompts to upload.
6. **Wait for processing** (usually 10 to 30 minutes). The build shows up under the app's **TestFlight** tab.
7. **Add testers:**
   - **You:** add yourself under Internal Testing.
   - **Family:** either add them in **Users and Access** so they can be internal testers too (fastest), or create an **External Testing** group, add their email, and submit the build for a short beta review (usually about a day).
8. **Install:** each tester gets an email invite, installs the free **TestFlight** app, and taps Accept.

For every new upload, raise the **Build** number (target, General tab) before archiving, or App Store Connect will reject it.

## App Store

Step by step from your Mac to Submitted for Review: `docs/ReleaseChecklist.md`. The support and privacy pages Apple requires are ready in `docs/site`.

The full listing (name, subtitle, description, keywords, category, age rating, privacy answers, and a screenshot plan) is in `docs/AppStoreListing.md`, along with the steps to turn on Game Center leaderboards for endless records and daily challenges.

## Roadmap

Next up:
- Pteranodons that fly over the maze (and an anti-air tower)
- Raptors that test fences for weak spots, triceratops that smash through them
- A generator that powers fences and turrets and has to be protected
- Park zones as levels: visitor center, raptor pen, jungle river, aviary, lab, helipad
- Flare tower lures dinos toward it

Later:
- Stars per level, saved progress, and an endless mode
- Daily challenge map with a leaderboard (Game Center)
- App icon and App Store listing
