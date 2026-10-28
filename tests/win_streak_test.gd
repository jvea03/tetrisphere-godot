# The win streak: level wins from level 7 count, the Daily Egg doesn't; three
# tiers -- from 2 wins in a row a level starts with a rock thrown at it, from 4
# also +2 pieces on the counter, from 6 a second rock; a loss ends the run unless a continue saves it;
# restarting ends it. Run with:
#   Godot.exe --headless --path . res://tests/win_streak_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0
var _thrown := -1   # rocks in the last throw (the real throw still happens)


func _ready() -> void:
	TSProfile.use_test_profile(40)
	TSProfile.coin_count = 100000
	TSProfile.win_streak = 0
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


func _throw_rocks(from: Vector2, targets: Array) -> void:
	_thrown = targets.size()
	super(from, targets)


func _says(dialog: Dictionary, text: String) -> bool:
	return (dialog["box"] as Node).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains(text))


## Starts a level on a streak of `n` and waits for its rocks.
func _start_on(n: int) -> int:
	TSProfile.win_streak = n
	_thrown = 0
	_start_level(41)
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.2).timeout
	return _thrown


func _run() -> void:
	_start_level(40)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_check("a win starts the streak", TSProfile.win_streak == 1)
	_check("the win card shows it, and what the next tier brings", _says(_win_card, "Win streak: 1") and _says(_win_card, "Win 1 more for a free rock!"))

	var runs := [0, 1, 2, 3, 4, 5, 6, 9]
	_check("tiers start at 2, 4 and 6 wins", runs.map(func(n): TSProfile.win_streak = n; return TSProfile.win_streak_tier()) == [0, 0, 1, 1, 2, 2, 3, 3])
	_check("rocks: one from 2 wins, a second from 6", runs.map(func(n): TSProfile.win_streak = n; return TSProfile.win_streak_rocks()) == [0, 0, 1, 1, 1, 1, 2, 2])
	_check("+2 pieces from 4 wins", runs.map(func(n): TSProfile.win_streak = n; return TSProfile.win_streak_pieces()) == [0, 0, 0, 0, 2, 2, 2, 2])
	_check("no streak: no rocks", await _start_on(0) == 0)
	_check("one win: no rocks yet", await _start_on(1) == 0)
	var two := await _start_on(2)
	_check("a 2-win streak throws one rock (%d)" % two, two == 1)
	TSProfile.win_streak = 4
	_start_level(41)
	_refresh_hud()
	_check("the bonus pieces wait to fly in: the counter shows the budget first", _pieces_label.text == str(TSLevels.piece_budget(41)) and _pieces_pending == TSProfile.WIN_STREAK_PIECES)
	var four := await _start_on(4)
	_check("a 4-win streak still one (%d), and +%d pieces (%d of %d)" % [four, TSProfile.WIN_STREAK_PIECES, pieces_left, TSLevels.piece_budget(41)], four == 1 and pieces_left == TSLevels.piece_budget(41) + TSProfile.WIN_STREAK_PIECES)
	_check("then the +%d has flown in and the counter shows it" % TSProfile.WIN_STREAK_PIECES, _pieces_pending == 0 and _pieces_label.text == str(pieces_left))
	var six := await _start_on(6)
	_check("a 6-win streak throws two (%d)" % six, six >= 1 and six <= 2)
	var many := await _start_on(9)
	_check("a longer run still throws two at most (%d)" % many, many >= 1 and many <= 2)
	_check("the pill under the hearts shows the run", _streak_pill.visible and _streak_label.text == "9")

	TSProfile.win_streak = 2
	_thrown = 0
	_start_level(41)
	_open_pause()
	(_pause["restart"] as Button).pressed.emit()
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.5).timeout
	_check("a restart straight away throws no stale rocks", _thrown == 0)

	TSProfile.win_streak = 2
	_thrown = 0
	_start_level(41)
	_tutorial.start([{"rect": Rect2(0, 0, 10, 10), "text": "a lesson"}])
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.5).timeout
	_check("the rocks wait while a lesson is up", _thrown == 0)
	_tutorial._next.pressed.emit()
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.0).timeout
	_check("and fly once it's done", _thrown == 1)

	_thrown = 0
	_start_level(41)
	_open_pause()
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.5).timeout
	_check("they hold while paused", _thrown == 0)
	TSUI.conceal(_pause["root"])
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.5).timeout
	_check("and fly on resuming", _thrown == 1)
	_thrown = 0
	_start_level(41)
	var parked := _snapshot()
	_check("left at once, the rocks are still due", bool(parked["streak_rocks_due"]))
	TSSession.state = parked
	_resume()
	await get_tree().create_timer(STREAK_ROCK_DELAY + 1.5).timeout
	_check("and fly when it is continued", _thrown == 1 and not bool(_snapshot()["streak_rocks_due"]))
	_lose()
	_check("a loss hides the streak pill", not _streak_pill.visible)
	_revive(LIVES)
	_check("a continue brings it back", _streak_pill.visible and _streak_label.text == "2")

	TSProfile.win_streak = 10
	_lose()
	_check("a loss ends it...", TSProfile.win_streak == 0)
	_check("...and the lose card says a continue keeps it", _says(_lose_card, "keep your 10-win streak"))
	_buy_continue()
	_check("a continue gives it back", TSProfile.win_streak == 10 and state == State.PLAYING)
	_lose()
	await get_tree().create_timer(1.0).timeout
	_check("giving up keeps it ended", TSProfile.win_streak == 0)

	TSProfile.win_streak = 4
	_start_level(41)
	_open_pause()
	_check("Restart warns it ends the streak", (_pause["restart"] as Button).text.contains("streak"))
	(_pause["restart"] as Button).pressed.emit()
	_check("and restarting ends it", TSProfile.win_streak == 0)

	TSProfile.win_streak = 4
	_start_daily()
	_debug_win()
	_check("the Daily Egg doesn't count", TSProfile.win_streak == 4)
	_start_daily()
	_lose()
	_check("nor does losing it", TSProfile.win_streak == 4)
	_start_level(5)
	_debug_win()
	_check("levels before 7 don't count", TSProfile.win_streak == 4)
	TSProfile.win_streak = 0
	print("win_streak_test: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
