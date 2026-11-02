# Level 1 cannot be lost: a drop that matches nothing there leaves the
# hearts alone, and one that would overload the shell is turned away. From
# level 2 on, and on a Daily Egg even at level 1, a miss costs a heart and
# the third loses. And a miss on level 1 points the next piece at a match.
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
	await get_tree().process_frame
	var notes := _hud.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with("No match!"))
	_check("and show one note, not five (%d)" % notes.size(), notes.size() == 1)

	# Mashing drops onto one spot, matching or not, never loses it either: a
	# drop that would overload the shell is turned away.
	var lost := false
	for spot in [Vector2(0.5, 0.5), Vector2(0.3, 0.45), Vector2(0.7, 0.55)]:
		_close_cards()
		_start_level(1)
		for _i in 60:
			if state != State.PLAYING:
				break
			_tap_aim(get_viewport().get_visible_rect().size * spot)
			_drop()
			await get_tree().process_frame
		lost = lost or state == State.LOST
	_check("mashing one spot on level 1 never loses it", not lost)
	_close_cards()
	_start_level(1)

	# A real miss: the next piece is aimed at a match, with the arrow over it,
	# and the arrow goes once the aim moves.
	var offs := current_offsets()
	var miss_at := Vector2i(-1, -1)
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var at := Vector2i(c, r)
			var depth := board.landing_depth(offs, at)
			if board.footprint_valid(offs, at) and depth < TSBoard.MAX_STACK and board.combo_preview(offs, at, cur_type, depth) < TSBoard.MIN_MATCH:
				miss_at = at
	cursor = miss_at
	_drop()
	await get_tree().process_frame
	var aimed := board.combo_preview(current_offsets(), cursor, cur_type, board.landing_depth(current_offsets(), cursor))
	_check("a miss aims the next piece at a match (%d pieces), arrow up" % aimed, _pointer != null and _pointer.visible and aimed >= TSBoard.MIN_MATCH)
	cursor.x = (cursor.x + 5) % TSBoard.COLS
	await get_tree().process_frame
	_check("and the arrow goes once the aim moves", not _pointer.visible)

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
