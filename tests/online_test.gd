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

	TSProfile.pending_board_results = []
	TSProfile._resolve_period("weekly", "W100", 30)
	_check("a finished board waits to be placed online", TSProfile.pending_board_results.size() == 1 and TSProfile.pending_board_results[0]["board"] == "weekly_W100")

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
