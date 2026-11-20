# Lifetime memberships (TSProfile.MEMBERSHIPS): buying one pays its bundle once
# and can't be bought again; Coin Club adds 5% to win coins, Material Club 5% to
# win materials, Time Saver takes 10% off builds and chest unlocks; each sends
# its daily gift by mail, once a day, and the store sees each as owned.
# Run with:
#   Godot.exe --headless --path . res://tests/membership_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSProfile.memberships = []
	var win_coins := TSProfile.win_coin_payout(3, 0)
	var win_mats := TSProfile.win_materials(false)
	var build := TSProfile.part_build_seconds(0)
	var chest_cut := TSChests.timer_discount_percent()
	_check("no membership mail without a membership", TSInbox.member_gifts().is_empty())

	# Coin Club: 40,000 coins, +5% on win coins, 1,000 coins a day by mail.
	var coins := TSProfile.coin_count
	Billing.purchase("egg_member_coins")
	_check("Coin Club pays 40,000 coins once", TSProfile.has_membership("coins") and TSProfile.coin_count == coins + 40000)
	Billing.purchase("egg_member_coins")
	_check("and can't be bought twice", TSProfile.coin_count == coins + 40000)
	_check("it adds 5%% to win coins (%d -> %d)" % [win_coins, TSProfile.win_coin_payout(3, 0)], TSProfile.win_coin_payout(3, 0) == roundi(win_coins * 1.05))
	var gift: Array = TSInbox.member_gifts()
	_check("its daily gift is in the mail", gift.size() == 1 and int(gift[0]["rewards"].get("coins", 0)) == 1000 and TSInbox.active().any(func(m: Dictionary) -> bool: return m["id"] == gift[0]["id"]))
	coins = TSProfile.coin_count
	TSInbox.claim(gift[0])
	_check("collecting it gives 1,000 coins", TSProfile.coin_count == coins + 1000)
	_check("once a day", not TSInbox.active().any(func(m: Dictionary) -> bool: return str(m["id"]).begins_with("member-coins")))

	# Material Club: 4,000 materials, +5% on win materials, 500 a day.
	var mats := TSProfile.materials
	Billing.purchase("egg_member_materials")
	_check("Material Club pays 4,000 materials", TSProfile.has_membership("materials") and TSProfile.materials == mats + 4000)
	_check("and adds 5%% to win materials (%d -> %d)" % [win_mats, TSProfile.win_materials(false)], TSProfile.win_materials(false) == roundi(win_mats * 1.05))

	# Time Saver: 1,000 time skips, builds and chests 10% faster, 50 skips a day.
	var skips := TSProfile.time_skips
	Billing.purchase("egg_member_time")
	_check("Time Saver gives 1,000 time skips", TSProfile.has_membership("time") and TSProfile.time_skips == skips + 1000)
	_check("builds take 10%% less (%d -> %d s)" % [build, TSProfile.part_build_seconds(0)], TSProfile.part_build_seconds(0) == roundi(build * 0.9))
	_check("chests unlock 10%% faster (%d%% -> %d%% off)" % [chest_cut, TSChests.timer_discount_percent()], TSChests.timer_discount_percent() == chest_cut + 10)
	var daily: Array = TSInbox.member_gifts()
	_check("Material Club and Time Saver mail too (%d gifts)" % daily.size(), daily.size() == 3 and daily.any(func(m: Dictionary) -> bool: return int(m["rewards"].get("skips", 0)) == 50) and daily.any(func(m: Dictionary) -> bool: return int(m["rewards"].get("materials", 0)) == 500))

	# Restoring on a new install: owned, and the bundle isn't paid again here.
	_check("the store sees them as owned", Billing.owns("egg_member_coins") and Billing.owns("egg_member_materials") and Billing.owns("egg_member_time"))

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
