class_name TSChests
extends RefCounted

## The chest tray on Home: four slots above PLAY, the fourth only open to
## Battle Pass holders. Every WINS_PER_CHEST level wins earn a chest (rarity
## rolled by DROP_WEIGHTS) into a free slot. A chest sits locked until tapped
## to start its timer -- one at a time, or two with the pass -- and once the
## timer is up a tap opens it for coins. Ported from Duckdoku's Chests.
##
## State is static and saved by TSProfile (to_save / from_save).

const SLOT_COUNT := 4
const PASS_SLOT := 3
const CONCURRENT_UNLOCKS := 1
const CONCURRENT_UNLOCKS_WITH_PASS := 2
const WINS_PER_CHEST := 3

const COMMON := "common"
const RARE := "rare"
const LEGENDARY := "legendary"
const RARITIES := [COMMON, RARE, LEGENDARY]

const DISPLAY_NAMES := {COMMON: "Common", RARE: "Rare", LEGENDARY: "Legendary"}
const UNLOCK_SECONDS := {COMMON: 5 * 60, RARE: 60 * 60, LEGENDARY: 24 * 60 * 60}
## The No Ads pass and an active Battle Pass each shave this off a timer.
const TIMER_DISCOUNT_PERCENT := 10
const DROP_WEIGHTS := {COMMON: 60, RARE: 30, LEGENDARY: 10}
const COIN_PAYOUT := {COMMON: [200, 500], RARE: [2000, 6000], LEGENDARY: [8000, 12000]}
## Building materials for the camp and the ship (TSProfile.materials).
const MATERIAL_PAYOUT := {COMMON: [8, 12], RARE: [20, 30], LEGENDARY: [50, 70]}

## {} for an empty slot, or {"rarity", "unlock_end"}: 0 until the timer
## starts, then the unix time it finishes.
static var slots: Array = [{}, {}, {}, {}]
static var win_progress: int = 0


static func to_save() -> Dictionary:
	return {"slots": slots.duplicate(true), "win_progress": win_progress}


static func from_save(data: Dictionary) -> void:
	var loaded: Array = data.get("slots", [])
	slots = []
	for i in SLOT_COUNT:
		var s: Dictionary = loaded[i] if i < loaded.size() and loaded[i] is Dictionary else {}
		if s.has("rarity") and RARITIES.has(s["rarity"]):
			slots.append({"rarity": str(s["rarity"]), "unlock_end": int(s.get("unlock_end", 0))})
		else:
			slots.append({})
	win_progress = clampi(int(data.get("win_progress", 0)), 0, WINS_PER_CHEST)


static func has_pass() -> bool:
	return TSProfile.battle_pass_active()


static func slot_open(i: int) -> bool:
	return i != PASS_SLOT or has_pass()


static func max_concurrent_unlocks() -> int:
	return CONCURRENT_UNLOCKS_WITH_PASS if has_pass() else CONCURRENT_UNLOCKS


static func unlocking_count() -> int:
	var n := 0
	for i in SLOT_COUNT:
		if is_unlocking(i):
			n += 1
	return n


static func is_empty(i: int) -> bool:
	return slots[i].is_empty()


static func rarity_of(i: int) -> String:
	return str(slots[i].get("rarity", ""))


static func is_unlocking(i: int) -> bool:
	return not is_empty(i) and int(slots[i]["unlock_end"]) > 0 and not is_ready(i)


static func is_ready(i: int) -> bool:
	var end := int(slots[i].get("unlock_end", 0))
	return end > 0 and _now() >= end


static func seconds_left(i: int) -> int:
	return maxi(int(slots[i].get("unlock_end", 0)) - _now(), 0)


static func can_start_another() -> bool:
	return unlocking_count() < max_concurrent_unlocks()


static func free_slot() -> int:
	for i in SLOT_COUNT:
		if is_empty(i) and slot_open(i):
			return i
	return -1


static func wins_to_next() -> int:
	return WINS_PER_CHEST - win_progress


## Once per level win: the rarity of a chest this win earned, or "".
static func record_win() -> String:
	if not TSNav.features_unlocked():
		return ""
	win_progress = mini(win_progress + 1, WINS_PER_CHEST)
	if win_progress < WINS_PER_CHEST:
		TSProfile.save()
		return ""
	var slot := free_slot()
	if slot < 0:
		TSProfile.save()
		return ""
	var rarity := _roll_rarity()
	slots[slot] = {"rarity": rarity, "unlock_end": 0}
	win_progress = 0
	TSProfile.save()
	return rarity


