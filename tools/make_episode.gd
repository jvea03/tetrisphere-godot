# "Crash Course", episode 1 -- Totally Fine Landing: a vertical Short told
# with the game's own art. The pink ship (the key art's, crew aboard) cruises
# through space; Sprout brags; a pebble taps the porthole; alarms; the game's
# crash cutscene (scripts/screens/intro.gd) takes the dive; then, beside the
# crashed ship on Home's planet, the crew pop out -- and a pumpkin rolls in.
# The cast are Collection critters: Sprout, Blu, Goldie, Capy and Patch.
# Recorded with Movie Maker like the Shorts (tools/make_shorts.ps1 -Only ep01):
#   (override.cfg 720 x 1280, stretch off) then
#   Godot --path . --write-movie <out>.avi --fixed-fps 30 res://tools/make_episode.tscn
# --snaps=<dir> saves a still at each beat.
extends "res://tools/make_video.gd"

const SPROUT := 8
const BLU := 0
const GOLDIE := 4
const CAPY := 33
const PATCH := 99   # the pumpkin
const SHIP_W := 680.0
const SHIP_AT := Vector2(20, 430)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snaps="):
			_snaps = a.substr(8)
	_art = ADS.new()
	_art.setup()
	var win := Vector2(get_viewport().get_visible_rect().size)
	size = win
	var design: Vector2 = DESIGN["portrait"]
	_stage = Control.new()
	_stage.size = design
	_stage.scale = Vector2.ONE * minf(win.x / design.x, win.y / design.y)
	_stage.position = (win - design * _stage.scale.x) / 2.0
	add_child(_stage)
	_caption = _label(64, Rect2(20, 120, design.x - 40, 220))
	END_HEADLINE = "Next time:\nThe Giant Eggs!"
	TSSfx.music("menu")
	_episode()


func _episode() -> void:
	await _title_card()
	await _space()
	await _crash()
	await _landing()
	await _end_card()
	get_tree().quit()


## A layer filling the frame, under the caption.
func _scene() -> Control:
	var c := Control.new()
	c.size = DESIGN["portrait"]
	c.clip_contents = true
	_stage.add_child(c)
	_stage.move_child(c, 0)
	return c


func _title_card() -> void:
	var s := _scene()
	_art._sky(s, s.size)
	_art._headline(s, "Crash Course", 112, Rect2(20, 380, 680, 200))
	var rib := TSUI.ribbon("Ep. 1: Totally Fine Landing", TSUI.PINK, 40, 640.0)
	rib.position = Vector2(40, 610)
	rib.size = rib.custom_minimum_size
	(rib.get_child(0) as Label).add_theme_font_override("font", TSToon.hand_font())
	s.add_child(rib)
	var crew := [SPROUT, BLU, GOLDIE, CAPY]
	for k in crew.size():
		var c := _critter(crew[k], 120.0, s)
		c.position = Vector2(70 + k * 150, 820)
		_pop_in(c, 0.15 * k)
	TSSfx.play("popper")
	await _wait(2.4)
	await _snap("title")
	s.queue_free()


