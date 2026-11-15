# Online leaderboards and stickers

The leaderboards (Daily, Weekly, Season) and stickers run on the game's
Firebase project, `egg-escape-196b6`, the same one Analytics uses. The game
talks to it over Firebase's REST APIs (`scripts/meta/online.gd`), so Android
and iOS work the same way, with no plugin.

## How it works

- **Sign-in is anonymous.** Each install gets a random Firebase user id the
  first time it goes online. Nothing to type, no Google account. The id and its
  refresh token live in `user://online_auth.json`; reinstalling makes a new one.
- **Boards:** `boards/{board}/entries/{uid}` with `name`, `avatar` (a critter),
  `stars`, `t`. Board ids: `daily_2026-11-14`, `weekly_W2915`, `season_S2`
  (the player's local date and week, as before). The phone writes its own row
  after each win, name change or new avatar, and reads the top 50.
- **Prizes:** when a board ends, the phone asks how many rows beat it (a count
  query) and pays the top-3 coins as before. If it's offline, it asks next time.
- **Stickers:** `stickers/{to}/got/{from}`. One waiting per sender per receiver;
  a new one replaces it, so nobody can be flooded. The receiver's game shows them
  (Home and Ranks) and deletes them. Only the sticker ids in `firestore.rules`
  can be sent, so there is no free text.
- **Block** hides a player's rows and stickers on that phone. **Report Name**
  adds a document to `reports` (player id, name, who reported).
- **Stickers owned:** the basic three (Grr!, Aww..., Congrats!) for everyone.
  The Christmas Battle Pass adds Brrr! and Cozy! (free, tiers 10 and 20) and
  Ho Ho Ho! and For You! (premium, tiers 5 and 15). They're in
  `TSProfile.BATTLE_PASS_SEASON_REWARDS` (`free_stickers`, `paid_stickers`) and
  drawn by `TSIcon` (`sticker`). A new sticker needs its id added to
  `TSStickers.ALL`, its drawing, and `firestore.rules`.

## One-time setup in the Firebase console

Done on 2026-11-14: Anonymous sign-in on (auto clean-up off, so players keep
their id), Firestore created (Standard edition, nam5, production mode, no
backups on the free plan), rules published. The Android key works for the REST
calls as it is (checked: Firestore, Identity Toolkit and Token Service accept
it), so no key change was needed.

1. **Authentication → Sign-in method:** enable **Anonymous**.
2. **Firestore Database → Create database:** production mode, a location near
   most players (e.g. `nam5`, US). This can't be changed later.
3. **Firestore → Rules:** paste `firestore.rules` from this repo and Publish.
   Do this again whenever the file changes.
4. **API key:** the game uses the key in `scripts/meta/analytics.gd`. If Google
   Cloud console restricts it to Android apps, REST calls from the game are
   refused. Either allow "None" for application restrictions and limit it to the
   Identity Toolkit, Token Service and Cloud Firestore APIs (plus the Firebase
   ones already listed), or make a separate key for the game's REST calls.

Free tier is plenty at this size: Firestore allows 50,000 reads and 20,000
writes a day.

## Moderation

- Reported names: Firestore → `reports`. To remove a player from the boards,
  delete their rows under `boards/*/entries/{uid}` in the console.
- Names are already filtered on the phone (`TSFilter`).

## Before a build with this ships

- Publish the updated `store/privacy.html` (leaderboards and stickers section)
  as `egg-escape.html` in the `duckdoku-privacy` repo.
- Play Console → Data safety: add "Name" (user-generated, shared: shown to other
  players) and "User IDs" (the anonymous id), collected for app functionality.
- iOS App Privacy: the same, and update the review notes, which say no server.
