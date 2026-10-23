# App Store listing: Dino Breakout

Everything to paste into App Store Connect when the app record is created. Character limits are Apple's.

## Name (30 max)

**Dino Breakout: Tower Defense** (28)

## Subtitle (30 max)

**Build the maze. Stop the rex.** (29)

## Promotional text (170 max, can change any time without a new build)

The paddocks are open. Fence in raptors, tranq the triceratops, flak the pterodactyls, and hold the line until the rescue chopper lifts off.

## Description

The power's out, the paddocks are open, and every dinosaur in the park is running for the evac helipad. You're park security.

BUILD THE MAZE
There are no set paths. Every fence and tower you place is a wall, and the dinos always take the shortest way left. Build a long, twisting maze and line it with firepower.

SIX TOWERS, TEN UPGRADE PATHS
- Tranq rifles slow dinos down
- Turrets do the heavy lifting
- Flares burn whole crowds
- Flak cannons shoot down pterodactyls
- Shock pylons chain lightning through the herd
- Electric fences shape the maze
Every tower upgrades to level 5, picks one of two specialties along the way, and has a special move.

TEN KINDS OF DINOSAUR
Compies swarm. Raptors sprint. Triceratops and armored stegosaurs soak up damage. Dilophosaurs spit venom that jams your towers. Ankylosaurs club your fences flat. Pachys headbutt your towers. Spinosaurs swim straight across rivers. Pterodactyls fly right over your fences. And every tenth wave, the ground starts shaking.

SEVEN PARKS
Open paddocks, boulder ridges, a river with two bridges, the visitor center, an open aviary, a park in total darkness, and the slopes of a waking volcano.

PLAY YOUR WAY
- Easy, Medium, and Hard
- 50 waves per park, then endless mode
- A new daily challenge every day
- Call in an air strike when things get desperate
- Speed up to 3x
- 14 achievements and a Research Lab for permanent upgrades
- Saves between waves, so you can pick up where you left off
- No ads
- No account needed, plays offline

## Keywords (100 max, comma separated, no spaces needed)

dinosaur,dino,td,maze,strategy,raptor,trex,defense,offline,park,pterodactyl,survival,waves

## Category

- Primary: **Games > Strategy**
- Secondary: **Games > Casual**

## Age rating

Answer the questionnaire with **Infrequent/Mild Cartoon or Fantasy Violence** and **None** for everything else. That should come out at **9+**.

## App privacy

Version 1.0 has no ads, so answer **Data Not Collected**. Game Center is Apple's service and doesn't change that. When the version 1.1 ads are added, update these answers using Google's guide ("Google Mobile Ads SDK: Apple App Store data disclosure", on developers.google.com/admob).

In the age rating questionnaire, answer **No** to "Does your app contain ads?"

## Also required

- **Support URL:** any page with a way to contact you. A simple page on a free site is fine.
- **Privacy policy URL:** the ready-made page in `docs/site/privacy.html`.
- **Copyright:** "2026" followed by your name or business name.

## Screenshots

Apple needs at least the 6.9 inch iPhone size (1320 x 2868). Take them in the simulator with an iPhone Pro Max selected, using **Cmd + S**. Suggested set, in order, with a caption above each:

1. **"Build the maze."** Paddock B mid wave, long fence maze, towers firing.
2. **"Stop the rex."** A boss wave with a T-Rex in the maze and the screen full of fire.
3. **"Watch the skies."** A pterodactyl flock over the board with flak bursts.
4. **"Seven parks to defend."** Jungle River or Mount Ember.
5. **"Upgrade everything."** A tower panel open on a level 5 tower with its ability ready.
6. **"A new challenge every day."** The main menu with the daily challenge card.

Test mode (tap the DINO title 7 times) makes it easy to set up these scenes quickly. Turn it off before you submit.

## Game Center (optional, later)

1. In Xcode, target, Signing & Capabilities, add **Game Center**.
2. In App Store Connect, under the app's Game Center section, create leaderboards with these IDs: `endless.paddock-b`, `endless.raptor-ridge`, `endless.jungle-river`, `endless.visitor-center`, `endless.aviary`, `endless.night-shift`, `endless.mount-ember`, and `daily.waves`. Score format: integer, higher is better.
3. In `GameCenter.swift`, change `isConfigured` to `true`.
