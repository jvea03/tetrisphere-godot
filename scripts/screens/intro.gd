extends Control

## The opening cutscene, once, before level 1: the little pink ship full of
## eggs cruises through space, its engine sputters, it dives into the planet
## and crashes -- and the eggs burst out on impact and bounce across the
## ground. Everything is drawn here in code, in the menus' cartoon style (the
## same ship, hull and planet colours as the crash site on Home, TSShipScene).
## Skip ends it at any time; after the last caption a tap (or a wait) goes
## straight into level 1.

const CRUISE_END := 1.6      # seconds: calm cruising through space
const ALARM_END := 2.8       # the engine sputters, the alarm blinks
const IMPACT := 4.8          # the dive ends in the ground
const EGGS_AT := IMPACT + 0.3
const DONE := 8.0            # the last caption; a tap now starts level 1
const AUTO_ADVANCE := 12.0
const EGG_COUNT := 7
const GRAVITY := 2400.0
const HORIZON := 800.0       # the ground's edge, after the crash
const CRASH_AT := Vector2(360.0, 850.0)   # where the ship ends up, nose in the dirt

const INK := Color(0.27, 0.16, 0.19)
const HULL := Color(1.0, 0.74, 0.82)
const TRIM := Color(1.0, 0.97, 0.9)
const GLASS := Color(0.62, 0.84, 1.0)
const ACCENT := Color(0.62, 0.8, 1.0)
const NOZZLE := Color(0.62, 0.6, 0.68)
const BUTTER := Color(1.0, 0.86, 0.45)
const DIRT := Color(0.74, 0.58, 0.44)
const SPACE_TOP := Color(0.16, 0.13, 0.30)
const SPACE_LOW := Color(0.34, 0.26, 0.50)

const CAPTIONS := [
	[0.3, "Far, far away, a little ship full of eggs was sailing home..."],
	[CRUISE_END, "Uh-oh! Engine trouble!"],
	[IMPACT + 0.5, "CRASH! The eggs flew everywhere!"],
	[DONE, "Crack the eggs open to free the critters inside!"],
]

var _t := 0.0
var _done := false
var _rng := RandomNumberGenerator.new()
var _stars: Array = []       # [position, size, phase]
var _puffs: Array = []       # smoke and dust: {pos, vel, r, grow, life, age, col}
var _rocks: Array = []       # debris: {pos, vel, r, spin}
var _eggs: Array = []        # {icon, pos, vel, spin, land_y, bounced, landed_at, launch}
var _puff_timer := 0.0
var _impacted := false
var _alarmed := false
var _caption_i := -1

var _stage: Control          # everything that shakes: the drawing and the eggs
var _flash: ColorRect
var _caption: PanelContainer
var _caption_label: Label
var _tap_hint: Label


