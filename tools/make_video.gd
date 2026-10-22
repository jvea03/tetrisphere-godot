# Records a Google Ads video with Godot's Movie Maker: the real game playing
# itself (tools/video_game.gd) -- a level dug out and its critter rescued --
# under captions, then an end card (the key art's title and ship, "Play
# free!"). One run, one shape: portrait 720 x 1280 (the game full screen),
# landscape 1920 x 1080 or square 1080 x 1080 (the game on a phone beside the
# title). tools/make_videos.ps1 runs all three; by hand:
#   (override.cfg setting the window size, stretch off) then
#   Godot --path . --write-movie <out>.avi --fixed-fps 30 res://tools/make_video.tscn -- --shape=landscape
# --snaps=<dir> also saves a PNG at each beat, to check the cut without a player.
# For other cuts (tools/make_shorts.ps1): --level=<n> plays that level;
# --cap1= and --cap2= replace the two captions and --end= the end card's
# headline, with "|" for a line break.
extends Control

const ADS := preload("res://tools/make_ads.gd")
const GAME := preload("res://tools/video_game.gd")
const INK := Color(0.27, 0.16, 0.19)
const GAME_SIZE := Vector2i(720, 1280)
## Each shape is laid out at a design size like the images' and scaled to
## the window.
const DESIGN := {"portrait": Vector2(720, 1280), "landscape": Vector2(1200, 675), "square": Vector2(1200, 1200)}
var CAPTIONS := ["Can you free\nthe critter?", "Spin. Match.\nEscape!"]
var END_HEADLINE := "Can you save\nthem all?"
var _level := 8

var _shape := "portrait"
var _snaps := ""
var _art: Node
var _game: Node
var _stage: Control      # the design-size layer, scaled to the window
var _caption: Label
var _snap_n := 0
var _sub: SubViewport   # what the phone / full screen shows: the game, then Home's camp and the Collection


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shape="):
			_shape = a.substr(8)
		elif a.begins_with("--snaps="):
			_snaps = a.substr(8)
		elif a.begins_with("--level="):
			_level = int(a.substr(8))
		elif a.begins_with("--cap1="):
			CAPTIONS[0] = a.substr(7).replace("|", "\n")
		elif a.begins_with("--cap2="):
			CAPTIONS[1] = a.substr(7).replace("|", "\n")
		elif a.begins_with("--end="):
			END_HEADLINE = a.substr(6).replace("|", "\n")
	_art = ADS.new()
	_art.setup()
	var win := Vector2(get_viewport().get_visible_rect().size)
	size = win
	var design: Vector2 = DESIGN[_shape]
	_stage = Control.new()
	_stage.size = design
	_stage.scale = Vector2.ONE * minf(win.x / design.x, win.y / design.y)
	_stage.position = (win - design * _stage.scale.x) / 2.0
	add_child(_stage)
	# The game, in a viewport of its own at its native size.
	var sub := SubViewport.new()
	_sub = sub
	sub.size = GAME_SIZE
	sub.own_world_3d = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	_game = Node3D.new()
	_game.set_script(GAME)
	_game.video_level = _level
	sub.add_child(_game)
	if _shape == "portrait":
		_full_screen(sub.get_texture(), design)
	else:
		_beside_title(sub.get_texture(), design)
	TSSfx.music("level")
	_run()


