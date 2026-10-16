# Switching tabs: a screen slides in from the side, so it is built a screen's
# width off to the side. Home must still lay itself out as it will finally sit
# -- the Camp badge centred, nothing off by a screen. Goes Home -> Ranks ->
# Home and Home -> Clubs -> Home and Collection -> Home, as a finger would.
# Run with:
#   Godot.exe --path . res://tests/nav_slide_test.tscn
extends Control

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(40)
	_run.call_deferred()


func _wait_scene(suffix: String) -> void:
	for _i in 200:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s.scene_file_path.ends_with(suffix) and not SceneFlow.in_flight:
			break
	for _i in 10:
		await get_tree().process_frame


func _home_ok(label: String) -> void:
	var home := get_tree().current_scene
	var view := get_viewport().get_visible_rect().size
	var badge: Control = home.camp_badge
	var centre := badge.get_global_rect().get_center().x
	_check("%s: Home sits in place (x %.0f)" % [label, home.position.x], is_zero_approx(home.position.x))
	_check("%s: the Camp badge is centred (%.0f of %.0f)" % [label, centre, view.x], absf(centre - view.x * 0.5) < 4.0)


func _run() -> void:
	get_tree().current_scene = null   # stay alive while the scenes change under us
	visible = false
	SceneFlow.go(SceneFlow.HOME)
	await _wait_scene("home.tscn")
	_home_ok("first open")
	for tab in ["leaderboard", "clubs", "collection", "shop"]:
		SceneFlow.slide("res://scenes/%s.tscn" % tab, 1)
		await _wait_scene("%s.tscn" % tab)
		var dir := -1 if tab in ["leaderboard", "clubs"] else 1
		SceneFlow.slide(SceneFlow.HOME, dir)
		await _wait_scene("home.tscn")
		_home_ok("back from %s" % tab)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
