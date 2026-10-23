# The reminders scheduled as the game goes to the background
# (scripts/meta/notify.gd): night-time ones move to 9 am, a chest unlocking
# gets one, a quick chest doesn't, and the daily one's words follow the Daily
# Egg's unlock and the streak. Run with:
#   Godot.exe --headless --path . -s tests/notify_test.gd
extends SceneTree

const N := preload("res://scripts/meta/notify.gd")

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _find(list: Array, id: int) -> Dictionary:
	for r in list:
		if int(r["id"]) == id:
			return r
	return {}


func _initialize() -> void:
	var h := 3600
	_check("a daytime reminder stays put", int(N._entry(1, "", "", h, 10 * h)["seconds"]) == h)
	_check("11 pm moves to 9 am", int(N._entry(1, "", "", h, 22 * h)["seconds"]) == 11 * h)
	_check("3 am moves to 9 am", int(N._entry(1, "", "", 2 * h, h)["seconds"]) == 8 * h)

	TSProfile.use_test_profile(3)
	TSChests.slots = [{}, {}, {}, {}]
	var early := N.reminders()
	_check("no chest, no chest reminder", _find(early, N.CHEST).is_empty())
	_check("before the Daily Egg: the next critter", str(_find(early, N.DAILY).get("title", "")).contains("critter"))
	_check("the three-day nudge", int(_find(early, N.COMEBACK).get("seconds", 0)) >= N.COMEBACK_SECONDS)

	var slot := TSChests.give(TSChests.RARE)
	TSChests.start_unlock(slot)
	var chest := _find(N.reminders(), N.CHEST)
	_check("an unlocking rare chest gets one", not chest.is_empty() and int(chest["seconds"]) >= TSChests.seconds_left(slot))
	TSChests.slots = [{}, {}, {}, {}]
	slot = TSChests.give(TSChests.COMMON)
	TSChests.start_unlock(slot)
	_check("a five-minute chest gets none", _find(N.reminders(), N.CHEST).is_empty() or TSChests.seconds_left(slot) >= N.MIN_SECONDS)

	TSProfile.last_level = TSNav.DAILY_UNLOCK_LEVEL
	TSProfile.login_streak_count = 4
	_check("a streak names its days", str(_find(N.reminders(), N.DAILY).get("title", "")).contains("4-day"))
	TSProfile.login_streak_count = 1
	_check("otherwise the Daily Egg", str(_find(N.reminders(), N.DAILY).get("title", "")).contains("Daily Egg"))
	for r in N.reminders():
		var at := (TSClock.local_unix() % 86400 + int(r["seconds"])) % 86400 / 3600
		_check("%d lands in waking hours" % int(r["id"]), at >= N.QUIET_TO and at < N.QUIET_FROM)

	print("notify_test: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
