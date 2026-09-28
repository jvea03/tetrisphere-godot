# Headless checks for the menus' systems -- coins, chests, the Battle Pass,
# quests, streaks, the Egg Hunt, the collection, clubs, sales and purchases --
# on a throwaway profile that never touches the real save. Run with:
#   Godot.exe --headless --path . --script res://tests/meta_test.gd
extends SceneTree

var _failures := 0


func _initialize() -> void:
	TSProfile.use_test_profile(1)
	_test_wins_and_stars()
	_test_chests()
	_test_battle_pass()
	_test_quests()
	_test_streaks()
	_test_collection()
	_test_clubs()
	_test_hunt()
	_test_purchases()
	_test_levels()
	_test_boosters()
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _test_wins_and_stars() -> void:
	TSProfile.last_level = 3
	var before := TSProfile.coin_count
	var stars := TSProfile.add_stars(2, 2, 0)
	_check("before level 7 a win pays coins but no stars", stars == 0 and TSProfile.coin_count > before)
	TSProfile.last_level = 12
	var xp := TSProfile.battle_pass_xp
	before = TSProfile.coin_count
	stars = TSProfile.add_stars(3, 2, 0)
	_check("a win pays hearts left + bonus as stars (5)", stars == 5)
	_check("each star pays %d coins" % TSProfile.coins_per_star(), TSProfile.coin_count - before == 5 * TSProfile.coins_per_star() * (1.0 + TSProfile.collection_coin_bonus_percent() / 100.0))
	_check("stars climb the Battle Pass", TSProfile.battle_pass_xp == xp + 5)
	before = TSProfile.coin_count
	TSProfile.add_stars(1, 0, TSLevels.DIFF_EXTREME)
	_check("Extreme pays double", TSProfile.coin_count - before == 2 * TSProfile.coins_per_star())


func _test_chests() -> void:
	TSChests.slots = [{}, {}, {}, {}]
	TSChests.win_progress = 0
	TSChests.record_win()
	TSChests.record_win()
	var r := TSChests.record_win()
	_check("every 3rd win earns a chest (%s)" % r, r != "" and not TSChests.is_empty(0))
	_check("a new chest waits for a tap", not TSChests.is_unlocking(0) and not TSChests.is_ready(0))
	_check("its timer starts", TSChests.start_unlock(0) and TSChests.is_unlocking(0))
	TSChests.slots[1] = {"rarity": "common", "unlock_end": 0}
	_check("only one chest unlocks at a time without the pass", not TSChests.start_unlock(1))
	TSProfile.coin_count = 1000000
	var before := TSProfile.coin_count
	_check("a running chest can be finished for coins", TSChests.skip_unlock(0) and TSProfile.coin_count < before and TSChests.is_ready(0))
	before = TSProfile.coin_count
	var got := TSChests.open(0)
	_check("opening pays its coins (%d)" % int(got.get("coins", 0)), not got.is_empty() and TSProfile.coin_count - before == int(got["coins"]) and TSChests.is_empty(0))
	_check("the 4th slot is the pass's", not TSChests.slot_open(3))


func _test_battle_pass() -> void:
	TSProfile.last_level = 12
	TSProfile.battle_pass_xp = 0
	TSProfile.battle_pass_purchased = false
	TSProfile.battle_pass_free_claimed.fill(false)
	TSProfile.battle_pass_paid_claimed.fill(false)
	_check("tier 1 is free from the start", TSProfile.battle_pass_tier() == 1)
	var before := TSProfile.coin_count
	var r := TSProfile.claim_battle_pass_free(1)
	_check("claiming tier 1's free reward pays coins", not r.is_empty() and TSProfile.coin_count > before)
	_check("a reward is claimed once", TSProfile.claim_battle_pass_free(1).is_empty())
	_check("premium needs the pass", not TSProfile.can_claim_battle_pass_paid(1))
	TSProfile.battle_pass_xp = TSProfile.battle_pass_stars_for_tier(15)
	_check("tier 15 reached", TSProfile.battle_pass_tier() == 15)
	var season := TSProfile.season_rewards()
	var critter := int(season["free_critters"][15])
	TSProfile.claim_battle_pass_free(15)
	_check("tier 15 hands over a critter (%s)" % TSProfile.critter_name(critter), TSProfile.is_critter_unlocked(critter) and TSProfile.is_critter_new(critter))
	TSProfile.purchase_battle_pass()
	var bombs := TSProfile.bomb_count
	TSProfile.claim_battle_pass_paid(2)
	_check("premium tiers pay bombs", TSProfile.bomb_count > bombs)
	TSProfile.coin_count = 1000000
	var tier := TSProfile.battle_pass_tier()
	_check("a tier can be bought for coins", TSProfile.purchase_battle_pass_tier() and TSProfile.battle_pass_tier() == tier + 1)


