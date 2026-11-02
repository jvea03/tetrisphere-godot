# The crash cutscene on its way into level 1, on a throwaway profile: it
# sends intro_start, loads level 1 behind itself, and once skipped sends
# intro_end ("skip") and goes into the game, which sends level_loaded (just
# once) and level 1's level_start. Run with:
#   Godot.exe --headless --path . res://tests/intro_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _has(name: String) -> bool:
	for e in TSAnalytics.recent:
		if e[0] == name:
			return true
	return false


func _last(name: String) -> Dictionary:
	for i in range(TSAnalytics.recent.size() - 1, -1, -1):
		if TSAnalytics.recent[i][0] == name:
			return TSAnalytics.recent[i][1]
	return {}


func _ready() -> void:
	TSProfile.use_test_profile(1)
	TSProfile.intro_seen = false
	TSAnalytics.recent.clear()
	# The cutscene as the current scene beside this one, so the scene change
	# into level 1 frees it and not the test.
	var intro: Node = (load("res://scenes/intro.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(intro)
	await get_tree().process_frame
	get_tree().current_scene = intro
	await get_tree().process_frame
	_check("the cutscene sends intro_start", _has("intro_start"))
	_check("...and loads level 1 behind itself",
		ResourceLoader.load_threaded_get_status(SceneFlow.GAME) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)

	for _i in 30:
		await get_tree().process_frame
	intro.call("on_back_requested")   # as the Skip button
	var e := _last("intro_end")
	_check("skipping sends intro_end, how: skip", e.get("how") == "skip" and e.get("seconds", -1) >= 0)
	_check("...and marks the cutscene seen", TSProfile.intro_seen)

	var waited := 0
	while waited < 600 and not (get_tree().current_scene is Node3D):
		await get_tree().process_frame
		waited += 1
	_check("level 1 follows", get_tree().current_scene is Node3D)
	for _i in 5:
		await get_tree().process_frame
	var loaded := _last("level_loaded")
	_check("the game sends level_loaded with the wait (%s s)" % str(loaded.get("seconds")), loaded.has("seconds") and float(loaded["seconds"]) >= 0.0)
	_check("...and level 1's level_start", _last("level_start").get("level") == "1")

	var count := 0
	TSAnalytics.level_loaded()   # again, with no cutscene before it
	for x in TSAnalytics.recent:
		if x[0] == "level_loaded":
			count += 1
	_check("level_loaded is sent only once", count == 1)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
