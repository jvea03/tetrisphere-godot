# Apple Ads (App Store search) plan: Egg Escape: Puzzle Break

The iOS app (id 6819941762) advertised in App Store search results, through
Apple Ads **Advanced** (keywords and bids under our control). Apple counts the
installs itself, so there's no SDK and nothing in the app to change.

## Setup

- **Countries:** United States and Canada, one campaign set per country (Apple
  bills and reports per country; Canada starts at a smaller budget).
- **Placement:** Search results (the main one). Leave Today tab and product
  pages off until search shows what works.
- **Budget:** about $10 a day in all for the first one to two weeks: US $7, CA $3.
- **Bids:** start at a max cost-per-tap of **$0.90** (Apple suggests ranges; stay
  near the low end and raise winners).
- **Audience:** all users, every age the rating allows. Leave customer type at
  "All users" to begin with.
- **Ad:** the default ad, built from the App Store listing's screenshots (already
  captioned). Custom product pages can come later.

## Campaigns (per country)

1. **Discovery:** Search Match on, no keywords. Apple matches searches to the
   listing; its search-terms report shows which words bring installs. $0.80
   max cost-per-tap.
2. **Generic:** Search Match off; the keywords below on Exact match, plus Broad
   in a second ad group so new terms surface. $0.90 max cost-per-tap.
3. **Brand:** "egg escape" on Exact at $0.50, so someone looking for the game
   by name always finds it, not a rival's ad.

No competitor game names: Apple refuses some, and it's a fast way to waste money.

## Keywords (Generic)

block puzzle, block puzzle game, puzzle games, puzzle game free, match puzzle,
match 3, cute games, cute puzzle game, kawaii games, cozy games, relaxing games,
brain games, brain puzzle, egg games, egg game, critter games, pet collecting
game, collect animals game, puzzle adventure, offline puzzle games, casual games,
satisfying games, tile match, block blast, block games

**Negative keywords (all campaigns):** free money, casino, slots, multiplayer
shooter, word, crossword, sudoku (unless it earns), jigsaw.

## Reading the results (after about 7 days)

- **Cost per install** (Apple's "CPA") by keyword. Keep under about $1.50 to
  start; pause anything far over it with installs coming in, and raise bids
  where it is low and impressions are few.
- **Tap-through rate** below 5%: the term doesn't fit the listing; pause it.
- **Install rate (installs per tap)** below 40%: the listing isn't convincing
  for that term.
- Whether the installs become players: Firebase (GA4, iOS stream) `level_start`
  and `tutorial_complete` against the installs Apple reports for the same days.
- Search terms from the Discovery campaign that bring installs move into
  Generic as Exact keywords (and become negatives in Discovery).
