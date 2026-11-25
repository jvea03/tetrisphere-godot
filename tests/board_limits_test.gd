# The leaderboard ceilings in firestore.rules. The rules are what Firebase
# enforces; this repeats their formula with the numbers read back out of the
# file, and checks those numbers against the season dates the game actually
# uses. Run with:
#   Godot.exe --headless --path . res://tests/board_limits_test.tscn
extends Node

const STARS_PER_MIN := 8
const STAR_BURST := 40
const SLACK_SEC := 3600
const DAILY_CAP := 12000
const WEEKLY_CAP := 15000
const SEASON_CAP := 30000
const SNOW_PER_MIN := 180
const SNOW_BURST := 2000
const SNOW_CAP := 100000
const SNOW_TAIL_SEC := 64800
const CHECK_CAP := 100

var _failures := 0
var _rules := ""


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	_rules = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://firestore.rules"))
	_check("firestore.rules is readable", _rules != "")
	_test_constants_match_the_file()
	_test_formula_is_the_one_in_the_rules()
	_test_daily()
	_test_weekly_and_season()
	_test_snowball_and_check()
	_test_shape_and_clock()
	_test_against_the_game()
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _fn_return(name: String) -> int:
	var re := RegEx.new()
	re.compile("function %s\\(\\) \\{ return (\\d+); \\}" % name)
	var found := re.search(_rules)
	return int(found.get_string(1)) if found != null else -1


func _test_constants_match_the_file() -> void:
	_check("starsPerMin", _fn_return("starsPerMin") == STARS_PER_MIN)
	_check("starBurst", _fn_return("starBurst") == STAR_BURST)
	_check("slackSec", _fn_return("slackSec") == SLACK_SEC)
	_check("dailyCap", _fn_return("dailyCap") == DAILY_CAP)
	_check("weeklyCap", _fn_return("weeklyCap") == WEEKLY_CAP)
	_check("seasonCap", _fn_return("seasonCap") == SEASON_CAP)
	_check("snowPerMin", _fn_return("snowPerMin") == SNOW_PER_MIN)
	_check("snowBurst", _fn_return("snowBurst") == SNOW_BURST)
	_check("snowCap", _fn_return("snowCap") == SNOW_CAP)
	_check("snowTailSec", _fn_return("snowTailSec") == SNOW_TAIL_SEC)
	_check("checkCap", _fn_return("checkCap") == CHECK_CAP)


func _test_formula_is_the_one_in_the_rules() -> void:
	_check("star ceiling is burst plus the per-minute rate over elapsed + slack",
		_rules.contains("let grown = starBurst() + starsPerMin() * int((elapsedSec + slackSec()) / 60);"))
	_check("snowball ceiling is the same shape at its own rate",
		_rules.contains("let grown = snowBurst() + snowPerMin() * int((elapsedSec + slackSec()) / 60);"))
	_check("a later write cannot lower stars",
		_rules.contains("request.resource.data.stars >= resource.data.stars"))
	_check("week start is the game's Monday index", _rules.contains("return (w * 7 - 3) * 86400;"))
	_check("snowball opens Thursday and closes the next Monday",
		_rules.contains("monday + 3 * 86400") and _rules.contains("monday + 7 * 86400"))
	_check("season 1 starts the day leaderboards opened", _rules.contains("timestamp.date(2026, 11, 11)"))
	_check("later seasons count from 1 Dec 2026 in 28-day steps",
		_rules.contains("timestamp.date(2026, 12, 1)") and _rules.contains("(n - 2) * 28 * 86400"))