## Portrait: the game is the whole frame; captions sit low over the hills.
func _full_screen(tex: Texture2D, design: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.size = design
	_stage.add_child(t)
	_caption = _label(64, Rect2(20, 820, design.x - 40, 200))


## Wide or square: the night sky, the title, a caption, and the game on a
## phone -- to the right when wide, under the caption when square.
func _beside_title(tex: Texture2D, design: Vector2) -> void:
	_art._sky(_stage, design)
	var wide := _shape == "landscape"
	var title_w := 560.0 if wide else 640.0
	var title_at := Vector2(40, 30) if wide else Vector2((design.x - title_w) / 2.0, 16)
	var tr: Rect2i = ADS.TITLE_RECT
	var title_h := title_w * tr.size.y / tr.size.x
	_art._sprite(_stage, _art._crop(tr), Rect2(title_at, Vector2(title_w, title_h)), 0.16)
	var phone: Rect2
	if wide:
		_caption = _label(54, Rect2(40, title_at.y + title_h + 20, title_w, 220))
		phone = Rect2(760, 20, 360, 640)
	else:
		_caption = _label(54, Rect2(40, title_h + 10, design.x - 80, 150))
		var top := title_h + 170.0
		var h := design.y - top - 20.0
		phone = Rect2((design.x - h * 9.0 / 16.0) / 2.0, top, h * 9.0 / 16.0, h)
	var frame := Panel.new()
	var face := StyleBoxFlat.new()
	face.bg_color = INK
	face.set_corner_radius_all(int(phone.size.x * 0.11))
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 18
	face.shadow_offset = Vector2(0, 10)
	frame.add_theme_stylebox_override("panel", face)
	frame.position = phone.position
	frame.size = phone.size
	_stage.add_child(frame)
	var pad := phone.size.x * 0.035
	var screen := Panel.new()
	var sface := StyleBoxFlat.new()
	sface.bg_color = Color.WHITE
	sface.set_corner_radius_all(int(phone.size.x * 0.085))
	screen.add_theme_stylebox_override("panel", sface)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	screen.position = Vector2(pad, pad)
	screen.size = phone.size - Vector2(pad, pad) * 2.0
	frame.add_child(screen)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = screen.size
	screen.add_child(t)
	# Two critters cheering it on.
	for k in 2:
		var left := k == 0
		var cs := phone.size.y * 0.24
		var c := TSIcon.make("critter", cs, [8, 4][k])
		c.size = Vector2(cs, cs)
		c.position = Vector2(phone.position.x - cs * 0.6 if left else phone.end.x - cs * 0.4, phone.position.y + phone.size.y * (0.66 if left else 0.28))
		c.pivot_offset = c.size / 2.0
		c.rotation = deg_to_rad(-12.0 if left else 12.0)
		_stage.add_child(c)


func _label(font_size: int, rect: Rect2) -> Label:
	var ls := LabelSettings.new()
	ls.font = TSToon.hand_font()
	ls.font_size = font_size
	ls.font_color = Color.WHITE
	ls.outline_size = int(font_size * 0.3)
	ls.outline_color = INK
	ls.line_spacing = -font_size * 0.12
	var l := Label.new()
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = rect.position
	l.size = rect.size
	l.pivot_offset = rect.size / 2.0
	l.modulate.a = 0.0
	_stage.add_child(l)
	return l


## A caption pops in (or out, with "").
func _say(text: String) -> void:
	var t := _caption.create_tween()
	if _caption.modulate.a > 0.0:
		t.tween_property(_caption, "modulate:a", 0.0, 0.15)
	if text == "":
		return
	t.tween_callback(func():
		_caption.text = text
		_caption.scale = Vector2(0.6, 0.6))
	t.set_parallel(true)
	t.tween_property(_caption, "modulate:a", 1.0, 0.18)
	t.tween_property(_caption, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(tag: String) -> void:
	if _snaps == "":
		return
	await RenderingServer.frame_post_draw
	_snap_n += 1
	get_viewport().get_texture().get_image().save_png("%s/%s_%02d_%s.png" % [_snaps, _shape, _snap_n, tag])


func _run() -> void:
	await _wait(0.1)
	_game.face_blocker()   # a blocker level opens on its blocker
	await _wait(0.2)
	_say(CAPTIONS[0])
	await _wait(0.8)
	_snap("hook")
	# Play until the egg is won, watching every frame: a quick level is won
	# in a few seconds, and the cut below must follow the win itself (a fixed
	# wait let a three-move level's win card into the video).
	_game.autoplay()
	var t := 0.0
	var second := false
	while _game.playing():
		await get_tree().process_frame
		t += get_process_delta_time()
		if not second and t >= 2.0:
			second = true
			_say(CAPTIONS[1])
		if second and t >= 3.0 and t - get_process_delta_time() < 3.0:
			_snap("play")
	# The critter shoots out of the egg -- cut before the win card lands
	# (it shows some 2.1 s after the win).
	_say("Critter saved!")
	await _wait(1.8)
	await _snap("win")
	await _showcase()
	await _end_card()
	get_tree().quit()


## After the level: the camp the critters are rebuilding, the world gliding
## past its spots, then the Collection's critters scrolling by -- each under
## its own caption, in the same frame the game was in.
func _showcase() -> void:
	_game.queue_free()
	_showcase_profile()
	var home: Control = (load("res://scenes/home.tscn") as PackedScene).instantiate()
	_sub.add_child(home)
	_say("Rebuild your camp!")
	await _wait(0.6)
	var world = home._world
	# Just the camp: Home's buttons, tray and bars put away for the shot.
	await get_tree().process_frame
	for c in home.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl != world and not ctl.is_ancestor_of(world) and not world.is_ancestor_of(ctl) and ctl.get_parent() != null \
				and (ctl.get_parent() == home or ctl.get_parent().is_ancestor_of(world) or ctl.get_parent() == world.get_parent()):
			ctl.visible = false
	for part in [TSProfile.PART_ENGINE, TSProfile.CAMP_WELL, TSProfile.CAMP_FIRE]:   # the ship, then on round the finished camp
		world.glide_to_part(part)
		await _wait(1.1)
	await _snap("camp")
	home.queue_free()
	var coll: Control = (load("res://scenes/collection.tscn") as PackedScene).instantiate()
	_sub.add_child(coll)
	_say("Collect cute\ncritters!")
	await _wait(0.5)
	var sc: ScrollContainer = coll._critter_scroll
	var t := sc.create_tween()
	t.tween_property(sc, "scroll_vertical", 260, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(1.4)
	await _snap("critters")
	await _wait(1.3)
	_say("")
	coll.queue_free()


## A player well into the game: the camp and ship fully upgraded,
## a crowd of critters to show off -- and no pop-ups or walkthroughs.
func _showcase_profile() -> void:
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSProfile.collection_tutorial_seen = true
	TSProfile.ship_story_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 48250
	TSProfile.materials = 2400
	var owned := [0, 1, 2, 4, 8, 11, 15, 20, 23, 24, 33, 40, 47, 51, 60, 66, 70, 75]
	for i in owned:
		if i < TSProfile.CRITTER_COUNT and not TSProfile.is_critter_pass_exclusive(i):
			TSProfile.critter_unlocked[i] = true
			TSProfile.critter_level[i] = 2 + i % 6
	TSProfile.part_level = []
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level.append(TSProfile.PART_MAX_LEVEL)   # every spot fully upgraded: no build markers over the camp
	TSProfile._fill_parts()
	TSProfile.part_builds = {}
	TSChests.slots = [{"rarity": "rare", "unlock_end": 0}, {"rarity": "common", "unlock_end": 0}, {}, {}]
	TSSales.roll()
	TSSales.mark_popup_shown()


## The end card: the images' "adventure" layout -- title, ship, headline and
## Play free! -- fading in over everything, the ship gliding in.
func _end_card() -> void:
	TSSfx.play("fanfare")
	var card := Control.new()
	var design: Vector2 = DESIGN[_shape]
	# Laid out at the images' width (narrower for a tall frame, so its words
	# stay big), then scaled into the frame.
	var w := 900.0 if _shape == "portrait" else 1200.0
	var s := Vector2(w, w * design.y / design.x)
	card.size = s
	var k := minf(size.x / s.x, size.y / s.y)
	card.scale = Vector2(k, k)
	card.position = (size - s * k) / 2.0
	card.modulate.a = 0.0
	add_child(card)
	var shape := "landscape" if _shape == "landscape" else ("square" if _shape == "square" else "portrait")
	_art._compose(card, {"headline": END_HEADLINE, "hero": "ship", "critters": []}, shape, s)
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.4)
	# The ship (the hero) glides in from the left.
	var ship := card.get_child(3) as Control   # _compose: sky, stars, title, then the hero
	if ship != null:
		var to := ship.position
		ship.position = to - Vector2(s.x * 0.5, -s.y * 0.05)
		card.create_tween().tween_property(ship, "position", to, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.4)
	_snap("end")
	await _wait(2.6)
