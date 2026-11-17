# Visual QA for the Christmas season: the date set to December 2026, then
# `home` (Santa's sleigh over Home), `level` (the sleigh behind the egg) or
# `sets` (Snow Day featured in the Sets tab), saved to OUT after WAIT seconds
# (the sleigh is sent off at once). Run with:
#   OUT=shots Godot.exe --path . res://tests/sleigh_capture.tscn -- home
extends Node

var _what := "home"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_what = args[0] if args.size() > 0 else "home"
	TSProfile.use_test_profile(20)
	_hold_date()
	TSProfile.planet_season = TSProfile.battle_pass_season_number()   # no voyage due
	var path: String = {"home": "res://scenes/home.tscn", "level": "res://scenes/game.tscn", "sets": "res://scenes/collection.tscn"}.get(_what, "res://scenes/home.tscn")
	if _what == "level":
		path = SceneFlow.GAME
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	var wait := float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 4.0
	await get_tree().process_frame
	await get_tree().process_frame
	for s in scene.find_children("*", "", true, false):
		if s is TSSleigh:
			(s as TSSleigh).set("_wait", 0.0)
	if "_sleigh" in scene and scene.get("_sleigh") != null:
		(scene.get("_sleigh") as TSSleigh).set("_wait", 0.0)
	if _what == "sets":
		scene.set("_tab", 1)
		scene.call("_show_tab")
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join("xmas_%s.png" % _what))
	get_tree().quit()


func _process(_delta: float) -> void:
	_hold_date()


func _hold_date() -> void:
	TSClock.offset = Time.get_unix_time_from_datetime_string("2026-12-03T10:00:00") - Time.get_unix_time_from_system()
