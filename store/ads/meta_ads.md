# Meta ads (Facebook and Instagram): iOS install campaign

For Egg Escape: Puzzle Break on the App Store (id 6819941762), measured by the
Meta SDK in iOS 1.3.8 (build 16) and later: installs, app opens, the first
lesson, levels 5/10/20, valuable_player and purchases (docs/ios.md). Material
from the Google Ads App campaign (README.md), with "100+ critters" corrected to
"80+" (82 in the Collection; the App Store listing says "over 80").

## Setup (decided 26 Nov 2026)

- **Ad account:** 1147370341286624. **Meta app:** Egg Escape (1108143348953147).
- **Campaign:** `EE - Meta - iOS - Installs - US/CA`, objective App promotion,
  app Egg Escape, store App Store, optimisation App installs.
- **Budget:** $10 a day.
- **Countries:** United States and Canada (no consent card there, so Meta sees
  every install).
- **Age:** 18+ (Meta's minimum for most ad delivery; the game is rated 13+, but
  ads to under-18s are restricted).
- **Placements:** Advantage+ placements (Facebook, Instagram, Audience Network,
  Messenger).
- **Start:** published 26 Nov 2026, while 1.3.8 was still in App Review: until
  it's live, Meta can't see iPhone installs, so learning starts once it is.

## Live (26 Nov 2026)

Campaign `EE - Meta - iOS - Installs - US/CA` (Advantage+ app campaign, iOS 14+
campaign with SKAdNetwork reporting, $10/day campaign budget), ad set
`EE - iOS - US/CA - 18+ - Advantage+` (US and Canada, 18+, Advantage+
placements, Maximize number of app installs), page The Little Guy Games and
Instagram @thelittleguygames, six ads with the five primary texts and five
headlines below and Install now:

- `EE - Images - Google Ads set (80+)` (01 crack), `EE - 02 Rescue - portrait`,
  `EE - 03 Collect 80+ - portrait`, `EE - 04 Adventure - portrait`,
  `EE - 05 Spin - portrait`: the 1200x1500 images.
- `EE - Video - gameplay 9:16`: the portrait gameplay video for vertical
  placements and the square one for feeds (Crop step, per placement).

Advantage+ creative: Text improvements and Add overlays off (no AI rewrites of
the copy, no text over the art); visual touch-ups, animation and Flex media on;
no AI-generated images. The account also holds the Duckdoku (DB) drafts from
another session: publish Egg Escape drafts by selecting their rows only.

## Primary text (up to 5; 125 characters show before "See more")

1. Spin the egg, drop matching blocks and dig a path out for the critter trapped inside. 🥚
2. Hundreds of levels, clever blockers, win streaks and timed challenge eggs to beat!
3. Collect and level up 80+ cute critters, open chests and rebuild your crashed ship.
4. Relaxing pastel art, cozy music and a new Daily Egg puzzle to crack every day.
5. Can you save them all? Play Egg Escape: Puzzle Break free today!

## Headlines (up to 5, 40 characters)

1. Crack the egg, free a critter
2. Spin, match & break free!
3. Collect 80+ cute critters
4. Cozy block puzzle game
5. Free puzzle fun, any time

## Call to action

Install now.

## Images

The square (1200x1200) and portrait (1200x1500, 4:5) versions of all five
ideas: `01_crack`, `02_rescue`, `03_collect`, `04_adventure`, `05_spin`
(`*_square_1200x1200.png`, `*_portrait_1200x1500.png`). Feed placements use
square or 4:5; Stories and Reels crop the 4:5 or use a 9:16 if given. The
landscape ones are for Google's Display network and aren't needed here.

The "Collect" images were rebuilt on 26 Nov 2026 to say "Collect 80+ cute critters!"
(they said 100+).

## Videos

Rebuilt on the Mac 26 Nov 2026 with Godot's Movie Maker (the same
tools/make_video.tscn as make_videos.ps1, with a temporary override.cfg for the
window size), then made into H.264 MP4s for upload (Meta via the browser takes
files under 10 MB):

```
ffmpeg -i egg_escape_portrait_720x1280.avi -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k egg_escape_portrait_720x1280.mp4
```

Portrait 720x1280 (6.8 MB) and square 1080x1080 (3.9 MB), about 18 s each, in
store/ads/video/ (git-ignored).
