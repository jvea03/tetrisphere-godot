# Visual QA for the menus: sets up a throwaway profile far enough along that
# every feature is unlocked, with coins, chests, a club and some progress,
# then opens the screen named on the command line. Never touches the real
# save. Run with:
#   Godot.exe --path . res://tests/menu_capture.tscn -- home
# or `-- game 22` for the game screen on a given level, or `-- home all` for
# Home with every critter owned.
extends Node


func _ready() -> void:
	TSProfile.use_test_profile(30)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.collection_tutorial_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 48250
	TSProfile.bomb_count = 7
	for i in [1, 2, 4, 8, 11, 15]:
		TSProfile.critter_unlocked[i] = true
		TSProfile.critter_level[i] = 1 + i % 6
	TSProfile.avatar_critter = 8
	for i in [3, 9]:
		TSProfile.shell_unlocked[i] = true
		TSProfile.shell_level[i] = 2
	TSProfile.equipped_shell = 3
	TSProfile.record_login()
	TSProfile.battle_pass_xp = 140
	TSProfile.add_stars(3, 2, 1)
	TSProfile.record_quest_event("win", 2)
	TSProfile.record_quest_event("clear", 45)
	TSChests.slots = [{"rarity": "rare", "unlock_end": int(Time.get_unix_time_from_system()) + 2400}, {"rarity": "common", "unlock_end": 0}, {}, {}]
	TSChests.win_progress = 2
	TSSales.roll()
	TSSales.mark_popup_shown()
	var args := OS.get_cmdline_user_args()
	var screen: String = args[0] if args.size() > 0 else "home"
	if screen == "home" and args.size() > 1 and args[1] == "all":
		# `-- home all`: every critter owned, so the whole crash-site crew shows.
		for i in TSProfile.CRITTER_COUNT:
			TSProfile.critter_unlocked[i] = true
	if screen == "clubs_in":
		TSProfile.join_club("Sunny Side Up")
		screen = "clubs"
	if screen == "slide":
		get_tree().change_scene_to_file.call_deferred("res://scenes/home.tscn")
		get_tree().create_timer(0.6).timeout.connect(func(): SceneFlow.slide("res://scenes/shop.tscn", -1))
		return
	if screen == "game":
		# An optional level after it: `-- game 22` opens level 22's ball.
		if args.size() > 1:
			TSProfile.last_level = int(args[1])
		get_tree().change_scene_to_file.call_deferred(SceneFlow.GAME)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/%s.tscn" % screen)
