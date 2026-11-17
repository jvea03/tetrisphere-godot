# Visual QA for the Snowball Fight: the date held on a Christmas-season
# Saturday (2026-12-05), then `screen` (the event, 520 snowballs thrown, the
# first milestone claimed), `result` (last weekend's result shown on top) or
# `home` (its tile on Home), saved to OUT after WAIT seconds. Run with:
#   OUT=shots Godot.exe --path . res://tests/snowball_capture.tscn -- screen
extends Node

var _what := "screen"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_what = args[0] if args.size() > 0 else "screen"
	TSProfile.use_test_profile(20)
	_hold_date()
	TSProfile.planet_season = TSProfile.battle_pass_season_number()   # no voyage due
	TSSnowball.roll()
	TSSnowball.team = "red"
	TSSnowball.thrown = 520
	TSSnowball.claimed = [0]
	if _what == "result":
		TSSnowball.result = {"team": "red", "won": true, "coins": 3500, "bombs": 1, "mine": 1243118, "theirs": 1198542, "thrown": 812}
	var path := "res://scenes/home.tscn" if _what == "home" else "res://scenes/snowball.tscn"
	add_child((load(path) as PackedScene).instantiate())
	var wait := float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 2.5
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join("snowball_%s.png" % _what))
	get_tree().quit()


func _process(_delta: float) -> void:
	_hold_date()


func _hold_date() -> void:
	TSClock.offset = Time.get_unix_time_from_datetime_string("2026-12-05T14:00:00") - Time.get_unix_time_from_system()
