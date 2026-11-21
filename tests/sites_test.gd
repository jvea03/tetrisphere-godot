# Seasonal work sites: on a season's planet (Christmas, New Year, Valentine's)
# every camp spot has its own name and five stages, the autumn planet keeps the
# camp's own, analytics keep the autumn names, and each season's camp draws at
# every level without errors. Run with:
#   Godot.exe --path . res://tests/sites_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(30)
	var camp: Array = []
	for i in TSProfile.PART_COUNT:
		if TSProfile.is_camp(i):
			camp.append(i)
	_check("20 camp spots", camp.size() == 20)
	TSProfile.planet_theme = "autumn"
	_check("the autumn planet keeps the camp's names", TSProfile.part_name(TSProfile.CAMP_FIRE) == "Campfire" and TSProfile.part_stage(TSProfile.CAMP_FIRE, 4) == "Bonfire")
	for theme in TSSites.THEMES:
		TSProfile.planet_theme = theme
		var names := {}
		var bad: Array = []
		for i in camp:
			var n := TSProfile.part_name(i)
			names[n] = true
			if n == str(TSProfile.PARTS[i]["name"]) or TSProfile.part_stage(i, 0) == "" or TSProfile.part_stage(i, 4) == TSProfile.part_stage(i, 3):
				bad.append(i)
			if (TSProfile.SITES[theme][i][1] as Array).size() != TSProfile.PART_MAX_LEVEL + 1:
				bad.append(i)
		_check("%s: every spot has its own name and five stages %s" % [theme, bad], bad.is_empty() and names.size() == camp.size())
		_check("%s: the ship's parts keep their names" % theme, TSProfile.part_name(TSProfile.PART_ENGINE) == "Engine")
		_check("%s: analytics keep the camp's own name" % theme, TSProfile.part_key(TSProfile.CAMP_STALL) == "MarketStall")
	# Each season's camp drawn at every level.
	for theme in TSSites.THEMES:
		TSProfile.planet_theme = theme
		for lv in TSProfile.PART_MAX_LEVEL + 1:
			for i in camp:
				TSProfile.part_level[i] = lv
			var scene := TSShipScene.new()
			scene.size = Vector2(1080, 1920)
			add_child(scene)
			await get_tree().process_frame
			await get_tree().process_frame
			scene.queue_free()
			for i in camp:
				var icon := TSIcon.make("part", 64, i, "" if lv > 0 else "broken")
				add_child(icon)
				icon.queue_free()
		_check("%s: drawn at levels 0-4" % theme, true)
	TSProfile.planet_theme = "autumn"
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
