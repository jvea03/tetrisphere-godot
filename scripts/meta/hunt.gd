class_name TSHunt
extends RefCounted

## The 7-Day Eggsperience (Duckdoku's Voyage, re-themed): a rolling event with
## three quests for each of seven days. Day N unlocks N-1 days after the hunt
## began; a day's quests only count once it is unlocked, and finishing all
## three pays that day's coins on the spot. Earlier days stay open for
## catching up. HUNT_LENGTH_DAYS after it began a fresh hunt starts.
##
## Opens with the level-7 features. Progress is fed by
## TSProfile.record_quest_event, the same stats the quests use.

const DAYS := 7
const HUNT_LENGTH_DAYS := 10 # days 1-7 unlock over a week, then 3 days of grace

## Per day: three quests {name, stat, target}. "level" means reach a level
## `target` above the one the hunt began on; "collection" means be at that
## Collection level.
const QUESTS := [
	[{"name": "Reach level", "stat": "level", "target": 7}, {"name": "Clear 60 pieces", "stat": "clear", "target": 60}, {"name": "Use 1 booster", "stat": "booster", "target": 1}],
	[{"name": "Reach level", "stat": "level", "target": 14}, {"name": "Reach Collection level 2", "stat": "collection", "target": 2}, {"name": "Open 2 chests", "stat": "chest", "target": 2}],
	[{"name": "Reach level", "stat": "level", "target": 21}, {"name": "Use 5 boosters", "stat": "booster", "target": 5}, {"name": "Win 1 level flawless", "stat": "flawless", "target": 1}],
	[{"name": "Reach level", "stat": "level", "target": 28}, {"name": "Clear 120 pieces", "stat": "clear", "target": 120}, {"name": "Complete a Daily Egg", "stat": "daily_puzzle", "target": 1}],
	[{"name": "Reach level", "stat": "level", "target": 35}, {"name": "Open 3 chests", "stat": "chest", "target": 3}, {"name": "Win 2 levels flawless", "stat": "flawless", "target": 2}],
	[{"name": "Reach level", "stat": "level", "target": 42}, {"name": "Use 8 boosters", "stat": "booster", "target": 8}, {"name": "Clear 150 pieces", "stat": "clear", "target": 150}],
	[{"name": "Reach level", "stat": "level", "target": 49}, {"name": "Win 3 levels flawless", "stat": "flawless", "target": 3}, {"name": "Open 5 chests", "stat": "chest", "target": 5}],
]
const DAY_REWARDS := [1000, 1000, 1000, 1000, 1000, 1000, 3000]

static var start_day: int = 0 # local day index the hunt began on; 0 = not started
static var start_level: int = 0
static var best_level: int = 0
static var progress: Array = []
static var claimed: Array = []
static var last_seen_day: int = 0
static var reward_message: String = ""


static func _static_init() -> void:
	_blank()


static func _blank() -> void:
	progress = []
	claimed = []
	for i in DAYS:
		progress.append({})
		claimed.append(false)


static func to_save() -> Dictionary:
	return {"start_day": start_day, "start_level": start_level, "best_level": best_level, "progress": progress.duplicate(true), "claimed": claimed.duplicate(), "last_seen_day": last_seen_day}


static func from_save(data: Dictionary) -> void:
	_blank()
	start_day = int(data.get("start_day", 0))
	start_level = int(data.get("start_level", TSProfile.last_level))
	best_level = int(data.get("best_level", TSProfile.last_level))
	last_seen_day = int(data.get("last_seen_day", 0))
	var p: Array = data.get("progress", [])
	var c: Array = data.get("claimed", [])
	for i in DAYS:
		if i < p.size() and p[i] is Dictionary:
			progress[i] = p[i]
		if i < c.size():
			claimed[i] = bool(c[i])


static func _today() -> int:
	return TSProfile._local_day_index()


static func is_open() -> bool:
	return TSNav.features_unlocked()


## Starts the clock the first time, and a new hunt once the old one ran out.
static func roll() -> void:
	if not is_open():
		return
	if progress.size() != DAYS:
		_blank()
	var today := _today()
	if start_day == 0 or today >= start_day + HUNT_LENGTH_DAYS:
		start_day = today
		start_level = TSProfile.last_level
		best_level = start_level
		_blank()
		last_seen_day = 0
		TSProfile.save()


static func goal_level(day: int, i: int) -> int:
	return start_level + int(QUESTS[day - 1][i]["target"])


static func quest_name(day: int, i: int) -> String:
	var q: Dictionary = QUESTS[day - 1][i]
	if q["stat"] == "level":
		return "Reach level %d" % goal_level(day, i)
	return q["name"]


static func today_day() -> int:
	if start_day == 0:
		return 1
	return clampi(_today() - start_day + 1, 1, DAYS)


static func day_unlocked(day: int) -> bool:
	return start_day > 0 and day <= today_day()


static func days_left() -> int:
	if start_day == 0:
		return HUNT_LENGTH_DAYS
	return maxi(start_day + HUNT_LENGTH_DAYS - _today(), 0)


static func quest_progress(day: int, i: int) -> int:
	var q: Dictionary = QUESTS[day - 1][i]
	if q["stat"] == "level":
		return clampi(best_level - start_level, 0, int(q["target"]))
	if q["stat"] == "collection":
		return clampi(TSProfile.collection_level(), 0, int(q["target"]))
	return mini(int(progress[day - 1].get(q["stat"], 0)), int(q["target"]))


static func quest_done(day: int, i: int) -> bool:
	return quest_progress(day, i) >= int(QUESTS[day - 1][i]["target"])


static func day_done(day: int) -> bool:
	for i in QUESTS[day - 1].size():
		if not quest_done(day, i):
			return false
	return true


static func day_claimed(day: int) -> bool:
	return bool(claimed[day - 1])


static func record_event(stat: String, amount: int) -> void:
	if not is_open():
		return
	roll()
	if start_day == 0:
		return
	for day in range(1, DAYS + 1):
		if not day_unlocked(day) or day_claimed(day):
			continue
		var p: Dictionary = progress[day - 1]
		p[stat] = int(p.get(stat, 0)) + amount
		if day_done(day):
			_pay_day(day)


## The game reports each level won, so "Reach level" quests advance.
static func note_level_reached(level: int) -> void:
	if not is_open():
		return
	roll()
	if start_day == 0 or level <= best_level:
		return
	best_level = level
	for day in range(1, DAYS + 1):
		if day_unlocked(day) and not day_claimed(day) and day_done(day):
			_pay_day(day)


static func _pay_day(day: int) -> void:
	claimed[day - 1] = true
	var coins := TSProfile.boost_earned_coins(int(DAY_REWARDS[day - 1]))
	TSProfile.coin_count += coins
	TSProfile.note_coins("Eggsperience Day %d" % day, coins)
	reward_message = "Day %d complete! +%s coins" % [day, TSProfile.fmt_coins(coins)]


static func has_alert() -> bool:
	return is_open() and today_day() > last_seen_day


static func mark_seen() -> void:
	if today_day() != last_seen_day:
		last_seen_day = today_day()
		TSProfile.save()
