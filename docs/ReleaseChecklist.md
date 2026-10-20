# Release checklist: Dino Breakout 1.0

Work top to bottom. Items marked **(done)** are already handled in the project.

## 1. Project (done)

- [x] App icon (paddock gate design, 1024 x 1024)
- [x] Bundle ID `com.zeroday.dinobreakout`, version **1.0.0**, build **1**
- [x] Export compliance: no non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`), so App Store Connect won't ask
- [x] Game Center capability on (`DinoBreakout.entitlements`)
- [x] Test mode only exists in builds run from Xcode. TestFlight and App Store builds never have it (Apple rejects hidden features)
- [x] Portrait only, iPhone

## 2. Signing (Xcode, once)

1. Xcode, Settings, Accounts: make sure your developer Apple ID is listed.
2. Click the blue DinoBreakout project icon, select the DinoBreakout target, open **Signing & Capabilities**.
3. Team: pick your **paid developer team** (not "Personal Team").
4. You should see **Game Center** listed as a capability. If Xcode shows a red error about the bundle ID, change it (for example `com.zeroday.dinobreakout2`) and use that everywhere below.

## 3. Host the support and privacy pages

App Store Connect needs a public **Support URL** and **Privacy Policy URL**. The pages are ready in `docs/site` (home, support, privacy, and the icon).

1. Replace `SUPPORT_EMAIL` in `docs/site/support.html` and `docs/site/privacy.html` with the email you want players to use.
2. Publish the folder. The free way:
   - On GitHub, create a new **public** repository named `dino-breakout-site` (the game repo stays private).
   - Upload the four files from `docs/site` (or ask Claude to push them once the repo exists).
   - In that repo: Settings, Pages, Source: Deploy from a branch, Branch: `main`, folder `/ (root)`, Save.
   - After a minute the pages are live at `https://mellemnick-del.github.io/dino-breakout-site/`.
3. Your URLs:
   - Support: `https://mellemnick-del.github.io/dino-breakout-site/support.html`
   - Privacy: `https://mellemnick-del.github.io/dino-breakout-site/privacy.html`
   - Marketing (optional): `https://mellemnick-del.github.io/dino-breakout-site/`

## 4. Create the app in App Store Connect

appstoreconnect.apple.com, Apps, +, New App:

- Platform: iOS
- Name: **Dino Breakout: Tower Defense** (if taken, try "Dino Breakout: Park Defense")
- Primary language: English (U.S.)
- Bundle ID: the one from step 2
- SKU: `dinobreakout`
- User access: Full Access

Then fill in everything from `docs/AppStoreListing.md`: subtitle, promotional text, description, keywords, support and privacy URLs, category (Games > Strategy), age rating questionnaire, and App Privacy (**Data Not Collected**).

## 5. Game Center leaderboards

In the app's page in App Store Connect: Services (or Features), Game Center, then create **Classic leaderboards**, score format **Integer**, sort **High to Low**, with these IDs:

| Leaderboard | ID |
| --- | --- |
| Endless: Paddock B | `endless.paddock-b` |
| Endless: Raptor Ridge | `endless.raptor-ridge` |
| Endless: Jungle River | `endless.jungle-river` |
| Endless: Visitor Center | `endless.visitor-center` |
| Endless: The Aviary | `endless.aviary` |
| Endless: Night Shift | `endless.night-shift` |
| Endless: Mount Ember | `endless.mount-ember` |
| Daily challenge | `daily.waves` |

Then add Game Center to the version you're submitting (in the version page, Game Center section, add the leaderboards).

## 6. Upload a build

1. In Xcode, set the run destination to **Any iOS Device (arm64)**.
2. Product, **Archive**.
3. In the Organizer window: **Distribute App**, App Store Connect, Upload. Accept the defaults.
4. Wait 10 to 30 minutes for processing. The build appears under the app's **TestFlight** tab.

For every later upload, raise the **Build** number first (target, General tab), or the upload is rejected.

## 7. TestFlight

1. TestFlight tab, Internal Testing, +, create a group, add yourself.
2. To add family: **Users and Access**, invite them with the role **Customer Support** (or any role), then add them to the internal group. Internal builds need no review.
3. Testers install the free **TestFlight** app and accept the email invite.
4. Play through the tutorial, a few parks, endless mode, and the daily challenge on a real device before submitting.

## 8. Screenshots

At least the **6.9 inch** size (1320 x 2868). In Xcode, run on an **iPhone Pro Max** simulator and press **Cmd + S** to save a screenshot to the desktop. The suggested six shots and captions are in `docs/AppStoreListing.md`. Running from Xcode means test mode is available to set up scenes fast; it won't exist in the submitted build.

## 9. Submit

1. On the 1.0 version page: pick the build, add screenshots, fill **App Review Information**:
   - Sign-in required: **No**
   - Notes: "No account or login. All content is playable offline. Parks unlock by reaching wave 10 on the previous park."
2. Version release: **Manually release this version** is safest for a first launch.
3. **Add for Review**, then **Submit**.

Review usually takes one to three days. If Apple sends back a question or rejection, paste it to Claude.
