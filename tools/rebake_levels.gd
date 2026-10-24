# Rebakes only the levels named into res://levels/levels.json and leaves every
# other baked ball as it is -- after a level's rules or SEED_SHIFT change.
# Each comes from its level's seed as tools/bake_levels.gd makes it, rolling on
# while its surface looks like any other baked level's. Run with:
#   Godot.exe --headless --path . --script res://tools/rebake_levels.gd -- 1 2 7
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open(TSLevels.LEVEL_BANK, FileAccess.READ)
	var bank: Dictionary = _ints(JSON.parse_string(f.get_as_text()))
	f.close()
	var levels: Array = []
	for a in OS.get_cmdline_user_args():
		levels.append(int(a))
	# Every other level's surface, to keep the new eggs unlike them.
	var seen := {}
	for key in bank:
		if int(key) in levels:
			continue
		var b := TSBoard.new()
		b.load_dict(bank[key])
		seen[b.surface_signature()] = int(key)
	for lvl in levels:
		var attempt := 0
		while true:
			var b := TSBoard.new()
			b.generate(TSLevels.seed_for_level(lvl) + attempt, TSLevels.rules_for_level(lvl))
			var sig := b.surface_signature()
			if not seen.has(sig):
				seen[sig] = lvl
				bank[str(lvl)] = b.to_dict()
				print("level %2d: %-12s  %d pieces, kinds %s" % [lvl, TSLevels.tier_name(lvl), b.plate_kind.size(), str(b.piece_counts(TSLevels.rules_for_level(lvl)["pieces"]))])
				break
			print("level %d looked like level %d, rolling again" % [lvl, seen[sig]])
			attempt += 1
	f = FileAccess.open(TSLevels.LEVEL_BANK, FileAccess.WRITE)
	f.store_string(JSON.stringify(bank))
	f.close()
	print("REBAKED %s" % str(levels))
	quit()


## JSON reads every number back as a float; the bank holds ints.
func _ints(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Array:
		return (v as Array).map(_ints)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _ints(v[k])
		return d
	return v
