# Visual QA for the menus: sets up a throwaway profile far enough along that
# every feature is unlocked, with coins, chests, a club and some progress,
# then opens the screen named on the command line. Never touches the real
# save. Run with:
#   Godot.exe --path . res://tests/menu_capture.tscn -- home
# or `-- game 22` for the game screen on a given level (`-- game 10 ties` or
# `-- game 13 geodes` to see that lesson), or `-- home all` for
# Home with every critter owned (add `max` or `broken` for the ship's parts),
# or `-- settings` for Home's Settings pop-up. `-- home camp` glides Home to
# the camp's build nodes, `-- home ship` finishes the camp and glides to the
# ship's, and `-- home camp card` opens the tent's build card.
extends Node


static func args_has(a: String) -> bool:
	return OS.get_cmdline_user_args().has(a)


func _ready() -> void:
	if OS.get_environment("OUT") != "":
		# OUT=folder: saves shot.png there after a few seconds (or SHOT=name.png) and quits.
		var t0 := get_tree()
		t0.create_timer(3.0).timeout.connect(func():
			await RenderingServer.frame_post_draw
			t0.root.get_texture().get_image().save_png(OS.get_environment("OUT").path_join(OS.get_environment("SHOT") if OS.get_environment("SHOT") != "" else "shot.png"))
			t0.quit())
	TSProfile.use_test_profile(30)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = not args_has("callout")   # `-- home broken callout`: the first-visit camp pointer
	TSProfile.collection_tutorial_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 48250
	TSProfile.bomb_count = 7
	for i in [1, 2, 4, 8, 11, 15]:
		TSProfile.critter_unlocked[i] = true
		TSProfile.critter_level[i] = 1 + i % 6
	TSProfile.avatar_critter = 8
	# The camp and the ship, spot by spot -- `-- home all max` (or
	# `broken`) as the last argument sets every part to its best (or worst).
	# (The first wave part way up; the later waves not open yet.)
	TSProfile.part_level = [4, 3, 2, 1, 1, 0, 2, 1, 0, 3, 0, 1, 1, 2, 1]
	TSProfile._fill_parts()
	var args_all := OS.get_cmdline_user_args()
	var last_arg: String = args_all[-1] if args_all.size() > 0 else ""
	if args_all.has("lv"):
		# `-- home lv 2 at 19`: every camp spot at level 2, gliding to spot 19.
		var lv := int(args_all[args_all.find("lv") + 1])
		for i in TSProfile.PART_COUNT:
			TSProfile.part_level[i] = lv if TSProfile.is_camp(i) else 0
	TSProfile.materials = 1200
	TSProfile.time_skips = 12
	TSProfile.mine_since = int(Time.get_unix_time_from_system()) - (7200 if args_has("full") else 4000)   # the mine under the ship part full (`full`: full)
	if args_all.has("building"):
		# `-- home building camp`: a build counting down, and one done to collect.
		var now := int(Time.get_unix_time_from_system())
		TSProfile.part_builds = {TSProfile.CAMP_TENT: {"end": now + 95, "critter": 8}, TSProfile.CAMP_GARDEN: {"end": now - 5, "critter": 2}}
	if args_all.has("at"):
		var spot := int(args_all[args_all.find("at") + 1])
		var t := get_tree()
		t.create_timer(0.8).timeout.connect(func(): t.current_scene._world.glide_to_part(spot))
	if last_arg == "max" or args_all.has("max"):
		TSProfile.part_level = []
		for i in TSProfile.PART_COUNT:
			TSProfile.part_level.append(TSProfile.PART_MAX_LEVEL)
	elif last_arg == "broken" or args_all.has("broken"):
		TSProfile.part_level = []
		for i in TSProfile.PART_COUNT:
			TSProfile.part_level.append(0)
	elif last_arg == "ship":
		# The camp finished, so the ship's build nodes show; a few parts done.
		TSProfile.part_level = [4, 4, 4, 4, 4, 4, 2, 1, 0, 3, 0, 1, 0, 0, 1]
		TSProfile._fill_parts()
		for i in TSProfile.PART_COUNT:
			if TSProfile.is_camp(i):
				TSProfile.part_level[i] = TSProfile.PART_MAX_LEVEL
	if args_has("camp") or args_has("ship") or args_has("card"):
		# `-- home camp` glides to the camp's nodes (`ship`, the ship's);
		# `card` opens the tent's build card too.
		var tree := get_tree()
		var part := TSProfile.CAMP_TENT if not args_has("ship") else TSProfile.PART_HULL
		tree.create_timer(0.8).timeout.connect(func():
			tree.current_scene._world.glide_to_part(part)
			if args_has("card"):
				tree.current_scene._open_part(part))
	TSProfile.record_login()
	TSProfile.battle_pass_xp = 140
	TSProfile.add_stars(3, 2, 1)
	TSProfile.record_quest_event("win", 2)
	TSProfile.record_quest_event("clear", 45)
	TSChests.slots = [{"rarity": "rare", "unlock_end": int(Time.get_unix_time_from_system()) + 2400}, {"rarity": "common", "unlock_end": 0}, {}, {}]
	TSChests.win_progress = 2
	TSSales.roll()
	TSSales.mark_popup_shown()
	if args_has("midweek"):
		# `-- hunt midweek`: the Eggsperience on Day 3, Days 1 and 2 claimed.
		TSHunt.roll()
		TSHunt.start_day -= 2
		TSHunt.claimed[0] = true
		TSHunt.claimed[1] = true
	if args_has("claimed"):
		# `-- shop claimed`: today's free coins taken, so the pack offers its ads.
		TSProfile.roll_starter_claims()
		TSProfile.starter_coin_claims = 1
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
	if screen == "settings":
		# `-- settings`: Home with its Settings pop-up open.
		var tree := get_tree()   # this node is gone by the time the timer fires
		tree.change_scene_to_file.call_deferred("res://scenes/home.tscn")
		tree.create_timer(1.0).timeout.connect(func(): tree.current_scene._open_settings())
		return
	if screen == "game":
		# An optional level after it: `-- game 22` opens level 22's ball.
		if args.size() > 1:
			TSProfile.last_level = int(args[1])
		if args.size() > 2 and args[2] == "geodes":
			TSProfile.geode_tutorial_seen = false
		if args.size() > 2 and args[2] == "ties":
			TSProfile.tie_tutorial_seen = false
		get_tree().change_scene_to_file.call_deferred(SceneFlow.GAME)
		return
	if args_all.has("scroll"):
		# `-- shop scroll 1400`: the screen's list scrolled that far down.
		var px := int(args_all[args_all.find("scroll") + 1])
		var ts := get_tree()
		ts.create_timer(0.6).timeout.connect(func():
			for s in ts.current_scene.find_children("*", "ScrollContainer", true, false):
				(s as ScrollContainer).scroll_vertical = px)
	if args_has("players") or args_has("sticker") or args_has("got"):
		# `-- leaderboard players`: sample players on the boards (as if fetched);
		# `sticker` opens the second one's card, `got` shows stickers received.
		TSProfile.stickers_owned = ["jolly", "snowman", "gift", "cocoa"]
		var names := ["Sunny", "Pip", "Marshmallow", "Bean", "Clover", "Waffles", "Juniper", "Tofu"]
		for period in ["daily", "weekly", "season"]:
			var rows: Array = []
			for k in names.size():
				rows.append({"uid": "u%d" % k, "name": names[k], "avatar": [3, 11, 15, 22, 31, 40, 52, 8][k], "stars": (40 - k * 5) * (1 if period == "daily" else 4), "is_player": false})
			Online.boards[TSProfile.current_board(period)] = {"entries": rows, "at": Time.get_unix_time_from_system() + 9999}
		if args_has("got"):
			Online.received = [{"from": "u1", "name": "Pip", "avatar": 11, "sticker": "congrats"}, {"from": "u4", "name": "Clover", "avatar": 31, "sticker": "angry"}]
		if args_has("sticker"):
			var ts2 := get_tree()
			ts2.create_timer(0.8).timeout.connect(func():
				TSStickerCards.show_player(ts2.current_scene, Online.entries(TSProfile.current_board("daily"))[1], func(): pass))
	if args_has("profile"):
		# `-- home profile`: the Profile card, with some lifetime stats.
		TSProfile.lifetime = {"win": 42, "loss": 9, "flawless": 17, "stars": 186, "clear": 5230, "booster": 34, "daily_puzzle": 6, "chest": 12}
		TSProfile.lifetime_seconds = 3.0 * 3600.0 + 25.0 * 60.0
		TSProfile.win_streak_best = 8
		var tp := get_tree()
		tp.create_timer(0.8).timeout.connect(func(): tp.current_scene._open_profile())
	if args_has("inbox"):
		# `-- home inbox`: the inbox opened (empty on a test profile).
		var ti := get_tree()
		ti.create_timer(0.8).timeout.connect(func(): ti.current_scene._open_inbox())
	if args_has("fake"):
		# `-- leaderboard fake`: the editor's fake leaderboard, on this throwaway profile.
		Online.force_fake = true
	if args_has("bubble"):
		# `-- collection bubble`: the featured critter's speech bubble, as its picture is tapped.
		var tb := get_tree()
		tb.create_timer(1.0).timeout.connect(func(): tb.current_scene._say(tb.current_scene._sel_critter))
	if args_has("bottom"):
		# `-- shop bottom`: the screen's list scrolled to its end.
		var t := get_tree()
		t.create_timer(0.6).timeout.connect(func():
			for s in t.current_scene.find_children("*", "ScrollContainer", true, false):
				(s as ScrollContainer).scroll_vertical = 100000)
	get_tree().change_scene_to_file.call_deferred("res://scenes/%s.tscn" % screen)
