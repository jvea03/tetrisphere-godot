# The rating ask: due from level 12, never mid-walkthrough, counted as asked
# the moment it goes up (Back is a "maybe later", the next ask 25 levels on),
# three asks at most, and never again after "No thanks". Run with:
#   Godot.exe --headless --path . res://tests/review_test.tscn
extends "res://scripts/screens/home.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.review_done = false
	TSProfile.review_asks = 0
	TSProfile.review_next_level = TSProfile.REVIEW_FIRST_LEVEL
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _run() -> void:
	TSProfile.won_since_home = true
	TSProfile.last_level = 11
	_check("not due before level 12", not TSProfile.review_due())
	TSProfile.last_level = 12
	_check("due at level 12", TSProfile.review_due())
	TSProfile.won_since_home = false
	_check("only on the way back from a win", not TSProfile.review_due())
	TSProfile.won_since_home = true
	_open_review()
	await get_tree().create_timer(1.0).timeout
	_check("the card is up", _review["root"].visible)
	_check("asked once, next ask 25 levels on", TSProfile.review_asks == 1 and TSProfile.review_next_level == 37)
	_check("not due again at once", not TSProfile.review_due())
	for i in 4:   # a sale pop-up may be up too: Back closes one at a time
		if _review["root"].visible:
			on_back_requested()
			await get_tree().create_timer(0.6).timeout
	_check("Back closes it and isn't a rating", not _review["root"].visible and not TSProfile.review_done)
	TSProfile.last_level = 37
	_check("due again at level 37", TSProfile.review_due())
	TSProfile.review_asks = TSProfile.REVIEW_MAX_ASKS
	_check("three asks at most", not TSProfile.review_due())
	TSProfile.review_asks = 1
	TSProfile.review_done = true
	_check("never after rating or no thanks", not TSProfile.review_due())
	print("review_test: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
