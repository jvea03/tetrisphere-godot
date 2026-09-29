# Checks the game screen's side of the menus on a throwaway profile: a win
# pays and advances the level, a ball parked on the way Home comes back
# exactly as it was, the lose card's refill and the out-of-bombs buy work,
# the Daily Egg leaves level progress alone, and the level 2 sliding and
# level 3 bomb lessons wait for the real thing. Run with:
#   Godot.exe --path . res://tests/flow_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.coin_count = 10000
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
	_check("the game starts on the profile's level", current_level == 12 and _lbl_level.text == "LEVEL 12")
	_check("at that level's difficulty", difficulty == TSLevels.difficulty_for_level(12))

	# a drop, then park and resume in a second game screen
	_tap_aim(get_viewport().get_visible_rect().size * 0.5)
	_drop()
	var drops_board := board
	lives = 2
	_park()
	_check("parking the ball keeps it for CONTINUE", TSSession.has_saved_game)
	var other: Node = load("res://main.tscn").instantiate()
	get_root_ref().add_child(other)
	await get_tree().process_frame
	_check("a new game screen picks the ball back up", other.board == drops_board and other.lives == 2 and other.current_level == 12)
	_check("and the parked ball is used up", not TSSession.has_saved_game)
	other.queue_free()

	# the out-of-bombs buy
	TSProfile.bomb_count = 0
	_toggle_bomb()
	_check("an empty bomb button opens the buy/ad card", _ad_card["root"].visible and _ad_reward == "bomb")
	var coins := TSProfile.coin_count
	_on_ad_buy()
	_check("buying bombs mid-level", TSProfile.bomb_count == TSProfile.bomb_buy_count() and TSProfile.coin_count == coins - TSProfile.bomb_buy_cost())

	# the Any Piece: a wild block, aimed at its biggest match
	TSProfile.swap_count = 2
	var best := board.best_piece([TSBoard.WILD])
	_use_any_piece()
	_check("the Any Piece turns the held piece into the wild block", cur_type == TSBoard.WILD and cursor == best["at"])
	_check("and aims it at a match, spending one", aim_combo == int(best["pieces"]) and aim_combo >= 3 and TSProfile.swap_count == 1)
	_use_any_piece()
	_check("a second tap while holding one spends nothing", TSProfile.swap_count == 1 and cur_type == TSBoard.WILD)
	var wild_pieces := board.plate_kind.size()
	var lives_before := lives
	_drop()
	_check("dropped by a pair, it matches like that piece (no life lost)", lives == lives_before and board.plate_kind.size() < wild_pieces and cur_type != TSBoard.WILD)
	_check("and nothing wild is left on the ball", not board.plate_kind.values().has(TSBoard.WILD))
	# That match can dig the critter out and win; start level 12 afresh for
	# the Rocks.
	if state != State.PLAYING:
		TSProfile.last_level = 12
		_close_cards()
		_start_level(12)

	# Rocks: two rocks fly, and each finishes a match when it lands
	TSProfile.rock_count = 1
	var pieces_before := board.plate_kind.size()
	var shot := board.rock_targets(ROCKS_PER_SHOT, cursor)
	var aimed := 0
	for g in shot:
		aimed += (g as Array).size()
	_fire_rocks()
	_check("firing Rocks spends a shot and holds off drops in flight", TSProfile.rock_count == 0 and _rocks_flying)
	for _i in 40:
		await get_tree().process_frame
		if not _rocks_flying:
			break
	_check("the rocks land on two pairs and clear them (%d pieces aimed, %d gone)" % [aimed, pieces_before - board.plate_kind.size()], not _rocks_flying and shot.size() == 2 and aimed >= 4 and pieces_before - board.plate_kind.size() >= aimed)
	# The rocks can dig the critter out and win outright; start level 12 afresh
	# for the checks that follow.
	if state != State.PLAYING:
		TSProfile.last_level = 12
		_close_cards()
		_start_level(12)

	# the empty Swap and Rocks buttons offer the same buy
	for id in ["swap", "rocks"]:
		if id == "swap":
			TSProfile.swap_count = 0
			_use_any_piece()
		else:
			TSProfile.rock_count = 0
			_fire_rocks()
		var had := TSProfile.coin_count
		var opened: bool = _ad_card["root"].visible and _ad_reward == id
		_on_ad_buy()
		_check("an empty %s button opens its buy card, and buying works" % id, opened and TSProfile.booster_count(id) == TSProfile.booster_buy_count(id) and TSProfile.coin_count == had - TSProfile.booster_buy_cost(id))

	# losing, then the coin refill
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	_check("running out of hearts shows the lose card", state == State.LOST and _lose_card["root"].visible)
	TSProfile.coin_count = 5000
	_revive_after_refill()
	_check("the refill costs %d coins and restores %d hearts" % [LIVES_REFILL_COST, LIVES], TSProfile.coin_count == 5000 - LIVES_REFILL_COST and lives == LIVES and state == State.PLAYING and not is_first_attempt)

	# winning
	var before := TSProfile.coin_count
	var level_before := TSProfile.last_level
	var chest_before := TSChests.win_progress
	_debug_win()
	_check("a win pays coins", TSProfile.coin_count > before)
	_check("and moves the level on", TSProfile.last_level == level_before + 1)
	_check("and banks chest progress", TSChests.win_progress == (chest_before + 1) % TSChests.WINS_PER_CHEST or TSChests.free_slot() != 0)
	await get_tree().create_timer(3.0).timeout
	_check("the win card shows once the critter is out", _win_card["root"].visible)

	# the Daily Egg
	var last := TSProfile.last_level
	_start_daily()
	_check("the Daily Egg is today's level, marked as such", is_daily and current_level == TSLevels.daily_level() and _lbl_level.text == "DAILY EGG")
	_debug_win()
	_check("winning it completes the day and leaves progress alone", TSProfile.is_daily_completed_today() and TSProfile.last_level == last)

	# Level 2's sliding lesson: it waits for a real slide.
	TSProfile.slide_tutorial_seen = false
	_close_cards()
	_start_level(2)
	for _i in 4:
		await get_tree().process_frame
	_check("level 2 opens the sliding lesson, with a flat line to slide", _tutorial.on_step("slide") and cur_type == TSBoard.I_FLAT)
	# Done the way a player does it -- real touches, through the spotlight --
	# so a lesson that swallows touches can't pass here.
	var lesson_id := _slide_example(TSBoard.I_FLAT)
	var grip := Vector2i(-1, -1)
	var slide_dir := Vector2i.ZERO
	for col in board.plate_cols[lesson_id]:
		var cell: Vector2i = col
		if not _touchable(cell):
			continue
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var d: Vector2i = dir
			var next := Vector2i(board.wrap_col(cell.x + d.x), cell.y + d.y)
			if board.slide_preview(lesson_id, d) >= 0 and board.in_rows(next.y) and _touchable(next):
				grip = cell
				slide_dir = d
				break
		if grip.x >= 0:
			break
	_check("the lesson's line can be touched and slid on screen", grip.x >= 0)
	if grip.x >= 0:
		var from := _screen_of(grip)
		_touch(from, true)
		_touch_ms -= 1000   # as if held for a second
		_process(0.0)
		var towards := _screen_of(Vector2i(board.wrap_col(grip.x + slide_dir.x), grip.y + slide_dir.y)) - from
		_drag_to(from, from + towards.normalized() * (SLIDE_STEP + 4.0), 4)
		_touch(from + towards.normalized() * (SLIDE_STEP + 4.0), false)
	for _i in 3:
		await get_tree().process_frame
	_check("sliding the piece moves the lesson on", _tutorial.visible and not _tutorial.on_step("slide"))
	_tutorial._finish()
	_check("and it is marked seen", TSProfile.slide_tutorial_seen)

	# Level 3's bomb lesson: bombs arrive, then arm one, then blast.
	TSProfile.bomb_tutorial_seen = false
	TSProfile.bombs_unlocked = false
	TSProfile.bomb_count = 0
	_start_level(3)
	for _i in 4:
		await get_tree().process_frame
	_check("level 3 brings %d bombs and opens the bomb lesson" % TSProfile.BOMB_UNLOCK_GRANT, _tutorial.on_step("arm_bomb") and TSProfile.bomb_count == TSProfile.BOMB_UNLOCK_GRANT)
	_toggle_bomb()
	for _i in 3:
		await get_tree().process_frame
	_check("arming a bomb moves the lesson on to the blast", bomb_armed and _tutorial.on_step("blast"))
	var blast_at := _screen_of(cursor)
	_touch(blast_at, true)
	_touch(blast_at, false)
	_touch(blast_at, true)
	_touch(blast_at, false)   # a double tap on the egg, through the spotlight
	for _i in 3:
		await get_tree().process_frame
	_check("the blast moves it on to the last card", _tutorial.visible and not _tutorial.on_step("blast") and TSProfile.bomb_count == TSProfile.BOMB_UNLOCK_GRANT - 1)
	_tutorial._finish()
	_check("and it is marked seen", TSProfile.bomb_tutorial_seen)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func get_root_ref() -> Node:
	return get_tree().root


## The lose card's refill button, pressed.
func _revive_after_refill() -> void:
	for b in (_lose_card["box"] as Node).get_children():
		if b is Button and (b as Button).text.begins_with("+%d hearts" % LIVES):
			(b as Button).pressed.emit()
			return


# Touch helpers, as the tap test has them: events straight into the game's
# touch handling, the way the phone delivers them.
func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	_touch_input(ev)


func _drag_to(from: Vector2, to: Vector2, steps: int) -> void:
	var last := from
	for i in steps:
		var p := from.lerp(to, float(i + 1) / float(steps))
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = p
		ev.relative = p - last
		_touch_input(ev)
		last = p


func _screen_of(cell: Vector2i) -> Vector2:
	var top := float(board.height(cell.x, cell.y)) - 0.5
	return _camera.unproject_position(TSBoardView.cell_transform(cell.x, cell.y, top).origin)


# A cell showing on screen, clear of the buttons, that a finger could press.
func _touchable(cell: Vector2i) -> bool:
	var at := _screen_of(cell)
	if _on_booster_button(at) or _pause_btn.get_global_rect().has_point(at):
		return false
	return _cell_at(at) == cell
