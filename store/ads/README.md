# Google Ads: App campaign for Egg Escape: Puzzle Break

Assets for a Google Ads **App campaign** (Campaign type: App promotion →
App installs, platform Android). Google mixes these into ads on Search,
Google Play, YouTube, Discover and the Display network.

An App campaign can only promote an app that is **live on Google Play**, so
set it up once production access is granted and the app is published.

## Headlines (up to 5, 30 characters max)

1. Crack the egg, free a critter
2. Spin, match & break free!
3. Collect 84 cute critters
4. A cozy space puzzle game
5. Free puzzle fun, any time

## Descriptions (up to 5, 90 characters max)

1. Spin the egg, drop matching blocks and dig a path out for the critter trapped inside.
2. Hundreds of levels, clever blockers and handy boosters. A fresh puzzle every spin!
3. Collect and level up 84 cute critters, open chests and rebuild your crashed ship.
4. Relaxing pastel art, cozy music and a new Daily Egg puzzle to crack every day.
5. Can you save them all? Play Egg Escape: Puzzle Break free today!

## Images (15 of the 20 allowed)

Five ideas, each in all three shapes App campaigns use. Upload all 15.

| Idea | Headline on the image | Landscape 1200x628 | Square 1200x1200 | Portrait 1200x1500 |
|---|---|---|---|---|
| Crack | Crack the egg. Free the critter! | `01_crack_landscape_1200x628.png` | `01_crack_square_1200x1200.png` | `01_crack_portrait_1200x1500.png` |
| Rescue | Can you save them all? | `02_rescue_landscape_1200x628.png` | `02_rescue_square_1200x1200.png` | `02_rescue_portrait_1200x1500.png` |
| Collect | Collect 84 cute critters! | `03_collect_landscape_1200x628.png` | `03_collect_square_1200x1200.png` | `03_collect_portrait_1200x1500.png` |
| Adventure | A cozy puzzle adventure | `04_adventure_landscape_1200x628.png` | `04_adventure_square_1200x1200.png` | `04_adventure_portrait_1200x1500.png` |
| Spin | Spin. Match. Escape! | `05_spin_landscape_1200x628.png` | `05_spin_square_1200x1200.png` | `05_spin_portrait_1200x1500.png` |

All are PNG, no transparency, under 1.1 MB each (the limit is 5 MB).

## Videos (3, one per shape)

Real gameplay: level 8 played by a bot, the egg turning to each piece as it
drops, blocks popping, the critter escaping and the "Rescued!" card, then an
end card with the title, the ship of critters, "Can you save them all?" and
"Play free!". The game's own music and sound effects are the soundtrack.

| File (store/ads/video/) | Shape | Length |
|---|---|---|
| `egg_escape_portrait_720x1280.avi` | Portrait 9:16 (the game full screen, captions over it) | ~24 s |
| `egg_escape_landscape_1920x1080.avi` | Landscape 16:9 (title and captions left, the game on a phone right) | ~18 s |
| `egg_escape_square_1080x1080.avi` | Square 1:1 (title and caption over the phone) | ~18 s |

Captions: "Can you free the critter?", "Spin. Match. Escape!", "Critter saved!".

Google Ads takes videos as YouTube links: upload each to YouTube (Unlisted
is fine; YouTube takes AVI as it is), then add the links to the campaign's
asset group under Videos. The files are 60-100 MB each and are not kept in
git; rebuild them with:

```
powershell -ExecutionPolicy Bypass -File tools/make_videos.ps1
```

(`-Snaps <dir>` also saves a still at each beat.) Movie Maker records the
window, so a shape can't be bigger than the screen: portrait is the game's
own 720 x 1280. The bot's game differs a little from run to run, so the
length does too.

## Rebuilding the images

`tools/make_ads.gd` puts them together from the key art
(`icons/loading_screen.webp`), the critters and the game screens in
`store/ads/src/`. To refresh the screens (after an art change, say) and
rebuild:

```
Godot --path . res://tools/store_shot.tscn -- --scene=game --level=12 --drops=3 --size=1080x1920 --out=<repo>/store/ads/src/game.png
Godot --path . res://tools/store_shot.tscn -- --scene=game --level=160 --drops=2 --size=1080x1920 --out=<repo>/store/ads/src/game_prism.png
Godot --path . res://tools/store_shot.tscn -- --scene=win --level=12 --size=1080x1920 --out=<repo>/store/ads/src/win.png
Godot --path . res://tools/make_ads.tscn
```

`-- --only=03` rebuilds just one idea. The headlines, critters and screens
for each idea are in `IDEAS` at the top of the script.
