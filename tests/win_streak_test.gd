# The win streak: level wins from level 7 count, the Daily Egg doesn't; three
# tiers -- 1, 2 and 3+ wins in a row -- and each level then starts with that
# many rocks thrown at it; a loss ends the run unless a continue saves it;
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
	_check("the win card shows it, and the next level's rocks", _says(_win_card, "Win streak: 1") and _says(_win_card, "starts with 1 free rock -- win again for 2"))

	_check("tiers: 0, 1, 2, 3, then 3", [0, 1, 2, 3, 7].map(func(n): TSProfile.win_streak = n; return TSProfile.win_streak_tier()) == [0, 1, 2, 3, 3])
	_check("no streak: no rocks", await _start_on(0) == 0)
	var one := await _start_on(1)
	_check("tier 1 throws one rock (%d)" % one, one == 1)
	var three := await _start_on(3)
	_check("tier 3 throws up to three (%d)" % three, three >= 1 and three <= 3)
	var many := await _start_on(9)
	_check("a longer run still throws three at most (%d)" % many, many >= 1 and many <= 3)
	_check("the pill under the hearts shows the run", _streak_pill.visible and _streak_label.text == "9")

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