func _test_quests() -> void:
	TSProfile.last_level = 12
	TSProfile.quest_daily_date = ""
	TSProfile.record_quest_event("clear", 30)
	var rows := TSProfile.daily_quest_rows()
	var clear_row: Dictionary = {}
	for q in rows:
		if q["stat"] == "clear":
			clear_row = q
	_check("clearing 30 pieces finishes the daily quest", bool(clear_row.get("done", false)))
	var xp := TSProfile.battle_pass_xp
	var got := TSProfile.claim_quest("", int(clear_row["index"]))
	_check("collecting it pays its stars into the pass (%d)" % got, got == int(clear_row["points"]) and TSProfile.battle_pass_xp == xp + got)
	_check("a quest is collected once", TSProfile.claim_quest("", int(clear_row["index"])) == -1)


func _test_streaks() -> void:
	TSProfile.login_streak_last_date = ""
	TSProfile.login_reward_claimed_date = ""
	TSProfile.record_login()
	_check("a first login starts the streak", TSProfile.login_streak_count == 1)
	var before := TSProfile.coin_count
	_check("today's login coins can be collected", TSProfile.claim_login_reward() > 0 and TSProfile.coin_count > before)
	_check("once a day", TSProfile.claim_login_reward() == 0)
	TSProfile.login_streak_last_date = TSProfile._yesterday_of(Time.get_date_string_from_system())
	TSProfile.login_streak_count = 6
	var bombs := TSProfile.bomb_count
	TSProfile.record_login()
	_check("the 7th day in a row pays %d bombs" % TSProfile.STREAK_REWARD_BOMBS, TSProfile.login_streak_count == 7 and TSProfile.bomb_count == bombs + TSProfile.STREAK_REWARD_BOMBS)


