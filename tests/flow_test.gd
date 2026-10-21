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
	for _i in 120:   # a rock flies for about 0.4 s; frames run as fast as they can here
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

	# A geode cracking open fires its own rock, which lands like the booster's.
	var pieces_before_geode := board.plate_kind.size()
	_crack_geodes({"geode_shots": [cursor]})
	_check("a geode cracking open fires a rock", _rocks_flying)
	for _i in 120:   # a rock flies for about 0.4 s; frames run as fast as they can here
		await get_tree().process_frame
		if not _rocks_flying:
			break
	_check("and it lands, finishing a match", not _rocks_flying and board.plate_kind.size() < pieces_before_geode)
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

	# bombs aren't earned in play: no chain or clear pays one
	_start_level(current_level)
	TSProfile.bombs_unlocked = true
	var bombs := TSProfile.bomb_count
	for c in [2, 4, 8]:
		_finish_drop({"pieces": 12, "chain": c, "fx": [], "overload": false})
	_check("no chain, however big, earns a bomb", TSProfile.bomb_count == bombs)
	_start_level(current_level)

	# interstitials: how often, by level, for non-payers and payers
	var was_level := current_level
	var was_payer := TSProfile.is_payer
	var counts := {}
	for who in ["free", "payer"]:
		for lvl in [20, 40, 70]:
			TSProfile.is_payer = who == "payer"
			TSProfile.interstitial_win_count = 0
			current_level = lvl
			var shown := 0
			for _w in 12:
				shown += 1 if _roll_interstitial() else 0
			counts["%s %d" % [who, lvl]] = shown
	current_level = was_level
	TSProfile.is_payer = was_payer
	TSProfile.interstitial_win_count = 0
	_check("no interstitials before level 30 (%s)" % counts, counts["free 20"] == 0 and counts["payer 20"] == 0)
	_check("from level 30, every 3rd win for non-payers; none yet for payers", counts["free 40"] == 4 and counts["payer 40"] == 0)
	_check("from level 60, every 2nd win for non-payers and every 3rd for payers", counts["free 70"] == 6 and counts["payer 70"] == 4)

	# losing, then the coin refill
	lives = 0
	lose_reason = "OUT OF LIVES"
	TSProfile.coin_count = 5000
	_lose()
	_check("the lose card waits a beat before it shows", state == State.LOST and not _lose_card["root"].visible)
	_check("and back waits for it rather than skipping it", on_back_requested())
	await get_tree().create_timer(LOSE_CARD_DELAY + 0.1).timeout
	_check("running out of hearts shows the lose card", state == State.LOST and _lose_card["root"].visible)
	var shielded := (_lose_card["root"] as Node).has_node("Shield")
	_check("and its buttons don't take a tap at first", shielded)
	await get_tree().create_timer(LOSE_CARD_LOCK + 0.1).timeout
	shielded = (_lose_card["root"] as Node).has_node("Shield")
	_check("...then they do", not shielded)
	var first_offer := ""
	for b in (_lose_card["box"] as Node).get_children():
		if b is Button and (b as Button).text.begins_with("Continue"):
			first_offer = (b as Button).text
	_revive_after_refill()
	_check("the first continue on a ball is on sale", first_offer.contains("%s coins  (was %s)" % [TSProfile.fmt_coins(FIRST_CONTINUE_COST), TSProfile.fmt_coins(LIVES_REFILL_COST)]))
	_check("the first refill costs %d coins and restores %d hearts" % [FIRST_CONTINUE_COST, LIVES], TSProfile.coin_count == 5000 - FIRST_CONTINUE_COST and lives == LIVES and state == State.PLAYING and not is_first_attempt)

	# the second continue on the same ball is full price -- and short of coins,
	# Continue sells the smallest coin pack that covers it, and carries straight
	# on once the purchase lands
	lives = 0
	lose_reason = "OUT OF LIVES"
	TSProfile.coin_count = 1000
	_lose()
	var offer := ""
	for b in (_lose_card["box"] as Node).get_children():
		if b is Button and (b as Button).text.begins_with("Continue"):
			offer = (b as Button).text
	_check("short of coins, Continue offers the 5,000 coin pack", offer.contains("Get 5,000 coins"))
	_revive_after_refill()
	_check("buying it from the lose card spends the refill and carries on", TSProfile.coin_count == 1000 + 5000 - LIVES_REFILL_COST and lives == LIVES and state == State.PLAYING)
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	var card_text := ""
	for l in (_lose_card["box"] as Node).get_children():
		if l is Label:
			card_text += (l as Label).text + " "
	_check("the lose card says how close the critter is to escaping", card_text.contains("% of the way out"))
	TSProfile.coin_count = 5000
	_revive_after_refill()

	# an overloaded egg can't be continued: Try Again, and no Continue on offer
	lives = 0
	lose_reason = "SHELL OVERLOADED"
	_lose()
	var texts: Array = []
	for b in (_lose_card["box"] as Node).get_children():
		if b is Button:
			texts.append((b as Button).text)
	_check("the overload card offers Try Again and no Continue", texts.has("Try Again") and not texts.any(func(t): return str(t).begins_with("Continue")))
	_close_cards()
	_start_level(current_level)

	# the ad's heart is not a bought continue: the sale still waits after it
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	_ad_reward = "life"
	_on_ad_finished()
	_check("the ad's heart revives with one heart", state == State.PLAYING and lives == 1 and lose_ad_used)
	_check("...and leaves the first-continue sale for later", _continue_cost() == FIRST_CONTINUE_COST)

	# the count rides along with a parked ball, and a new ball starts over
	continues_bought = 1
	_check("a parked ball keeps its continues count", int(_snapshot().get("continues_bought", -1)) == 1)
	_start_level(current_level)
	_check("a new ball puts the first continue back on sale", continues_bought == 0 and _continue_cost() == FIRST_CONTINUE_COST)

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
	for _i in 120:   # the bomb falls onto the egg (about 0.4 s) before it goes off
		await get_tree().process_frame
		if not _rocks_flying:
			break
	_check("the blast moves it on to the last card", _tutorial.visible and not _tutorial.on_step("blast") and TSProfile.bomb_count == TSProfile.BOMB_UNLOCK_GRANT - 1)
	_tutorial._finish()
	_check("and it is marked seen", TSProfile.bomb_tutorial_seen)

	# A bomb falls on the very cell double-tapped, wherever the piece was aimed.
	TSProfile.bomb_count += 1
	_toggle_bomb()
	var spot := Vector2i(board.wrap_col(cursor.x + 2), cursor.y)
	var tap_at := _screen_of(spot)
	var want := _cell_at(tap_at)
	_bomb_landed = Vector2i(-9, -9)
	_touch(tap_at, true)
	_touch(tap_at, false)
	_touch(tap_at, true)
	_touch(tap_at, false)
	for _i in 120:
		await get_tree().process_frame
		if not _rocks_flying:
			break
	_check("an armed bomb falls on the cell double-tapped (%s)" % want, want.x >= 0 and _bomb_landed == want)

	# The new blockers' first eggs: each opens its card once.
	TSProfile.vine_tutorial_seen = false
	_close_cards()
	_start_level(TSLevels.VINE_FROM_LEVEL)
	for _i in 4:
		await get_tree().process_frame
	_check("level %d has creeping vines and opens their card" % TSLevels.VINE_FROM_LEVEL, not board.vined.is_empty() and _tutorial.visible)
	_tutorial._finish()
	_check("and it is marked seen", TSProfile.vine_tutorial_seen)
	TSProfile.lock_tutorial_seen = false
	_start_level(TSLevels.LOCK_FROM_LEVEL)
	for _i in 4:
		await get_tree().process_frame
	_check("level %d has padlocks and a key, and opens their card (a breather: Intermediate)" % TSLevels.LOCK_FROM_LEVEL, not board.locked.is_empty() and board.key_piece != TSBoard.HOLE and _tutorial.visible and difficulty == 1)
	_tutorial._advance()
	_check("...whose second step turns to the key", _tutorial.visible)
	_tutorial._finish()
	_check("and it is marked seen", TSProfile.lock_tutorial_seen)

	for debut in [[TSLevels.PRISM_FROM_LEVEL, "prism"], [TSLevels.FOG_FROM_LEVEL, "fog"]]:
		if debut[1] == "prism":
			TSProfile.prism_tutorial_seen = false
		else:
			TSProfile.fog_tutorial_seen = false
		_start_level(int(debut[0]))
		for _i in 4:
			await get_tree().process_frame
		var has: bool = not board.prisms.is_empty() if debut[1] == "prism" else not board.fog.is_empty()
		_check("level %d has %s and opens its card (a breather)" % [debut[0], debut[1]], has and _tutorial.visible and difficulty <= 1)
		_tutorial._finish()
		_check("and it is marked seen", TSProfile.prism_tutorial_seen if debut[1] == "prism" else TSProfile.fog_tutorial_seen)

	# A real drop on a vine egg with nothing cut, three times: the vines spread.
	_start_level(TSLevels.VINE_FROM_LEVEL + 3)
	for _i in 4:
		await get_tree().process_frame
	var before_vines := board.vined.size()
	var spreads := 0
	for _i in TSBoard.VINE_GROW_EVERY:
		var probe_res := board.clone().place_and_resolve(current_offsets(), cursor, cur_type, _current_depth())
		if int(probe_res["chain"]) > 0 or state != State.PLAYING:
			break
		lives = LIVES
		_drop()
		spreads += 1
	if spreads == TSBoard.VINE_GROW_EVERY:
		_check("three drops that cut no vine make the vines spread", board.vined.size() == before_vines + 1)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func get_root_ref() -> Node:
	return get_tree().root


## The lose card's refill button, pressed.
func _revive_after_refill() -> void:
	for b in (_lose_card["box"] as Node).get_children():
		if b is Button and (b as Button).text.begins_with("Continue"):
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


var _bomb_landed := Vector2i(-9, -9)

func _bomb_lands(cell: Vector2i, at: Vector2) -> void:
	_bomb_landed = cell
	super(cell, at)
