# UGC kit: Egg Escape

Material for creator-style ads (TikTok, Reels, Shorts, and the Google Ads App campaign's
videos): clean gameplay B-roll with no captions, plus scripts a creator reads over it.

- **Android:** Egg Escape: Block Puzzle Match (Google Play)
- **iPhone and iPad:** Egg Escape: Puzzle Break (App Store)
- **Price:** free, with optional purchases and ads

## The clips

These are in `store/ugc/clips/`. Each is vertical 720 x 1280 at 30 fps, with the game's own
music and sound effects. None has captions or an end card, so creators can add their own text
and talk over them.

| File (`.mp4` and `.avi`) | What happens | Use it for |
|---|---|---|
| `egg_escape_ugc_01_gameplay_rescue.avi` | Level 8: the egg spins, blocks drop and pop, the critter escapes, and the "Rescued!" card shows | The core loop, the hook |
| `egg_escape_ugc_02_gameplay_chains.avi` | Level 33: matches set off chain reactions | "So satisfying" moments |
| `egg_escape_ugc_03_gameplay_vines.avi` | Level 50: vines creep across the egg | Variety, challenge |
| `egg_escape_ugc_04_gameplay_locks.avi` | Level 100: padlocks and the key that opens them | Variety, "puzzle brain" |
| `egg_escape_ugc_05_gameplay_prisms.avi` | Level 150: prism stones that break one colour only | Variety |
| `egg_escape_ugc_06_gameplay_fog.avi` | Level 200: fog hides part of the egg | Variety, mystery |
| `egg_escape_ugc_07_camp_build.avi` | The crash site with nothing built, then the fire, tent, bench, garden and well going up one by one, the "Camp Lv 2!" banner, and a glide past the finished camp and the ship | Camp, progression |
| `egg_escape_ugc_08_critters.avi` | The Collection, full, scrolling slowly from top to bottom | Critters, collecting |
| `egg_escape_ugc_09_critter_parade.avi` | Every critter hops across the camp, then they all pop in to fill the screen | Critters, the ending shot |

Each clip comes as the raw AVI (35-80 MB) and an H.264/AAC MP4 (7-20 MB). Send creators the
MP4s. The gameplay clips run 10-26 seconds, the camp 22, the Collection 14 and the parade 17. A
bot plays the levels, so each recording comes out a little different. The script makes the MP4s
when FFmpeg is installed (`winget install Gyan.FFmpeg`).

To rebuild them, or just one, use `-Only 07`:

```
powershell -ExecutionPolicy Bypass -File tools/make_ugc.ps1
```

Creators recording their own phone get the most natural look. Ask for a screen recording of the
first few levels, the Collection and the camp, plus a face-cam reaction.

## Key messages

Keep to these, in this order of importance:

1. **The gameplay:** spin the egg, drop blocks, match them to pop, and dig a path out for the
   critter trapped inside.
2. **Critters:** 100+ cute critters to collect and level up, each with a name and its own look.
3. **The camp:** every win earns coins and materials to rebuild the crash site and fix the
   ship, one spot at a time.
4. Cozy and relaxing, no pressure, free to play.

Claims to avoid: "no ads", "offline", "win money", and any number of levels beyond
"hundreds".

## Script A: "The hook" (15 seconds)

For TikTok and Reels. Fast and gameplay first.

| Time | On screen | Voiceover / text |
|---|---|---|
| 0-2 s | Clip 01, the egg spinning | **Text:** "there's a critter stuck in this egg" / **VO:** "Okay, there's a little critter stuck inside this egg..." |
| 2-6 s | Clip 01, blocks dropping and popping | "...and I have to spin it and match blocks to dig it out." |
| 6-9 s | Clip 01, the critter escaping | "AND HE'S FREE." (a genuine reaction) |
| 9-12 s | Clip 08, critters scrolling | "And now I have to collect all of them." |
| 12-15 s | Clip 09's finale | **Text:** "Egg Escape, free on iPhone and Android" |

## Script B: "Why I can't stop playing this" (30 seconds)

Covers all three: gameplay, critters and camp.

| Time | On screen | Voiceover |
|---|---|---|
| 0-3 s | Face-cam, or clip 02's chain reaction | "I found the coziest puzzle game and I'm obsessed." |
| 3-10 s | Clip 01 | "Every level, a critter's trapped inside an egg. You spin the egg, drop blocks, and match colours to break your way in." |
| 10-14 s | Clip 02, the chain | "Chain reactions are SO satisfying." |
| 14-17 s | Clips 04 and 05, quick cuts | "And it keeps adding new stuff: locks, prisms, vines..." |
| 17-22 s | Clip 08 | "Every critter you save joins your collection. There are over a hundred and they're all adorable." |
| 22-27 s | Clip 07, the camp going up | "And your wins rebuild this little crash-site camp, piece by piece, so you can fix the ship." |
| 27-30 s | Clip 09's finale | "It's called Egg Escape, and it's free. Go save them all!" |

## Script C: "Cozy game check-in" (45 to 60 seconds)

For a creator with a cozy-gaming or wind-down audience. Slower and more personal.

1. **Hook (0-5 s):** "This is my new wind-down game, and it's genuinely so relaxing." Face-cam
   with clip 01 behind.
2. **How it works (5-20 s):** "So, every egg has a critter trapped inside. I spin it around,
   drop these block pieces, and when colours match they pop. Dig deep enough and the critter
   escapes." Clip 01, then clip 02.
3. **It gets clever (20-30 s):** "Later on you get puzzles like padlocks you need a key for,
   prism stones, and fog that hides the egg." Clips 04, 05 and 06, a few seconds each.
4. **The critters (30-40 s):** "The best part is the critters. You collect them, level them
   up, and they all have little names. This one's my favourite." Clip 08; pause the scroll on
   one the creator picks.
5. **The camp (40-52 s):** "And all the coins you win rebuild your camp. It starts as a crash
   site, and you build the campfire, the tent, the garden... and eventually you fix the
   rocket." Clip 07.
6. **Call to action (52-60 s):** "It's Egg Escape. It's free, so try it, and tell me which
   critter you got first." Clip 09.

## Hooks to test

Use these as the first line or as on-screen text over clip 01 or 02:

- "POV: you find a critter trapped inside an egg"
- "The most satisfying puzzle game I've played this year"
- "I said one level. It's been an hour."
- "Rate my camp" (over clip 07)
- "I need ALL of these critters" (over clip 08)
- "Wait for the chain reaction..." (over clip 02)
- "This game is so cozy it should be illegal"

## Notes for creators

- **Show the game in the first second.** The spinning egg or a pop is the hook. A face-cam
  works best as a small corner or a split screen.
- **React honestly.** The critter's escape and a chain reaction are the moments to react to.
- **Make it readable.** Keep text short and in the safe zone: away from the top 15% and the
  bottom 25% of the frame, where the app's buttons sit.
- **Keep the game's sound, or keep it low.** The pops and the escape sound help.
- **Disclose the ad.** Use #ad or the platform's paid-partnership label, as the platform and
  local law require.
- **Finish on the name.** Close on "Egg Escape" and "free". On Android the store name is
  "Egg Escape: Block Puzzle Match"; on iPhone it is "Egg Escape: Puzzle Break".