func _ready() -> void:
	TSProfile.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 20260928
	for i in 90:
		_stars.append([Vector2(_rng.randf_range(0, 720), _rng.randf_range(0, 1280)), _rng.randf_range(1.5, 4.0), _rng.randf() * TAU])

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	for i in EGG_COUNT:
		var egg := TSIcon.make("egg", 100, i % TSProfile.EGG_PAINTS.size())
		egg.visible = false
		_stage.add_child(egg)
		_eggs.append({"icon": egg, "launch": EGGS_AT + float(i) * 0.13})

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)

	var top := maxf(TSUI.safe_top(), 48.0)
	var caption_row := CenterContainer.new()
	caption_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caption_row.offset_top = top + 110.0
	caption_row.offset_bottom = top + 110.0
	caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption_row)
	_caption = PanelContainer.new()
	_caption.add_theme_stylebox_override("panel", TSUI.sb(TSUI.CARD, 24, 3, 3, 18))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	caption_row.add_child(_caption)
	_caption_label = TSUI.label("", 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.custom_minimum_size.x = 560.0
	_caption.add_child(_caption_label)

	var skip := TSUI.button("Skip", TSUI.CARD, 24, Vector2(120, 60), 4)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -144.0
	skip.offset_right = -24.0
	skip.offset_top = top
	skip.offset_bottom = top + 60.0
	skip.pressed.connect(_finish)
	add_child(skip)

	_tap_hint = TSUI.outlined(TSUI.label("Tap to start!", 44, TSUI.PINK, HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, 12)
	_tap_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tap_hint.offset_top = -170.0 - TSUI.safe_bottom()
	_tap_hint.offset_bottom = -110.0 - TSUI.safe_bottom()
	_tap_hint.visible = false
	add_child(_tap_hint)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and _t >= DONE:
		_finish()


## Android back skips the cutscene, like the Skip button.
func on_back_requested() -> bool:
	_finish()
	return true


## Straight into level 1 -- no Home, no loading screen -- and never again.
func _finish() -> void:
	if _done:
		return
	_done = true
	TSProfile.intro_seen = true
	TSProfile.save()
	SceneFlow.go(SceneFlow.GAME)


func _process(delta: float) -> void:
	_t += delta
	if _t >= AUTO_ADVANCE:
		_finish()
	if not _alarmed and _t >= CRUISE_END:
		_alarmed = true
		TSSfx.play("miss")
	if not _impacted and _t >= IMPACT:
		_impact()
	_update_caption()
	_update_smoke(delta)
	_update_eggs(delta)
	_flash.modulate.a = clampf(1.0 - (_t - IMPACT) / 0.5, 0.0, 1.0) if _t >= IMPACT else 0.0
	_tap_hint.visible = _t >= DONE + 0.4
	_tap_hint.modulate.a = 0.8 + 0.2 * sin(_t * 4.0)
	_stage.position = _shake()
	_stage.queue_redraw()


func _update_caption() -> void:
	var i := -1
	for k in CAPTIONS.size():
		if _t >= float(CAPTIONS[k][0]):
			i = k
	if i != _caption_i and i >= 0:
		_caption_i = i
		_caption_label.text = CAPTIONS[i][1]
		_caption.modulate.a = 0.0
		_caption.create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)


# A rumble through the dive that peaks at the crash, then dies away.
func _shake() -> Vector2:
	var amp := 0.0
	if _t >= ALARM_END and _t < IMPACT:
		amp = 7.0 * (_t - ALARM_END) / (IMPACT - ALARM_END)
	elif _t >= IMPACT:
		amp = 30.0 * exp(-(_t - IMPACT) * 3.5)
	elif _t >= CRUISE_END:
		amp = 2.0
	return Vector2(sin(_t * 53.0), cos(_t * 47.0)) * amp


func _impact() -> void:
	_impacted = true
	TSSfx.play("bomb")
	TSHaptics.heavy()
	_puffs.clear()
	for i in 26:
		var a := PI + _rng.randf() * PI   # a dome of dust over the crater
		var speed := _rng.randf_range(220.0, 620.0)
		_puffs.append({"pos": CRASH_AT + Vector2(_rng.randf_range(-40, 40), 10.0), "vel": Vector2(cos(a), sin(a) * 0.6) * speed,
			"r": _rng.randf_range(26.0, 50.0), "grow": 40.0, "life": _rng.randf_range(0.9, 1.6), "age": 0.0, "col": Color(0.94, 0.86, 0.74)})
	for i in 14:
		var a := PI + _rng.randf_range(0.2, PI - 0.2)
		_rocks.append({"pos": CRASH_AT, "vel": Vector2(cos(a), sin(a)) * _rng.randf_range(500.0, 900.0), "r": _rng.randf_range(6.0, 13.0), "spin": _rng.randf() * TAU})


# -- the ship's path -------------------------------------------------------------

# Where the ship is and how it is tipped, before the crash (nose right).
func _ship_pose() -> Array:
	if _t < CRUISE_END:
		var u := _t / CRUISE_END
		return [Vector2(lerpf(-120.0, 250.0, u), 430.0 + sin(_t * 3.0) * 10.0), sin(_t * 2.0) * 0.05]
	if _t < ALARM_END:
		var u := (_t - CRUISE_END) / (ALARM_END - CRUISE_END)
		var wobble := sin(_t * 18.0) * 0.08
		return [Vector2(lerpf(250.0, 330.0, u), 430.0 + sin(_t * 9.0) * 8.0), wobble + u * 0.15]
	# The dive: down and to the right, tipping nose-first into the ground.
	var u := clampf((_t - ALARM_END) / (IMPACT - ALARM_END), 0.0, 1.0)
	var e := u * u
	var at := Vector2(lerpf(330.0, 470.0, e), lerpf(430.0, _planet_top() + 40.0, e))
	return [at, lerpf(0.15, 0.95, e) + sin(_t * 24.0) * 0.04 * (1.0 - u)]


# The top of the planet's curve: it rises into view as the ship dives at it.
func _planet_top() -> float:
	var u := clampf((_t - CRUISE_END) / (IMPACT - CRUISE_END), 0.0, 1.0)
	return lerpf(1120.0, 780.0, u * u)


# -- smoke, dust and debris ------------------------------------------------------

func _update_smoke(delta: float) -> void:
	_puff_timer -= delta
	if _puff_timer <= 0.0:
		_puff_timer = 0.05
		if _t >= CRUISE_END and _t < IMPACT:
			# Sputtering smoke from the engine, darker as the dive goes on.
			var pose := _ship_pose()
			var tail: Vector2 = pose[0] + Vector2(-110.0, 0.0).rotated(float(pose[1]))
			var dark := clampf((_t - CRUISE_END) / (IMPACT - CRUISE_END), 0.0, 1.0)
			_puffs.append({"pos": tail, "vel": Vector2(_rng.randf_range(-60, -20), _rng.randf_range(-40, -10)), "r": _rng.randf_range(12.0, 20.0),
				"grow": 30.0, "life": 1.1, "age": 0.0, "col": Color(0.78, 0.74, 0.8).lerp(Color(0.45, 0.42, 0.5), dark)})
		elif _t >= IMPACT + 0.4:
			# After the crash: a lazy column of smoke from the wreck.
			_puffs.append({"pos": CRASH_AT + Vector2(-90.0, -70.0) + Vector2(_rng.randf_range(-10, 10), 0), "vel": Vector2(_rng.randf_range(-10, 20), -70.0),
				"r": _rng.randf_range(14.0, 22.0), "grow": 18.0, "life": 2.2, "age": 0.0, "col": Color(0.66, 0.63, 0.7)})
			_puff_timer = 0.14
	for p in _puffs:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * (1.0 - minf(1.0, delta * 1.8))
		p["r"] = float(p["r"]) + float(p["grow"]) * delta
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	for r in _rocks:
		r["vel"] = (r["vel"] as Vector2) + Vector2(0.0, GRAVITY * 0.8) * delta
		r["pos"] = (r["pos"] as Vector2) + (r["vel"] as Vector2) * delta
		r["spin"] = float(r["spin"]) + delta * 8.0
	_rocks = _rocks.filter(func(r: Dictionary) -> bool: return (r["pos"] as Vector2).y < 1400.0)


# -- the eggs ----------------------------------------------------------------------

func _update_eggs(delta: float) -> void:
	for i in _eggs.size():
		var e: Dictionary = _eggs[i]
		var icon: TSIcon = e["icon"]
		if _t < float(e["launch"]):
			continue
		if not icon.visible:
			# Out of the hatch, fanned left to right, the nearer ones bigger.
			icon.visible = true
			var spread := float(i) / float(EGG_COUNT - 1)
			var land_y := _rng.randf_range(930.0, 1150.0)
			var s := lerpf(84.0, 128.0, (land_y - 930.0) / 220.0)
			icon.size = Vector2(s, s)
			icon.pivot_offset = icon.size * 0.5
			e["pos"] = CRASH_AT + Vector2(-60.0, -90.0)
			e["vel"] = Vector2(lerpf(-560.0, 560.0, spread) + _rng.randf_range(-60, 60), -_rng.randf_range(1050.0, 1350.0))
			e["spin"] = _rng.randf_range(-9.0, 9.0)
			e["land_y"] = land_y
			e["bounced"] = false
			e["landed_at"] = -1.0
			TSSfx.play("aim", 0.8 + spread * 0.6)
		var pos: Vector2 = e["pos"]
		if float(e["landed_at"]) < 0.0:
			var vel: Vector2 = e["vel"]
			vel.y += GRAVITY * delta
			pos += vel * delta
			if pos.x < 60.0 or pos.x > 660.0:
				vel.x = -vel.x
				pos.x = clampf(pos.x, 60.0, 660.0)
			icon.rotation += float(e["spin"]) * delta
			if pos.y >= float(e["land_y"]) and vel.y > 0.0:
				pos.y = float(e["land_y"])
				if not bool(e["bounced"]):
					e["bounced"] = true
					vel = Vector2(vel.x * 0.5, -vel.y * 0.34)
					e["spin"] = float(e["spin"]) * 0.4
					TSSfx.play("click", 0.7 + _rng.randf() * 0.5)
				else:
					e["landed_at"] = _t
					e["rest"] = wrapf(icon.rotation, -PI, PI) * 0.15
			e["vel"] = vel
			e["pos"] = pos
		else:
			# Settled: a wobble that dies away, as if something inside stirred.
			var since := _t - float(e["landed_at"])
			icon.rotation = lerpf(icon.rotation, float(e["rest"]), minf(1.0, since * 6.0)) + sin(since * 14.0) * 0.25 * exp(-since * 2.5)
		icon.position = pos - icon.size * 0.5
	# Nearer (lower) eggs over farther ones.
	var order := _eggs.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("land_y", 0.0)) < float(b.get("land_y", 0.0)))
	for k in order.size():
		_stage.move_child((order[k] as Dictionary)["icon"], k)


