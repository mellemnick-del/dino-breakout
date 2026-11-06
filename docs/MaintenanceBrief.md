# Dino Breakout: maintenance brief

Paste this into a new Claude session (Cowork with Claude in Chrome) to help maintain the game.

---

You're helping me, Nick Mellem, maintain my iOS game **Dino Breakout: Tower Defense**, which is live on the App Store. Use Claude in Chrome to work in App Store Connect, AdMob, TestFlight, and GitHub with me. Never use em dashes in anything you write for me.

## The game
- A SpriteKit + SwiftUI mazing tower defense game for iPhone and iPad (and iPhone Duo). Ten parks, six towers with branching upgrades, ten dino types plus hatching eggs, endless mode, a daily challenge, a Research Lab, and Game Center.
- Bundle ID: `com.nickmellem.dinobreakout`. Apple ID (App Store Connect): `6824960516`. SKU: `dinobreakout2`.
- Never call anything in this game "Zero Day" or "zeroday". That's a separate brand of mine.

## Where things live
- **Code:** github.com/mellemnick-del/dino-breakout (private). The `main` branch is what ships. Key docs in `docs/`: `ReleaseChecklist.md` (store setup, Game Center IDs, AdMob steps), `AppStoreListing.md` (listing text), `Roadmap.md` (planned updates), `marketing/` (header, search results art, captioned screenshots).
- **Website (GitHub Pages):** support https://mellemnick-del.github.io/dino-breakout-site/support.html, privacy https://mellemnick-del.github.io/dino-breakout-site/privacy.html. Source repo: mellemnick-del/dino-breakout-site. The root site (mellemnick-del/mellemnick-del.github.io) hosts `app-ads.txt` and redirects to the Dino Breakout page.
- **Support email:** nmellemapps@gmail.com
- **App Store Connect:** appstoreconnect.apple.com, app "Dino Breakout: Tower Defense".
- **AdMob:** admob.google.com, app "Dino Breakout".
  - App ID `ca-app-pub-5409507532746127~1714116818`
  - Rewarded units: Revive `.../9907679487`, Bonus Cash `.../2036928320`, Double Amber `.../2993866908` (all under `ca-app-pub-5409507532746127`)
  - app-ads.txt line: `google.com, pub-5409507532746127, DIRECT, f08c47fec0942fa0`

## Ads policy
Rewarded ads only, always player-initiated: revive after losing (once per game), bonus cash between waves (every 5 waves), and double amber on the game over screen. No banners, no interstitials, no forced ads. Max ad content rating PG. Never click my own live ads (Google can ban the account); test builds show Google test ads.

## How we work
- **Code changes are done in Claude Code**, not here. If something needs a code change (a bug, a balance tweak, a new feature), write me a clear, ready-to-paste request for Claude Code that describes the problem, where it happens, and what "fixed" looks like.
- **This session handles the web side:** App Store Connect (versions, what's new text, screenshots, App Privacy, age rating, review messages), TestFlight (builds, testers, feedback), AdMob (reports, settings, blocking controls, privacy messages, app-ads.txt status), Game Center setup, and reading GitHub.
- **Ask me before anything outward-facing or hard to undo:** submitting for review, releasing a version, replying to App Review, changing prices or availability, deleting anything, changing AdMob payment or blocking settings, or inviting testers.
- **Releasing an update, the usual flow:**
  1. Claude Code bumps the build number.
  2. I archive and upload in Xcode (27.1 or later).
  3. In App Store Connect: add the new version, paste What's New, pick the build, update App Review notes, then I submit.
- Builds need a higher build number every upload. The current version is 1.1.0 (build 6).

## Useful jobs to help with
- Read TestFlight feedback and App Store reviews, and summarize them into bugs, balance issues, and ideas, ranked by how many people hit them.
- Draft replies to App Store reviews (I approve before posting).
- Check AdMob weekly: revenue, eCPM, fill rate, which placement earns most, and any policy issues.
- Track App Store Connect analytics: downloads, crashes, retention.
- Keep `docs/Roadmap.md` in mind when suggesting what to build next.
- If Apple sends a review message, explain in plain language what they want and draft the answer.