func _test_collection() -> void:
	TSProfile.coin_count = 1000000
	var lvl := TSProfile.collection_level()
	_check("buying a critter", TSProfile.unlock_critter(5) and TSProfile.is_critter_unlocked(5))
	_check("levelling it", TSProfile.level_up_critter(5) and TSProfile.critter_level_of(5) == 2)
	# The camp and the ship: every spot starts broken; the camp comes first.
	var all_broken := true
	for p in TSProfile.PART_COUNT:
		all_broken = all_broken and not TSProfile.is_part_fixed(p)
	_check("every camp spot and ship part starts broken", all_broken and TSProfile.parts_fixed() == 0 and TSProfile.PART_COUNT == 15 and TSProfile.camp_spot_count() == 6)
	_check("the ship waits for the camp: no fixing the engine yet", not TSProfile.is_ship_open() and not TSProfile.improve_part(TSProfile.PART_ENGINE))
	var coins := TSProfile.coin_count
	var build_cost := TSProfile.part_next_cost(TSProfile.CAMP_FIRE)
	_check("building the campfire costs %s" % TSProfile.fmt_coins(build_cost), TSProfile.improve_part(TSProfile.CAMP_FIRE) and TSProfile.part_stage(TSProfile.CAMP_FIRE, 1) == "Little Fire" and TSProfile.coin_count == coins - build_cost)
	_check("each upgrade costs one more multiple of the first step", TSProfile.part_next_cost(TSProfile.CAMP_FIRE) == build_cost * 2)
	for p in TSProfile.PART_COUNT:
		if TSProfile.is_camp(p):
			while TSProfile.improve_part(p):
				pass
	_check("finishing every camp spot (Lv %d) opens the ship" % TSProfile.CAMP_LEVEL_FOR_SHIP, TSProfile.camp_spots_done() == 6 and TSProfile.is_ship_open())
	var fix_cost := TSProfile.part_next_cost(TSProfile.PART_ENGINE)
	_check("then the engine can be fixed, for %s" % TSProfile.fmt_coins(fix_cost), TSProfile.improve_part(TSProfile.PART_ENGINE) and TSProfile.part_stage(TSProfile.PART_ENGINE, 1) == "Running")
	while TSProfile.improve_part(TSProfile.PART_ENGINE):
		pass
	_check("a part tops out at level %d (%s)" % [TSProfile.PART_MAX_LEVEL, TSProfile.part_stage(TSProfile.PART_ENGINE, TSProfile.PART_MAX_LEVEL)], TSProfile.part_level_of(TSProfile.PART_ENGINE) == TSProfile.PART_MAX_LEVEL and TSProfile.is_part_max_level(TSProfile.PART_ENGINE))
	var pass_part := TSProfile.battle_pass_paid_reward(30)
	_check("the Battle Pass's tier 30 is a free ship-part fix or upgrade", pass_part.has("part") and TSProfile.grant_part_level(TSProfile.PART_HULL) and TSProfile.part_level_of(TSProfile.PART_HULL) == 1)
	# The launch: every ship part fixed, at the season's end, once a season.
	_check("the ship isn't ready to launch with parts still broken", not TSProfile.is_ship_ready() and not TSProfile.can_launch())
	for p in TSProfile.PART_COUNT:
		if not TSProfile.is_camp(p) and not TSProfile.is_part_fixed(p):
			TSProfile.improve_part(p)
	TSProfile.launch_window_forced = false
	var window := TSProfile.is_launch_window()
	_check("every ship part fixed: ready, launching at the season's end (window open now: %s)" % window, TSProfile.is_ship_ready() and TSProfile.can_launch() == window)
	TSProfile.launch_window_forced = true
	var points := TSProfile.collection_points()
	var planet := TSProfile.planet_number
	var reward := TSProfile.launch_reward()
	var paid := TSProfile.launch_ship()
	_check("launching pays %s (more for upgrades)" % TSProfile.fmt_coins(reward), paid >= reward and reward > TSProfile.LAUNCH_REWARD_BASE)
	_check("and lands the critters on a new planet with a fresh camp and ship", TSProfile.planet_number == planet + 1 and TSProfile.parts_fixed() == 0 and not TSProfile.is_ship_open())
	_check("without the collection level dropping", TSProfile.collection_points() == points)
	_check("once a season", TSProfile.has_launched_this_season() and not TSProfile.can_launch())
	TSProfile.launch_window_forced = false
	for i in 8:
		TSProfile.level_up_critter(5)
	_check("the collection level rises with it (%d -> %d)" % [lvl, TSProfile.collection_level()], TSProfile.collection_level() > lvl)
	_check("a critter tops out at level %d" % TSProfile.CRITTER_MAX_LEVEL, not TSProfile.level_up_critter(5) and TSProfile.is_critter_max_level(5))
	_check("pass-only critters are marked", TSProfile.is_critter_pass_exclusive(19))
	TSProfile.set_avatar_critter(5)
	_check("an owned critter becomes the avatar", TSProfile.avatar() == 5)


func _test_clubs() -> void:
	TSProfile.leave_club()
	TSProfile.coin_count = 50000
	_check("a crude club name is refused", not TSProfile.is_valid_club_name("sh1t club"))
	_check("joining a club", TSProfile.join_club("Cozy Nest") and TSProfile.has_club and not TSProfile.club_is_owner)
	_check("its chat is seeded", TSProfile.club_chat.size() == 3)
	_check("its roster has the player as a Member", TSProfile.club_roster().any(func(m): return m["is_player"] and m["rank"] == TSProfile.RANK_MEMBER))
	_check("posting to chat", TSProfile.post_club_chat("hello friends") and TSProfile.club_chat.back()["is_player"])
	TSProfile.leave_club()
	var before := TSProfile.coin_count
	_check("founding a club costs %s coins" % TSProfile.fmt_coins(TSProfile.CLUB_CREATE_COST), TSProfile.create_club("Egg Friends", 3) and TSProfile.coin_count == before - TSProfile.CLUB_CREATE_COST and TSProfile.club_is_owner)
	_check("the club board lists the player's club", TSProfile.club_standings().any(func(e): return e["is_player"]))
	TSProfile.leave_club()


