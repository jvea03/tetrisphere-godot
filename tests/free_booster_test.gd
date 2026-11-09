# A booster is free and endless on the level that teaches it (bombs on 3, the
# Any Piece on 4, rocks on 8), retries included: using it there spends none of
# the player's own, and its button shows ∞. Anywhere else (another level, a
# Daily Egg) it costs one as usual, and an empty button offers an ad.
# Run with:
#   Godot.exe --headless --path . res://tests/free_booster_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(9)
	TSProfile.tutorial_seen = true
	TSProfile.slide_tutorial_seen = true
	TSProfile.bomb_tutorial_seen = true
	TSProfile.swap_tutorial_seen = true
	TSProfile.rocks_tutorial_seen = true
	for id in ["bomb", "swap", "rocks"]:
		TSProfile.add_boosters(id, 1)
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


func _empty() -> void:
	TSProfile.bomb_count = 0
	TSProfile.swap_count = 0
	TSProfile.rock_count = 0


func _level(n: int) -> void:
	_close_cards()
	TSUI.conceal(_ad_card["root"])
	_start_level(n)
	for _i in 3:
		await get_tree().process_frame
	_tutorial._finish()


func _wait_settled() -> void:
	for _i in 240:
		if not _rocks_flying and state == State.PLAYING:
			return
		await get_tree().process_frame


func _run() -> void:
	_empty()
	await _level(3)
	_check("level 3: the bomb's badge shows ∞", _bomb_badge.text == FREE_BADGE)
	for k in 3:
		_toggle_bomb()
		_check("level 3: bomb %d arms with none owned" % (k + 1), bomb_armed and not _ad_card["root"].visible)
		_drop()
		await get_tree().create_timer(1.5).timeout
		if state != State.PLAYING:
			await _level(3)
	_check("level 3: none of the player's bombs spent", TSProfile.bomb_count == 0)

	await _level(3)   # a retry
	_toggle_bomb()
	_check("a retry of level 3 is free too", bomb_armed and _bomb_badge.text == FREE_BADGE)
	bomb_armed = false

	await _level(4)
	_check("level 4: the Any Piece shows ∞, the bomb doesn't", (_booster_badges["swap"] as Label).text == FREE_BADGE and _bomb_badge.text == "+")
	_use_any_piece()
	_check("level 4: the Any Piece works with none owned", cur_type == TSBoard.WILD and TSProfile.swap_count == 0 and not _ad_card["root"].visible)
	_toggle_bomb()
	_check("level 4: an empty bomb offers an ad", not bomb_armed and _ad_card["root"].visible)

	await _level(8)
	_check("level 8: rocks show ∞", (_booster_badges["rocks"] as Label).text == FREE_BADGE)
	_fire_rocks()
	_check("level 8: rocks fire with none owned", _rocks_flying and TSProfile.rock_count == 0)
	await _wait_settled()

	await _level(5)
	TSProfile.bomb_count = 2
	_refresh_hud()
	_toggle_bomb()
	_drop()
	await get_tree().create_timer(1.5).timeout
	_check("level 5: a bomb costs one (2 -> %d)" % TSProfile.bomb_count, TSProfile.bomb_count == 1)

	current_level = 3
	is_daily = true
	_check("a Daily Egg isn't a lesson level", not _free_booster("bomb"))
	is_daily = false

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
