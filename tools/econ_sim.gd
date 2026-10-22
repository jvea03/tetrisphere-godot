# Economy check: a free player's first DAYS days, played through the game's
# own reward and cost functions on a throwaway profile. Each day they log in,
# play ATTEMPTS levels (winning at about the casual bot's rate by tier, a bit
# better with boosters), open every chest, empty the mine twice, claim the
# Battle Pass's free tiers and the Eggsperience, then spend: camp and ship
# builds first (a few per builder a day -- builds take real time), coins left
# over on critters. Prints where coins and materials come from, where they go,
# and what holds the camp back. Run with:
#   Godot.exe --headless --path . --script res://tools/econ_sim.gd -- [days] [attempts] [ads]
extends SceneTree

const WIN_RATE := [0.95, 0.66, 0.51, 0.41, 0.3]   # by tier: tests/sim.gd's casual bot + boosters
const BUILDS_PER_BUILDER := 4                     # builds a critter gets through in a day of check-ins

var days := 60
var attempts := 15
var ads := false   # the player watches the Double Coins / mine / login ads
var rng := RandomNumberGenerator.new()
var income := {}
var spend := {}


func _add(book: Dictionary, key: String, n: int) -> void:
	book[key] = int(book.get(key, 0)) + n


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: days = int(a[0])
	if a.size() > 1: attempts = int(a[1])
	if a.size() > 2: ads = a[2] == "ads"
	rng.seed = 7
	TSProfile.use_test_profile(1)
	TSProfile.coin_count = 600   # a new game's purse
	TSProfile.materials = 0
	TSProfile.bomb_count = 0
	for i in TSProfile.CRITTER_COUNT:
		TSProfile.critter_unlocked[i] = i == 0
		TSProfile.critter_level[i] = 1 if i == 0 else 0
	TSProfile.part_level = []
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level.append(0)
	TSProfile.part_builds = {}
	TSChests.slots = [{}, {}, {}, {}]
	TSChests.win_progress = 0
	var start := TSClock.offset
	print("day level  coins  mats | camp ship critters | builds  blocked-by")
	for day in range(1, days + 1):
		TSClock.offset = start + day * 86400
		_play_day(day)
	print("\n== where coins came from (%d days) ==" % days)
	_book(income)
	print("== where coins went ==")
	_book(spend)
	print("== still to buy ==")
	var parts_left := 0
	var mats_left := 0
	for i in TSProfile.PART_COUNT:
		for l in range(TSProfile.part_level[i], TSProfile.PART_MAX_LEVEL):
			parts_left += roundi(int(TSProfile.PARTS[i]["fix"]) * (l + 1) * (TSProfile.CAMP_COIN_SCALE if TSProfile.is_camp(i) else TSProfile.SHIP_COIN_SCALE) / 10.0) * 10
			mats_left += _mats_at(i, l)
	var critters_left := 0
	for i in TSProfile.CRITTER_COUNT:
		if TSProfile.is_critter_hidden(i) or TSProfile.is_critter_pass_exclusive(i):
			continue
		if not TSProfile.is_critter_unlocked(i):
			critters_left += TSProfile.critter_unlock_cost(i)
	print("camp+ship: %s coins, %s materials; critters to unlock: %s coins" % [TSProfile.fmt_coins(parts_left), TSProfile.fmt_coins(mats_left), TSProfile.fmt_coins(critters_left)])
	TSClock.offset = start
	quit()


func _mats_at(i: int, lvl: int) -> int:
	var keep: int = TSProfile.part_level[i]
	TSProfile.part_level[i] = lvl
	var m := TSProfile.part_next_materials(i)
	TSProfile.part_level[i] = keep
	return m


func _book(book: Dictionary) -> void:
	var total := 0
	for k in book:
		total += int(book[k])
	var keys := book.keys()
	keys.sort_custom(func(x, y): return int(book[x]) > int(book[y]))
	for k in keys:
		print("  %-22s %9s  %3d%%" % [k, TSProfile.fmt_coins(int(book[k])), roundi(100.0 * int(book[k]) / maxf(total, 1))])
	print("  %-22s %9s" % ["total", TSProfile.fmt_coins(total)])


func _gain(key: String, before: int) -> void:
	_add(income, key, TSProfile.coin_count - before)


