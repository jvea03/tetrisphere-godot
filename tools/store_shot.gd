# Renders one App Store / Play screenshot from the game at an exact pixel size.
# macOS clamps windows to the display, so a 1290 x 2796 capture can't come from
# the window: the screen is instanced into an off-screen SubViewport of that size
# (with the project's canvas_items / expand stretch applied by hand), a PNG is
# written, and Godot quits. A throwaway profile is used and never saved.
# Run (see tools/ios-screenshots.sh, which runs the whole set):
#   Godot --path . res://tools/store_shot.tscn -- --scene=home --size=1290x2796 --out=/abs/home.png
# --scene=<name>  a screen in res://scenes, or an overlay: pause, lose, timeup (a challenge's), bomb_empty,
#                 swap_empty, rocks_empty (over the game), settings (over Home);
#                 a screen in res://scenes (home, shop, collection, battle_pass,
#                 hunt, streak ...), `game` (a level part way dug) or `win`
#                 (the same level's win card)
# --level=<n>     the level for game / win (default 12)
# --drops=<n>    greedy drops played before a game / win shot (default 6, which
#                 clears the level; tests/demo.gd reads it)
# --fresh        first-visit walkthroughs not yet seen (Collection, Home)
# --advance=<n>  press Next n times on the first-visit walkthrough (with --fresh)
# --wait=<s>      seconds to let animations settle (default 1.5)
# --date=<Y-M-D> pretend it is that day: a later Battle Pass season, say
# --planet=<theme> the critters' planet dressed for a season: christmas, newyear...
# --crashed      Home with the ship as it crash-landed: no part fixed or built
# --built        Home with every camp and ship part built to the top
# --collected=<n> the first n critters collected (a fuller Collection)
# --streak=<n>   on a win streak of n wins
# --release      as players see it: features the editor switches on early stay off
# --challenge    a challenge level waiting (one sits behind --level, e.g. 41)
# Over Home: camp (its info card), mine (a haul, and the ad to double it),
# chest_skip (an unlocking chest's card), build (a build under way). And
# streak_double: Daily Streaks with today's login coins claimed.
extends Node

var _date_offset := 0.0   # --date: kept in place every frame, as the network clock sync would undo it


func _process(_delta: float) -> void:
	if _date_offset != 0.0:
		TSClock.offset = _date_offset


