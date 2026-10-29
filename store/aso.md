# Egg Escape – Play Store listing (ASO)

Store-listing text written for search: the keywords players type ("block
puzzle", "puzzle game", "match 3", "brain teaser", "relaxing", "offline",
"cute") sit in the title, the first line of the short description, and four
or five times across the full description, read naturally. Google Play
indexes all three; it penalises lists of keywords, and its policy bars words
like "free", "best" or "#1" in the title.

## App name (30 max)

    Egg Escape: Block Puzzle Match

(30 characters.) The old title, "Egg Escape: Puzzle Break", has no search
term after "puzzle". To keep the brand name, "Egg Escape: Puzzle Break" still
works, but "block puzzle" is the bigger search.

## Short description (80 max)

    Spin the egg, match blocks & free cute critters! A relaxing block puzzle game.

(78 characters.)

## Full description (4000 max)

    Crack eggs, match blocks and rescue the cutest critters in this relaxing block puzzle game!

    Your ship crash-landed on a strange planet, and the critters are stuck inside giant eggs. Spin each egg all the way around, aim your falling block and match three or more to dig a path through the shell. Open an escape hole and watch your critter break free!

    🧩 A FRESH TWIST ON BLOCK PUZZLES
    • Spin the 3D egg in any direction – every turn shows a new puzzle
    • Match 3 or more blocks, slide pieces into place and set off chain reactions
    • Easy to learn, with a gentle start and short levels you can finish in minutes
    • Hundreds of levels that grow into a real brain teaser

    🪨 CLEVER BLOCKERS
    • Armoured stones, tie-downs, geodes, creeping vines, locks and keys, prisms and fog
    • Each new blocker arrives with a quick, hands-on lesson

    💣 HANDY BOOSTERS
    • Bombs, Any Piece and Rocks for when you're stuck
    • No timers on regular levels – think as long as you like

    🐣 COLLECT CUTE CRITTERS
    • Collect and level up 84 adorable hand-drawn critters
    • Open chests full of coins, materials and rewards

    🏕️ REBUILD YOUR CAMP
    • Build a cozy camp and fix your crashed spaceship
    • Every season, fly to a new themed planet: autumn, Christmas, New Year and Valentine's

    📅 SOMETHING NEW EVERY DAY
    • A new Daily Egg puzzle every day
    • Daily streaks, quests and a seasonal Battle Pass

    🌙 RELAX AND UNWIND
    • Soft pastel art and calm music
    • Play offline, any time – no Wi-Fi needed to play

    If you love block puzzles, match 3 games and cozy brain teasers, Egg Escape is made for you. Can you save every critter?

(About 1,630 characters. Room to add a seasonal line, e.g. "NEW: the
Christmas planet is here!", when a season starts.)

## Release notes for version code 4 (500 max)

Release name: `1.0 (4) – Launch`

    <en-US>
    Welcome to Egg Escape: Block Puzzle Match!

    • Spin the egg, match blocks and dig a path to free trapped critters
    • Hundreds of block puzzle levels with clever blockers and boosters
    • Collect 84 cute critters and rebuild your crashed camp and ship
    • Fly to a new themed planet every season
    • A new Daily Egg puzzle every day

    Thanks for playing!
    </en-US>

## Release notes for version code 5 (1.1)

Release name: `1.1 (5) – Win Streaks & Challenges`

    <en-US>
    New in Egg Escape: Block Puzzle Match!

    • Win streaks: win levels in a row and each new level starts with free rocks
    • Challenge levels: beat a tough egg against a 3-minute clock for a big coin bonus
    • Reminders when your chest, build or Daily Egg is ready (you choose)
    • Smoother early levels and a clearer first tutorial
    • Leaderboards open November 11, and teams are coming December 9!
    • A redesigned Daily Streaks screen, plus bug fixes

    Thanks for playing!
    </en-US>

## Release notes for version code 6 (1.2)

Release name: `1.2 (6) – Piece Counter, Win Streaks & Challenges`

Covers 1.1 too, since 1.2 may be the first of them players get.

    <en-US>
    New in Egg Escape!

    • Win streaks start November 4: win in a row for free rocks and bonus pieces
    • Challenge levels: beat a tough egg against a 2-minute clock for a big coin bonus
    • Piece counter: each egg has a set number of pieces, so make every drop count!
    • Fairer deals, smoother difficulty, and the Daily Egg is never Extreme
    • Optional reminders for chests, builds and the Daily Egg
    • Leaderboards open November 11, and teams are coming December 9!

    Thanks for playing!
    </en-US>

## Release notes for version code 8 (1.3)

Release name: `1.3 (8) – Challenge Pieces & Replay Tips`

Code 7 (1.3 without Firebase) was uploaded too; 8 replaces it with the same notes.

    <en-US>
    New in Egg Escape!

    • Challenge levels have a piece counter too: 30 pieces to beat the clock
    • Replay Tips in Settings: see the game's tips and walkthroughs again
    • A quick guide to win streaks the first time yours starts
    • Home is lighter on your battery when you're not touching it
    • Rate Egg Escape right in the game, without leaving it
    • Bug fixes

    Thanks for playing!
    </en-US>

## Other ASO levers

- **Category and tags**: Game → Puzzle. Tags: Puzzle, Block puzzle, Match 3,
  Casual, Brain games (pick the closest Play offers).
- **Screenshots**: the first two do most of the work. The phone set is
  `store/screenshots_captioned/` (the egg mid-match, then the rescue, each
  with a big caption). Rebuild: render the raw screens into
  `store/screenshots_src/` with tools/store_shot (`--size=1080x1920`:
  `game --level=14 --drops=3`, `win --level=8 --wait=4`,
  `collection --collected=40`, `home --built`, `game --level=50 --drops=2`,
  `game --level=37 --drops=2`), then run `res://tools/make_store_screens.tscn`.
- **Promo video**: the YouTube trailer (https://www.youtube.com/watch?v=egDqiAWohac)
  is the listing's video.
- **Feature graphic**: shown with any promo video; worth a gameplay clip once
  the video ads are on YouTube.
- **Ratings**: ask for a review after a happy moment (a win streak or a
  finished camp level), never after a loss. Ratings weigh heavily in ranking.
- **Custom store listings**: Play lets each country or ad campaign have its
  own listing text, to test other titles or a seasonal hook.
