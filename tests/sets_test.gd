# Collection sets: every set can be finished (no critter held back for a later
# release or only in the Battle Pass, none in two sets), an unfinished set
# can't be claimed, a finished one pays its coins once, and then it ranks up:
# rank N once every critter is level N, each later rank paying half the coins.
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
	_check("Snack Time pays 12,500 (a quarter of its critters' price)", TSSets.reward_for(snacks, 1) == 12500)
	# Ranks: rank 2 needs every critter at level 2, and pays half the set's coins.
	_check("claiming makes it rank 1", TSSets.rank(snacks) == 1 and TSSets.next_rank(snacks) == 2)
	var members: Array = snacks["critters"]
	for i: int in members:
		TSProfile.critter_level[i] = 1
	TSProfile.critter_level[members[0]] = 2
	_check("rank 2 waits while any critter is under level 2", not TSSets.can_claim(snacks) and TSSets.claim(snacks) == 0 and TSSets.at_level(snacks, 2) == 1)
	for i: int in members:
		TSProfile.critter_level[i] = 2
	_check("and is ready once they're all level 2", TSSets.can_claim(snacks))
	var coins2 := TSProfile.coin_count
	var got2 := TSSets.claim(snacks)
	_check("rank 2 pays half the set's coins (+%d)" % got2, got2 == TSProfile.boost_earned_coins(TSSets.reward_for(snacks, 2)) and TSSets.reward_for(snacks, 2) == 6500 and TSProfile.coin_count == coins2 + got2)
	_check("and the set is rank 2, saved", TSSets.rank(snacks) == 2 and int(TSProfile.sets_rank.get("snacks", 0)) == 2 and TSSets.claim(snacks) == 0)
	# A set claimed before ranks (only in sets_claimed) is rank 1.
	TSProfile.sets_rank.erase("pets")
	TSProfile.sets_claimed.append("pets")
	var pets: Dictionary = TSSets.SETS[1]
	_check("a set claimed before ranks counts as rank 1", TSSets.rank(pets) == 1 and TSSets.next_rank(pets) == 2)
	for i: int in members:
		TSProfile.critter_level[i] = TSProfile.CRITTER_MAX_LEVEL
	while TSSets.can_claim(snacks):
		TSSets.claim(snacks)
	_check("ranks run up to %d, then it's maxed" % TSSets.MAX_RANK, TSSets.rank(snacks) == TSSets.MAX_RANK and TSSets.is_maxed(snacks) and not TSSets.can_claim(snacks))
	# Snow Day is the Christmas season's featured set: first, and double coins.
	var snow: Dictionary = TSSets.SETS.filter(func(s: Dictionary) -> bool: return s["id"] == "snow")[0]
	var before := TSClock.offset
	TSClock.offset = Time.get_unix_time_from_datetime_string("2026-12-03T10:00:00") - Time.get_unix_time_from_system()
	_check("at Christmas Snow Day is featured, first on the tab, at double coins", TSSets.is_featured(snow) and TSSets.ordered()[0]["id"] == "snow" and TSSets.reward(snow) == TSSets.base_reward(snow) * 2 and not TSSets.is_featured(snacks))
	TSClock.offset = Time.get_unix_time_from_datetime_string("2027-01-05T10:00:00") - Time.get_unix_time_from_system()
	_check("after Christmas it is an ordinary set again", not TSSets.is_featured(snow) and TSSets.reward(snow) == TSSets.base_reward(snow))
	TSClock.offset = before
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