func _ready() -> void:
	var scene_name := "home"
	var out := ""
	var level := 12
	var wait := 1.5
	var fresh := false
	var advance := 0
	var planet := ""
	var home_zoom := 0.0
	var size := Vector2i(1290, 2796)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_name = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--drops="):
			pass   # read by tests/demo.gd from the same command line
		elif a == "--fresh":
			fresh = true
		elif a.begins_with("--advance="):
			advance = int(a.substr(10))
		elif a.begins_with("--wait="):
			wait = float(a.substr(7))
		elif a.begins_with("--zoom="):   # Home zoomed (a pinch): 0.7 to 1.6
			home_zoom = float(a.substr(7))
		elif a.begins_with("--planet="):   # the planet dressed for this season (TSShipScene.THEMES)
			planet = a.substr(9)
		elif a.begins_with("--date="):   # pretend it is this day (UTC noon): a future season, sale...
			_date_offset = Time.get_unix_time_from_datetime_string(a.substr(7) + "T12:00:00") - Time.get_unix_time_from_system()
			TSClock.offset = _date_offset
		elif a.begins_with("--level="):
			level = int(a.substr(8))
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	if out == "":
		printerr("usage: --scene=<name> --size=WxH --out=<abs>.png")
		get_tree().quit(1)
		return
	_profile(level)
	if OS.get_cmdline_user_args().has("--crashed"):   # the ship as it lands: nothing fixed, nothing built
		for i in TSProfile.part_level.size():
			TSProfile.part_level[i] = 0
	if OS.get_cmdline_user_args().has("--built"):   # every part built to the top: no plus left on the camp
		for i in TSProfile.part_level.size():
			TSProfile.part_level[i] = TSProfile.PART_MAX_LEVEL
	if OS.get_cmdline_user_args().has("--challenge"):   # the challenge before --level is waiting
		TSProfile.challenge_done_through = 0
	if OS.get_cmdline_user_args().has("--release"):   # the tabs and features as players see them, not the editor
		TSNav.as_released = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--streak="):   # on a win streak of n
			TSProfile.win_streak = int(a.substr(9))
		if a.begins_with("--collected="):   # the first n critters collected, at mixed levels
			for i in mini(int(a.substr(12)), TSProfile.CRITTER_COUNT):
				if not TSProfile.is_critter_hidden(i):
					TSProfile.critter_unlocked[i] = true
					TSProfile.critter_level[i] = 1 + (i * 7) % 9
	if planet != "":
		TSProfile.planet_theme = planet
	if fresh:   # a brand-new player: the first-visit walkthroughs still to come
		TSProfile.collection_tutorial_seen = false
		TSProfile.home_tutorial_seen = false
		TSProfile.ship_story_seen = false
		TSProfile.collection_gift_claimed = false
		for i in TSProfile.CRITTER_COUNT:   # only the starter critter, as in a new game
			TSProfile.critter_unlocked[i] = i == 0
			TSProfile.critter_level[i] = 1 if i == 0 else 0
		TSProfile.avatar_critter = 0
		TSProfile.coin_count = 600
		TSChests.slots = [{}, {}, {}, {}]   # no chests yet: the Home walkthrough hands over the first
		TSChests.win_progress = 0
	var path := "res://scenes/%s.tscn" % scene_name
	var game_cards := ["pause", "lose", "timeup", "bomb_empty", "swap_empty", "rocks_empty"]
	var home_cards := ["settings", "camp", "mine", "chest_skip", "build"]
	if scene_name == "streak_double":
		TSProfile.claim_login_reward()
		path = "res://scenes/streak.tscn"
	if scene_name == "game" or scene_name == "win" or game_cards.has(scene_name):
		path = "res://tests/demo.tscn"   # the real game, six greedy drops in
	elif home_cards.has(scene_name):
		path = "res://scenes/home.tscn"
	var packed: PackedScene = load(path)
	if packed == null:
		printerr("FAILED_LOAD ", path)
		get_tree().quit(2)
		return
	var base_w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var base_h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var scale := minf(float(size.x) / base_w, float(size.y) / base_h)
	var sub := SubViewport.new()
	sub.size = size
	sub.size_2d_override = Vector2i(roundi(size.x / scale), roundi(size.y / scale))
	sub.size_2d_override_stretch = true
	sub.msaa_3d = Viewport.MSAA_4X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var inst: Node = packed.instantiate()
	sub.add_child(inst)
	Input.warp_mouse(Vector2(2, 2))   # keep hover states out of the picture
	# Wait in seconds, not frames: a big off-screen render runs slower than 60 fps.
	await get_tree().create_timer(wait).timeout
	for i in advance:   # step the walkthrough on (fresh shots)
		(inst.tutorial if "tutorial" in inst else inst._tutorial)._advance()
		await get_tree().create_timer(0.8).timeout
	if home_zoom > 0.0 and scene_name == "home":
		var w = inst._world
		w.zoom_at(home_zoom, w.get_global_rect().get_center())
		await get_tree().create_timer(0.6).timeout
	if scene_name == "win":
		inst._debug_win()
		await get_tree().create_timer(wait).timeout
	elif game_cards.has(scene_name) or home_cards.has(scene_name):
		match scene_name:   # the same hooks tests/card_capture.gd and menu_capture.gd use
			"pause": inst._open_pause()
			"lose":
				inst.lives = 0
				inst.lose_reason = "OUT OF LIVES"
				inst._lose()
			"timeup":   # a challenge's clock run out, a heart down (with --challenge)
				inst.lives = 2
				inst.lose_reason = "TIME'S UP"
				inst._lose()
			"bomb_empty":
				TSProfile.bomb_count = 0
				inst._toggle_bomb()
			"swap_empty":
				TSProfile.swap_count = 0
				inst._use_any_piece()
			"rocks_empty":
				TSProfile.rock_count = 0
				inst._fire_rocks()
			"settings": inst._open_settings()
			"camp": inst._on_camp_badge_pressed()
			"mine":
				TSProfile.mine_since = int(Time.get_unix_time_from_system()) - 4000
				inst._collect_mine()
			"chest_skip":
				TSChests.slots[0] = {"rarity": "rare", "unlock_end": TSChests._now() + 2400}
				inst._refresh_chest_tray()
				inst._open_skip(0)
			"build":
				TSProfile.materials = 100000
				TSProfile.coin_count = 900000
				for i in TSProfile.PART_COUNT:
					if TSProfile.part_build_block(i) == "" and TSProfile.start_part_build(i):
						TSProfile.part_builds[i]["end"] = int(Time.get_unix_time_from_system()) + 5000
						inst._open_part(i)
						break
		await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var err := sub.get_texture().get_image().save_png(out)
	if err != OK:
		printerr("FAILED_SAVE ", out, " err=", err)
		get_tree().quit(3)
		return
	print("SHOT_OK ", out)
	get_tree().quit(0)


# A mid-game profile like tests/menu_capture.gd's: everything unlocked, coins,
# chests, some critters, a Battle Pass part way up. Never saved.
func _profile(level: int) -> void:
	TSProfile.use_test_profile(level)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	# no Double Coins button on a win card in the store art: the day's ads are used up
	TSProfile.ad_rewards_date = TSClock.date_string()
	TSProfile.ad_rewards_used = {"win_coins": 99}
	TSProfile.camp_callout_seen = true
	TSProfile.collection_tutorial_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 48250
	TSProfile.bomb_count = 7
	for i in [1, 2, 4, 8, 11, 15]:
		TSProfile.critter_unlocked[i] = true
		TSProfile.critter_level[i] = 1 + i % 6
	TSProfile.avatar_critter = 8
	TSProfile.part_level = [4, 3, 2, 1, 1, 0, 2, 1, 0, 3, 0, 1, 1, 2, 1]
	TSProfile._fill_parts()
	TSProfile.materials = 1200
	TSProfile.time_skips = 12
	TSProfile.mine_since = int(Time.get_unix_time_from_system()) - 4000
	TSProfile.record_login()
	TSProfile.battle_pass_xp = 140
	TSProfile.add_stars(3, 2, 1)
	TSProfile.record_quest_event("win", 2)
	TSProfile.record_quest_event("clear", 45)
	TSChests.slots = [{"rarity": "rare", "unlock_end": int(Time.get_unix_time_from_system()) + 2400}, {"rarity": "common", "unlock_end": 0}, {}, {}]
	TSChests.win_progress = 2
	TSSales.roll()
	TSSales.mark_popup_shown()
