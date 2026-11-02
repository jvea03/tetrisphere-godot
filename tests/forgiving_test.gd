# Level 1 costs no hearts: a drop that matches nothing there leaves the
# hearts alone and the egg in play, however many times; from level 2 on, and
# on a Daily Egg even at level 1, a miss costs a heart and the third loses.
# Run with:
#   Godot.exe --headless --path . res://tests/forgiving_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(1)
	TSProfile.tutorial_seen = true
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


func _run() -> void:
	_check("the game starts on level 1", current_level == 1 and state == State.PLAYING)
	for _i in 5:
		_missed()
	_check("five misses on level 1 cost no heart", lives == LIVES and lose_reason == "")

	is_daily = true
	_missed()
	_check("a Daily Egg's miss costs one, even at level 1", lives == LIVES - 1)
	is_daily = false

	current_level = 2
	lives = LIVES
	for _i in LIVES:
		_missed()
	_check("on level 2 three misses use up the hearts", lives == 0 and lose_reason == "OUT OF LIVES")

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