func _test_hunt() -> void:
	TSProfile.last_level = 12
	TSHunt.start_day = 0
	TSHunt.roll()
	_check("the Egg Hunt starts on day 1", TSHunt.start_day > 0 and TSHunt.today_day() == 1 and TSHunt.day_unlocked(1) and not TSHunt.day_unlocked(2))
	var before := TSProfile.coin_count
	TSProfile.coin_notices.clear()
	TSHunt.note_level_reached(TSHunt.goal_level(1, 0))
	TSProfile.record_quest_event("clear", 60)
	TSProfile.record_quest_event("booster", 1)
	_check("finishing day 1's quests pays its coins", TSHunt.day_claimed(1) and TSProfile.coin_count > before)
	_check("and lists them for the win card", TSProfile.coin_notices.size() == 1)


func _test_purchases() -> void:
	var billing := preload("res://scripts/meta/billing.gd").new()
	get_root().add_child(billing)
	var before := TSProfile.coin_count
	var bombs := TSProfile.bomb_count
	billing.purchase("bundle_value")
	_check("a bundle grants its coins and bombs (simulated store)", TSProfile.coin_count == before + 50000 and TSProfile.bomb_count == bombs + 11)
	_check("any purchase makes the player a payer", TSProfile.is_payer)
	before = TSProfile.coin_count
	billing.purchase(billing.NO_ADS)
	_check("the No Ads pass comes with %s coins" % TSProfile.fmt_coins(TSProfile.NO_ADS_PASS_COINS), TSProfile.no_ads and TSProfile.coin_count == before + TSProfile.NO_ADS_PASS_COINS)
	before = TSProfile.coin_count
	TSProfile.no_ads = false
	TSProfile.battle_pass_purchased = false
	var boosted := TSProfile.boost_earned_coins(1000)
	_check("earned coins are not boosted without a pass", boosted == 1000)
	TSProfile.no_ads = true
	_check("the No Ads pass boosts earned coins by %d%%" % TSProfile.no_ads_coin_bonus_percent(), TSProfile.boost_earned_coins(1000) == 1000 + 10 * TSProfile.no_ads_coin_bonus_percent())
	TSSales.fired = {}
	TSSales.active_id = ""
	TSProfile.last_level = 8
	_check("the level-8 sale starts on its own", TSSales.roll() and TSSales.current()["id"] == "starter_sprinkle")
	billing.purchase("popup_starter_sprinkle")
	_check("buying it ends it", TSSales.current().is_empty())
	billing.queue_free()


