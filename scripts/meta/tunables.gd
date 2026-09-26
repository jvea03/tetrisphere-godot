class_name TSTunables
extends RefCounted

## Live-tunable numbers in one place, so a remote-config SDK can override them
## without a build. Nothing fetches anything yet: DEFAULTS are the shipped
## values and apply() is the hook an integration would call.

const DEFAULTS := {
	"interstitial_from_level": 30, # non-payers see a post-level ad every Nth win from this level on
	"interstitial_every_n_wins": 3,
	"interstitial_every_win_from_level": 60,
	"coins_per_star": 100, # base win payout per star
	"no_ads_coin_bonus_percent": 5,
	"bomb_buy_count": 3, # bombs per mid-game coin buy
	"bomb_pack_cost": 4000, # the Shop's x5 price; the mid-game buy is pro rata
	"swap_buy_count": 3, # swaps per mid-game coin buy
	"swap_pack_cost": 3000, # the Shop's x5 Swap price
	"rocks_buy_count": 2, # rock shots per mid-game coin buy
	"rocks_pack_cost": 6000, # the Shop's x5 Rocks price
	"social_enabled": true, # Leaderboards + Clubs; false shows "Coming soon"
}

static var _values: Dictionary = {}


static func apply(overrides: Dictionary) -> void:
	for key in overrides:
		_values[key] = overrides[key]


static func get_int(key: String) -> int:
	return int(_values.get(key, DEFAULTS[key]))


static func get_bool(key: String) -> bool:
	return _values.get(key, DEFAULTS[key]) == true
