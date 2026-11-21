# Apple Ads (App Store search) plan: Egg Escape: Puzzle Break

The iOS app (id 6819941762) advertised in App Store search results, through
Apple Ads **Advanced** (keywords and bids under our control). Apple counts the
installs itself, so there's no SDK and nothing in the app to change.

## Setup

- **Countries:** United States and Canada together in each campaign (as the
  Duckdoku campaigns in the same account do).
- **Placement:** Search results (the main one). Leave Today tab and product
  pages off until search shows what works.
- **Budget:** $10 a day in all: Discovery $3, Generic $5, Brand $2.
- **Bids:** start at a max cost-per-tap of **$0.90** (Apple suggests ranges; stay
  near the low end and raise winners).
- **Audience:** all users, every age the rating allows. Leave customer type at
  "All users" to begin with.
- **Ad:** the default ad, built from the App Store listing's screenshots (already
  captioned). Custom product pages can come later.

## Campaigns (created 2026-11-21, Manage Bids, all users, default ad)

1. **Discovery** (`EE - ASA - Discovery - US/CA`, ad group "Search Match"):
   Search Match on, no keywords. Apple matches searches to the
   listing; its search-terms report shows which words bring installs. $0.80
   max cost-per-tap.
2. **Generic** (`EE - ASA - Generic - US/CA`, ad group "Keywords - Exact"):
   Search Match off; the keywords below on Exact match, $0.90 max cost-per-tap.
   Discovery does the finding, so there is no Broad ad group.
3. **Brand** (`EE - ASA - Brand - US/CA`, ad group "Brand - Exact"): egg
   escape, egg escape puzzle break, egg escape game, on Exact at $0.50, so someone looking for the game
   by name always finds it, not a rival's ad.

No competitor game names: Apple refuses some, and it's a fast way to waste money.

## Keywords (Generic)

block puzzle, block puzzle game, puzzle games, puzzle game free, match puzzle,
match 3, cute games, cute puzzle game, kawaii games, cozy games, relaxing games,
brain games, brain puzzle, egg games, egg game, critter games, pet collecting
game, collect animals game, puzzle adventure, offline puzzle games, casual games,
satisfying games, tile match, block games (24; "block blast" left out: it's a
rival game's name)

**Negative keywords (Discovery and Generic ad groups, Exact):** casino, slots,
crossword, word, jigsaw, shooter, free money.

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
