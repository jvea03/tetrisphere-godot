# Headless balance check. Part 1 plays generated balls at each of the five
# difficulty tiers; part 2 plays the level journey itself -- levels 1-70, the
# baked 1-50 and the generated loop after -- to show the win rate climbing
# and dipping the way Duckdoku's difficulty curve does. Two bots: a careful
# one that looks at 40 spots a drop, and a casual one that looks at 8 (a
# player who does not study the aim readout). A loss is running out of the
# three hearts, with no paid rescue. Run with:
#   Godot.exe --headless --path . --script res://tests/sim.gd
extends SceneTree

const TIER_TRIALS := 40
const JOURNEY_TRIALS := 12
const JOURNEY_LEVELS := 70
const TURN_CAP := 250
const CAREFUL := 40
const CASUAL := 8
const LIVES := 3


func _initialize() -> void:
	# `-- probe 16,23 8 24`: for each level, the casual bot's win rate on its
	# egg from each of the next 8 seeds (shift 0 is its own), over 24 plays --
	# to pick TSLevels.SEED_SHIFT for a level that plays as a wall.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "probe":
		var levels: Array = []
		for s in args[1].split(","):
			levels.append(int(s))
		_probe(levels, int(args[2]), int(args[3]) if args.size() > 3 else 24)
		quit()
		return
	print("==== tiers: win rate over %d generated balls each ====" % TIER_TRIALS)
	print("%-13s %-8s %-6s %-5s | %-26s | %-26s" % ["tier", "pieces", "hole", "deal", "careful: won  drops  hearts", "casual: won  drops  hearts"])
	for t in TSLevels.DIFFICULTIES.size():
		var d: Dictionary = TSLevels.DIFFICULTIES[t]
		var careful := _batch(t, CAREFUL, TIER_TRIALS, 1000)
		var casual := _batch(t, CASUAL, TIER_TRIALS, 1000)
		print("%-13s %-8s %dx%d   %3d%%  | %4d%%  %5.1f  %5.2f        | %4d%%  %5.1f  %5.2f" % [
			d["name"], "I I" + (" O" if (d["pieces"] as Array).has(TSBoard.O) else "") + (" +" if (d["pieces"] as Array).has(TSBoard.PLUS) else ""), d["escape_size"], d["escape_size"], roundi(d["common_bias"] * 100.0),
			roundi(careful["win"] * 100.0), careful["drops"], careful["lost"],
			roundi(casual["win"] * 100.0), casual["drops"], casual["lost"]])

	print("")
	print("==== the journey: casual bot, %d plays per level ====" % JOURNEY_TRIALS)
	var by_tier := {}
	var line := ""
	for lvl in range(1, JOURNEY_LEVELS + 1):
		var r := _level(lvl, CASUAL, JOURNEY_TRIALS)
		var t := TSLevels.difficulty_for_level(lvl)
		if not by_tier.has(t):
			by_tier[t] = []
		by_tier[t].append(r)
		line += "%2d %s %3d%%   " % [lvl, "BIHXE"[t], roundi(r * 100.0)]
		if lvl % 5 == 0:
			print(line)
			line = ""
	print("")
	for t in by_tier.keys():
		var rates: Array = by_tier[t]
		var total := 0.0
		for x in rates:
			total += x
		print("%-13s %2d levels, average win rate %3d%%" % [TSLevels.DIFFICULTIES[t]["name"], rates.size(), roundi(total / rates.size() * 100.0)])
	quit()


func _probe(levels: Array, shifts: int, trials: int) -> void:
	for lvl in levels:
		var rules := TSLevels.rules_for_level(lvl)
		var line := "%2d %s" % [lvl, "BIHXE"[TSLevels.difficulty_for_level(lvl)]]
		for shift in range(0, shifts + 1):
			var egg := TSBoard.new()
			egg.generate(TSLevels.shifted_seed(lvl, shift), rules)
			var wins := 0
			for i in trials:
				var rng := RandomNumberGenerator.new()
				rng.seed = lvl * 7919 + i
				if bool(_play(egg.clone(), TSLevels.difficulty_for_level(lvl), rules, rng, CASUAL)["win"]):
					wins += 1
			line += "  +%d:%3d%%" % [shift, roundi(100.0 * wins / trials)]
		print(line)


