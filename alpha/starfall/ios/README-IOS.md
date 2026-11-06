# Starfall iOS integration

The web game is already wired for these native services:

- **Game Center leaderboard:** `com.agosllc.starfall.score`
- **Non-consumable full-game unlock:** `com.agosllc.starfall.fullgame`
- **Free content:** levels 1-10, including Hive Queen (5) and The Warden (10)
- **Paid content:** levels 11-100 for one purchase

## App Store Connect

1. Create a **Non-Consumable** in-app purchase with product ID `com.agosllc.starfall.fullgame` and set the U.S. price to **$2.99**. StoreKit supplies the localized price shown by the game.
2. Create a Game Center leaderboard with ID `com.agosllc.starfall.score`, score format **integer / points**, and sort order **high to low**.
3. Add **Game Center** and **In-App Purchase** capabilities to the Starfall target.
4. Attach the IAP to the app version before review and supply an App Review screenshot of the unlock screen.

## Xcode target

Add `GameView.swift`, `GameStore.swift`, `GameCenter.swift`, and `StarfallApp.swift` to the app target. Add the `web` folder as a folder reference/resource so `index.html` and the nested `assets` folder are copied into the bundle. Point the target at `Starfall.entitlements`.

`Products.storekit` is a local StoreKit test configuration. Select it in the Run scheme while testing purchases; the live price still comes from App Store Connect in production.

## Browser behavior

The plain desktop/browser build remains fully playable because it has no App Store purchase bridge. The level-10 paywall is enforced when the game is running inside the iPhone/iPad WKWebView with the native StoreKit bridge injected at document start.


## iPhone / iPad polish in this build

- Gameplay is portrait-locked in the native iOS/iPadOS app so an accidental rotation cannot interrupt a boss fight.
- Native safe-area insets are pushed into the web UI and used by the HUD, pause control, Nova control, menus, and hangar.
- iPhone HUD spacing is more compact, with boss bars moved upward to free more visible combat space.
- Touch controls remain at least 44 points and are moved inward from the home indicator / screen edges.
- Haptic feedback is bridged for shield hits, hull damage, pickups, Nova use, boss warnings, boss defeats, and successful fleet actions.
- App interruptions (Control Center, app switching, calls, lock) pause gameplay through both native and web lifecycle handling.
- Decorative effect density adapts by device class, and the renderer automatically falls back to a lighter effects pass if sustained frame time drops.
- On a stressed iPhone, canvas resolution can step down before gameplay objects are reduced; enemy counts and projectile patterns remain unchanged.
- Boss geometry scales slightly by device class so iPhone encounters retain maneuvering room while iPad/desktop keep a larger cinematic presence.

## Campaign ending structure

- **Level 50 / Sovereign Singularity:** completes the primary campaign, shows a Mission Complete ending, then reveals **Beyond the Event Horizon** and unlocks the level-51 checkpoint.
- **Levels 51-100:** post-campaign arc with Super-tier fleet progression and ascended encounters.
- **Level 100 / Dreadnought:** existing capture cinematic now leads into the true ending / campaign-complete credits screen.
- **After Level 100:** **Infinite Mode** is enabled and the level-101 checkpoint remains available.
- Ending progress is persisted so a system interruption or app relaunch does not destroy the player's unlocked continuation.