func _test_levels() -> void:
	# Duckdoku's curve, spot-checked against its level design sheet.
	var sheet := {1: 0, 6: 0, 7: 1, 9: 0, 15: 2, 22: 3, 25: 4, 30: 3, 37: 4, 46: 4, 50: 0, 51: 1, 54: 3, 56: 4, 61: 4, 70: 4}
	var wrong: Array = []
	for lvl in sheet:
		if TSLevels.difficulty_for_level(lvl) != sheet[lvl]:
			wrong.append(lvl)
	_check("the tiers follow Duckdoku's curve (wrong at %s)" % [wrong], wrong.is_empty())
	var loops := true
	for lvl in range(71, 131):
		loops = loops and TSLevels.difficulty_for_level(lvl) == TSLevels.difficulty_for_level(lvl - 20)
	_check("after level 70 the 51-70 stretch repeats", loops)
	var baked := true
	var sigs := {}
	for lvl in range(1, 51):
		var data := TSLevels.baked_board(lvl)
		baked = baked and not data.is_empty()
		var ball := TSBoard.new()
		ball.load_dict(data)
		sigs[ball.surface_signature()] = true
	_check("levels 1-50 are baked, and no two look alike, however turned (%d different)" % sigs.size(), baked and sigs.size() == 50)
	_check("51 on are generated", TSLevels.baked_board(51).is_empty())
	var b := TSBoard.new()
	b.load_dict(TSLevels.baked_board(12))
	var round_trip := b.to_dict()
	var src := TSLevels.baked_board(12)
	var same: bool = round_trip["kinds"].size() == src["kinds"].size()
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var a: Array = round_trip["cells"][c][r]
			var s: Array = src["cells"][c][r]
			same = same and a.size() == s.size()
			for k in mini(a.size(), s.size()):
				same = same and int(a[k]) == int(s[k])
	_check("a baked ball loads back exactly", same)
	var whole := true
	for id in b.plate_kind:
		var kind := int(b.plate_kind[id])
		whole = whole and (b.plate_cols[id] as Array).size() == (TSBoard.SHAPES[kind]["offsets"] as Array).size()
	_check("its pieces are whole", whole and b.initial_blocks > 0)
	_check("Beginner deals the two lines", TSLevels.rules_for_tier(0)["pieces"] == [TSBoard.I_FLAT, TSBoard.I_UPRIGHT])
	_check("Intermediate and Hard add the O square", TSLevels.rules_for_tier(1)["pieces"] == [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O] and TSLevels.rules_for_tier(2)["pieces"] == TSLevels.rules_for_tier(1)["pieces"])
	_check("Expert and Extreme add the plus on top", TSLevels.rules_for_tier(3)["pieces"] == [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O, TSBoard.PLUS] and TSLevels.rules_for_tier(4)["pieces"] == TSLevels.rules_for_tier(3)["pieces"])
	var own_pieces := true
	for lvl in range(1, TSLevels.LEVEL_PLAN.size() + 1):
		var ball := TSBoard.new()
		ball.load_dict(TSLevels.baked_board(lvl))
		var want: Array = TSLevels.rules_for_level(lvl)["pieces"]
		var found := {}
		for id in ball.plate_kind:
			found[int(ball.plate_kind[id])] = true
		for kind in found.keys():
			own_pieces = own_pieces and (want.has(kind) or kind == TSBoard.BLOCKER)
		for kind in want:
			own_pieces = own_pieces and found.has(int(kind))
	_check("every baked ball is built from exactly its level's pieces", own_pieces)
	_check("level 3 is only squares and upright lines; level 4 only flat lines and pluses", TSLevels.rules_for_level(3)["pieces"] == [TSBoard.O, TSBoard.I_UPRIGHT] and TSLevels.rules_for_level(4)["pieces"] == [TSBoard.I_FLAT, TSBoard.PLUS] and TSLevels.rules_for_level(5)["pieces"] == TSLevels.LINES)
	var pairs_ok := true
	var last_pair: Array = []
	for lvl in range(TSLevels.BEGINNER_MIX_FROM, TSLevels.LEVEL_PLAN.size() + 1):
		if TSLevels.difficulty_for_level(lvl) != 0:
			continue
		var pair: Array = TSLevels.rules_for_level(lvl)["pieces"]
		pairs_ok = pairs_ok and pair.size() == 2 and pair != last_pair
		last_pair = pair
	_check("Beginner levels from %d are two pieces each, never the same pair twice running" % TSLevels.BEGINNER_MIX_FROM, pairs_ok and TSLevels.rules_for_level(9)["pieces"] != TSLevels.LINES)
	var l_cells: Array = TSBoard.SHAPES[TSBoard.L]["offsets"]
	_check("the L is a capital L: a stem of three with a foot of three along the bottom", l_cells.size() == 5 and l_cells.has(Vector2i(0, 0)) and l_cells.has(Vector2i(1, 0)) and l_cells.has(Vector2i(2, 0)) and l_cells.has(Vector2i(0, 1)) and l_cells.has(Vector2i(0, 2)))
	var t_cells: Array = TSBoard.SHAPES[TSBoard.T]["offsets"]
	_check("the T is a capital T: a bar of three on top of a stem of two", t_cells.size() == 5 and t_cells.has(Vector2i(0, 2)) and t_cells.has(Vector2i(1, 2)) and t_cells.has(Vector2i(2, 2)) and t_cells.has(Vector2i(1, 1)) and t_cells.has(Vector2i(1, 0)))
	var mixes_ok := true
	var last_mix := {}
	var seen_l := false
	var seen_t := false
	for lvl in range(1, 71):
		var tier := TSLevels.difficulty_for_level(lvl)
		if not TSLevels.TIER_MIX.has(tier):
			continue
		var mix: Array = TSLevels.rules_for_level(lvl)["pieces"]
		var distinct := {}
		for k in mix:
			distinct[k] = true
			mixes_ok = mixes_ok and TSLevels.PIECE_POOL.has(k)
		mixes_ok = mixes_ok and distinct.size() == int(TSLevels.TIER_MIX[tier]) and mix != last_mix.get(tier, [])
		last_mix[tier] = mix
		seen_l = seen_l or mix.has(TSBoard.L)
		seen_t = seen_t or mix.has(TSBoard.T)
	_check("Hard levels mix 3 of the %d pieces, Expert and Extreme 4, never the same mix twice running" % TSLevels.PIECE_POOL.size(), mixes_ok and seen_l and seen_t)
	var first := TSBoard.new()
	first.load_dict(TSLevels.baked_board(1))
	var two_deep := first.shell_depth == 2 and first.largest_group() <= 2
	for column in first.cells:
		for stack in column:
			two_deep = two_deep and (stack as Array).size() == 2 and not (stack as Array).has(TSBoard.HOLE)
	var second := TSBoard.new()
	second.load_dict(TSLevels.baked_board(2))
	_check("level 1's egg is two full layers everywhere, with no ready-made match; level 2's is %d deep" % TSBoard.SHELL_DEPTH, two_deep and second.shell_depth == TSBoard.SHELL_DEPTH and second.clone().shell_depth == TSBoard.SHELL_DEPTH)
	_check("a generated level is always the same ball", TSLevels.seed_for_level(57) == TSLevels.seed_for_level(57) and TSLevels.seed_for_level(57) != TSLevels.seed_for_level(58))
	var d := TSLevels.daily_level()
	_check("the Daily Egg is never Beginner (level %d)" % d, TSLevels.difficulty_for_level(d) > 0)