func _play_day(day: int) -> void:
	var c := TSProfile.coin_count
	TSProfile.record_login()
	TSProfile.claim_login_reward()
	_gain("login streak", c)
	if ads:
		c = TSProfile.coin_count
		TSProfile.double_login_reward()
		_gain("ads (login x2)", c)
	if day <= 7:   # the 7-Day Eggsperience
		_add(income, "eggsperience", TSHunt.DAY_REWARDS[day - 1])
		TSProfile.coin_count += TSHunt.DAY_REWARDS[day - 1]
	var doubles := 5 if ads else 0
	for n in attempts:
		var lvl := TSProfile.last_level
		var tier := TSLevels.difficulty_for_level(lvl)
		var first := not _tried.has(lvl)
		_tried[lvl] = true
		if rng.randf() > WIN_RATE[tier]:
			continue
		var lives: int = [1, 2, 2, 3, 3][rng.randi() % 5]
		c = TSProfile.coin_count
		TSProfile.add_stars(lives, 2 if first else 0, tier)
		var won := TSProfile.coin_count - c
		_add(income, "level wins", won)
		if doubles > 0:
			doubles -= 1
			TSProfile.coin_count += won
			_add(income, "ads (win x2)", won)
		TSProfile.add_materials(TSProfile.win_materials(false))
		TSChests.record_win()   # a chest only if a slot is free
		TSProfile.last_level = lvl + 1
	# Chests unlock one at a time, CHEST_HOURS a day of check-ins to start
	# the next; a long one carries its time over to tomorrow.
	_unlock_time += CHEST_HOURS * 3600
	while true:
		var next := -1
		for i in TSChests.SLOT_COUNT:
			if not TSChests.is_empty(i):
				next = i
				break
		if next < 0:
			_unlock_time = mini(_unlock_time, CHEST_HOURS * 3600)
			break
		var need := TSChests.unlock_seconds(TSChests.rarity_of(next))
		if _unlock_time < need:
			break
		_unlock_time -= need
		TSChests.slots[next]["unlock_end"] = 1
		c = TSProfile.coin_count
		TSChests.open(next)
		_gain("chests", c)
	# The mine, twice a day.
	for v in 2:
		TSProfile.mine_since = TSProfile._now_unix() - TSProfile.MINE_CAP_SECONDS
		TSProfile.collect_mine()
		if ads and v == 0:
			TSProfile.double_mine_haul()
	# The Battle Pass's free side.
	for t in range(1, TSProfile.battle_pass_tier() + 1):
		if TSProfile.can_claim_battle_pass_free(t):
			c = TSProfile.coin_count
			TSProfile.claim_battle_pass_free(t)
			_gain("battle pass (free)", c)
	# Spend: builds first, cheapest first, as builders and the day allow.
	var builds := 0
	var cap := TSProfile.builder_count() * BUILDS_PER_BUILDER
	var blocked := ""
	while builds < cap:
		var best := -1
		var best_cost := 1 << 40
		blocked = ""
		for i in TSProfile.PART_COUNT:
			var why := TSProfile.part_build_block(i)
			if why == "":
				if TSProfile.part_next_cost(i) < best_cost:
					best_cost = TSProfile.part_next_cost(i)
					best = i
			elif why == "materials" or why == "coins":
				blocked = why if blocked == "" or blocked == why else "both"
		if best < 0:
			break
		c = TSProfile.coin_count
		TSProfile.start_part_build(best)
		_add(spend, "camp & ship", c - TSProfile.coin_count)
		TSProfile.part_builds[best]["end"] = 0
		TSProfile.finish_part_build(best)
		builds += 1
	# Leftover coins on critters, keeping a build's worth in hand.
	var reserve := 3000
	while true:
		var pick := -1
		var cost := 1 << 40
		for i in TSProfile.CRITTER_COUNT:
			if TSProfile.is_critter_hidden(i) or TSProfile.is_critter_pass_exclusive(i):
				continue
			var k := TSProfile.critter_unlock_cost(i) if not TSProfile.is_critter_unlocked(i) else (TSProfile.critter_level_up_cost(i) if not TSProfile.is_critter_max_level(i) else 1 << 40)
			if k < cost:
				cost = k
				pick = i
		if pick < 0 or TSProfile.coin_count - cost < reserve:
			break
		c = TSProfile.coin_count
		if TSProfile.is_critter_unlocked(pick):
			TSProfile.level_up_critter(pick)
		else:
			TSProfile.unlock_critter(pick)
		_add(spend, "critters", c - TSProfile.coin_count)
	var owned := 0
	for i in TSProfile.CRITTER_COUNT:
		owned += 1 if TSProfile.is_critter_unlocked(i) else 0
	var ship := 0
	for i in TSProfile.PART_COUNT:
		if not TSProfile.is_camp(i) and TSProfile.part_level[i] >= 1:
			ship += 1
	if day <= 10 or day % 5 == 0:
		print("%3d %5d %7s %5d | %4d %4d %8d | %5d  %s" % [day, TSProfile.last_level, TSProfile.fmt_coins(TSProfile.coin_count), TSProfile.materials, TSProfile.camp_level(), ship, owned, builds, blocked])


var _tried := {}
var _unlock_time := 0
const CHEST_HOURS := 16   # waking hours a day a chest can be unlocking
