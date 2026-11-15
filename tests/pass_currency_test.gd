# Tier Skips and Pass Tickets: inbox gifts give them; a Tier Skip moves the
# pass up one tier; ten tickets unlock this season's premium track, and not
# when it's already unlocked or short of ten.
# Run with:
#   Godot.exe --headless --path . res://tests/pass_currency_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSProfile.tier_skips = 0
	TSProfile.pass_tickets = 0
	TSProfile.inbox_done = {}
	var gift: Array = TSInbox.parse(JSON.stringify({"messages": [{"id": "g", "title": "Gift", "rewards": {"tier_skips": 2, "pass_tickets": 9}}]}))
	_check("an inbox gift can carry them", (gift[0]["rewards"] as Dictionary) == {"tier_skips": 2, "pass_tickets": 9})
	TSInbox.claim(gift[0])
	_check("collecting it gives them", TSProfile.tier_skips == 2 and TSProfile.pass_tickets == 9)

	var tier := TSProfile.battle_pass_tier()
	_check("a Tier Skip moves the pass up a tier", TSProfile.use_tier_skip() and TSProfile.battle_pass_tier() == tier + 1 and TSProfile.tier_skips == 1)

	TSProfile.battle_pass_purchased = false
	_check("nine tickets aren't enough", not TSProfile.redeem_pass_tickets() and not TSProfile.battle_pass_purchased)
	TSProfile.pass_tickets = 12
	_check("ten unlock premium, and are spent", TSProfile.redeem_pass_tickets() and TSProfile.battle_pass_purchased and TSProfile.pass_tickets == 2)
	TSProfile.pass_tickets = 10
	_check("not again once it's unlocked", not TSProfile.redeem_pass_tickets() and TSProfile.pass_tickets == 10)
	# The pass itself gives tickets from the Christmas season on: 2 free, 3 premium.
	var free_n := 0
	var paid_n := 0
	var autumn := 0
	for t in range(1, TSProfile.BATTLE_PASS_TIER_COUNT + 1):
		free_n += int(TSProfile.battle_pass_free_reward(t, 2).get("pass_tickets", 0))
		paid_n += int(TSProfile.battle_pass_paid_reward(t, 2).get("pass_tickets", 0))
		autumn += int(TSProfile.battle_pass_free_reward(t, 1).get("pass_tickets", 0)) + int(TSProfile.battle_pass_paid_reward(t, 1).get("pass_tickets", 0))
	_check("Christmas: %d free, %d premium; autumn none (%d)" % [free_n, paid_n, autumn], free_n == 2 and paid_n == 3 and autumn == 0)
	_check("later seasons too", int(TSProfile.battle_pass_free_reward(12, 7).get("pass_tickets", 0)) == 1)
	var had := TSProfile.pass_tickets
	TSProfile._apply_reward(TSProfile.battle_pass_free_reward(12, 2))
	_check("claiming that tier gives the ticket", TSProfile.pass_tickets == had + 1)
	# Collect All: every reached tier, both tracks; every finished quest.
	TSProfile.battle_pass_free_claimed.fill(false)
	TSProfile.battle_pass_paid_claimed.fill(false)
	TSProfile.battle_pass_purchased = true
	TSProfile.battle_pass_xp = TSProfile.battle_pass_stars_for_tier(4)
	var got := TSProfile.claim_all_battle_pass()
	_check("Collect All takes 4 tiers on both tracks (%d)" % got, got == 8 and not TSProfile.has_claimable_battle_pass_reward())
	_check("and again finds nothing", TSProfile.claim_all_battle_pass() == 0)
	TSProfile.daily_quest_rows()   # rolls the day
	for i in TSProfile.quest_daily_done.size():
		TSProfile.quest_daily_done[i] = true
		TSProfile.quest_daily_claimed[i] = false
	var quests := TSProfile.claim_all_quests()
	_check("Collect All takes every finished quest (%d)" % quests, quests == TSProfile.quest_daily_done.size() and not TSProfile.has_unclaimed_daily_quests())
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
