# Plays Home's first walkthrough (the one that opens with the chest tray at
# level 7) as a brand-new player: a free Common chest is handed over, the
# walkthrough points at it and waits for the player to tap it to start the
# unlock, then carries on. A player who left mid-way is given no second chest
# and isn't made to unlock again. Run with:
#   Godot.exe --path . res://tests/chest_lesson_test.tscn
extends "res://scripts/screens/home.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(7)
	TSProfile.home_tutorial_seen = false
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSChests.slots = [{}, {}, {}, {}]
	TSChests.win_progress = 0
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _text() -> String:
	return str(tutorial.steps[tutorial.step_index].get("text", ""))


func _run() -> void:
	_check("the walkthrough opens", tutorial.visible)
	_check("a Common chest is waiting in the first slot", TSChests.rarity_of(0) == TSChests.COMMON and not TSChests.is_unlocking(0) and not TSChests.is_ready(0))
	_check("it is the only chest", TSChests.unlocking_count() == 0 and [1, 2, 3].all(func(i): return TSChests.is_empty(i)))
	_check("the first step is about the free chest", _text().contains("free chest"))
	tutorial._advance()
	await get_tree().create_timer(0.6).timeout
	var gated: bool = tutorial.steps[tutorial.step_index].get("gate", false)
	_check("then it waits for the player to tap the chest", tutorial.visible and gated and _text().begins_with("Tap it"))
	# The spotlight is on the chest, and nothing dark covers it, so the tap gets through.
	var rect := (_chest_slots[0]["btn"] as Control).get_global_rect()
	var covered := false
	for m in tutorial._masks:
		if (m as Control).get_global_rect().has_point(rect.get_center()):
			covered = true
	_check("no dark panel covers the chest, so a tap reaches it", not covered)
	_on_chest_slot_pressed(0)   # what the tap does
	await get_tree().create_timer(1.0).timeout
	_check("tapping it starts the unlock", TSChests.is_unlocking(0))
	_check("and moves the walkthrough on, saying how long it takes", tutorial.visible and _text().contains(TSChests.format_unlock_time(TSChests.COMMON)))
	for _i in 4:   # the rest: the tray, the Battle Pass, the Eggsperience
		tutorial._advance()
		await get_tree().create_timer(0.5).timeout
	_check("the walkthrough finishes and is remembered", not tutorial.visible and TSProfile.home_tutorial_seen)
	# Left mid-way and back again: no second chest, and nothing to unlock again.
	TSProfile.home_tutorial_seen = false
	TSProfile.starter_chest_given = false
	_start_home_tutorial()
	await get_tree().create_timer(1.0).timeout
	_check("coming back mid-way gives no second chest", [1, 2, 3].all(func(i): return TSChests.is_empty(i)))
	_check("and skips the unlock step", tutorial.visible and not _text().contains("free chest") and not tutorial.steps.any(func(s): return s.get("gate", false)))
	for _i in 4:
		tutorial._advance()
		await get_tree().create_timer(0.3).timeout
	# Settings' Replay Tips, with the tray empty: the walkthrough again, but no chest.
	TSChests.slots = [{}, {}, {}, {}]
	_build_settings()
	var replay: Button = null
	for b in (_settings["box"] as Node).find_children("*", "Button", true, false):
		if (b as Button).text == "Replay Tips":
			replay = b
	_check("Settings has Replay Tips", replay != null)
	replay.pressed.emit()
	await get_tree().create_timer(1.5).timeout
	_check("it plays Home's walkthrough again, from the story", tutorial.visible and not TSProfile.ship_story_seen and not TSProfile.home_tutorial_seen)
	for _i in 2:   # the story's two steps
		tutorial._advance()
		await get_tree().create_timer(0.5).timeout
	_check("then the chests and pass, with no free chest this time", tutorial.visible and TSChests.slots.all(func(s): return (s as Dictionary).is_empty()) and tutorial.steps.any(func(s): return str(s["text"]).contains("Battle Pass")) and not _text().contains("free chest"))
	_check("and the other tips are back for their screens", not TSProfile.collection_tutorial_seen and not TSProfile.daily_callout_seen and not TSProfile.pieces_intro_seen and not TSProfile.streak_intro_seen)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
