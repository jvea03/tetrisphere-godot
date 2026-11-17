# The Snowball Fight: on only on Christmas-season weekends; the player joins a
# team, every piece popped throws a snowball, milestones pay once, and when
# the weekend ends the team prize (and any milestone left unclaimed) is paid.
# Run with:
#   Godot.exe --headless --path . res://tests/snowball_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _at(when: String) -> void:
	TSClock.offset = Time.get_unix_time_from_datetime_string(when) - Time.get_unix_time_from_system()


func _ready() -> void:
	TSProfile.use_test_profile(20)
	var before := TSClock.offset
	_at("2026-11-21T12:00:00")
	_check("not on an autumn weekend", not TSSnowball.is_live())
	_at("2026-12-03T12:00:00")
	_check("not on a Christmas Thursday", not TSSnowball.is_live())
	_at("2026-12-05T12:00:00")
	_check("on a Christmas Saturday", TSSnowball.is_live() and TSSnowball.seconds_left() > 0 and TSSnowball.seconds_left() < 2 * 86400)
	TSSnowball.roll()
	_check("joined a team", TSSnowball.TEAMS.has(TSSnowball.team) and TSSnowball.thrown == 0)
	var mine := TSSnowball.team_total(TSSnowball.team)
	TSProfile.record_quest_event("clear", 160)
	_check("popping 160 pieces throws 160 snowballs, for the team too", TSSnowball.thrown == 160 and TSSnowball.team_total(TSSnowball.team) == mine + 160)
	_check("the crowd has thrown plenty by Saturday", TSSnowball.team_total(TSSnowball.rival()) > 100000)
	var coins := TSProfile.coin_count
	_check("the first milestone is ready", TSSnowball.claimable_count() == 1)
	var got := TSSnowball.claim(0)
	_check("and pays once (%s)" % got, got != "" and TSProfile.coin_count > coins and TSSnowball.claim(0) == "" and TSSnowball.claimable_count() == 0)
	TSProfile.record_quest_event("clear", 300)   # 460: the bomb milestone, left unclaimed
	var bombs := TSProfile.bomb_count
	coins = TSProfile.coin_count
	_at("2026-12-08T12:00:00")
	TSSnowball.roll()
	var r := TSSnowball.result
	_check("the next week settles it: the team prize and the unclaimed bomb", not r.is_empty() and TSProfile.coin_count - coins >= TSSnowball.LOSE_COINS and TSProfile.bomb_count == bombs + 1 and int(r["thrown"]) == 460)
	_check("not live on Tuesday, but Home still shows the result", not TSSnowball.is_live() and TSSnowball.show_tile())
	TSSnowball.take_result()
	_check("once seen the tile goes", not TSSnowball.show_tile())
	TSClock.offset = before
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
