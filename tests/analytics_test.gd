# What TSAnalytics sends from a level (off-device it only keeps TSAnalytics.recent):
# level_start when an egg begins or is retried; level_end with the level as a
# number, its kind, the play time, the pieces dropped and the hearts left; and
# a parked egg keeps its drops and time. Run with:
#   Godot.exe --headless --path . res://tests/analytics_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(40)
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _last(name: String) -> Dictionary:
	for i in range(TSAnalytics.recent.size() - 1, -1, -1):
		if TSAnalytics.recent[i][0] == name:
			return TSAnalytics.recent[i][1]
	return {}


func _run() -> void:
	_close_cards()
	TSAnalytics.recent.clear()
	_start_level(20)
	var s := _last("level_start")
	_check("a level sends level_start with its number and kind", s.get("level") == 20 and s.get("kind") == "level" and s.get("level_name") == "level_20")

	_drop()
	_drop()
	for _i in 30:
		await get_tree().process_frame
	_check("drops are counted (2, got %d)" % drops, drops == 2)
	_check("play time is counted", play_seconds > 0.1)

	var snap := _snapshot()
	drops = 0
	play_seconds = 0.0
	TSSession.state = snap
	_resume()
	_check("a parked egg keeps its drops and play time", drops == 2 and play_seconds > 0.1)

	play_seconds = 61.4
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	var e := _last("level_end")
	_check("a loss sends level_end with success false", e.get("success") == false and e.get("level") == 20 and e.get("kind") == "level")
	_check("...its play time in whole seconds (61, got %s)" % str(e.get("seconds")), e.get("seconds") == 61)
	_check("...the pieces dropped and the hearts left", e.get("drops") == 2 and e.get("hearts_left") == 0)

	_close_cards()
	TSAnalytics.recent.clear()
	_start_level(20)
	_check("a retry sends level_start again, with fresh counters", not _last("level_start").is_empty() and drops == 0 and play_seconds < 0.5)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
