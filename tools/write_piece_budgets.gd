# Writes levels/piece_budgets.json (TSLevels.PIECE_BUDGETS) from the BUDGET
# lines `tests/sim.gd -- budget` prints, gathered in text files. A level the
# casual bot wins under LOW_WIN of the time has too few wins to set a budget
# by, so it gets at least the median budget of its tier. The sim is quick
# enough to split across cores, a range of levels each:
#   Godot --headless --path . --script res://tests/sim.gd -- budget 1 42 150 > b1.txt
#   ...
#   Godot --headless --path . --script res://tools/write_piece_budgets.gd -- b1.txt b2.txt ...
extends SceneTree

const LOW_WIN := 10   # percent


func _initialize() -> void:
	var rows := {}   # level -> [tier letter, base win %, budget]
	for path in OS.get_cmdline_user_args():
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			printerr("Can't read ", path)
			quit(1)
			return
		while not f.eof_reached():
			var parts := f.get_line().split(" ", false)
			# BUDGET <level> <tier> base <n>% budget <pieces> ...
			if parts.size() > 6 and parts[0] == "BUDGET" and parts[5] == "budget":
				rows[int(parts[1])] = [parts[2], int(parts[4].trim_suffix("%")), int(parts[6])]
	var by_tier := {}
	for lvl in rows:
		if int(rows[lvl][1]) >= LOW_WIN:
			if not by_tier.has(rows[lvl][0]):
				by_tier[rows[lvl][0]] = []
			by_tier[rows[lvl][0]].append(int(rows[lvl][2]))
	var median := {}
	for t in by_tier:
		var b: Array = by_tier[t]
		b.sort()
		median[t] = int(b[b.size() / 2])
	var levels := rows.keys()
	levels.sort()
	var out := {}
	var raised := 0
	for lvl in levels:
		var budget := int(rows[lvl][2])
		if int(rows[lvl][1]) < LOW_WIN and budget < int(median.get(rows[lvl][0], budget)):
			budget = int(median[rows[lvl][0]])
			raised += 1
		out[str(lvl)] = budget
	var w := FileAccess.open(TSLevels.PIECE_BUDGETS, FileAccess.WRITE)
	w.store_string(JSON.stringify(out, "", false) + "\n")
	w.close()
	print("PIECE_BUDGETS %d levels, %d to %d; tier medians %s; %d low-win levels raised to them" % [levels.size(), levels.front(), levels.back(), median, raised])
	quit()
