# Bakes levels 1-50 into res://levels/levels.json (TSLevels.LEVEL_BANK), the
# way Duckdoku bakes its first fifty boards: every player gets the same fifty
# balls, and they stay the same even if the generator changes later. Each
# ball comes from its level's seed (as a generated level would), and its
# surface -- what the player sees, however the ball is turned -- is
# checked against every other one; a lookalike rolls the next seed. Levels after
# 50 are generated live. Run with:
#   Godot.exe --headless --path . --script res://tools/bake_levels.gd
extends SceneTree


func _initialize() -> void:
	var out := {}
	var seen := {}
	for lvl in range(1, TSLevels.LEVEL_PLAN.size() + 1):
		var attempt := 0
		while true:
			var b := TSBoard.new()
			b.generate(TSLevels.seed_for_level(lvl) + attempt, TSLevels.rules_for_level(lvl))
			var entry := b.to_dict()
			var sig := b.surface_signature()
			if not seen.has(sig):
				seen[sig] = lvl
				out[str(lvl)] = entry
				print("level %2d: %-12s  %d pieces, %d%% grey on top, kinds %s" % [lvl, TSLevels.tier_name(lvl), b.plate_kind.size(), roundi(b.grey_share(true) * 100.0), str(b.piece_counts(TSLevels.rules_for_level(lvl)["pieces"]))])
				break
			print("level %d looked like level %d, rolling again" % [lvl, seen[sig]])
			attempt += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels"))
	var f := FileAccess.open(TSLevels.LEVEL_BANK, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("BAKED %d levels" % out.size())
	quit()
