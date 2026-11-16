# Analytics

Two things, both following the same rules (below):

- **GameAnalytics** (`scripts/meta/game_analytics.gd`, the `GA` autoload): anonymous
  gameplay analytics over GameAnalytics' REST API, ported from Duckdoku. No native
  plugin, so Android and iOS behave the same. Runs only on a phone: the editor,
  desktop builds and the test suite's throwaway profiles report nothing.
- **Firebase Analytics, Android only** (`scripts/meta/analytics.gd`, `TSAnalytics`,
  the EggAnalytics plugin): first_open plus the events Google Ads imports as
  conversions. `TSAnalytics.event()` also forwards every event to GameAnalytics,
  so game code reports through `TSAnalytics` only.

## Turn GameAnalytics on for real

A GameAnalytics game is one platform with one key pair, so Egg Escape needs two
games (iOS and Android) under the studio The Little Guy Games. Until a platform has
its pair, its events go to GameAnalytics' public **sandbox**, which throws them away.

1. gameanalytics.com: create the game ("Egg Escape: Puzzle Break", App Store) and
   ("Egg Escape (Android)", Google Play).
2. Each game's Settings -> General: copy the Game Key and Secret Key into
   `GAME_KEY_IOS` / `SECRET_KEY_IOS` and `GAME_KEY_ANDROID` / `SECRET_KEY_ANDROID`
   in `game_analytics.gd`. (The secret ships in the app; every GameAnalytics SDK
   does the same.)
3. Bump and export, play a level on a phone, and check the dashboard's Real-time page.

## What it reports

| Where | Event | |
|---|---|---|
| Session | `user`, `Session:Start`, session end | Retention, session length |
| Levels | `Start/Complete/Fail : Level / Daily / Challenge : Level_012` (attempt number; hearts left as score) | Win rate and attempts by level |
| Levels | `Level:Seconds:<kind>`, `Level:Drops:<kind>` | Time and pieces a level takes |
| First run | `FirstRun:Intro:Start`, `FirstRun:Intro:Skip/Tap/Auto` (seconds), `FirstRun:Level1Loaded` (seconds), `Tutorial:Level1:Done` | Players lost before level 1 |
| Ads | `Ad:Rewarded:Earned/Skipped`, `Ad:Interstitial:Shown/Closed/NoFill:<Level/Home>`, `Ad:Interstitial:Due/Owed/BoughtOff/SkipPass/Abandoned`, `...:OwedDropped:NoAds`, `...:OwedDeferred:Busy` | The ad funnel (same names as Duckdoku) |
| Money | `business` `IAP:<product>` in USD cents (`PRICE_CENTS`) | Revenue and best sellers |
| Errors | `error` events: the game's own script errors (`TSErrorReporter`), once each per run, at most 25 | Bugs seen only on some phones |
| Anything else sent with `TSAnalytics.event()` | `Event:<name>` | |

Every event carries `custom_01` = `free` / `payer` / `noads`, to split any chart by
who sees ads. Keep `PRICE_CENTS` in step with the store prices.

## What it never sends
The advertising ID, the leaderboard name, anything typed, location, contacts,
payment details. The random user id lives in `user://analytics_state.cfg`.

## The UK, the EEA and Switzerland: consent first
The game is not sold in the EU, but the UK, Norway, Iceland, Liechtenstein and
Switzerland have it. There (`TSPrivacyRegion`: the phone's country, or a UTC+0 to
UTC+3 time zone) nothing is sent and nothing is written, to GameAnalytics or to
Firebase, until the player taps **Allow** on the card Home shows (after any
walkthrough, sale or results card). *No thanks* and *Allow* look the same on purpose.
A no stands wherever the player goes.

## Player control and kill switch
Settings -> **Share usage data** shows whether analytics is really running. Off stops
it and deletes the random ID and anything queued; on counts as a yes. Remote kill
switch: the Tunables key `analytics_enabled` = `false` (also hides the Settings row
and the consent card). Firebase on Android starts only when allowed; switched off
mid-run it stops logging the game's events, and from the next launch it does not
start at all (the plugin has no way to stop Firebase's own automatic events in the
same run).

## Store forms
- **App Store Connect -> App Privacy:** Usage Data -> Product Interaction, and
  Diagnostics -> Other Diagnostic Data (the error events), for Analytics, not linked
  to the user, not used for tracking. Identifiers -> Device ID is the random install
  ID, also not linked.
- **Play Console -> Data safety:** App activity (in-app interactions), Device or other
  IDs, App info and performance (crash logs / diagnostics); purpose Analytics; shared
  with GameAnalytics; optional (the Settings switch).
- The privacy policy (`store/privacy.html`) has the GameAnalytics section: publish it
  to the `duckdoku-privacy` repo as `egg-escape.html`.

## How it behaves
- Events queue and go out every 20 seconds, when the app is backgrounded, or when 50
  wait. Offline they wait (up to 400, a day at most) and are saved on exit.
- A new session starts after 30 seconds in the background; a session the app was
  killed in is closed at the next launch.
- A refused key (401) turns it off for the run; a refused batch (400) is dropped.
- Watch events on the desktop: run with `-- analytics-test analytics-log` (forces it
  on as Android, reporting to the sandbox, and prints each event).
- Tests: `tests/ga_test.tscn`.
