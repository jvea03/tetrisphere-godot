# The voyage, end to end: a new season since the critters landed, so opening
# Home flies the ship on (the voyage cutscene), which lands the critters on a
# planet dressed for the season and goes back to Home there. Run with:
#   Godot.exe --path . res://tests/voyage_test.tscn
extends Control

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSClock.offset = Time.get_unix_time_from_datetime_string("2026-12-03T10:00:00") - Time.get_unix_time_from_system()
	TSProfile.planet_season = TSProfile.battle_pass_season_number() - 1   # landed last season
	TSProfile.planet_theme = "autumn"
	var planet := TSProfile.planet_number
	_run.call_deferred(planet)


## The network clock sync would put the real date back: keep the pretend one.
func _hold_date() -> void:
	TSClock.offset = Time.get_unix_time_from_datetime_string("2026-12-03T10:00:00") - Time.get_unix_time_from_system()


func _scene() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s != null else ""


func _run(planet: int) -> void:
	get_tree().current_scene = null   # stay alive (a child of the root) while the scenes change under us
	visible = false
	SceneFlow.go(SceneFlow.HOME)
	for _i in 120:
		await get_tree().process_frame
		_hold_date()
		if _scene().ends_with("voyage.tscn"):
			break
	_check("a new season: Home sends the ship on its voyage", _scene().ends_with("voyage.tscn"))
	_check("the critters land on the next planet, dressed for Christmas", TSProfile.planet_number == planet + 1 and TSProfile.planet_theme == "christmas" and not TSProfile.voyage_due())
	var voyage := get_tree().current_scene
	if voyage != null and voyage.has_method("_finish"):
		voyage.call("_finish")
	for _i in 120:
		await get_tree().process_frame
		if _scene().ends_with("home.tscn"):
			break
	for _i in 30:
		await get_tree().process_frame
	_check("then Home opens there -- and stays (no second voyage)", _scene().ends_with("home.tscn"))
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
