# YouTube channel – Egg Escape: Block Puzzle Match

Everything for the game's channel: art, videos and the text to paste.

## 1. Create the channel (you)

YouTube → your profile picture → **Create a channel**. Use a **brand
account** ("Use a custom name"), so the channel has the game's name and
you can add other managers later.

- **Channel name:** Egg Escape
- **Handle:** @EggEscapeGame (or the closest one free)
- **Profile picture:** `store/youtube/avatar.png` (800 x 800)
- **Banner:** `store/youtube/banner.png` (2560 x 1440; the title, tagline
  and ship sit in YouTube's always-visible middle strip)

**Description** (paste into Customize channel → Basic info):

    Welcome to Egg Escape: Block Puzzle Match! 🥚🧩

    Spin the egg, match blocks and dig a path to free the cute critters trapped inside. Hundreds of block puzzle levels, clever blockers (vines, locks, prisms, fog…), 84 critters to collect and a crash-landed camp to rebuild.

    New Shorts every week: satisfying chains, tricky blockers and critter rescues.

    ▶ Play free on Google Play: https://play.google.com/store/apps/details?id=com.jvea.eggescape

**Links** (Basic info → Links): "Play on Google Play" → the Play Store link
(`https://play.google.com/store/apps/details?id=com.jvea.eggescape`).

**Keywords** (Settings → Channel → Basic info): egg escape, block puzzle,
puzzle game, match 3, cute games, cozy games, brain teaser, mobile game.

## 2. Upload the videos (you)

YouTube takes the `.avi` files as they are. A vertical video under 60 s is
posted as a **Short** automatically. Post one Short every few days rather
than all at once.

### Shorts (`store/youtube/shorts/`, 720 x 1280)

Each one: the hook caption over the egg, the level played to the rescue
(cut as the critter flies out), the fully built camp, the critter
collection, then the end card. Short 07 is the critter parade instead: no
level -- every critter hops across the finished camp in three lanes, then
they all pop in to fill the screen, then the end card. The `ep` rows are
"Crash Course", the mini series (tools/make_episode.gd): a title card, the
crew's story, and a "Next time" end card.

Written for YouTube search: each title is its hook plus a search phrase
(block puzzle, puzzle game, brain teaser, match 3); each description opens
with the game's full name and those words, then the Play link, then
hashtags. Tags on every video: egg escape, block puzzle, puzzle game,
brain teaser, match 3, cozy games, mobile game, android game, casual game,
satisfying, plus one naming the Short's blocker.

Each description: "<line below> in Egg Escape: Block Puzzle Match, a cozy
block puzzle game where you spin the egg, match blocks and rescue cute
critters. ▶ Play free on Google Play: <link>" then the hashtags.

| File | Length | Title | Opening line | Hashtags |
|---|---|---|---|---|
| `egg_escape_short_01_rescue.avi` | ~31 s | Can you free the critter? 🥚 Cozy Block Puzzle Game #shorts | Dig the critter out of its egg | #blockpuzzle #puzzlegame #cozygames #mobilegame #eggescape |
| `egg_escape_short_02_chains.avi` | ~23 s | Wait for the chain reaction... 😮 Satisfying Block Puzzle #shorts | Line up a chain reaction and watch the blocks pop | #satisfying #blockpuzzle #match3 #puzzlegame #eggescape |
| `egg_escape_short_03_vines.avi` | ~18 s | Vines are creeping in! 🌿 Block Puzzle Brain Teaser #shorts | Cut the vines before they spread | #blockpuzzle #puzzlegame #brainteaser #cozygames #eggescape |
| `egg_escape_short_04_locks.avi` | ~23 s | Locked in? Find the key! 🔑 Puzzle Game Brain Teaser #shorts | Dig down to the key to break the padlocks | #puzzlegame #brainteaser #blockpuzzle #mobilegame #eggescape |
| `egg_escape_short_05_prisms.avi` | ~18 s | Prism stones only break one way... 💎 Match 3 Puzzle #shorts | Match a prism's color to crack it | #match3 #puzzlegame #brainteaser #blockpuzzle #eggescape |
| `egg_escape_short_06_fog.avi` | ~26 s | What's hiding in the fog? 🌫️ Cozy Puzzle Game #shorts | Clear the fog to see what's hiding | #puzzlegame #blockpuzzle #cozygames #mobilegame #eggescape |
| `egg_escape_short_07_parade.avi` | ~20 s | Critter parade! 🥚 How many can you collect? Cozy Puzzle Game #shorts | Every critter hops across the camp | #cozygames #cute #puzzlegame #mobilegame #eggescape |
| `egg_escape_short_ep01_crash.avi` | ~32 s | Crash Course Ep. 1: Totally Fine Landing 🚀 Cute Animation #shorts | The crew's smoothest flight in history meets one tiny pebble. Next time: the Giant Eggs! | #animation #cute #cozygames #eggescape #shorts |

Add to every Short: the Play Store link as a **pinned comment** ("▶ Play free:
https://play.google.com/store/apps/details?id=com.jvea.eggescape"), and the game linked under **Related video / Links** where YouTube
offers it.

### Trailer (`store/ads/video/`)

| File | Use |
|---|---|
| `egg_escape_landscape_1920x1080.avi` (~23 s) | Upload as a normal video: **Egg Escape: Block Puzzle Match – Official Trailer**. Set it as the **channel trailer** (Customize channel → Layout → Channel trailer for people who haven't subscribed). Also the Google Ads campaign's landscape video. |
| `egg_escape_square_1080x1080.avi` (~31 s) | Google Ads square video (upload Unlisted). |
| `egg_escape_portrait_720x1280.avi` (~31 s) | Google Ads vertical video (upload Unlisted), or another Short. |

Trailer description:

    Spin the egg, match blocks and rescue the critters trapped inside! Egg Escape is a relaxing block puzzle game with hundreds of levels, clever blockers, 84 cute critters to collect and a camp to rebuild.

    ▶ Play free on Google Play: https://play.google.com/store/apps/details?id=com.jvea.eggescape

    #puzzlegame #blockpuzzle #match3 #cozygames #mobilegame

Settings for every upload: **Made for kids: No** (the game is rated for
13+ in Play's target audience), category **Gaming**, and the game title
under "Game" if YouTube offers it.

## Rebuilding

The files are 70-130 MB each and stay out of git.

    powershell -ExecutionPolicy Bypass -File tools/make_shorts.ps1
    powershell -ExecutionPolicy Bypass -File tools/make_videos.ps1
    Godot --path . res://tools/make_channel_art.tscn

`tools/make_shorts.ps1` lists each Short's level and captions; add a row
for a new one. `-Only 03` records one; `-Snaps <dir>` saves a still at each
beat.