# The three boosters: each arrives at its level with a starting stock, and the
# mid-game buy is the Shop's five-pack pro rata.
func _test_boosters() -> void:
	TSProfile.bombs_unlocked = false
	TSProfile.bomb_count = 0
	TSProfile.note_level_started(2)
	var none_yet := not TSProfile.bombs_unlocked
	TSProfile.note_level_started(TSProfile.BOMB_UNLOCK_LEVEL)
	_check("bombs arrive at level %d (where they are taught), not level 2" % TSProfile.BOMB_UNLOCK_LEVEL, none_yet and TSProfile.BOMB_UNLOCK_LEVEL == 3 and TSProfile.bombs_unlocked and TSProfile.bomb_count == TSProfile.BOMB_UNLOCK_GRANT)
	TSProfile.swaps_unlocked = false
	TSProfile.swap_count = 0
	TSProfile.rocks_unlocked = false
	TSProfile.rock_count = 0
	TSProfile.note_level_started(TSProfile.SWAP_UNLOCK_LEVEL - 1)
	_check("no Swap before level %d" % TSProfile.SWAP_UNLOCK_LEVEL, not TSProfile.swaps_unlocked and TSProfile.swap_count == 0)
	TSProfile.note_level_started(TSProfile.SWAP_UNLOCK_LEVEL)
	_check("the Swap arrives at level %d with %d" % [TSProfile.SWAP_UNLOCK_LEVEL, TSProfile.SWAP_UNLOCK_GRANT], TSProfile.swaps_unlocked and TSProfile.swap_count == TSProfile.SWAP_UNLOCK_GRANT and not TSProfile.rocks_unlocked)
	TSProfile.note_level_started(TSProfile.ROCKS_UNLOCK_LEVEL)
	_check("Rocks arrive at level %d with %d shots" % [TSProfile.ROCKS_UNLOCK_LEVEL, TSProfile.ROCKS_UNLOCK_GRANT], TSProfile.rocks_unlocked and TSProfile.rock_count == TSProfile.ROCKS_UNLOCK_GRANT)
	TSProfile.note_level_started(TSProfile.ROCKS_UNLOCK_LEVEL + 1)
	_check("and only once", TSProfile.rock_count == TSProfile.ROCKS_UNLOCK_GRANT and TSProfile.swap_count == TSProfile.SWAP_UNLOCK_GRANT)
	var fair := true
	for id in TSProfile.BOOSTERS:
		fair = fair and TSProfile.booster_buy_cost(id) * TSProfile.BOMB_PACK_AMOUNT == TSProfile.booster_pack_cost(id) * TSProfile.booster_buy_count(id)
	_check("every booster's mid-game buy is its pack pro rata", fair)
	TSProfile.add_boosters("rocks", -99)
	_check("spending can't go below zero", TSProfile.rock_count == 0)
