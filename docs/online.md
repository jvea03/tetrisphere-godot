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
  (the UTC date and week, so every player is on the same board and it resets at UTC midnight for everyone; the week starts Monday, the season with the Battle Pass). The phone writes its own row
  after each win, name change or new avatar, and reads the top 50. `stars` has
  to fit the board's age; see "Who can write a score" below.
- **Snowball Fight Top Throwers:** one board per team per weekend,
  `snowball_W2970_red` / `snowball_W2970_green` (the weekend's week index;
  red is Team Gingerbread, green Team Snowman), `stars` holding the snowballs
  thrown. The phone writes its row at most once a minute while it pops pieces,
  at once after a Giant Snowball and when the event screen opens. When the
  weekend ends the board is placed like the others (`pending_board_results`,
  period `snowball`): each team's top 3 get 5,000 / 3,000 / 2,000 coins
  (`TSSnowball.TOP_COINS`), on a board of at least 10 players, collected on Home.
  The same rules cover these boards, with a higher ceiling and a weekend window.
- **Prizes:** when a board ends, the phone asks how many rows beat it (a count
  query) and pays the top-3 coins as before. If it's offline, it asks next time.
- **Stickers:** `stickers/{to}/got/{from}`. One waiting per sender per receiver;
  a new one replaces it, so nobody can be flooded. The receiver's game shows them
  when the player opens Ranks (never anywhere else) and deletes them. Only the sticker ids in `firestore.rules`
  can be sent, so there is no free text.
- **Sending, as in Duckdoku:** tap a rival's row and a speech bubble opens
  over it with the stickers you own; the one you tap arcs onto their row and
  slaps down. One sticker per player every 10 minutes (`STICKER_COOLDOWN` in
  `scripts/screens/leaderboard.gd`, kept on the phone); a failed send lifts it.
  Received stickers pop up when Ranks opens, slapping on one by one.
- **Block** hides a player's rows and stickers on that phone. **Report Name**
  adds a document to `reports` (player id, name, who reported). Both sit at
  the foot of the sticker bubble.
- **Stickers owned:** the basic three (Grr!, Aww..., Congrats!) for everyone.
  The Christmas Battle Pass adds Brrr! and Cozy! (free, tiers 10 and 20) and
  Ho Ho Ho! and For You! (premium, tiers 5 and 15). They're in
  `TSProfile.BATTLE_PASS_SEASON_REWARDS` (`free_stickers`, `paid_stickers`) and
  drawn by `TSIcon` (`sticker`). A new sticker needs its id added to
  `TSStickers.ALL`, its drawing, and `firestore.rules`.

## Who can write a score

Anyone with the app can sign in anonymously — the API key ships in the client —
and write their own row. The rules are what stop that write being a joke score.
They require `stars` to be a total someone could actually have reached on that
board by now. Publishing `firestore.rules` is the whole change. The live 1.3.6
apps already send `name`, `avatar`, `stars` and `t`, and an honest total still
lands. No new build.

A write must be all of the following:

- The signed-in player's own row, and only those four fields (as before).
- `stars` never goes down. A new name or avatar rewrites the same total; a win
  only adds. The phone syncs one total per write, including after playing
  offline, so the rules cannot ask for one small step at a time.
- `stars` is at most 8 a minute since the board opened, plus a 40-star burst
  and a one-hour grace, and never over the board's cap: **12,000 daily**,
  **15,000 weekly**, **30,000 season**. A win pays at most 5 (3 hearts left + 2
  for a first try), so 8 a minute is a perfect win every 37.5 seconds from the
  moment the board opens — faster than levels from 7 on. At the daily reset the
  ceiling is 520. It climbs from there and reaches 12,000 in the last few
  minutes of the UTC day. The weekly cap is reachable about 31 hours after
  Monday 00:00 UTC. The season cap is reachable about 62 hours after the season
  board opens (season 1 opened 2026-11-11, so 30,000 is already the limit).
- The board id is one the game uses (`daily_YYYY-MM-DD`, `weekly_W<n>`,
  `season_S<n>`, `snowball_W<n>_red` or `_green`). Anything else is rejected,
  except `check_*`, which `tools/online_check` uses and the game never reads,
  capped at 100.
