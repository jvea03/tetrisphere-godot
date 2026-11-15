# The Profile's lifetime stats: quest events count up, a loss and stars too,
# and Daily Eggs count as eggs won.
# Run with:
#   Godot.exe --headless --path . res://tests/stats_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.lifetime = {}
	TSProfile.record_quest_event("win")
	TSProfile.record_quest_event("win")
	TSProfile.record_quest_event("daily_puzzle")
	TSProfile.record_quest_event("clear", 7)
	TSProfile.add_lifetime("loss")
	_check("wins, Daily Eggs, pieces and losses count up", TSProfile.eggs_won() == 3 and TSProfile.lifetime_of("clear") == 7 and TSProfile.lifetime_of("loss") == 1)
	var stars := TSProfile.lifetime_of("stars")
	var got := TSProfile.add_stars(3, 2)
	_check("stars count as they're earned (+%d)" % got, TSProfile.lifetime_of("stars") == stars + got and got == 5)
	_check("nothing to count is 0", TSProfile.lifetime_of("nope") == 0)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
