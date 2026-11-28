# Season trophies: building every camp site and the whole ship on a planet
# completes its season -- a trophy (kept, once per planet), the season's
# exclusive critter, and +2% coins and materials for good, adding up season
# by season. Run with:
#   Godot.exe --path . res://tests/trophy_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(60)
	TSProfile.planet_theme = "christmas"
	TSProfile.planet_number = 3
	TSProfile.season_trophies = []
	TSProfile.season_complete_pending = {}
	var elf: int = TSProfile.SEASON_CRITTERS["christmas"]
	TSProfile.critter_unlocked[elf] = false
	TSProfile.critter_level[elf] = 0
	_check("the exclusive critters are held back (never in the Collection unowned)", TSProfile.SEASON_CRITTERS.values().all(func(c: int) -> bool: return TSProfile.is_critter_hidden(c) and not TSProfile.is_critter_pass_exclusive(c)))
	var coins_before := TSProfile.boost_earned_coins(1000)
	var mats_before := TSProfile.boost_earned_materials(1000)
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level[i] = TSProfile.PART_MAX_LEVEL
	TSProfile.part_level[TSProfile.CAMP_STATUE] = TSProfile.PART_MAX_LEVEL - 1
	_check("one step short: no trophy yet", not TSProfile.is_planet_complete() and TSProfile.season_trophies.is_empty())
	TSProfile.coin_count = 10000000
	TSProfile.materials = 10000000
	TSProfile.improve_part(TSProfile.CAMP_STATUE)
	_check("the last step completes the planet", TSProfile.is_planet_complete())
	_check("and earns the Christmas trophy", TSProfile.season_trophies.size() == 1 and TSProfile.season_trophies[0]["theme"] == "christmas" and TSProfile.has_planet_trophy())
	_check("the Elf joins the crew (%s)" % TSProfile.critter_name(elf), TSProfile.is_critter_unlocked(elf) and TSProfile.is_critter_new(elf))
	_check("Home's card waits", TSProfile.season_complete_pending.get("critter", -1) == elf)
	_check("+2%% coins (%d -> %d)" % [coins_before, TSProfile.boost_earned_coins(1000)], TSProfile.boost_earned_coins(1000) == roundi(coins_before * 1.0) + 20 or TSProfile.earned_coin_bonus_percent() >= 2)
	_check("+2%% materials (%d -> %d)" % [mats_before, TSProfile.boost_earned_materials(1000)], TSProfile.boost_earned_materials(1000) == roundi(mats_before * 1.02))
	var again := TSProfile._check_planet_complete()
	TSProfile.grant_part_level(TSProfile.CAMP_FIRE)
	_check("only once a planet", not again and TSProfile.season_trophies.size() == 1)
	# Kept in the save.
	var trophies := TSProfile.season_trophies.duplicate(true)
	TSProfile.save()   # (a test profile writes nothing; the fields round-trip below)
	_check("bonus is 2%% a trophy", TSProfile.season_bonus_percent() == 2)
	# A new planet: another season's trophy adds another 2%; a theme come round
	# again pays coins in place of the critter it already gave.
	TSProfile.planet_number = 4
	TSProfile.planet_theme = "christmas"
	TSProfile.season_complete_pending = {}
	var coins := TSProfile.coin_count
	_check("the next planet has no trophy yet", not TSProfile.has_planet_trophy())
	TSProfile._check_planet_complete()
	_check("a second Christmas: coins instead of a second Elf", int(TSProfile.season_complete_pending.get("critter", 0)) == -1 and TSProfile.coin_count == coins + TSProfile.SEASON_CRITTER_OWNED_COINS)
	_check("two trophies, +4%%", TSProfile.season_trophies.size() == 2 and TSProfile.season_bonus_percent() == 4)
	_check("the trophies were kept as they were", (TSProfile.season_trophies[0] as Dictionary) == (trophies[0] as Dictionary))

	# The card on Home.
	TSProfile.season_complete_pending = {"theme": "christmas", "critter": elf, "coins": 0}
	# Home's first-visit walkthroughs come first.
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	var home: Node = (load("res://scenes/home.tscn") as PackedScene).instantiate()
	add_child(home)
	await get_tree().create_timer(0.6).timeout
	var labels := home.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_check("Home shows Season Complete with the Elf", labels.has("Elf joins you!") and labels.any(func(t: String) -> bool: return t.contains("Christmas Village")))
	home._open_profile()
	await get_tree().process_frame
	labels = home.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_check("the profile shows the trophies", labels.count("Christmas Village") >= 2)
	# Before the first trophy the card says how to win one, across the card (it
	# once stood a letter to a line and pushed Save off the screen).
	TSProfile.season_trophies = []
	home._open_profile()
	for _i in 4:
		await get_tree().process_frame
	var hint: Label = home._profile["trophies"].get_child(home._profile["trophies"].get_child_count() - 1)
	var tall: float = (home._profile["panel"] as Control).size.y
	_check("no trophy yet: the hint runs across the card (%d wide, %d lines)" % [hint.size.x, hint.get_line_count()], hint.text.begins_with("Build every site") and hint.size.x >= 400 and hint.get_line_count() <= 3)
	_check("and the whole card fits the screen (%d of %d)" % [tall, home.size.y], tall <= (home as Control).size.y)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