- The server's clock is inside that board's open window, with an hour of slack
  so a write just either side of UTC midnight still lands. A daily board closes
  an hour after the next UTC midnight. Writing a huge score onto yesterday's
  board the next morning — the move that was sniping prizes after a board
  ended — is rejected.
- Snowball Fight uses its own rate, because a row's `stars` there are pieces
  popped, not wins: 180 a minute, a 2,000 burst, and the phone's own 100,000
  clamp. That ceiling is reached about 8 hours after Thursday 00:00 UTC, so a
  weekend total can still be faked up to 100,000. The window runs from Thursday
  00:00 UTC through Monday 18:00 UTC, so a Sunday night in UTC-12 (Sunday
  midnight there is Monday noon UTC) still posts. The weekend itself is local
  time. Outside the window the write is rejected.

`t` is the phone's own clock and is **not** checked against the server. A phone
with a wrong clock still posts. Which board it writes comes from the
network-corrected clock (`TSClock`) once that sync has landed.

### What this blocks

- Setting `stars` to 100,000 (or any total over the ceiling) in one request.
- Posting a season-sized score onto a daily board, or onto a season board in
  its first two days.
- Writing a board id the game does not show, or a daily/weekly/season board
  that has not opened yet or closed more than an hour ago.
- Lowering a score, or editing a row that is already over its cap (a rename
  included). Delete the row in the console instead.
- Snowball writes on a weekday outside the weekend window.

### What a cheater can still do

- Set `stars` to the current ceiling in one request. Offline play syncs as one
  write, so the first write of a board has to be allowed to be the whole total.
  The top of a board can still be someone sitting on that ceiling, and a new
  anonymous account is free, so it can be posted more than once.
- Reach the snowball cap of 100,000 once the weekend window has been open about
  8 hours. Piece pops are too fast for a tighter rate without rejecting a real
  chain.
- Keep a score that was stored before this change. Rules only affect new writes.
  Delete the impossible rows by hand (a season score of 100,000, a daily score
  over today's ceiling): Firebase console → Firestore → `boards` → the board →
  `entries`.
- Grant themselves the prize coins. Those are still added on the phone from the
  rank it asks for. The rules protect the public ranking, not the local wallet.

App Check, or a Cloud Function that saw the moves, would close the ceiling.
Both need a new build. Today's apps talk to the Firestore and Auth REST APIs
with the API key, send no App Check token, and send no replay. Enforcing either
would turn live leaderboards off. Not part of this change. Leave the API key
as the live apps have it: they call Firestore and Auth with it.

### Deploy

No store build. From a machine that is already logged in (`firebase login`):

```
firebase deploy --only firestore:rules --project egg-escape-196b6
```

`firebase.json` and `.firebaserc` in this repo point that at `firestore.rules`
and `egg-escape-196b6`. The same result, which is how the rules were first
published on 2026-11-14: Firebase console → Firestore → Rules, paste
`firestore.rules`, Publish.

Nothing else is deployed. There is no Cloud Function in this change.

### Tuning

The numbers are the one-line functions at the top of `firestore.rules`
(`starsPerMin`, `dailyCap`, and the rest). Change one and publish again; the
apps do not know the values. `tests/board_limits_test.tscn` checks the formula
against those values and against the season dates in `TSProfile`. If a real
player's update starts failing, their total is over the cap — raise that cap
and publish. The phone keeps showing them their own row either way; other
players see the higher total only after a write succeeds.

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

## Testing in the editor: the fake leaderboard

Run the game from the Godot editor (with your normal save) and the boards fill
with 20 made-up players; nothing is read from or written to Firebase. Tap one
to send a sticker: it "arrives", and about half the time they send one back a
few seconds later. A sticker from one of them also arrives once per run as you
open Ranks, to try the received card. Only the three basic stickers are there,
unless you earn more. Release builds, the test suite (throwaway profiles) and
`tools/online_check` never use it. Screenshots: `menu_capture -- leaderboard fake`.
