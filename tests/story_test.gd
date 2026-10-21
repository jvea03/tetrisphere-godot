# A brand-new player's first Home visit says where the story is going -- the
# camp and the ship have to be rebuilt to get off the planet -- once; a player
# already past the camp's unlock never gets it. And Daily Streaks shows the
# Daily Egg's streak only once the Daily Egg has unlocked, with the Home
# streak badge waiting on the login reward alone until then. Run with:
#   Godot.exe --path . res://tests/story_test.tscn
extends "res://scripts/screens/home.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(1)
	TSProfile.ship_story_seen = false
	TSProfile.home_tutorial_seen = false
	TSProfile.daily_callout_seen = false
	TSProfile.camp_callout_seen = false
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _streak_cards(level: int) -> int:
	TSProfile.last_level = level
	var s: Control = (load("res://scenes/streak.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	var n := 0
	for l in s.find_children("*", "Label", true, false):
		if (l as Label).text.ends_with("STREAK"):
			n += 1
	s.queue_free()
	await get_tree().process_frame
	return n


func _run() -> void:
	_check("the first visit opens the story", tutorial.visible and str(tutorial.steps[0]["text"]).contains("rebuild the camp and fix up the ship"))
	_check("it has nothing else queued behind it (no camp or chest lessons yet)", tutorial.steps.size() == 2)
	tutorial._advance()
	await get_tree().create_timer(0.5).timeout
	tutorial._advance()
	await get_tree().create_timer(0.5).timeout
	_check("it finishes and is remembered", not tutorial.visible and TSProfile.ship_story_seen)
	# Daily Streaks
	_check("before the Daily Egg unlocks only the login streak shows", await _streak_cards(6) == 1)
	TSProfile.login_streak_last_date = TSClock.date_string()
	TSProfile.login_reward_claimed_date = TSClock.date_string()
	TSProfile.daily_reward_claimed_date = ""
	TSProfile.last_level = 6
	_check("and the Home streak badge waits on that alone", TSProfile.has_claimed_all_streak_rewards_today())
	_check("once it unlocks both show", await _streak_cards(TSNav.DAILY_UNLOCK_LEVEL) == 2)
	TSProfile.last_level = TSNav.DAILY_UNLOCK_LEVEL
	_check("and the badge waits on the daily reward too", not TSProfile.has_claimed_all_streak_rewards_today())
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
