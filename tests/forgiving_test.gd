# Level 1 cannot be lost: a drop that matches nothing there leaves the
# hearts alone, and one that would overload the shell is turned away. Level 2's
# first miss in an egg is free. Otherwise, and on a Daily Egg even at level 1, a
# miss costs a heart and the third loses. On level 1 an arrow points the held
# piece at a match: before the first drop (once the walkthrough is done) and
# after every drop. On level 2 it does so only after a miss.
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


## How many pieces a drop at the aim would pop (the drop included).
func _aimed() -> int:
	return board.combo_preview(current_offsets(), cursor, cur_type, board.landing_depth(current_offsets(), cursor))


## Aims the held piece where a drop would match nothing (and not overload).
func _aim_at_miss() -> void:
	var offs := current_offsets()
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var at := Vector2i(c, r)
			var depth := board.landing_depth(offs, at)
			if board.footprint_valid(offs, at) and depth < TSBoard.MAX_STACK and board.combo_preview(offs, at, cur_type, depth) < TSBoard.MIN_MATCH:
				cursor = at


func _run() -> void:
	_check("the game starts on level 1", current_level == 1 and state == State.PLAYING)
	_check("the arrow is up before the first drop, over a match", _pointer != null and _pointer.visible and _aimed() >= TSBoard.MIN_MATCH)
	TSProfile.tutorial_seen = false
	_start_level(1)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check("not while the walkthrough is up", _tutorial.visible and not _pointer.visible)
	_tutorial._finish()
	for _i in 3:
		await get_tree().process_frame
	_check("but as soon as it ends", _pointer.visible and _aimed() >= TSBoard.MIN_MATCH)
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
	_aim_at_miss()
	_drop()
	await get_tree().process_frame
	var aimed := _aimed()
	_check("a miss aims the next piece at a match (%d pieces), arrow up" % aimed, _pointer != null and _pointer.visible and aimed >= TSBoard.MIN_MATCH)
	cursor.x = (cursor.x + 5) % TSBoard.COLS
	await get_tree().process_frame
	_check("and the arrow goes once the aim moves", not _pointer.visible)
	# A drop that matches: the arrow is up again, over the next piece's match.
	_point_to_match()
	_drop()
	await get_tree().process_frame
	_check("after a match too, the next piece is aimed and pointed", state != State.PLAYING or (_pointer.visible and _aimed() >= TSBoard.MIN_MATCH))

	# Doing nothing but drop where the arrow points wins level 1.
	_close_cards()
	_start_level(1)
	for _i in 3:
		await get_tree().process_frame
	var followed := 0
	while state == State.PLAYING and followed < 80:
		_drop()
		followed += 1
		await get_tree().process_frame
	_check("following the arrow wins level 1 (%d drops)" % followed, state == State.WON)

	# Level 2: no arrow until a miss. The first miss is free, every miss brings
	# the arrow, and a drop that matches leaves the aiming to the player.
	_close_cards()
	TSProfile.last_level = 2
	TSProfile.slide_tutorial_seen = true
	_start_level(2)
	for _i in 3:
		await get_tree().process_frame
	_check("level 2 has no arrow before a miss", not _pointer.visible)
	_aim_at_miss()
	_drop()
	await get_tree().process_frame
	_check("level 2's first miss is free", lives == LIVES and state == State.PLAYING)
	aimed = _aimed()
	_check("and aims the next piece at a match (%d pieces), arrow up" % aimed, _pointer.visible and aimed >= TSBoard.MIN_MATCH)
	notes = _hud.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with("Free miss!"))
	_check("and says so", notes.size() == 1)
	_drop()   # where the arrow points
	await get_tree().process_frame
	_check("a match on level 2 brings no arrow", state != State.PLAYING or not _pointer.visible)
	_close_cards()
	_start_level(2)
	for _i in 3:
		await get_tree().process_frame
	_missed()
	_check("a new try at level 2 has its free miss back", lives == LIVES)
	_missed()
	_check("the next miss costs a heart", lives == LIVES - 1)
	_missed()
	_missed()
	_check("and two more use up the hearts", lives == 0 and lose_reason == "OUT OF LIVES")
	_close_cards()
	_start_level(2)
	is_daily = true
	_missed()
	_check("a Daily Egg's first miss costs a heart at level 2", lives == LIVES - 1)
	is_daily = false
	_close_cards()
	_start_level(1)

	is_daily = true
	_missed()
	_check("a Daily Egg's miss costs one, even at level 1", lives == LIVES - 1)
	is_daily = false

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
