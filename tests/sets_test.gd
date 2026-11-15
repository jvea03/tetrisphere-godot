# Collection sets: every set can be finished (no critter held back for a later
# release or only in the Battle Pass, none in two sets), an unfinished set
# can't be claimed, and a finished one pays its coins once.
# Run with:
#   Godot.exe --headless --path . res://tests/sets_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(20)
	var seen := {}
	var bad: Array = []
	for st: Dictionary in TSSets.SETS:
		for i: int in st["critters"]:
			if i < 0 or i >= TSProfile.CRITTER_COUNT or TSProfile.is_critter_hidden(i) or TSProfile.is_critter_pass_exclusive(i) or seen.has(i):
				bad.append("%s:%d" % [st["id"], i])
			seen[i] = true
	_check("every set can be finished, no critter twice %s" % str(bad), bad.is_empty())
	var snacks: Dictionary = TSSets.SETS[0]
	TSProfile.sets_claimed = []
	for i: int in snacks["critters"]:
		TSProfile.critter_unlocked[i] = false
	var coins := TSProfile.coin_count
	_check("an unfinished set can't be claimed", TSSets.claim(snacks) == 0 and TSProfile.coin_count == coins)
	for i: int in snacks["critters"]:
		TSProfile.critter_unlocked[i] = true
	_check("a finished set is ready, and counted", TSSets.can_claim(snacks) and TSSets.claimable_count() >= 1)
	var got := TSSets.claim(snacks)
	_check("claiming pays its coins (+%d)" % got, got >= TSSets.reward(snacks) and TSProfile.coin_count == coins + got)
	_check("and only once", TSSets.claim(snacks) == 0 and TSSets.is_claimed(snacks) and TSProfile.coin_count == coins + got)
	_check("Snack Time pays 12,500 (a quarter of its critters' price)", TSSets.reward(snacks) == 12500)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
