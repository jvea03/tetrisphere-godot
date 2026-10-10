# Renders one App Store / Play screenshot from the game at an exact pixel size.
# macOS clamps windows to the display, so a 1290 x 2796 capture can't come from
# the window: the screen is instanced into an off-screen SubViewport of that size
# (with the project's canvas_items / expand stretch applied by hand), a PNG is
# written, and Godot quits. A throwaway profile is used and never saved.
# Run (see tools/ios-screenshots.sh, which runs the whole set):
#   Godot --path . res://tools/store_shot.tscn -- --scene=home --size=1290x2796 --out=/abs/home.png
# --scene=<name>  a screen in res://scenes, or an overlay: pause, lose, bomb_empty,
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
extends Node


func _ready() -> void:
	var scene_name := "home"
	var out := ""
	var level := 12
	var wait := 1.5
	var fresh := false
	var advance := 0
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
	if fresh:   # a brand-new player: the first-visit walkthroughs still to come
		TSProfile.collection_tutorial_seen = false
		TSProfile.home_tutorial_seen = false
		TSProfile.collection_gift_claimed = false
		for i in TSProfile.CRITTER_COUNT:   # only the starter critter, as in a new game
			TSProfile.critter_unlocked[i] = i == 0
			TSProfile.critter_level[i] = 1 if i == 0 else 0
		TSProfile.avatar_critter = 0
		TSProfile.coin_count = 600
	var path := "res://scenes/%s.tscn" % scene_name
	var game_cards := ["pause", "lose", "bomb_empty", "swap_empty", "rocks_empty"]
	if scene_name == "game" or scene_name == "win" or game_cards.has(scene_name):
		path = "res://tests/demo.tscn"   # the real game, six greedy drops in
	elif scene_name == "settings":
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
		inst._tutorial._advance()
		await get_tree().create_timer(0.8).timeout
	if scene_name == "win":
		inst._debug_win()
		await get_tree().create_timer(wait).timeout
	elif game_cards.has(scene_name) or scene_name == "settings":
		match scene_name:   # the same hooks tests/card_capture.gd and menu_capture.gd use
			"pause": inst._open_pause()
			"lose":
				inst.lives = 0
				inst.lose_reason = "OUT OF LIVES"
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
