# Plays the Collection walkthrough as a brand-new player. Its "Tap Grad" step
# spotlights one critter far down the alphabetical list, and the walkthrough
# blocks scrolling, so that tile has to be on screen -- clear of the bottom bar --
# when the step arrives, and a tap on it has to get through. Run with:
#   Godot.exe --path . res://tests/collection_lesson_test.tscn
extends "res://scripts/screens/collection.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(5)
	TSProfile.collection_tutorial_seen = false
	TSProfile.collection_gift_claimed = false
	for i in TSProfile.CRITTER_COUNT:   # only the starter critter, as in a new game
		TSProfile.critter_unlocked[i] = i == 0
		TSProfile.critter_level[i] = 1 if i == 0 else 0
	TSProfile.avatar_critter = 0
	TSProfile.coin_count = 600
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 20:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _run() -> void:
	_check("a new player gets the walkthrough", _tutorial.visible)
	_tutorial._advance()   # past "This is your Collection"
	await get_tree().create_timer(0.6).timeout
	_tutorial._advance()   # past the gift of coins
	await get_tree().create_timer(0.8).timeout
	_check("it reaches the Tap Grad step", _tutorial.visible and _tutorial.steps[_tutorial.step_index].get("gate", false))
	var rect := _tile_rect(TUTORIAL_CRITTER)
	var view := get_viewport().get_visible_rect()
	var scroll_box := _critter_scroll.get_global_rect()
	_check("the Grad tile is on screen", view.encloses(rect))
	_check("and inside the critter list, not under the bottom bar", scroll_box.encloses(rect))
	_check("and the tile is not hidden under the navigation bar", not rect.intersects(nav.get_global_rect()))
	# The spotlight must leave the tile reachable: no dark panel over its centre.
	var at := rect.get_center()
	var covered := false
	for m in _tutorial._masks:
		if (m as Control).get_global_rect().has_point(at):
			covered = true
	_check("no dark panel covers the tile, so a tap reaches it", not covered)
	# Pressing the tile (what a tap does) moves the walkthrough on to Buy.
	var button := _tile_button_for(TUTORIAL_CRITTER)
	_check("the Grad tile has a button", button != null)
	if button != null:
		button.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	_check("tapping the tile moves the walkthrough on to Buy", _tutorial.visible and str(_tutorial.steps[_tutorial.step_index].get("text", "")).begins_with("Tap Buy"))
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _tile_button_for(i: int) -> Button:
	for g in [_owned_grid, _locked_grid]:
		for t in g.get_children():
			if t.get_meta("index", -1) == i:
				return t.get_child(0) as Button
	return null
