# iOS build

What is done in the repo and what still needs an account or a console.
Egg Escape follows Duckdoku Blast's iOS setup (`duckdokublast/docs/ios.md`);
the same Mac, Xcode, Godot 4.7.2 and App Store Connect API key are used.

## Done in the repo

- **Export preset "iOS"** (`export_presets.cfg`, preset.2): bundle id
  `com.jvea.eggescape` (same as Android), iPhone + iPad, portrait, min iOS 15,
  version 1.0 build 1 (must match the App Store version), Team ID `75DDPXBG45`, exports an Xcode project to
  `build/ios/EggEscape.xcodeproj`. Icon `icons/icon_ios_1024.png` (the app
  icon, 1024, no alpha). Launch screen = the studio logo on the studio-splash
  blue, so it flows into the game's own splash. The ATT prompt text and
  `UIRequiresFullScreen` are in `additional_plist_content`.
- **Verified 7 Oct 2026**: `./tools/ios-setup.sh` exports, and an unsigned
  `xcodebuild` of the project succeeds.
- **Godot must be 4.7.2** (not 4.7.1): the AdMob addon's iOS binary
  (`addons/admob/downloads/ios/ios-template-v4.7.2.zip`) is per patch version.
- **AdMob**: `addons/admob/ios/bin` and `downloads/` (12 MB, git-ignored) were
  copied from Duckdoku's checkout; if missing, the addon re-fetches them, or
  copy them from `~/Desktop/duckdokublast/addons/admob/`. The iOS app id
  (`admob/general/ios/app_id`) is not set in `project.godot`, so the addon
  uses Google's **test** id, and
  `Ads.AD_UNITS_LIVE["ios"]` is empty: iOS shows Google's test ads until the
  real ids go in (below).
- **Billing**: `scripts/meta/billing.gd` has the StoreKit path; it switches on
  when the `InAppStore` singleton exists (`ios/plugins/`, copied from
  Duckdoku, `plugins/InAppStore=true`). The Output says
  `[Billing] simulated backend` if it is missing: do not ship that.
- **Screenshots**: `tools/ios-screenshots.sh` renders the six App Store shots at
  the three Apple sizes into `build/store/ios/` (resumable: delete a file to redo it).
- **Tools**: `tools/ios-setup.sh [check|release]` (export), `tools/ios-upload.sh`
  (release export, archive, upload), `tools/asc.py` (App Store Connect helper).

## Still to do, in order

1. **AdMob**: **done 7 Oct 2026**: iOS app "Egg Escape: Puzzle Break"
   (`ca-app-pub-6257234803503517~5835361087`) with units `egg_escape_rewarded`
   (`.../8642232686`) and `egg_escape_interstitial` (`.../8915810831`), in
   `project.godot` and `Ads.AD_UNITS_LIVE["ios"]`. The app is on the published
   consent (GDPR) message "Egg Escape European regulations message" (iOS and
   Android, 7 Oct 2026; it can take an hour to appear). After launch, link it to the App Store listing (Apps > Add store). New units can
   take up to an hour to serve, and nothing fills until the app is approved.
   `tetrisphere/test_ads` (on, for Android's closed test) applies to Android
   only, so iOS release builds show live ads (build 2 onward).
2. **Apple Developer**: register the bundle id `com.jvea.eggescape`, then
   create the App Store Connect app (name "Egg Escape: Puzzle Break", SKU
   `egg-escape`). Create an **App Store provisioning profile** named
   `Egg Escape App Store` for it (the Apple Distribution certificate from
   Duckdoku is reused); `tools/ios-upload.sh` expects that name.
3. **In-app purchases**: **done 7 Oct 2026** (app 6819941762): all 19 ids in
   `Billing.PRODUCTS`, `READY_TO_SUBMIT`, with USD prices, en-US text, all
   territories and review screenshots (`tools/asc_iaps.py`, re-runnable).
   Every id has an `egg_` prefix because **Apple product ids are unique across
   the whole developer account** and Duckdoku already used `coins_5000`,
   `no_ads_pass` and others. Use the same ids in Play Console. They are
   submitted with the first version ("Add for Review", tick them all).
   `egg_popup_hatch_day_2026` must be live before that sale (26 Nov).
4. **Listing**: filled in 7 Oct 2026 by `tools/asc_listing.py` (re-runnable):
   description, keywords, subtitle, promo text, categories (Games > Puzzle,
   Casual), age rating 4+ (ads are the only "yes"), copyright, manual release,
   privacy URL, price Free, and the three screenshot sets. **Still by hand:**
   - (Support URL is set: `store/support.html` is published at
     https://jvea03.github.io/duckdoku-privacy/egg-escape-support/)
   - **App Privacy** (the API can't): as Duckdoku: ad data used for tracking,
     purchase history for app functionality
   - **App Review contact** (name, phone, email) and notes ("No account needed")
   - **Content rights**: whether the app uses third-party content
     (the music in particular)
   - **Availability**: all territories except the 27 EU countries
5. **Screenshots**: uploaded 7 Oct 2026 (all three sets, processed). Rendered (`./tools/ios-screenshots.sh`, 7 Oct 2026) in
   `build/store/ios/<size>/`: Home, the egg part dug, the win card, Shop,
   Collection, Battle Pass. Upload 1290x2796 (6.7"), 1284x2778 (6.5") and
   2048x2732 (iPad 12.9") to the version.
6. **Privacy policy**: `store/privacy.html` now describes AdMob, the ATT prompt
   and the store purchases. Publish it as `egg-escape.html` in the
   `duckdoku-privacy` repo **before** the build goes to review.
7. **Test**: `./tools/ios-setup.sh`, open `build/ios/EggEscape.xcodeproj`, sign
   in with the Team, run on the phone: ATT prompt, consent form, a test ad,
   real store prices, a sandbox purchase, Restore Purchases, notch insets.
8. **Upload**: first build (1.0, build 1) uploaded 7 Oct 2026. For the next,  bump `application/version` in the preset, `./tools/ios-upload.sh`,
   attach the build, set release to **Manual**, then Add for Review.
9. **Countries**: Pricing and Availability: every territory **except the 27 EU
   countries** (same as Duckdoku). It is a by-hand edit (the API key cannot
   change availability), and it must be done **before** pressing Release.
10. After approval: link the AdMob iOS app to the store listing, switch
    `tetrisphere/test_ads` off for the public Android release (iOS is already live), press Release.
