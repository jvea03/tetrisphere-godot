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
	# `-- probe 16,23 8 24`: for each level, the casual bot's win rate, drops a
	# win takes and hearts lost a play on its
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
	# `-- journey 1 30 40`: levels 1-30 as shipped (their baked or seeded
	# eggs), each played 40 times by the casual bot -- the early curve, with
	# less noise than the full run's 12 plays a level.
	if args.size() >= 3 and args[0] == "journey":
		var line := ""
		for lvl in range(int(args[1]), int(args[2]) + 1):
			line += "%2d %s %3d%%    " % [lvl, "BIHXE"[TSLevels.difficulty_for_level(lvl)], roundi(100.0 * _level(lvl, CASUAL, int(args[3]) if args.size() > 3 else 40))]
			if lvl % 5 == 0:
				print(line)
				line = ""
		if line != "":
			print(line)
		quit()
		return
	# `-- early 1 10 40`: levels A to B in detail, for both bots -- win rate,
	# drops a win takes, hearts lost -- the first-session view.
	if args.size() >= 3 and args[0] == "early":
		print("lvl tier | careful: won drops hearts | casual: won drops hearts")
		for lvl in range(int(args[1]), int(args[2]) + 1):
			var row := "%3d  %s   |" % [lvl, "BIHXE"[TSLevels.difficulty_for_level(lvl)]]
			for bot in [CAREFUL, CASUAL]:
				var wins := 0
				var drops := 0
				var lost := 0
				var n := int(args[3]) if args.size() > 3 else 40
				for i in n:
					var board := TSBoard.new()
					var baked := TSLevels.baked_board(lvl)
					if baked.is_empty():
						board.generate(TSLevels.seed_for_level(lvl), TSLevels.rules_for_level(lvl))
					else:
						board.load_dict(baked)
					var rng := RandomNumberGenerator.new()
					rng.seed = lvl * 7919 + i
					var r := _play(board, TSLevels.difficulty_for_level(lvl), TSLevels.rules_for_level(lvl), rng, bot)
					if bool(r["win"]):
						wins += 1
						drops += int(r["drops"])
					lost += int(r["lost"])
				row += "  %4d%%  %5.1f  %4.2f      |" % [roundi(100.0 * wins / n), float(drops) / maxi(wins, 1), float(lost) / n]
			print(row)
		quit()
		return
	# `-- challenge 6 40`: the first 6 challenge levels (TSLevels.challenge_rules),
	# each played 40 times by both bots -- win rate and the drops a win takes
	# (against the clock: a player drops every few seconds).
	if args.size() >= 2 and args[0] == "challenge":
		print("after | careful: won drops hearts | casual: won drops hearts")
		var slots := [TSLevels.CHALLENGE_TUTORIAL_AFTER]
		for k in int(args[1]):
			slots.append(TSLevels.CHALLENGE_FIRST_AFTER + k * TSLevels.CHALLENGE_EVERY)
		for after in slots:
			var rules := TSLevels.challenge_rules(after)
			var row := "%5d |" % after
			for bot in [CAREFUL, CASUAL]:
				var wins := 0
				var drops := 0
				var lost := 0
				var n := int(args[2]) if args.size() > 2 else 40
				var egg := TSBoard.new()
				egg.generate(TSLevels.challenge_seed(after), rules)
				for i in n:
					var rng := RandomNumberGenerator.new()
					rng.seed = after * 7919 + i
					var r := _play(egg.clone(), TSLevels.challenge_tier(after), rules, rng, bot)
					lost += int(r["lost"])
					if bool(r["win"]):
						wins += 1
						drops += int(r["drops"])
				row += "  %4d%%  %5.1f  %4.2f      |" % [roundi(100.0 * wins / n), float(drops) / maxi(wins, 1), float(lost) / n]
			print(row)
		quit()
		return
	# `-- ramp 8`: the slow ramp past level 50 (TSLevels.ramp_step) -- for every
	# other step, one full loop of tiers at that step, each level played 8 times
	# by both bots, as average win rates per tier.
	if args.size() >= 1 and args[0] == "ramp":
		_ramp(int(args[1]) if args.size() > 1 else 8)
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
			var drops := 0
			var lost := 0
			for i in trials:
				var rng := RandomNumberGenerator.new()
				rng.seed = lvl * 7919 + i
				var r := _play(egg.clone(), TSLevels.difficulty_for_level(lvl), rules, rng, CASUAL)
				lost += int(r["lost"])
				if bool(r["win"]):
					wins += 1
					drops += int(r["drops"])
			# win rate / drops a win takes / hearts lost a play
			line += "  +%d:%3d%%/%.1f/%.2f" % [shift, roundi(100.0 * wins / trials), float(drops) / maxi(wins, 1), float(lost) / trials]
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
	var bias := float(rules.get("common_bias", d["common_bias"]))
	var pieces: Array = rules["pieces"]
	var dealt: Array = []
	var next := _sim_deal(board, pieces, bias, rng, dealt)
	var misses := 0
	for turn in range(1, TURN_CAP + 1):
		var type_id := next
		next = _sim_deal(board, pieces, bias, rng, dealt)
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


