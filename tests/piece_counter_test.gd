# The piece counter: a level starts with its budget (TSLevels.piece_budget),
# each drop spends one (a bomb doesn't); run out and a heart buys one more,
# dealt at random; with no heart to spend the egg is lost, and a continue or
# the heart ad brings CONTINUE_PIECES more. Challenges have their clock
# instead, and levels 1-5 have none. Past level 50 a 5-win streak takes a
# piece off, a 7-win streak two. Run with:
#   Godot.exe --headless --path . res://tests/piece_counter_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(40)
	TSProfile.coin_count = 100000
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


func _says(dialog: Dictionary, text: String) -> bool:
	return (dialog["box"] as Node).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains(text)) \
		or (dialog["box"] as Node).find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text.contains(text))


func _run() -> void:
	_check("levels 1-%d are unlimited" % TSLevels.UNLIMITED_PIECES_THROUGH, range(1, TSLevels.UNLIMITED_PIECES_THROUGH + 1).all(func(l): return TSLevels.piece_budget(l) == 0))
	_check("every later level has a budget of at least %d" % TSLevels.MIN_PIECE_BUDGET, range(TSLevels.UNLIMITED_PIECES_THROUGH + 1, 800).all(func(l): return TSLevels.piece_budget(l) >= TSLevels.MIN_PIECE_BUDGET))
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TSLevels.PIECE_BUDGETS))
	var raw := func(l: int) -> int: return maxi(TSLevels.MIN_PIECE_BUDGET, int(table[str(l)]))
	_check("levels 6-%d get %d pieces more, later ones none" % [TSLevels.EARLY_PIECES_THROUGH, TSLevels.EARLY_PIECES],
		range(TSLevels.UNLIMITED_PIECES_THROUGH + 1, TSLevels.EARLY_PIECES_THROUGH + 1).all(func(l): return TSLevels.piece_budget(l) == raw.call(l) + TSLevels.EARLY_PIECES)
		and range(TSLevels.EARLY_PIECES_THROUGH + 1, 200).all(func(l): return TSLevels.piece_budget(l) == raw.call(l)))

	_start_level(3)
	_refresh_hud()
	_check("an unlimited level shows no counter", not _pieces_pill.visible)
	_drop()
	_check("and its drops spend nothing", pieces_left == 0 and lose_reason != "OUT OF PIECES" and _next_box.visible)
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	_check("its lose card offers no pieces", not _says(_lose_card, "+%d pieces" % CONTINUE_PIECES))
	_check("past the table, a level takes the budget of its match in the last 60",
		TSLevels.piece_budget(TSLevels.PIECE_BUDGET_LAST + 1) == TSLevels.piece_budget(TSLevels.PIECE_BUDGET_LAST - 59)
		and TSLevels.piece_budget(TSLevels.PIECE_BUDGET_LAST + 125) == TSLevels.piece_budget(TSLevels.PIECE_BUDGET_LAST - 55))   # 785 plays as 605

	_start_level(20)
	_check("a level starts with its budget (%d)" % pieces_left, pieces_left == TSLevels.piece_budget(20))
	_refresh_hud()
	_check("the counter under the tray shows it", _pieces_pill.visible and _pieces_label.text == str(pieces_left) and _pieces_word.text == "pieces left")

	var before := pieces_left
	_drop()
	_check("a drop spends a piece", pieces_left == before - 1)

	_start_level(20)
	TSProfile.bomb_count = 3
	bomb_armed = true
	before = pieces_left
	_drop()
	_check("a bomb spends no piece", pieces_left == before)
	await get_tree().create_timer(2.0).timeout

	_start_level(20)
	pieces_left = 2
	_refresh_piece()
	_check("with two left the next piece shows", _next_box.visible)
	pieces_left = 1
	_refresh_piece()
	_check("on the last piece there is no next one", not _next_box.visible)
	_refresh_hud()
	_check("and the counter says \"1 piece left\"", _pieces_label.text == "1" and _pieces_word.text == "piece left")

	_start_level(20)
	pieces_left = 0
	lives = 3
	_buy_piece_with_heart()
	_check("out of pieces: a heart buys one more", lives == 2 and pieces_left == 1 and state == State.PLAYING)
	_check("dealt from the level's own pieces", (level["pieces"] as Array).has(cur_type))

	pieces_left = 0
	lives = 1
	_buy_piece_with_heart()
	_check("out of pieces and hearts: the egg is lost", state == State.LOST and lose_reason == "OUT OF PIECES")
	_check("the lose card says so, and the continue brings pieces", _says(_lose_card, "Out of pieces!") and _says(_lose_card, "+%d pieces" % CONTINUE_PIECES))
	_buy_continue()
	_check("a continue: full hearts and %d pieces" % CONTINUE_PIECES, state == State.PLAYING and lives == LIVES and pieces_left == CONTINUE_PIECES)

	_start_level(20)
	pieces_left = 7
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	_check("out of hearts with pieces left: no pieces offered", _says(_lose_card, "Out of hearts!") and not _says(_lose_card, "+%d pieces" % CONTINUE_PIECES))
	_buy_continue()
	_check("and the continue leaves the count alone", pieces_left == 7)

	_start_level(20)
	pieces_left = 9
	_park()
	_start_level(21)
	_resume()
	_check("a parked egg keeps its count", current_level == 20 and pieces_left == 9)

	TSProfile.challenge_done_through = 0
	_start_challenge(40)
	_refresh_hud()
	_check("a challenge has no counter", not _pieces_pill.visible and pieces_left == 0)
	_drop()
	_check("and a drop there buys nothing", lives >= 1 and pieces_left <= 0 and lose_reason != "OUT OF PIECES")
	TSProfile.challenge_done_through = 1 << 30

	var full := TSLevels.piece_budget(60)
	# [streak, pieces off for it past level 50, the streak's own +2 from 4 wins]
	for run in [[3, 0, 0], [4, 0, 2], [5, 1, 2], [6, 1, 2], [7, 2, 2], [12, 2, 2]]:
		TSProfile.win_streak = int(run[0])
		_start_level(60)
		_check("past level 50, a %d-win streak: +%d, -%d (%d of %d)" % [run[0], run[2], run[1], pieces_left, full], pieces_left == full + int(run[2]) - int(run[1]))
	TSProfile.win_streak = 7
	_start_level(50)
	_check("level 50 and below: no cut, just the streak's +%d" % TSProfile.WIN_STREAK_PIECES, pieces_left == TSLevels.piece_budget(50) + TSProfile.WIN_STREAK_PIECES)
	_start_daily()
	_check("the Daily Egg: no cut", pieces_left == TSLevels.piece_budget(current_level))
	TSProfile.win_streak = 0

	TSProfile.pieces_intro_seen = false
	_start_level(21)
	await get_tree().create_timer(0.5).timeout
	_check("the counter's card shows once, on a counted level", _tutorial.visible)

	print("piece_counter_test: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