## Space: the key art's ship, the crew aboard, bobbing along.
func _space() -> void:
	var s := _scene()
	_art._sky(s, s.size)
	var sr: Rect2i = ADS.SHIP_RECT
	var ship := TextureRect.new()
	ship.texture = _art._crop(sr)
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.size = Vector2(SHIP_W, SHIP_W * sr.size.y / sr.size.x)
	ship.position = SHIP_AT
	ship.pivot_offset = ship.size / 2.0
	s.add_child(ship)
	var k := SHIP_W / sr.size.x
	# Where things are on the ship, from the key art (941 x 1672): Sprout's
	# head and the front porthole.
	var sprout := SHIP_AT + (Vector2(735, 790) - Vector2(sr.position)) * k
	var porthole := SHIP_AT + (Vector2(420, 880) - Vector2(sr.position)) * k
	var bob := ship.create_tween().set_loops()
	bob.tween_property(ship, "position:y", SHIP_AT.y - 14.0, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(ship, "position:y", SHIP_AT.y + 14.0, 0.9).set_trans(Tween.TRANS_SINE)
	await _wait(0.6)
	var b := _bubble("Smoothest flight\nin history!", sprout, s)
	await _wait(1.4)
	await _snap("brag")
	await _wait(1.4)
	_unbubble(b)
	# A pebble drifts up to the porthole ... tink.
	var pebble := TSIcon.make("rocks", 54)
	pebble.size = Vector2(54, 54)
	pebble.pivot_offset = pebble.size / 2.0
	pebble.position = Vector2(760, 470)
	s.add_child(pebble)
	var drift := pebble.create_tween().set_parallel(true)
	drift.tween_property(pebble, "position", porthole - Vector2(27, 60), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(pebble, "rotation", -2.4, 1.6)
	await _wait(1.6)
	TSSfx.play("tink", 1.4)
	TSFX.sparkle_burst_at(s, Rect2(porthole - Vector2(30, 70), Vector2(60, 60)))
	pebble.create_tween().tween_property(pebble, "position", pebble.position + Vector2(140, -260), 1.4)
	await _wait(1.0)   # the beat
	await _snap("tink")
	# Every alarm on the ship.
	bob.kill()
	var red := ColorRect.new()
	red.color = Color(1.0, 0.15, 0.2, 0.0)
	red.size = s.size
	s.add_child(red)
	var flash := red.create_tween().set_loops(3)
	flash.tween_property(red, "color:a", 0.38, 0.22)
	flash.tween_property(red, "color:a", 0.0, 0.22)
	_say("WEE-OOO!\nWEE-OOO!")
	for i in 6:
		TSSfx.play("miss", 1.3 if i % 2 == 0 else 1.0)
		ship.rotation = sin(i * 1.7) * 0.06
		ship.position = SHIP_AT + Vector2(sin(i * 2.3), cos(i * 3.1)) * 10.0
		await _wait(0.22)
	await _snap("alarm")
	_say("")
	s.queue_free()


## The dive and the crash: the game's own cutscene, from its alarm on, with
## its own captions and buttons put away.
func _crash() -> void:
	var sub := SubViewport.new()
	sub.size = GAME_SIZE
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var intro: Control = (load("res://scenes/intro.tscn") as PackedScene).instantiate()
	sub.add_child(intro)
	intro._t = intro.CRUISE_END
	await get_tree().process_frame
	for c in intro.get_children():
		if c != intro._stage and c != intro._flash:
			(c as CanvasItem).visible = false
	var s := _scene()
	var t := TextureRect.new()
	t.texture = sub.get_texture()
	t.size = s.size
	s.add_child(t)
	await _wait(intro.IMPACT - intro.CRUISE_END - 0.05)
	_say("CRASH!")
	await _wait(0.6)
	await _snap("crash")
	await _wait(2.0)
	_say("")
	await _wait(0.3)
	s.queue_free()
	sub.queue_free()


## Beside the crashed ship on Home's planet: the crew pop out, one line each,
## and the tag -- Patch the pumpkin rolls in and bonks Capy.
func _landing() -> void:
	_crashed_profile()
	var sub := SubViewport.new()
	sub.size = GAME_SIZE
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var home: Control = (load("res://scenes/home.tscn") as PackedScene).instantiate()
	sub.add_child(home)
	await _bare_home(home)
	var s := _scene()
	var bg := TextureRect.new()
	bg.texture = sub.get_texture()
	bg.size = s.size
	s.add_child(bg)
	var world = home._world
	var ship_rect: Rect2 = world.ship_screen_rect()
	var ground: float = world.get_global_rect().position.y + ship_rect.end.y + 40.0
	var mid: float = world.get_global_rect().position.x + ship_rect.get_center().x
	ground = clampf(ground, 820.0, 1100.0)
	var spots := {SPROUT: Vector2(mid - 60, ground), BLU: Vector2(mid - 240, ground + 40), GOLDIE: Vector2(mid + 130, ground + 50), CAPY: Vector2(mid + 270, ground + 10)}
	var crew := {}
	for id in spots:
		var c := _critter(id, 130.0, s)
		c.position = Vector2(spots[id]) - Vector2(65, 130)
		c.visible = false
		crew[id] = c
	await _wait(0.4)
	# Sprout climbs out, dizzy.
	var sprout: Control = crew[SPROUT]
	var blu: Control = crew[BLU]
	var goldie: Control = crew[GOLDIE]
	var capy: Control = crew[CAPY]
	_hop_out(sprout)
	var dizzy := sprout.create_tween().set_loops(6)
	dizzy.tween_property(sprout, "rotation", 0.25, 0.18)
	dizzy.tween_property(sprout, "rotation", -0.25, 0.18)
	await _wait(0.5)
	var b := _bubble("...Landing\ncomplete.", sprout.position + Vector2(65, 0), s)
	await _wait(2.2)
	await _snap("landing")
	_unbubble(b)
	_hop_out(blu)
	await _wait(0.35)
	b = _bubble("Where... are we?", blu.position + Vector2(65, 0), s)
	await _wait(1.6)
	_unbubble(b)
	_hop_out(goldie)
	await _wait(0.35)
	b = _bubble("An ADVENTURE!", goldie.position + Vector2(65, 0), s)
	var hop := goldie.create_tween().set_loops(3)
	hop.tween_property(goldie, "position:y", goldie.position.y - 40.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(goldie, "position:y", goldie.position.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(1.6)
	_unbubble(b)
	_hop_out(capy)
	await _wait(0.9)
	# The tag: a pumpkin rolls in from the right ... bonk.
	var patch := _critter(PATCH, 110.0, s)
	patch.position = Vector2(780, capy.position.y + 20)
	var roll := patch.create_tween().set_parallel(true)
	roll.tween_property(patch, "position:x", capy.position.x + 70.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	roll.tween_property(patch, "rotation", -TAU * 1.5, 1.1).set_ease(Tween.EASE_IN)
	await _wait(1.1)
	TSSfx.play("knock")
	TSSfx.play("pop1", 0.7)
	var bonk := capy.create_tween()
	bonk.tween_property(capy, "rotation", -1.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	patch.create_tween().tween_property(patch, "position:x", patch.position.x + 60.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_say("bonk.")
	await _wait(1.4)
	await _snap("bonk")
	await _wait(0.6)
	_say("")
	await _wait(0.3)
	s.queue_free()
	sub.queue_free()


## The camp as it lands: nothing fixed or built, no walkthroughs or pop-ups.
func _crashed_profile() -> void:
	_showcase_profile()
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level[i] = 0


func _critter(id: int, px: float, parent: Control) -> TSIcon:
	var c := TSIcon.make("critter", px, id)
	c.size = Vector2(px, px)
	c.pivot_offset = Vector2(px / 2.0, px)
	parent.add_child(c)
	return c


func _pop_in(c: Control, delay: float) -> void:
	c.scale = Vector2.ZERO
	var t := c.create_tween()
	t.tween_interval(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A critter springs up out of the wreck and lands on its spot.
func _hop_out(c: Control) -> void:
	c.visible = true
	var to := c.position
	c.position = to + Vector2(0, 30)
	c.scale = Vector2(0.4, 0.4)
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "position:y", to.y - 60.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(c, "position:y", to.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	TSSfx.play("pop%d" % randi_range(0, 2), 1.2)


## A speech bubble: white, ink-edged, its tail pointing down at `at` (a
## speaker's head), kept inside the frame.
func _bubble(text: String, at: Vector2, parent: Control) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", TSUI.sb(Color.WHITE, 26, 4, 0, 18))
	var l := TSUI.label(text, 38, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", TSToon.hand_font())
	box.add_child(l)
	parent.add_child(box)
	box.size = box.get_combined_minimum_size()
	box.position = Vector2(clampf(at.x - box.size.x / 2.0, 16.0, 704.0 - box.size.x), at.y - box.size.y - 46.0)
	var tail := Polygon2D.new()
	var tx := clampf(at.x - box.position.x, 30.0, box.size.x - 30.0)
	tail.polygon = PackedVector2Array([Vector2(tx - 18, box.size.y - 4), Vector2(tx + 18, box.size.y - 4), Vector2(at.x - box.position.x, box.size.y + 40)])
	tail.color = Color.WHITE
	box.add_child(tail)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(tx - 18, box.size.y - 2), Vector2(at.x - box.position.x, box.size.y + 40), Vector2(tx + 18, box.size.y - 2)])
	edge.width = 4.0
	edge.default_color = TSUI.INK
	box.add_child(edge)
	box.pivot_offset = Vector2(tx, box.size.y + 40)
	box.scale = Vector2(0.3, 0.3)
	box.create_tween().tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TSSfx.play("click", 1.3)
	return box


func _unbubble(b: Control) -> void:
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2(0.2, 0.2), 0.15)
	t.tween_callback(b.queue_free)
