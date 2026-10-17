# Records a Google Ads video with Godot's Movie Maker: the real game playing
# itself (tools/video_game.gd) -- a level dug out and its critter rescued --
# under captions, then an end card (the key art's title and ship, "Play
# free!"). One run, one shape: portrait 720 x 1280 (the game full screen),
# landscape 1920 x 1080 or square 1080 x 1080 (the game on a phone beside the
# title). tools/make_videos.ps1 runs all three; by hand:
#   (override.cfg setting the window size, stretch off) then
#   Godot --path . --write-movie <out>.avi --fixed-fps 30 res://tools/make_video.tscn -- --shape=landscape
# --snaps=<dir> also saves a PNG at each beat, to check the cut without a player.
extends Control

const ADS := preload("res://tools/make_ads.gd")
const GAME := preload("res://tools/video_game.gd")
const INK := Color(0.27, 0.16, 0.19)
const GAME_SIZE := Vector2i(720, 1280)
## Each shape is laid out at a design size like the images' and scaled to
## the window.
const DESIGN := {"portrait": Vector2(720, 1280), "landscape": Vector2(1200, 675), "square": Vector2(1200, 1200)}
const CAPTIONS := ["Can you free\nthe critter?", "Spin. Match.\nEscape!"]
const END_HEADLINE := "Can you save\nthem all?"

var _shape := "portrait"
var _snaps := ""
var _art: Node
var _game: Node
var _stage: Control      # the design-size layer, scaled to the window
var _caption: Label
var _snap_n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shape="):
			_shape = a.substr(8)
		elif a.begins_with("--snaps="):
			_snaps = a.substr(8)
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
	sub.size = GAME_SIZE
	sub.own_world_3d = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	_game = Node3D.new()
	_game.set_script(GAME)
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
	await _wait(0.3)
	_say(CAPTIONS[0])
	await _wait(0.8)
	_snap("hook")
	var won := [false]
	_game.won.connect(func(): won[0] = true)
	_game.autoplay()
	await _wait(3.2)
	_say(CAPTIONS[1])
	await _wait(1.0)
	_snap("play")
	while not won[0] and _game.playing():
		await get_tree().process_frame
	# The critter shoots out and the win card lands; beside the phone the
	# caption cheers (full screen, the card says it).
	_say("" if _shape == "portrait" else "Critter saved!")
	await _wait(3.0)
	_snap("win")
	await _wait(1.6)
	await _end_card()
	get_tree().quit()


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
