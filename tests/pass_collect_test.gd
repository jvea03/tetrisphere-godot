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
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