## The game's deal (game.gd _deal): never one piece more than
## TSBoard.MAX_DEAL_RUN times running.
func _sim_deal(board: TSBoard, pieces: Array, bias: float, rng: RandomNumberGenerator, dealt: Array) -> int:
	var kind := board.deal_piece(pieces, bias, rng, TSBoard.deal_avoid(dealt))
	dealt.append(kind)
	if dealt.size() > TSBoard.MAX_DEAL_RUN:
		dealt.pop_front()
	return kind


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
		# ...cuts the vines before they spread...
		s += (board.vined.size() - probe.vined.size()) * 50
		if int(res.get("vine_grew", TSBoard.HOLE)) != TSBoard.HOLE:
			s -= 40
		# ...and digs down to the key, then pops it.
		if board.key_piece != TSBoard.HOLE:
			s += 300 if probe.key_piece == TSBoard.HOLE else (_cover(board, board.key_piece) - _cover(probe, probe.key_piece)) * 30
		if bool(res["overload"]):
			s -= 500
		if s > best_score:
			best_score = s
			best = at
	return best


## How many blocks sit above piece `id`, over all its cells.
func _cover(board: TSBoard, id: int) -> int:
	if not board.plate_cols.has(id):
		return 0
	var n := 0
	for col in board.plate_cols[id]:
		var v: Vector2i = col
		var stack: Array = board.cells[v.x][v.y]
		for above in range(stack.find(id) + 1, stack.size()):
			if int(stack[above]) != TSBoard.HOLE:
				n += 1
	return n


func _ramp(trials: int) -> void:
	print("step  first level | careful  I    H    X    E   all | casual  I    H    X    E   all")
	for step in range(0, TSLevels.RAMP_STEPS + 1, 2):
		var first := TSLevels.LEVEL_LOOP_START + step * TSLevels.RAMP_EVERY
		var rates := {CAREFUL: {}, CASUAL: {}}
		for bot in [CAREFUL, CASUAL]:
			for lvl in range(first, first + TSLevels.LEVEL_LOOP_TEMPLATE.size()):
				var t := TSLevels.difficulty_for_level(lvl)
				if not rates[bot].has(t):
					rates[bot][t] = []
				rates[bot][t].append(_level(lvl, bot, trials))
		var line := "%4d  %5d       |" % [step, first]
		for bot in [CAREFUL, CASUAL]:
			line += "        " if bot == CAREFUL else " |       "
			var all := 0.0
			var n := 0
			for t in [1, 2, 3, 4]:
				var rs: Array = rates[bot].get(t, [])
				var sum := 0.0
				for r in rs:
					sum += r
				all += sum
				n += rs.size()
				line += " %3d%%" % roundi(100.0 * sum / maxf(rs.size(), 1))
			line += " %3d%%" % roundi(100.0 * all / maxf(n, 1))
		print(line)
