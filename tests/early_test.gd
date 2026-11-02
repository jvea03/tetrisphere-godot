# The first few levels keep a new player playing: on levels 1-4 the win card
# has one way on (Next Level: no close, no ad), and Next Level starts the next
# egg; from level 5 the close and the ad are back. And opening the game while
# still on levels 1-4 goes straight into the next egg, not Home. Run with:
#   Godot.exe --headless --path . res://tests/early_test.tscn
extends "res://scripts/game.gd"

const OPENING := preload("res://scripts/screens/opening.gd")

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(2)
	TSProfile.tutorial_seen = true
	TSProfile.slide_tutorial_seen = true
	TSProfile.ad_rewards_used = {}
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


## The win card's buttons a player can see and press.
func _live_buttons() -> Array:
	return (_win_card["box"] as Node).find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return not b.disabled and b.modulate.a > 0.0 and b.is_visible_in_tree())


func _run() -> void:
	_check("opening on level 2 goes straight into the egg", OPENING._straight_in())
	TSProfile.last_level = TSNav.COLLECTION_UNLOCK_LEVEL
	_check("from level %d, Home" % TSNav.COLLECTION_UNLOCK_LEVEL, not OPENING._straight_in())
	TSProfile.last_level = 2

	_debug_win()
	await get_tree().create_timer(3.0).timeout
	var live := _live_buttons()
	_check("level 2's win card has one way on: Next Level", live.size() == 1 and (live[0] as Button).text == "Next Level")
	_on_next_pressed()
	await get_tree().create_timer(0.5).timeout
	_check("which starts level 3", current_level == 3 and state == State.PLAYING)

	_close_cards()
	TSProfile.last_level = 6
	_start_level(6)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_check("from level 5 on, the close and the coins ad are back", _live_buttons().size() >= 3)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
