# The Battle Pass at a season's end: every tier reached but not claimed is
# collected for the player, from that season's own rewards (premium too if the
# pass was bought), once; what was claimed already isn't paid again, and Home's
# card has what came in.
# Run with:
#   Godot.exe --headless --path . res://tests/pass_collect_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


## The tiers ask 20% more stars than they did; stars banked before that keep
## their tier and their share of the next one.
func _test_dearer_tiers() -> void:
	var top := TSProfile.BATTLE_PASS_TIER_COUNT
	var now := TSProfile.battle_pass_stars_for_tier(top)
	var was := TSProfile.battle_pass_stars_for_tier(top, 100)
	_check("all %d tiers: %d stars, 20%% over %d" % [top, now, was], was == 1276 and absi(now - roundi(was * 1.2)) <= 3 and TSProfile.battle_pass_tier_cost(2) == 36)
	var kept := true
	var order := true
	var last := 0
	for xp in range(1, was + 120):
		var moved := TSProfile._rescaled_pass_xp(xp, 100)
		var old_tier := range(1, top + 1).filter(func(t: int) -> bool: return xp >= TSProfile.battle_pass_stars_for_tier(t, 100)).size()
		var new_tier := range(1, top + 1).filter(func(t: int) -> bool: return moved >= TSProfile.battle_pass_stars_for_tier(t)).size()
		kept = kept and new_tier == old_tier
		order = order and moved >= last
		last = moved
	_check("stars banked before keep their tier, and more never count for less", kept and order)
	_check("past the last tier the stars over it stay (the Bonus Chests)", TSProfile._rescaled_pass_xp(was + 75, 100) == now + 75)
	_check("stars banked at today's cost are left alone", TSProfile._rescaled_pass_xp(500, TSProfile.BATTLE_PASS_STAR_PERCENT) == 500)


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSProfile.no_ads = false
	TSProfile.battle_pass_tier()   # settle into this season first
	# Last season: reached tier 16, bought the pass, claimed only free tier 1.
	TSProfile.battle_pass_key = "S0-old"
	TSProfile.battle_pass_xp = TSProfile.battle_pass_stars_for_tier(16)
	TSProfile.battle_pass_purchased = true
	TSProfile.battle_pass_free_claimed.fill(false)
	TSProfile.battle_pass_paid_claimed.fill(false)
	TSProfile.battle_pass_free_claimed[0] = true
	TSProfile.battle_pass_auto_claimed = {}
	var season := maxi(1, TSProfile.battle_pass_season_number() - 1)
	var want := 0
	for t in range(1, 17):
		if t > 1:
			want += int(TSProfile.battle_pass_free_reward(t, season).get("coins", 0))
		want += int(TSProfile.battle_pass_paid_reward(t, season).get("coins", 0))
	var free_critter: int = (TSProfile.season_rewards(season)["free_critters"] as Dictionary).get(15, -1)
	TSProfile.critter_unlocked[free_critter] = false
	var coins := TSProfile.coin_count

	TSProfile.battle_pass_tier()   # anything touching the pass rolls the season
	var got: Dictionary = TSProfile.battle_pass_auto_claimed
	_check("the unclaimed coins came in (+%d of %d)" % [TSProfile.coin_count - coins, want], TSProfile.coin_count - coins == want and int(got.get("coins", 0)) == want)
	_check("the tier-15 critter too", TSProfile.is_critter_unlocked(free_critter) and (got.get("critters", []) as Array).has(free_critter))
	_check("the new season starts clean", TSProfile.battle_pass_xp == 0 and not TSProfile.battle_pass_purchased and not TSProfile.battle_pass_free_claimed.has(true))
	var after := TSProfile.coin_count
	TSProfile.battle_pass_tier()
	_check("and nothing is paid twice", TSProfile.coin_count == after)

	# Without the pass bought, only the free track.
	TSProfile.battle_pass_key = "S0-old"
	TSProfile.battle_pass_xp = TSProfile.battle_pass_stars_for_tier(2)
	TSProfile.battle_pass_purchased = false
	TSProfile.battle_pass_free_claimed.fill(false)
	TSProfile.battle_pass_auto_claimed = {}
	var free_only := int(TSProfile.battle_pass_free_reward(1, season).get("coins", 0)) + int(TSProfile.battle_pass_free_reward(2, season).get("coins", 0))
	coins = TSProfile.coin_count
	TSProfile.battle_pass_tier()
	_check("not bought: only the free track (+%d)" % (TSProfile.coin_count - coins), TSProfile.coin_count - coins == free_only)
	_test_dearer_tiers()
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
