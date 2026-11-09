# Remote settings

Some of the game's numbers (ad frequency, rewarded-ad caps, prices) can be
changed without a new build. They live in the same file as the inbox,
`store/inbox.json`, under `"settings"`. Edit it, commit and push to `main`.
Phones pick it up the next time Home opens (allow a few minutes for GitHub's
cache), and remember it offline. Needs a build with this feature (1.3.3 on).

```json
{
  "messages": [],
  "settings_name": "ads-l10",
  "settings": {
    "interstitial_from_level": 10,
    "interstitial_every_n_wins": 3
  }
}
```

- Leave a number out to use the shipped value. Take `"settings"` out (or
  empty it) to undo everything.
- `settings_name` is a label for the setup. It's sent to Analytics as the
  `remote_settings` user property (`default` when there's no name), so you can
  compare players on each setup. Change it whenever you change the numbers.
- `"messages"` must be there, even if it's empty, or the whole file is ignored.
- A broken file is ignored and phones keep the last good one. A wrong value
  (negative, a fraction, text, a misspelled key) is skipped and that number
  stays at its shipped value. Numbers are capped at 1,000,000.
- Changes apply from the next win or screen that reads the number, with no
  restart. A phone that hasn't opened Home online since uses the last file it read.

## The numbers

| Key | Shipped | What it does |
|---|---|---|
| `interstitial_from_level` | 30 | Players who haven't bought anything see an ad between levels from this level |
| `interstitial_every_n_wins` | 3 | ...on every Nth win |
| `interstitial_late_from_level` | 60 | From this level the late rhythm applies (payers' first interstitials start here) |
| `interstitial_late_every_n_wins` | 2 | ...an ad every Nth win |
| `ad_win_coins_per_day` | 5 | Double Coins ads a day (win card, level 5 on) |
| `ad_chest_per_day` | 3 | "30 min off" ads a day for chests |
| `ad_build_per_day` | 3 | "30 min off" ads a day for camp/ship builds |
| `coins_per_star` | 100 | Coins per star on a win |
| `no_ads_coin_bonus_percent` | 5 | Extra coins for No Ads owners |
| `bomb_buy_count`, `swap_buy_count`, `rocks_buy_count` | 3, 3, 2 | Boosters per mid-game coin buy |
| `bomb_pack_cost`, `swap_pack_cost`, `rocks_pack_cost` | 4000, 3000, 6000 | Shop x5 prices (mid-game buys are pro rata) |
| `piece_budget_extra` | 0 | Pieces added to every level's counter |
| `social_enabled` | false | `true`/`false`. Leaderboards and Clubs are simulated on the phone; leave this off |

## Trying a change safely

1. Change one thing at a time, with a new `settings_name`.
2. Watch a week of GA4: level starts and wins (Early funnel), DAU, and AdMob
   earnings. Split by the `remote_settings` user property once it's registered
   as a custom dimension in GA4.
3. If retention drops, remove the setting. Phones go back on their next Home visit.