static func start_unlock(i: int) -> bool:
	if is_empty(i) or int(slots[i]["unlock_end"]) > 0 or not can_start_another():
		return false
	slots[i]["unlock_end"] = _now() + unlock_seconds(rarity_of(i))
	TSProfile.save()
	return true


## Opens a ready chest: grants and returns {"rarity", "coins", "materials"}.
static func open(i: int) -> Dictionary:
	if not is_ready(i):
		return {}
	var rarity := rarity_of(i)
	var range_: Array = COIN_PAYOUT[rarity]
	var coins := TSProfile.boost_earned_coins(randi_range(int(range_[0]), int(range_[1])))
	TSProfile.coin_count += coins
	var mats := randi_range(int(MATERIAL_PAYOUT[rarity][0]), int(MATERIAL_PAYOUT[rarity][1]))
	TSProfile.add_materials(mats)
	slots[i] = {}
	TSProfile.record_quest_event("chest")
	TSProfile.save()
	return {"rarity": rarity, "coins": coins, "materials": mats}


static func _roll_rarity() -> String:
	var total := 0
	for r in RARITIES:
		total += int(DROP_WEIGHTS[r])
	var pick := randi_range(1, total)
	for r in RARITIES:
		pick -= int(DROP_WEIGHTS[r])
		if pick <= 0:
			return r
	return COMMON


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func timer_discount_percent() -> int:
	var pct := 0
	if TSProfile.no_ads:
		pct += TIMER_DISCOUNT_PERCENT
	if TSProfile.battle_pass_active():
		pct += TIMER_DISCOUNT_PERCENT
	return pct


static func unlock_seconds(rarity: String) -> int:
	return roundi(int(UNLOCK_SECONDS[rarity]) * (100 - timer_discount_percent()) / 100.0)


## "5 min" / "1 hour" / "1 day", or "4m 30s" once a discount is in play.
static func format_unlock_time(rarity: String) -> String:
	var s := unlock_seconds(rarity)
	if s >= 86400 and s % 86400 == 0:
		@warning_ignore("integer_division")
		var d := s / 86400
		return "%d day%s" % [d, "" if d == 1 else "s"]
	if s >= 3600 and s % 3600 == 0:
		@warning_ignore("integer_division")
		var hr := s / 3600
		return "%d hour%s" % [hr, "" if hr == 1 else "s"]
	if s >= 3600:
		@warning_ignore("integer_division")
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	if s % 60 != 0:
		@warning_ignore("integer_division")
		return "%dm %ds" % [s / 60, s % 60]
	@warning_ignore("integer_division")
	return "%d min" % maxi(s / 60, 1)


## Coins to finish an unlocking chest now: its full price times the share of
## the timer still to run, rounded up to 50, never under SKIP_MIN_COINS.
const SKIP_OVER_PAYOUT_PERCENT := 10
const SKIP_MIN_COINS := 50

static func skip_cost(i: int) -> int:
	if not is_unlocking(i):
		return 0
	var left := clampf(float(seconds_left(i)) / float(maxi(unlock_seconds(rarity_of(i)), 1)), 0.0, 1.0)
	return maxi(ceili(skip_full_price(rarity_of(i)) * left / 50.0) * 50, SKIP_MIN_COINS)


static func skip_full_price(rarity: String) -> int:
	var top: int = TSProfile.boost_earned_coins(int(COIN_PAYOUT[rarity][1]))
	@warning_ignore("integer_division")
	var floor_coins: int = (top * (100 + SKIP_OVER_PAYOUT_PERCENT) + 99) / 100
	return ceili(floor_coins / 50.0) * 50


static func skip_unlock(i: int) -> bool:
	if not is_unlocking(i):
		return false
	var cost := skip_cost(i)
	if TSProfile.coin_count < cost:
		return false
	TSProfile.coin_count -= cost
	slots[i]["unlock_end"] = _now()
	TSProfile.save()
	return true


static func format_countdown(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func format_countdown_short(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh" % ceili(seconds / 3600.0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]