func _unix(y: int, m: int, d: int, h := 0, mi := 0, s := 0) -> int:
	return int(Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT%02d:%02d:%02dZ" % [y, m, d, h, mi, s]))


func _day_start(y: int, m: int, d: int) -> int:
	return _unix(y, m, d)


## Mirrors capAt: elapsed is server-now minus the board's start.
func _cap(elapsed: int, hard: int, burst: int, per_min: int) -> int:
	var grown := burst + per_min * int((elapsed + SLACK_SEC) / 60)
	return mini(hard, grown)


func _in_window(now: int, start: int, end: int, tail: int) -> bool:
	return now + SLACK_SEC >= start and now <= end + tail


func _week_start(w: int) -> int:
	return (w * 7 - 3) * 86400


func _season_start(n: int) -> int:
	if n <= 1:
		return _day_start(2026, 11, 11)
	return _day_start(2026, 12, 1) + (n - 2) * 28 * 86400


func _season_end(n: int) -> int:
	if n <= 1:
		return _day_start(2026, 12, 1)
	return _season_start(n) + 28 * 86400


## Whether the rules would accept `stars` on `board` at server time `now`.
## `prev` is the stored total, or -1 when the row is new.
func _allows(board: String, stars: int, now: int, prev := -1) -> bool:
	if stars < 0 or (prev >= 0 and stars < prev):
		return false
	if board.begins_with("check_"):
		return stars <= CHECK_CAP
	if board.begins_with("daily_"):
		var start := _day_start(int(board.substr(6, 4)), int(board.substr(11, 2)), int(board.substr(14, 2)))
		return _in_window(now, start, start + 86400, SLACK_SEC) and stars <= _cap(now - start, DAILY_CAP, STAR_BURST, STARS_PER_MIN)
	if board.begins_with("weekly_W"):
		var start := _week_start(int(board.trim_prefix("weekly_W")))
		return _in_window(now, start, start + 7 * 86400, SLACK_SEC) and stars <= _cap(now - start, WEEKLY_CAP, STAR_BURST, STARS_PER_MIN)
	if board.begins_with("season_S"):
		var n := int(board.trim_prefix("season_S"))
		if n < 1:
			return false
		return _in_window(now, _season_start(n), _season_end(n), SLACK_SEC) and stars <= _cap(now - _season_start(n), SEASON_CAP, STAR_BURST, STARS_PER_MIN)
	if board.begins_with("snowball_W") and (board.ends_with("_red") or board.ends_with("_green")):
		var token := board.trim_prefix("snowball_")
		var w := int(token.split("_")[0].trim_prefix("W"))
		var monday := _week_start(w)
		var start := monday + 3 * 86400
		var end := monday + 7 * 86400
		return _in_window(now, start, end, SNOW_TAIL_SEC) and stars <= _cap(now - start, SNOW_CAP, SNOW_BURST, SNOW_PER_MIN)
	return false


func _test_daily() -> void:
	var open := _unix(2026, 11, 25)
	_check("at UTC midnight a daily board takes 520 and refuses 521",
		_allows("daily_2026-11-25", 520, open) and not _allows("daily_2026-11-25", 521, open))
	_check("an hour later the ceiling is 1000",
		_allows("daily_2026-11-25", 1000, open + 3600) and not _allows("daily_2026-11-25", 1001, open + 3600))
	_check("noon is 6280, not 100000",
		_allows("daily_2026-11-25", 6280, open + 12 * 3600) and not _allows("daily_2026-11-25", 6281, open + 12 * 3600)
		and not _allows("daily_2026-11-25", 100000, open + 12 * 3600))
	_check("the 12000 cap binds in the last few minutes",
		_allows("daily_2026-11-25", 12000, open + 86400 - 60) and not _allows("daily_2026-11-25", 12001, open + 86400 - 60))
	_check("an hour early only the 40-star burst fits",
		_allows("daily_2026-11-25", 40, open - SLACK_SEC) and not _allows("daily_2026-11-25", 41, open - SLACK_SEC))
	_check("more than an hour early is closed", not _allows("daily_2026-11-25", 1, open - SLACK_SEC - 1))
	_check("half an hour after the next midnight still takes the day's cap",
		_allows("daily_2026-11-25", 12000, open + 86400 + 1800))
	_check("two hours after midnight yesterday's board is closed",
		not _allows("daily_2026-11-25", 5, open + 86400 + 2 * 3600))
	_check("tomorrow's board is closed at noon today", not _allows("daily_2026-11-26", 5, open + 12 * 3600))
	_check("a renamed row keeps its stars", _allows("daily_2026-11-25", 100, open + 6 * 3600, 100))
	_check("stars cannot go down", not _allows("daily_2026-11-25", 99, open + 6 * 3600, 100))
	_check("a real catch-up still fits at noon", _allows("daily_2026-11-25", 400, open + 12 * 3600, 20))
	_check("a board id the game does not use is refused", not _allows("hacked", 1, open) and not _allows("season_S0", 1, open))


func _test_weekly_and_season() -> void:
	var monday := _unix(2026, 11, 23)
	_check("week 2969 is the Monday of 23 Nov 2026", _week_start(2969) == monday)
	_check("a weekly board opens at the same 520 as a day",
		_allows("weekly_W2969", 520, monday) and not _allows("weekly_W2969", 521, monday))
	_check("the weekly cap is 15000 once the week is 31 hours old",
		_allows("weekly_W2969", 15000, monday + 31 * 3600) and not _allows("weekly_W2969", 15001, monday + 31 * 3600))
	var season_open := _unix(2026, 11, 11)
	_check("a new season starts at 520, not at its cap",
		_allows("season_S1", 520, season_open) and not _allows("season_S1", 521, season_open))
	_check("62 hours in, the season cap of 30000 is the ceiling",
		_allows("season_S1", 30000, season_open + 62 * 3600) and not _allows("season_S1", 30001, season_open + 62 * 3600))
	_check("on 25 Nov season 1 is already at that cap",
		_allows("season_S1", 30000, _unix(2026, 11, 25, 12)) and not _allows("season_S1", 30001, _unix(2026, 11, 25, 12))
		and not _allows("season_S1", 100000, _unix(2026, 11, 25, 12)))
	var s2 := _unix(2026, 12, 1)
	_check("season 2 is closed the day before it opens", not _allows("season_S2", 5, s2 - SLACK_SEC - 1))
	_check("season 2 opens at 520 on 1 Dec", _allows("season_S2", 520, s2) and not _allows("season_S2", 30000, s2))


func _test_snowball_and_check() -> void:
	var thursday := _unix(2026, 11, 26)   # week 2969's Thursday
	_check("snowball is closed on Wednesday", not _allows("snowball_W2969_red", 1, _unix(2026, 11, 25, 12)))
	_check("at Thursday 00:00 UTC the snowball ceiling is 12800",
		_allows("snowball_W2969_green", 12800, thursday) and not _allows("snowball_W2969_green", 12801, thursday)
		and not _allows("snowball_W2969_green", 100000, thursday))
	_check("an hour before Thursday only the 2000 burst fits",
		_allows("snowball_W2969_red", 2000, thursday - SLACK_SEC) and not _allows("snowball_W2969_red", 2001, thursday - SLACK_SEC))
	_check("eight hours later the phone's 100000 clamp is the ceiling",
		_allows("snowball_W2969_red", 100000, thursday + 8 * 3600 + 300) and not _allows("snowball_W2969_red", 100001, thursday + 8 * 3600 + 300))
	var monday_after := _unix(2026, 11, 30)
	_check("Sunday night in UTC-12 (Monday noon UTC) still posts",
		_allows("snowball_W2969_red", 100, monday_after + 12 * 3600))
	_check("after Monday 18:00 UTC the snowball board is closed",
		not _allows("snowball_W2969_red", 1, monday_after + SNOW_TAIL_SEC + 1))
	_check("a check board takes the e2e score and refuses 101",
		_allows("check_e2e", 42, _unix(2026, 11, 25)) and _allows("check_e2e", 100, 0) and not _allows("check_e2e", 101, 0))
	_check("a blue snowball team is not a board", not _allows("snowball_W2969_blue", 1, thursday))


func _test_shape_and_clock() -> void:
	_check("the row is still exactly name, avatar, stars, t",
		_rules.contains("keys().hasOnly(['name', 'avatar', 'stars', 't'])"))
	var online := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://scripts/meta/online.gd"))
	_check("the phone still writes those four fields",
		online.contains('{"name": TSProfile.player_name, "avatar": TSProfile.avatar(), "stars": stars, "t": int(Time.get_unix_time_from_system())}'))
	_check("the device clock is not compared to the server",
		not _rules.contains("data.t >") and not _rules.contains("data.t <") and not _rules.contains("data.t =="))
	_check("a player still cannot delete a row", _rules.contains("allow delete: if false;"))
	_check("every critter avatar fits", TSProfile.CRITTER_COUNT > 0 and TSProfile.CRITTER_COUNT < 200)


func _test_against_the_game() -> void:
	_check("leaderboards opened 2026-11-11", TSNav.LEADERBOARDS_OPEN_DATE == "2026-11-11")
	_check("the pass calendar is 16 Oct then 1 Dec 2026",
		TSProfile.BATTLE_PASS_CALENDAR == ["2026-10-16", "2026-12-01"] and TSProfile.BATTLE_PASS_DAYS == 28)
	_check("season 1's board starts when the rules say",
		TSProfile._board_season_start(1) == _season_start(1) and TSProfile._season_end(1) == _season_end(1))
	_check("season 2 and 3 follow the 28-day rule",
		TSProfile._board_season_start(2) == _season_start(2) and TSProfile._season_end(2) == _season_end(2)
		and TSProfile._board_season_start(3) == _season_start(3) and TSProfile._season_end(3) == _season_end(3))
	# The game's week index for a UTC day is (day + 3) / 7, Monday-based.
	var day := _unix(2026, 11, 25) / 86400
	_check("25 Nov 2026 is week 2969, opened the Monday before",
		(day + 3) / 7 == 2969 and _week_start(2969) == _unix(2026, 11, 23))