# -- drawing -------------------------------------------------------------------------

func _draw_stage() -> void:
	if _t < IMPACT:
		_draw_space()
	else:
		_draw_crash_site()
	for p in _puffs:
		var fade := 1.0 - float(p["age"]) / float(p["life"])
		var col: Color = p["col"]
		_stage.draw_circle(p["pos"], float(p["r"]), Color(col, 0.85 * fade), true, -1.0, true)
	for r in _rocks:
		var c: Vector2 = r["pos"]
		var rad := float(r["r"])
		var pts := PackedVector2Array()
		for k in 6:
			var a := float(r["spin"]) + TAU * float(k) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad * (0.8 + 0.3 * float(k % 2)))
		_poly(pts, DIRT.darkened(0.15))


func _draw_space() -> void:
	_stage.draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(760, -40), Vector2(760, 1320), Vector2(-40, 1320)]),
		PackedColorArray([SPACE_TOP, SPACE_TOP, SPACE_LOW, SPACE_LOW]))
	for st in _stars:
		var r: float = float(st[1]) * (0.6 + 0.4 * sin(_t * 2.5 + float(st[2])))
		_stage.draw_circle(st[0], r, Color(1.0, 0.92, 0.7, 0.9), true, -1.0, true)
	# The planet, rising as the ship dives at it: a glow of air, then the ground.
	var top := _planet_top()
	var radius := 1400.0
	var centre := Vector2(360.0, top + radius)
	_stage.draw_circle(centre, radius + 34.0, Color(0.62, 0.84, 1.0, 0.35), true, -1.0, true)
	_stage.draw_circle(centre, radius, TSShipScene.PLANETS[0]["ground"], true, -1.0, true)
	for spot in [Vector2(-260, 70), Vector2(150, 140), Vector2(330, 60), Vector2(-60, 230)]:
		var sv: Vector2 = spot
		_stage.draw_circle(Vector2(360.0 + sv.x, top + sv.y), 46.0, TSShipScene.PLANETS[0]["ground_dark"], true, -1.0, true)
	_stage.draw_arc(centre, radius, 0.0, TAU, 256, INK, 5.0, true)
	var pose := _ship_pose()
	_draw_ship(pose[0], float(pose[1]), 1.0)