## Win rate on one level of the journey: its own ball (baked or seeded),
## played with different deals.
func _level(lvl: int, candidates: int, trials: int) -> float:
	var wins := 0
	for i in trials:
		var board := TSBoard.new()
		var baked := TSLevels.baked_board(lvl)
		if baked.is_empty():
			board.generate(TSLevels.seed_for_level(lvl), TSLevels.rules_for_level(lvl))
		else:
			board.load_dict(baked)
		var rng := RandomNumberGenerator.new()
		rng.seed = lvl * 7919 + i
		if bool(_play(board, TSLevels.difficulty_for_level(lvl), TSLevels.rules_for_level(lvl), rng, candidates)["win"]):
			wins += 1
	return float(wins) / float(trials)


func _batch(tier: int, candidates: int, trials: int, seed_base: int) -> Dictionary:
	var wins := 0
	var drops := 0
	var lost := 0
	for i in trials:
		var board := TSBoard.new()
		board.generate(seed_base + i, TSLevels.rules_for_tier(tier))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7777 + i
		var r := _play(board, tier, TSLevels.rules_for_tier(tier), rng, candidates)
		if r["win"]:
			wins += 1
			drops += int(r["drops"])
		lost += int(r["lost"])
	return {"win": float(wins) / trials, "drops": float(drops) / maxi(wins, 1), "lost": float(lost) / trials}


## One ball, played to a win or three misses, with the game's deal, fair deal
## and rules.
func _play(board: TSBoard, tier: int, rules: Dictionary, rng: RandomNumberGenerator, candidates: int) -> Dictionary:
	var d: Dictionary = TSLevels.DIFFICULTIES[tier]
	var escape := int(rules.get("escape_size", d["escape_size"]))
	var bias := float(d["common_bias"])
	var pieces: Array = rules["pieces"]
	var next := board.deal_piece(pieces, bias, rng)
	var misses := 0
	for turn in range(1, TURN_CAP + 1):
		var type_id := next
		next = board.deal_piece(pieces, bias, rng)
		if rules.get("fair_deal", false) and not board.has_combo_spot(type_id):
			for other in pieces:
				if int(other) != type_id and board.has_combo_spot(int(other)):
					type_id = int(other)
					break
		var at := _best_move(board, type_id, rng, candidates, escape)
		var res := board.place_and_resolve(TSBoard.SHAPES[type_id]["offsets"], at, type_id)
		board.resolve_geode_shots(res)   # a geode's rock lands at once here: no flight to show
		if int(res["pieces"]) == 0:
			misses += 1
		if board.has_escape(escape):
			return {"win": true, "drops": turn, "lost": misses}
		if misses >= LIVES or bool(res["overload"]):
			return {"win": false, "drops": turn, "lost": misses}
	return {"win": false, "drops": TURN_CAP, "lost": misses}


func _best_move(board: TSBoard, type_id: int, rng: RandomNumberGenerator, candidates: int, escape: int) -> Vector2i:
	var offsets: Array = TSBoard.SHAPES[type_id]["offsets"]
	var best := Vector2i(0, 0)
	var best_score := -999999
	for _i in candidates:
		var at := Vector2i(rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1))
		if not board.footprint_valid(offsets, at):
			continue
		var probe := board.clone()
		var res := probe.place_and_resolve(offsets, at, type_id)
		probe.resolve_geode_shots(res)
		var s := int(res["removed"]) * 10 + int(res["pieces"]) * 25 + int(probe.best_escape_patch(escape)["open"]) * 60
		# A player aims at the tie-downs: every layer knocked off is worth a lot.
		s += (board.tie_layers_left() - probe.tie_layers_left()) * 80
		if bool(res["overload"]):
			s -= 500
		if s > best_score:
			best_score = s
			best = at
	return best
