class_name TSTunables
extends RefCounted

## Live-tunable numbers in one place. DEFAULTS are the shipped values; the
## "settings" in the inbox file (store/inbox.json on GitHub, read with the
## messages: see docs/remote-settings.md) can change any of them without a
## build, and taking a key out of the file puts it back to its default.
## apply() is for tests and tools, and beats the file.

const DEFAULTS := {
	"interstitial_from_level": 30, # non-payers see a post-level ad every Nth win from this level on
	"interstitial_every_n_wins": 3,
	"interstitial_late_from_level": 60, # from here non-payers see one every interstitial_late_every_n_wins wins (payers' first start here)
	"interstitial_late_every_n_wins": 2,
	"coins_per_star": 100, # base win payout per star
	"no_ads_coin_bonus_percent": 5,
	"bomb_buy_count": 3, # bombs per mid-game coin buy
	"bomb_pack_cost": 4000, # the Shop's x5 price; the mid-game buy is pro rata
	"swap_buy_count": 3, # swaps per mid-game coin buy
	"swap_pack_cost": 3000, # the Shop's x5 Swap price
	"rocks_buy_count": 2, # rock shots per mid-game coin buy
	"rocks_pack_cost": 6000, # the Shop's x5 Rocks price
	"ad_win_coins_per_day": 5, # rewarded ads: double a win's coins
	"ad_chest_per_day": 3, # 30 minutes off an unlocking chest
	"ad_build_per_day": 3, # 30 minutes off a camp or ship build
	"social_enabled": false, # Leaderboards + Clubs are simulated on the device: "Coming soon" until they are real (the editor still shows them)
	"piece_budget_extra": 0, # pieces added to every level's counter (TSLevels.piece_budget)
}
## The most a file can set a number to (anything above is cut to this), so a
## slipped digit can't make a level unwinnable or a booster free.
const MAX_REMOTE := 1000000

static var _values: Dictionary = {}
static var _remote: Dictionary = {}
static var remote_name := ""   # the file's settings_name, if any (also the remote_settings user property)


static func apply(overrides: Dictionary) -> void:
	for key in overrides:
		_values[key] = overrides[key]


## Takes the file's settings in place of the last ones: only keys in DEFAULTS,
## of the same kind (a whole number from 0 to MAX_REMOTE, or true/false); the
## rest are left out. Returns the keys it took.
static func apply_remote(settings: Variant, name := "") -> Array:
	_remote = {}
	remote_name = name
	if not settings is Dictionary:
		return []
	for key: String in DEFAULTS:
		if not (settings as Dictionary).has(key):
			continue
		var v: Variant = settings[key]
		if DEFAULTS[key] is bool:
			if v is bool:
				_remote[key] = v
		elif (v is int or v is float) and float(v) == floorf(float(v)) and float(v) >= 0.0:
			_remote[key] = mini(int(v), MAX_REMOTE)
	return _remote.keys()


static func _value(key: String) -> Variant:
	TSInbox.load_cache()   # the last file read, before the first number is needed
	if _values.has(key):
		return _values[key]
	return _remote.get(key, DEFAULTS[key])


static func get_int(key: String) -> int:
	return int(_value(key))


static func get_bool(key: String) -> bool:
	return _value(key) == true
