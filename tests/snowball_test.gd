# The Snowball Fight's Giant Snowball: 5-15 snowballs by how fast it's
# mashed, added to the player's throws, then a six-hour wait (kept in the
# save); and on the event screen, mashing it launches it, the other squad
# is knocked out of its fort when it lands, and is back a few seconds later.
# Top Throwers keeps a board per team per weekend, with the player on their
# own team's. Run with:
#   Godot.exe --path . res://tests/snowball_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _process(_delta: float) -> void:
	_hold("2026-12-05T14:00:00")


func _hold(at: String) -> void:
	TSClock.offset = Time.get_unix_time_from_datetime_string(at) - Time.get_unix_time_from_system()


func _ready() -> void:
	TSProfile.use_test_profile(20)
	_hold("2026-12-05T14:00:00")
	TSProfile.planet_season = TSProfile.battle_pass_season_number()
	TSSnowball.blast_at = 0.0
	TSSnowball.roll()
	_check("the fight is on on a Christmas Saturday", TSSnowball.is_live())
	TSSnowball.team = "red"
	TSSnowball.thrown = 0
	_check("a Giant Snowball is ready to start with", TSSnowball.blast_ready())
	_check("one tap throws 5 (%d)" % TSSnowball.blast_amount(1), TSSnowball.blast_amount(1) == 5)
	_check("15 taps throw 10 (%d)" % TSSnowball.blast_amount(15), TSSnowball.blast_amount(15) == 10)
	_check("30 taps or more throw 15", TSSnowball.blast_amount(30) == 15 and TSSnowball.blast_amount(80) == 15)
	var mine_before := TSSnowball.team_total("red")
	var n := TSSnowball.blast(30)
	_check("it throws 15 for the team", n == 15 and TSSnowball.thrown == 15 and TSSnowball.team_total("red") == mine_before + 15)
	_check("then it isn't ready again", not TSSnowball.blast_ready() and TSSnowball.blast(30) == 0 and TSSnowball.thrown == 15)
	_check("for six hours (%d s)" % TSSnowball.blast_wait(), absi(TSSnowball.blast_wait() - 6 * 3600) <= 2)
	var saved := TSSnowball.to_save()
	TSSnowball.blast_at = 0.0
	TSSnowball.from_save(saved)
	_check("the wait is kept in the save", not TSSnowball.blast_ready())
	_hold("2026-12-05T20:01:00")
	_check("ready again after six hours", TSSnowball.blast_ready())
	_check("Home's tile shows a dot while it's ready", TSSnowball.has_alert())
	_hold("2026-12-05T14:00:00")
	TSSnowball.blast_at = 0.0

	# Top Throwers: a board per team per weekend, the player on their own.
	_check("each team has its own board this weekend (%s)" % TSSnowball.board("red"), TSSnowball.board("red") == "snowball_W%d_red" % TSSnowball.week and TSSnowball.board("green") != TSSnowball.board("red"))
	var mine_rows := TSSnowball.standings("red")
	_check("the player is on their team's Top Throwers with what they threw", mine_rows.size() == 1 and mine_rows[0]["is_player"] and int(mine_rows[0]["stars"]) == TSSnowball.thrown)
	_check("and not on the other team's", TSSnowball.standings("green").is_empty())
	# A finished weekend: a top-3 thrower's place is queued with the other boards,
	# and pays TOP_COINS once placed.
	var saved_week := TSSnowball.week
	TSProfile.boards_joined.append(TSSnowball.board("red"))
	var board_red := TSSnowball.board("red")
	TSSnowball._settle()
	var queued := TSProfile.pending_board_results.filter(func(r: Dictionary) -> bool: return r["board"] == board_red)
	_check("the weekend's board is queued to be placed", queued.size() == 1 and queued[0]["period"] == "snowball" and int(queued[0]["stars"]) == 15)
	var coins_before := TSProfile.pending_board_prizes.size()
	TSProfile._settle_board_result(queued[0], 1)
	_check("first place queues %s coins" % TSSnowball.TOP_COINS[0], TSProfile.pending_board_prizes.size() == coins_before + 1 and int(TSProfile.pending_board_prizes[-1]["coins"]) == TSProfile.boost_earned_coins(TSSnowball.TOP_COINS[0]))
	var q2 := {"period": "snowball", "board": board_red, "stars": 15, "team": "red"}
	TSProfile.pending_board_results.append(q2)
	TSProfile._settle_board_result(q2, 4)
	_check("fourth place pays nothing", TSProfile.pending_board_prizes.size() == coins_before + 1)
	TSSnowball.result = {}
	TSSnowball.week = saved_week
	TSSnowball.team = "red"
	TSSnowball.thrown = 15

	# On the screen: mash, it flies, the other squad is knocked out, back later.
	var screen: Node = (load("res://scenes/snowball.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the screen says how to earn snowballs", not screen.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "How to earn snowballs").is_empty())
	var btn: Button = screen._blast_btn
	_check("its button is ready (%s)" % screen._blast_label.text, not btn.disabled and screen._blast_label.text == "THROW IT!")
	var thrown_before := TSSnowball.thrown
	for i in 20:
		screen._mash()
	var field = screen._field
	_check("mashing charges the Giant Snowball (%.2f)" % field.charge, field.charge > 0.6)
	await get_tree().process_frame
	_check("the snowball in the button grows (%.2f) and it counts down MASH! (%s)" % [screen._blast_ball.grow, screen._blast_label.text], screen._blast_ball.grow > 0.6 and screen._blast_label.text.begins_with("MASH!"))
	await get_tree().create_timer(TSSnowball.BLAST_SECONDS + 0.2).timeout
	_check("after the mashing it's in the air", not field._giant.is_empty())
	_check("and threw 12 snowballs (%d)" % (TSSnowball.thrown - thrown_before), TSSnowball.thrown - thrown_before == TSSnowball.blast_amount(20))
	await get_tree().create_timer(field.GIANT_FLIGHT).timeout
	var out := (field._squads[false] as Array).filter(func(m: Dictionary) -> bool: return m.has("out")).size()
	_check("it knocks all three snowmen out of their fort (%d)" % out, out == 3)
	_check("and says what it threw", screen._toast.visible and screen._toast_text.text.contains("+12"))
	_check("the button waits six hours (%s)" % screen._blast_label.text, btn.disabled and screen._blast_label.text.begins_with("Ready in"))
	await get_tree().create_timer(field.KNOCKED + field.SPAWN + 0.3).timeout
	out = (field._squads[false] as Array).filter(func(m: Dictionary) -> bool: return m.has("out") or m.has("spawn")).size()
	_check("they're back a few seconds later", out == 0)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
