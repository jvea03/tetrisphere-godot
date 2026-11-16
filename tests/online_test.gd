# The leaderboards and stickers without a network (Online is quiet on a
# throwaway profile): Firestore's value format both ways, a board's standings
# from fetched rows with the player's own in place and blocked players left
# out, the basic stickers and Battle Pass ones, and a finished board waiting
# to be placed. Run with:
#   Godot.exe --headless --path . res://tests/online_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSProfile.player_name = "Tester"
	_check("a throwaway profile stays offline", not Online.enabled())

	var f := Online.to_fields({"name": "Pip", "stars": 12, "ok": true})
	_check("values go out as Firestore's", f["name"] == {"stringValue": "Pip"} and f["stars"] == {"integerValue": "12"} and f["ok"] == {"booleanValue": true})
	_check("and come back", Online.from_fields(f) == {"name": "Pip", "stars": 12, "ok": true})
	_check("a board id", Online.board_id("daily", "2026-11-14") == "daily_2026-11-14")

	var board := TSProfile.current_board("daily")   # (rolls the day first)
	TSProfile.daily_star_total = 7
	Online.boards[board] = {"at": Time.get_unix_time_from_system(), "entries": [
		{"uid": "a", "name": "Ann", "avatar": 3, "stars": 20, "is_player": false},
		{"uid": "b", "name": "Bo", "avatar": 4, "stars": 7, "is_player": false},
		{"uid": "me", "name": "Old me", "avatar": 1, "stars": 2, "is_player": true},
		{"uid": "c", "name": "Cy", "avatar": 5, "stars": 3, "is_player": false}]}
	var rows: Array = TSProfile.standings_for("daily")
	var names := rows.map(func(r: Dictionary) -> String: return r["name"])
	_check("standings: best first, the player's own row (as on the phone) in its place (%s)" % str(names), names == ["Ann", "Tester", "Bo", "Cy"])
	TSProfile.blocked_players = ["b"]
	names = TSProfile.standings_for("daily").map(func(r: Dictionary) -> String: return r["name"])
	_check("a blocked player is left off", names == ["Ann", "Tester", "Cy"])
	TSProfile.blocked_players = []

	_check("everyone has the three basic stickers", TSStickers.owned() == ["angry", "sad", "congrats"])
	var xmas: Dictionary = TSProfile.BATTLE_PASS_SEASON_REWARDS[1]
	_check("the Christmas pass gives four more", xmas["theme"] == "christmas" and (xmas["free_stickers"] as Dictionary).size() + (xmas["paid_stickers"] as Dictionary).size() == 4)
	TSProfile._apply_reward({"sticker": "jolly"})
	_check("a pass reward grants its sticker", TSStickers.owns("jolly") and TSStickers.owned() == ["angry", "sad", "congrats", "jolly"])
	_check("granting it again does nothing", not TSStickers.grant("jolly") and TSProfile.stickers_owned.size() == 1)
	_check("no such sticker", not TSStickers.grant("nope") and not TSStickers.owns("nope"))
	var sent := []
	Online.send_sticker("a", "angry", func(ok: bool) -> void: sent.append(ok))
	_check("offline, sending says so at once", sent == [false])

	# The shared boards run on UTC, the same day and week for everyone.
	TSProfile.current_board("daily")
	_check("the daily board is today in UTC (%s)" % TSProfile.daily_star_date, TSProfile.daily_star_date == TSClock.utc_date_string())
	_check("the daily board id is that UTC date", TSProfile.current_board("daily") == "daily_" + TSClock.utc_date_string())
	var day_left := TSProfile.seconds_until_board_day()
	var week_left := TSProfile.seconds_until_board_week()
	_check("its reset is the next UTC midnight (%d s), the week's within 7 days (%d s)" % [day_left, week_left], day_left > 0 and day_left <= 86400 and week_left >= day_left and week_left <= 7 * 86400 and (int(TSClock.now()) + day_left) % 86400 == 0)
	_check("the weekly board is the UTC week", TSProfile.current_board("weekly") == "weekly_W%d" % ((int(TSClock.now()) / 86400 + 3) / 7))

	TSProfile.pending_board_results = []
	TSProfile._resolve_period("weekly", "W100", 30)
	_check("a finished board waits to be placed online", TSProfile.pending_board_results.size() == 1 and TSProfile.pending_board_results[0]["board"] == "weekly_W100")

	# Prizes only on boards this player was on online, with enough players.
	Online.force_fake = true
	TSProfile.pending_board_prizes = []
	TSProfile.boards_joined = ["weekly_W8888"]
	TSProfile.pending_board_results = [{"period": "weekly", "board": "weekly_W7777", "stars": 999}, {"period": "weekly", "board": "weekly_W8888", "stars": 9999}]
	TSProfile.resolve_board_results()
	await get_tree().process_frame
	_check("a board never played online pays nothing", TSProfile.pending_board_results.is_empty() and TSProfile.pending_board_prizes.size() == 1)
	_check("a board played online pays its place (1st)", TSProfile.pending_board_prizes.size() == 1 and int(TSProfile.pending_board_prizes[0]["place"]) == 1)
	Online.force_fake = false
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
