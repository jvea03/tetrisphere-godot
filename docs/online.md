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
  after each win, name change or new avatar, and reads the top 50.
- **Snowball Fight Top Throwers:** one board per team per weekend,
  `snowball_W2970_red` / `snowball_W2970_green` (the weekend's week index;
  red is Team Gingerbread, green Team Snowman), `stars` holding the snowballs
  thrown. The phone writes its row at most once a minute while it pops pieces,
  at once after a Giant Snowball and when the event screen opens. When the
  weekend ends the board is placed like the others (`pending_board_results`,
  period `snowball`): each team's top 3 get 5,000 / 3,000 / 2,000 coins
  (`TSSnowball.TOP_COINS`), on a board of at least 10 players, collected on Home.
  No rule change was needed (the rules take any board id).
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

## Bots (27 Nov 2026)

A Daily, Weekly or Season board with fewer than 20 real players is topped up with
computer players (`scripts/meta/bots.gd`, `TSBots`).

- **Count:** `bots_fill_to` (20) minus the real players on the board, so each real
  player takes one bot's place. The remote setting `bots_fill_to: 0` turns them off.
- **Nothing is stored online.** Each phone works the bots out from the board id, so
  everyone sees the same names, critters and scores. Offline (board not fetched), none.
- **Scores** grow as the day, week or season passes and end at up to 30 (daily),
  140 (weekly) and 14 per season day, so an active player can beat them. A bot with
  no star yet isn't shown.
- **Prizes:** bots stand in the finished board. A player's place counts the bots with
  more stars, and bots count toward the 10 players a prize needs
  (`TSProfile.resolve_board_results`). More players win coins than before bots.
- **Stickers** to a bot show as sent and go nowhere (no reply); Report Name on one
  sends nothing; Block hides it like anyone.
- **Not on** the Snowball Fight boards or Clubs.
- Builds before this one don't show bots and still need 10 real players for a prize.
- The store description and the in-game text no longer say every rival is a real player.

## Naming (27 Nov 2026)

- **Everyone on the leaderboards needs a name of their own.** Any player at level 7 or
  later who is still "Hatchling" gets `TSNameCard`: new unlocks and players from
  before alike. It opens on Home after the ship story and before the chest and Battle
  Pass walkthrough, and on Ranks if they get there first (`TSProfile.must_name`).
- **Rules for a name** (`TSProfile.choose_name`): 2 to 18 characters, not "Hatchling",
  past `TSFilter`, not a bot's name, and not another player's. Capitals and spaces
  don't count ("Egg Bert" is "eggbert").
- **Unique, on the server:** `names/{sha256 of the name}` holds `uid`, `name`, `t`.
  The first to create it holds the name; changing names releases the old one.
  **`firestore.rules` must be published (Firebase console) before a build with this
  ships**, or no name can be checked.
- **Offline** a name can't be checked: the card then offers **Not now** (until the next
  run), so nobody is locked out of playing.
- **Names from before** are claimed the next time the game goes online; if somebody
  else claimed it first (or it is a bot's), the card asks for another.
- **No rows without a name:** this build writes no leaderboard row under "Hatchling"
  or a name somebody else holds. Builds before it still can.
- Reinstalling makes a new player id, so the old name stays held by the old one.
- Saving the profile with the name box empty keeps the current name.
- **Ruling a name out (moderation):** add it to `"blocked_names"` in
  `store/inbox.json` and push. Games with naming (this build on) ask anyone under it
  for another name the next time they read the file, and nobody can pick it. Capitals
  and spaces don't count; it matches the whole name only ("captain" doesn't block
  "Captain Crumble"). Older builds can't be asked. `captain` added 27 Nov 2026.