func _draw_crash_site() -> void:
	var planet: Dictionary = TSShipScene.PLANETS[0]
	_stage.draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(760, -40), Vector2(760, HORIZON), Vector2(-40, HORIZON)]),
		PackedColorArray([planet["sky_top"], planet["sky_top"], planet["sky_low"], planet["sky_low"]]))
	# Gentle hills along the horizon, then the ground.
	var ground := PackedVector2Array([Vector2(-40, 1320)])
	for k in 25:
		var x := -40.0 + float(k) * 34.0
		ground.append(Vector2(x, HORIZON - 18.0 * sin(x * 0.012) - 10.0 * sin(x * 0.031 + 1.0)))
	ground.append(Vector2(760, 1320))
	_stage.draw_colored_polygon(ground, planet["ground"])
	var edge := ground.slice(1, ground.size() - 1)
	_stage.draw_polyline(edge, INK, 5.0, true)
	for spot in [Vector2(110, 1000), Vector2(600, 940), Vector2(520, 1180), Vector2(160, 1210)]:
		_ellipse(spot, 70.0, 20.0, planet["ground_dark"], false)
	# The crater, the ship nose-down in it, and a lip of thrown-up dirt that
	# hides the buried nose.
	_ellipse(CRASH_AT + Vector2(40.0, 20.0), 190.0, 46.0, planet["ground_dark"].darkened(0.12), true)
	_draw_ship(CRASH_AT + Vector2(-30.0, -40.0), 0.62, 1.15)
	_ellipse(CRASH_AT + Vector2(95.0, 44.0), 120.0, 30.0, DIRT, true)
	for k in 5:
		_stage.draw_circle(CRASH_AT + Vector2(20.0 + float(k) * 40.0, 22.0 + float(k % 2) * 6.0), 16.0, DIRT.lightened(0.1), true, -1.0, true)


