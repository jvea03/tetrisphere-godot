# Challenge levels: a tutorial one (Intermediate) after level 17, then from
# between 40 and 41 every 20, each played once (marked as it starts); an Extreme egg with a 2-minute clock (3 on the tutorial one) that waits
# for its intro, pauses and cards; out of time (or hearts) there is no
# continue -- the next level follows; a win pays the bonus but moves neither
# the level nor the win streak; leaving parks it with its clock. Run with:
#   Godot.exe --headless --path . res://tests/challenge_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(41)   # just won level 40
	TSProfile.challenge_done_through = 0
	TSProfile.challenge_intro_seen = false
	TSProfile.pieces_intro_seen = false
	TSProfile.no_ads = true
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


func _says(dialog: Dictionary, text: String) -> bool:
	return (dialog["box"] as Node).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains(text)) \
		or (dialog["box"] as Node).find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text.contains(text))


func _run() -> void:
	_check("slots: after 17 (the tutorial one), after 40, then every 20", TSLevels.is_challenge_slot(17) and TSLevels.is_challenge_slot(40) and TSLevels.is_challenge_slot(60) and not TSLevels.is_challenge_slot(50) and not TSLevels.is_challenge_slot(20))
	_check("the newest slot behind a level", TSLevels.challenge_slot_at(16) == -1 and TSLevels.challenge_slot_at(17) == 17 and TSLevels.challenge_slot_at(39) == 17 and TSLevels.challenge_slot_at(45) == 40 and TSLevels.challenge_slot_at(300) == 300)

	_check("having won 40, the game opens on the challenge", is_challenge and current_level == 40 and _lbl_level.text == "CHALLENGE")
	_check("an Extreme egg", difficulty == TSLevels.DIFF_EXTREME and _escape_size() >= 3)
	_check("marked played as it starts: no retry by quitting", TSProfile.challenge_due() == -1 and TSProfile.challenge_done_through == 40)
	_check("its clock shows %d:00" % (TSLevels.CHALLENGE_SECONDS / 60), _timer_pill.visible and _timer_label.text == "%d:00" % (TSLevels.CHALLENGE_SECONDS / 60))
	_check("the level stays 41", TSProfile.last_level == 41)

	await get_tree().create_timer(1.0).timeout
	_check("the first one opens with its intro, and the clock waits", _tutorial.visible and challenge_left > TSLevels.CHALLENGE_SECONDS - 0.2)
	_check("its card names the pieces with the minutes", str(_tutorial.steps[0]["text"]).contains("2 minutes and %d pieces" % TSLevels.CHALLENGE_PIECES))
	_tutorial._next.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_check("its intro has a second step: the rules", _tutorial.visible)
	_tutorial._next.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	_check("then it runs", challenge_left < TSLevels.CHALLENGE_SECONDS - 0.5 and challenge_left > TSLevels.CHALLENGE_SECONDS - 3.0 and TSProfile.challenge_intro_seen)
	_check("the piece counter's own card doesn't pile on (the challenge's names its pieces)", not _tutorial.visible and not TSProfile.pieces_intro_seen)
	_open_pause()
	_check("Pause has no Restart on a challenge", not (_pause["restart"] as Button).visible)
	var held := challenge_left
	await get_tree().create_timer(1.0).timeout
	_check("and holds the clock", is_equal_approx(challenge_left, held))
	TSUI.conceal(_pause["root"])
	await get_tree().create_timer(0.5).timeout

	var parked := _snapshot()
	_check("a parked challenge keeps its clock", bool(parked["challenge"]) and absf(float(parked["challenge_left"]) - challenge_left) < 0.5)
	# Parked before challenges had a counter (0 then): back with a full one.
	parked["pieces_left"] = 0
	TSSession.state = parked
	_resume()
	_check("a challenge parked before the counter comes back with a full one", pieces_left == TSLevels.CHALLENGE_PIECES and is_challenge)

	challenge_left = 0.05
	await get_tree().create_timer(0.3).timeout
	_check("out of time, it's lost", state == State.LOST and lose_reason == "TIME'S UP")
	_refresh_lose_card()
	_check("no continue, no ad: on to level 41", _says(_lose_card, "Time's up!") and _says(_lose_card, "On to Level 41") and not _says(_lose_card, "Continue") and not _says(_lose_card, "Watch an ad"))
	_check("but a buy-out: +1 min (no heart: none was lost)", _says(_lose_card, "+1 min") and not _says(_lose_card, "+1 heart"))
	var wallet := TSProfile.coin_count
	_buy_challenge_time()
	_check("bought: a minute more, play on", state == State.PLAYING and is_equal_approx(challenge_left, 60.0) and lives == LIVES and TSProfile.coin_count == wallet - TSLevels.CHALLENGE_BUYOUT_COINS)
	lives = LIVES - 1
	challenge_left = 0.05
	await get_tree().create_timer(0.3).timeout
	_refresh_lose_card()
	_check("out of time again, a heart down: the buy-out gives it back too", _says(_lose_card, "+1 min") and _says(_lose_card, "+1 heart"))
	_buy_challenge_time()
	_check("a minute and a heart", state == State.PLAYING and is_equal_approx(challenge_left, 60.0) and lives == LIVES)
	lives = 0
	lose_reason = "OUT OF LIVES"
	_lose()
	await get_tree().create_timer(0.3).timeout
	_refresh_lose_card()
	_check("out of hearts there's no buy-out", state == State.LOST and lose_reason != "TIME'S UP" and not _says(_lose_card, "+1 min") and _says(_lose_card, "On to Level 41"))
	_play_after(current_level)
	_check("which follows", not is_challenge and current_level == 41)

	# A win: the bonus, but no level progress and no streak.
	TSProfile.challenge_done_through = 0
	TSProfile.win_streak = 2
	_start_challenge(40)
	var coins := TSProfile.coin_count
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_check("a win pays the challenge bonus", _says(_win_card, "Challenge won!") and _says(_win_card, "Challenge bonus") and TSProfile.coin_count >= coins + TSLevels.CHALLENGE_BONUS_COINS)
	_check("but moves neither the level nor the streak", TSProfile.last_level == 41 and TSProfile.win_streak == 2)
	_on_next_pressed()
	_check("Next goes on to level 41", not is_challenge and current_level == 41)

	# Winning level 40 itself leads into the challenge.
	TSProfile.challenge_done_through = 0
	TSProfile.last_level = 40
	_start_level(40)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_on_next_pressed()
	_check("Next after level 40 opens the challenge", is_challenge and current_level == 40)

	TSProfile.challenge_done_through = 0
	TSProfile.last_level = 300
	_check("a player far along gets the newest one behind them only", TSProfile.challenge_due() == 280)
	TSProfile.last_level = 301
	_check("(which sits behind level 301)", TSProfile.challenge_due() == 300)
	# The tutorial one, after level 17: an Intermediate egg on a longer clock.
	TSProfile.challenge_done_through = 0
	TSProfile.last_level = 18
	_check("having won 17, the tutorial challenge is due", TSProfile.challenge_due() == 17)
	_start_challenge(17)
	_check("an Intermediate egg, on a %d-minute clock (the rest %d)" % [TSLevels.CHALLENGE_TUTORIAL_SECONDS / 60, TSLevels.CHALLENGE_SECONDS / 60], is_challenge and difficulty == 1 and _escape_size() == 3 and is_equal_approx(challenge_left, float(TSLevels.CHALLENGE_TUTORIAL_SECONDS)) and TSLevels.CHALLENGE_TUTORIAL_SECONDS > TSLevels.CHALLENGE_SECONDS)
	_refresh_timer()
	_check("its clock shows 3:00", _timer_label.text == "%d:00" % (TSLevels.CHALLENGE_TUTORIAL_SECONDS / 60))
	TSProfile.last_level = 41
	_check("and once it's played, the one after 40 is next", TSProfile.challenge_due() == 40)
	# The whole way through the tutorial one: win 17, Next, the challenge, win it, Next, 18.
	TSProfile.challenge_done_through = 0
	TSProfile.last_level = 17
	_start_level(17)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_on_next_pressed()
	_check("winning 17 leads into the tutorial challenge", is_challenge and current_level == 17 and difficulty == 1)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_on_next_pressed()
	_check("and winning it on to level 18", not is_challenge and current_level == 18 and TSProfile.last_level == 18)
	print("challenge_test: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
