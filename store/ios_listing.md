# iOS store listing

Done 16 Nov 2026 on 1.3.4 (build 11; pulled from review, updated, resubmitted the
same day): the description, keywords and an 8-shot set below. The description,
keywords and screenshots belong to a version and go to review with it; promotional
text is not versioned and can change any time, with no review.

Live today (1.0 and 1.3.4): name "Egg Escape: Puzzle Break" (24/30), subtitle
"Spin the egg, free critters" (27/30). Both are fine and stay.

## Promotional text (170 max)

Set on 16 Nov 2026 (1.0 and 1.3.4), while 1.0 is what players have:

    Coming soon: online leaderboards, stickers to send other players, and a snowy Christmas planet! Spin the egg, match blocks and rescue over 80 cute critters.

Once 1.3.4 is released (and until 1 Dec, when the Christmas planet arrives):

    NEW: race real players on daily, weekly and season leaderboards, and send them stickers! Christmas lands on the critters' planet on 1 December.

From 1 Dec (the Christmas season, BATTLE_PASS_CALENDAR):

    Christmas is here! Snowy camp, presents to tap, Santa and the Frost Queen in the Battle Pass, and real-player leaderboards. Can you rescue every critter?

## Keywords (100 max)

Live (94 chars) repeats "critters" and "spin", which the subtitle already gives
Apple, and leaves 6 characters unused:

    match,3d,casual,critters,blocks,brain,relax,cute,spin,rotate,pastel,logic,daily,collect,sphere

Proposed (99 chars): no word from the name or subtitle; adds block, animal,
rescue, pet, cozy:

    block,match,3d,cute,animal,rescue,pet,relax,brain,logic,casual,cozy,rotate,daily,collect,sphere,fun

Apple matches singular and plural, and combines keywords with the name and subtitle
("block puzzle", "puzzle game", "cute animal rescue"), so single words go further.

## Description (4000 max)

The Play Store's (store/aso.md), adapted: no Wi-Fi/Play wording, the ads and
purchases line kept from the live iOS text. About 2,000 characters.

    Crack eggs, match blocks and rescue the cutest critters in this relaxing block puzzle game!

    Your ship crash-landed on a strange planet, and the critters are stuck inside giant eggs. Spin each egg all the way around, aim your falling block and match three or more to dig a path through the shell. Open an escape hole and watch your critter break free!

    A FRESH TWIST ON BLOCK PUZZLES
    • Spin the 3D egg in any direction – every turn shows a new puzzle
    • Match 3 or more blocks, slide pieces into place and set off chain reactions
    • Easy to learn, with a gentle start and short levels you can finish in minutes
    • Hundreds of levels that grow into a real brain teaser

    CLEVER BLOCKERS
    • Armoured stones, tie-downs, geodes, creeping vines, locks and keys, prisms and fog
    • Each new blocker arrives with a quick, hands-on lesson

    HANDY BOOSTERS
    • Bombs, Any Piece and Rocks for when you're stuck
    • No timers on regular levels – think as long as you like

    COLLECT CUTE CRITTERS
    • Collect and level up over 80 adorable hand-drawn critters
    • Complete themed Collection Sets for bonus coins
    • Open chests full of coins, materials and rewards

    REBUILD YOUR CAMP
    • Build a cozy camp and fix your crashed spaceship
    • Every season, fly to a new themed planet: autumn, Christmas, New Year and Valentine's

    CLIMB THE LEADERBOARDS
    • Race real players on daily, weekly and season leaderboards
    • Cheer on rivals (or tease them!) with fun stickers
    • Finish in the top 3 to win coins

    SOMETHING NEW EVERY DAY
    • A new Daily Egg puzzle every day
    • Daily streaks, quests and a seasonal Battle Pass

    RELAX AND UNWIND
    • Soft pastel art and calm music
    • Play offline, any time (leaderboards and stickers need a connection)

    If you love block puzzles, match 3 games and cozy brain teasers, Egg Escape is made for you. Can you save every critter?

    Egg Escape: Puzzle Break is free to play, with optional in-app purchases and ads. Remove the ads with the No Ads Pass.

Check before using: "Hundreds of levels" (how many ship), and "over 80" (82 in the
Collection today).

## Screenshots

Live: 6 per device (iPhone 6.5", 6.7", iPad 13"), made 6 Oct 2026 for 1.0: none show
the leaderboards, stickers, the Battle Pass or a seasonal planet. Apple allows 10;
the first two are what most people see in search, so they carry the pitch.

On 1.3.4, in this order. iPhone (6.7" and 6.5"): captioned like the Play set, by
tools/make_ios_screens.tscn from raw 1080 x 1920 screens in store/screenshots_src/
(git-ignored; tools/store_shot `--size=1080x1920`: `game --level=14 --drops=3
--wait=5`, `win --level=8 --wait=4`, `leaderboard --fake --release --wait=4`,
`collection --collected=40`, `home --built --release`, `battle_pass --release`,
`game --level=50 --drops=2`, `game --level=37 --drops=2`). iPad 13": the same screens
rendered at 2048 x 2732 with no caption and **no phone frame** (an iPhone frame on an
iPad screenshot is a 2.3.3 rejection). Upload: `tools/asc.py screenshots`.

| # | Caption | Screen (store_shot) |
|---|---|---|
| 1 | Spin the egg, set critters free! | `game` part dug, a bright level |
| 2 | Match 3 to crack the shell | `game` mid-chain, more dug |
| 3 | Rescue over 80 cute critters | `win` card with a rare critter |
| 4 | Race real players | `leaderboard` (the editor's fake board: made-up names, a sticker card) |
| 5 | Collect them all | `collection` `--collected=40` |
| 6 | Build your camp, fix the ship | `home` `--built` (`--planet=christmas` from 1 Dec) |
| 7 | A new Battle Pass every season | `battle_pass` (Christmas from 1 Dec) |
| 8 | A new Daily Egg every day | `streak` or the Daily Egg |

Christmas shots (6, 7) are worth making for an update shipped in late November or
December; swap them back after the season.

## Preview video (optional)

None today. 15-30 s, portrait, recorded from the game: an egg spinning, a block
dropped, a chain, the shell cracking, the critter popping out, then a quick pan
of Home and the leaderboard. App Store previews autoplay muted, so no voice-over;
the first 3 seconds should show the egg spinning.