# The ship, drawn nose-right in its own units and placed at `at`, tipped by
# `angle`: a pink hull with a blue racing stripe, three portholes with eggs
# peeking out, cream fins, a nozzle -- and, before the crash, its flame and a
# blinking alarm once the engine starts to fail.
func _draw_ship(at: Vector2, angle: float, zoom: float) -> void:
	_stage.draw_set_transform(at, angle, Vector2.ONE * zoom)
	var crashed := _t >= IMPACT
	if not crashed:
		var sputter := 1.0 if _t < CRUISE_END else (0.35 + 0.65 * absf(sin(_t * 17.0)))
		var reach := (70.0 + 18.0 * sin(_t * 31.0)) * sputter
		_blob([Vector2(-118, -18), Vector2(-118 - reach, 0), Vector2(-118, 18)], Color(1.0, 0.6, 0.3, 0.95))
		_blob([Vector2(-118, -9), Vector2(-118 - reach * 0.55, 0), Vector2(-118, 9)], BUTTER)
		if _t >= ALARM_END:
			# Burning up on the way in: a glow round the nose.
			var heat := clampf((_t - ALARM_END) / (IMPACT - ALARM_END), 0.0, 1.0)
			_stage.draw_circle(Vector2(150, 0), 50.0 + 30.0 * heat, Color(1.0, 0.55, 0.25, 0.45 * heat), true, -1.0, true)
	_blob([Vector2(-80, -30), Vector2(-120, -40), Vector2(-120, 40), Vector2(-80, 30)], NOZZLE)
	_blob([Vector2(-60, -40), Vector2(-100, -90), Vector2(-60, -90), Vector2(10, -42)], TRIM)
	_blob([Vector2(-60, 40), Vector2(-100, 90), Vector2(-60, 90), Vector2(10, 42)], TRIM)
	var hull := PackedVector2Array()
	for k in 25:
		var a := -PI * 0.5 + PI * float(k) / 24.0
		hull.append(Vector2(60.0 + cos(a) * 120.0, sin(a) * 50.0))
	hull.append(Vector2(-90, 50))
	hull.append(Vector2(-90, -50))
	_stage.draw_colored_polygon(hull, HULL)
	_stage.draw_line(Vector2(-86, 22), Vector2(150, 22), ACCENT, 9.0, true)
	var closed := hull.duplicate()
	closed.append(hull[0])
	_stage.draw_polyline(closed, INK, 5.0, true)
	for k in 3:
		var p := Vector2(-40.0 + float(k) * 62.0, -8.0)
		_stage.draw_circle(p, 18.0, GLASS, true, -1.0, true)
		# An egg peeking out of each porthole.
		_stage.draw_set_transform(at + (p + Vector2(0, 5)).rotated(angle) * zoom, angle, Vector2(0.75, 1.0) * zoom)
		_stage.draw_circle(Vector2.ZERO, 12.0, TRIM, true, -1.0, true)
		_stage.draw_circle(Vector2(0, -6), 8.0, HULL.lightened(0.1), true, -1.0, true)
		_stage.draw_set_transform(at, angle, Vector2.ONE * zoom)
		_stage.draw_arc(p, 18.0, 0.0, TAU, 32, INK, 4.0, true)
	# The alarm light on top: red and blinking once things go wrong.
	var alarm := _t >= CRUISE_END and not crashed and fposmod(_t, 0.4) < 0.2
	_stage.draw_circle(Vector2(20, -52), 11.0, Color(1.0, 0.3, 0.3) if alarm else Color(0.7, 0.55, 0.6), true, -1.0, true)
	_stage.draw_arc(Vector2(20, -52), 11.0, PI, TAU, 16, INK, 4.0, true)
	if alarm:
		_stage.draw_circle(Vector2(20, -52), 26.0, Color(1.0, 0.3, 0.3, 0.3), true, -1.0, true)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# -- drawing helpers ---------------------------------------------------------------

func _poly(pts: PackedVector2Array, fill: Color) -> void:
	_stage.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	_stage.draw_polyline(closed, INK, 4.0, true)


func _blob(points: Array, fill: Color, outline := true) -> void:
	var pts := PackedVector2Array(points)
	_stage.draw_colored_polygon(pts, fill)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		_stage.draw_polyline(closed, INK, 4.0, true)


func _ellipse(c: Vector2, rx: float, ry: float, fill: Color, outline: bool) -> void:
	var pts := PackedVector2Array()
	for k in 36:
		var a := TAU * float(k) / 36.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_stage.draw_colored_polygon(pts, fill)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		_stage.draw_polyline(closed, INK, 4.0, true)
