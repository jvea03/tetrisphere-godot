class_name TSShipScene
extends Control

## Home's backdrop: a little planet, seen in three-quarter view, where a
## cartoon spaceship has crash-landed nose-first in a heap of dirt (its
## engine smoking until it is fixed), with the critters the player owns busy
## all over the crash site. It is a world bigger than the screen: drag any
## empty part of Home to look around, and tap a critter to make it hop. The
## menus stay put on top.
##
## The avatar critter comes first; each critter takes the next job in JOBS --
## flying it (dizzily), fixing the engine up a ladder, digging the nose out,
## fishing in a crater pond, toasting a marshmallow, and so on down to the
## silly ones. A lone critter just strolls about. Nearer things are drawn
## bigger and in front, each on its own soft shadow. The ship's six parts
## (TSProfile.PARTS) look as they are in the Collection -- broken, fixed or
## upgraded, from a smoking engine to rainbow thrusters. Everything is drawn
## in code, in the menus' hand-drawn style, and animated from one clock in
## _process.

const W := 2600.0                # the world, in the menus' 720-wide units
const H := 2300.0                # deep enough to scroll the far south up into view
const INK := Color(0.27, 0.16, 0.19)
const GLASS := Color(0.62, 0.84, 1.0)
const GROUND := Color(0.72, 0.88, 0.70)
const GROUND_DARK := Color(0.60, 0.79, 0.61)
const SKY_TOP := Color(0.90, 0.86, 1.0)
const SKY_LOW := Color(1.0, 0.95, 0.88)
const DIRT := Color(0.74, 0.58, 0.44)
const WATER := Color(0.60, 0.82, 1.0)
const WOOD := Color(0.64, 0.44, 0.30)
const BUTTER := Color(1.0, 0.86, 0.45)
const SHADOW := Color(0.27, 0.16, 0.19, 0.16)
const GOLD := Color(1.0, 0.8, 0.3)
const CHROME := Color(0.88, 0.9, 0.96)
const ACCENT := Color(0.62, 0.8, 1.0)     # the hull's racing stripe, the fins' stripes

# The ship is drawn in its own coordinates (the flying pose, nose right) and
# placed by _xf: tipped nose-down and dropped so the nose is in the ground and
# the bottom fin rests on it.
const SHIP_TILT := 0.3
const SHIP_PIN := Vector2(270.0, 200.0)     # ship point that lands at SHIP_AT
const SHIP_AT := Vector2(1300.0, 720.0)
const SHIP_DEPTH := SHIP_AT.y + 55.0         # where it meets the ground, for draw order
const DECK_Y := 145.0
const DOME := Vector2(360.0, 145.0)
const DOME_R := 44.0
const HATCH := Vector2(232.0, 145.0)
const PORTHOLES := [Vector2(196.0, 204.0), Vector2(256.0, 204.0), Vector2(316.0, 204.0)]
const PORTHOLE_R := 19.0
const NOZZLE := Vector2(66.0, 200.0)
const ANTENNA_TIP := Vector2(154.0, 106.0)    # bent; ANTENNA_UP once fixed
const ANTENNA_UP := Vector2(176.0, 96.0)
const FIN_TIP := Vector2(109.0, 96.0)
const PATCH := Vector2(290.0, 176.0)        # the sticking plaster over a dent

# Scenery, in world coordinates. The jobs are spread over the planet in
# little neighbourhoods round the crash: the ship itself; a pond to the west
# with a reader and, farther out, a kite flyer; a camp to the east with the
# campfire, a dancer and a juggler, and a stargazer out beyond it; and a
# crater field to the south.
const PLANET := Vector2(1900.0, 170.0)
const MOON := Vector2(620.0, 120.0)
const KITE_SKY := Vector2(340.0, 250.0)     # where the kite flies
const POND := Vector2(560.0, 1000.0)
const MOUND := SHIP_AT + Vector2(195.0, 62.0)
const FIRE := Vector2(2060.0, 1060.0)
const CRATER := Vector2(1250.0, 1500.0)

## The jobs, in the order critters take them.
const JOBS := [
	"pilot", "walk", "mechanic", "dig", "fish", "campfire", "nap", "bounce",
	"peek", "flag", "kite", "telescope", "carry", "paint", "juggle", "sweep",
	"chase", "read", "dance", "crater", "swing", "perch", "bubbles", "stroll",
]
## Jobs on the ship, and their critters' sizes. Everyone else is on the ground.
const ON_SHIP := {"pilot": 56.0, "peek": 36.0, "nap": 60.0, "bounce": 58.0, "swing": 52.0, "perch": 56.0, "bubbles": 52.0, "mechanic": 62.0}
const GROUND_SIZE := 76.0        # a ground critter's size where it is nearest
## Where each standing job's feet go.
const FEET := {
	"flag": Vector2(1600, 770), "dig": Vector2(1400, 832), "paint": Vector2(1200, 830),
	"telescope": Vector2(2360, 640), "kite": Vector2(280, 760), "read": Vector2(700, 880),
	"fish": Vector2(800, 1016), "sweep": Vector2(1640, 1000), "campfire": Vector2(1970, 1072),
	"dance": Vector2(2210, 1090), "juggle": Vector2(2080, 1260), "crater": CRATER,
}
## The walkers: [from x, to x, feet y, speed].
const PATHS := {
	"walk": [1040.0, 1460.0, 930.0, 0.07], "carry": [1640.0, 1960.0, 1180.0, 0.06],
	"stroll": [1480.0, 1960.0, 1580.0, 0.05],
}
const CHASE := Vector2(840.0, 1420.0)       # the middle of the bug chase's loop

var _t := 0.0
var _xf := Transform2D()        # ship coordinates -> world coordinates
var _world: Control             # everything that pans
var _ground: Control            # sky, planet, ground, scenery and shadows
var _painters: Array = []       # layers that redraw every frame
var _ship_layer: Control
var _props_layer: Control       # over the ship: the heap, ladder and flag
var _glass_layer: Control       # the dome glass and porthole rims, over the crew inside
var _fire_layer: Control
var _lip_layer: Control         # the crater's front lip
var _overlay: Control           # tools, lines, smoke: over everything
var _crew: Array = []           # {icon, job, size, phase, centre, feet}
var _jobs := {}                 # job -> its crew entry, for the props
var _hull := Color(1.0, 0.74, 0.82)   # the ship's pink and cream
var _trim := Color(1.0, 0.97, 0.9)
var _stars: Array = []          # [position, size, phase]
var _levels: Array = []         # each ship part's level (TSProfile.PARTS): 0 broken
var _scatter: Array = []        # ground decoration: [kind, position, size]

var _offset := Vector2.ZERO     # where the world sits on screen
var _velocity := Vector2.ZERO   # a flick's glide
var _dragging := false
var _drag_moved := 0.0
var _press_at := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for i in TSProfile.PART_COUNT:
		_levels.append(TSProfile.part_level_of(i))
	_xf = Transform2D(SHIP_TILT, Vector2.ONE, 0.0, Vector2.ZERO)
	_xf.origin = SHIP_AT - _xf.basis_xform(SHIP_PIN)
	_make_scenery()

	_world = Control.new()
	_world.size = Vector2(W, H)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_ground = _layer(_draw_ground, -1.0)
	_ship_layer = _layer(_draw_ship, SHIP_DEPTH)
	_props_layer = _layer(_draw_ship_props, SHIP_DEPTH + 1.0)
	_glass_layer = _layer(_draw_ship_glass, SHIP_DEPTH + 3.0)
	_overlay = _layer(_draw_overlay, 99999.0)
	var owned := _owned_critters()
	for i in mini(owned.size(), JOBS.size()):
		var job: String = "walk" if owned.size() == 1 else JOBS[i]
		var feet := _feet(job, 0.0)
		var s: float = ON_SHIP.get(job, GROUND_SIZE * _depth_scale(feet.y))
		var icon := TSIcon.make("critter", s, owned[i])
		icon.size = Vector2(s, s)
		icon.pivot_offset = Vector2(s, s) * 0.5
		_world.add_child(icon)
		var entry := {"icon": icon, "job": job, "size": s, "phase": float(i) * 1.7, "centre": Vector2.ZERO, "feet": feet}
		_crew.append(entry)
		_jobs[job] = entry
	if _jobs.has("campfire"):
		_fire_layer = _layer(_draw_fire, FIRE.y)
	if _jobs.has("crater"):
		_lip_layer = _layer(_draw_crater_lip, CRATER.y + 1.0)
	_home_view()
	_process(0.0)


func _layer(painter: Callable, depth: float) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter)
	c.set_meta("depth", depth)
	_world.add_child(c)
	_painters.append(c)
	return c


func _make_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while _stars.size() < 120:
		var p := Vector2(rng.randf_range(10.0, W - 10.0), rng.randf_range(10.0, 300.0))
		if p.y < _horizon(p.x) - 24.0 and p.distance_to(PLANET) > 110.0 and p.distance_to(MOON) > 60.0:
			_stars.append([p, rng.randf_range(3.0, 8.0), rng.randf() * TAU])
	var keep_clear := [SHIP_AT, POND, MOUND, FIRE, CRATER, Vector2(1250, 930), CHASE]
	while _scatter.size() < 110:
		var p := Vector2(rng.randf_range(20.0, W - 20.0), rng.randf_range(_horizon(W * 0.5) + 30.0, H - 20.0))
		if p.y < _horizon(p.x) + 20.0:
			continue
		var clear := true
		for q in keep_clear:
			clear = clear and p.distance_to(q) > 170.0
		if not clear:
			continue
		var kind: String = ["crater", "pebble", "sprout", "sprout", "pebble"][rng.randi() % 5]
		_scatter.append([kind, p, rng.randf_range(0.7, 1.3)])
	_scatter.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector2).y < (b[1] as Vector2).y)


## The avatar first, then every other critter the player owns.
static func _owned_critters() -> Array:
	var out: Array = [TSProfile.avatar()]
	for i in TSProfile.CRITTER_COUNT:
		if i != TSProfile.avatar() and TSProfile.is_critter_unlocked(i):
			out.append(i)
	return out


## Where the planet meets the sky: it curves away at the edges of the world.
func _horizon(x: float) -> float:
	var u := (x - W * 0.5) / (W * 0.5)
	return 330.0 + u * u * 70.0


## Nearer (lower) things are drawn bigger: the three-quarter view's depth.
func _depth_scale(y: float) -> float:
	return clampf(lerpf(0.8, 1.12, (y - 420.0) / 1200.0), 0.8, 1.12)


# -- panning -------------------------------------------------------------------

## Starts with the ship in the open middle of Home, between the top bar and
## the chest tray.
func _home_view() -> void:
	var view := _view_size()
	_offset = Vector2(view.x * 0.56, view.y * 0.39) - (SHIP_AT + Vector2(-10.0, -10.0))
	_clamp_offset()


func _view_size() -> Vector2:
	return size if size.x > 0.0 else Vector2(720.0, 1280.0)


func _clamp_offset() -> void:
	var view := _view_size()
	_offset.x = clampf(_offset.x, view.x - W, 0.0)
	_offset.y = clampf(_offset.y, view.y - H, 0.0)


# Drags on any part of Home the menus leave uncovered (the buttons and cards
# take their own touches first) pan the world; a quick tap on a critter
# makes it hop.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			if not get_global_rect().has_point(touch.position):
				return
			_dragging = true
			_drag_moved = 0.0
			_velocity = Vector2.ZERO
			_press_at = touch.position
		elif _dragging:
			_dragging = false
			if _drag_moved < 12.0:
				_poke(touch.position)
	elif event is InputEventScreenDrag and _dragging:
		var drag := event as InputEventScreenDrag
		if drag.index != 0:
			return
		_offset += drag.relative
		_drag_moved += drag.relative.length()
		_velocity = drag.velocity
		_clamp_offset()


func _poke(at: Vector2) -> void:
	for c in _crew:
		var icon: TSIcon = c["icon"]
		if icon.get_global_rect().has_point(at):
			c["hop"] = _t
			TSSfx.play("tap")
			return


# -- the crew ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if not _dragging and _velocity.length() > 5.0:
		_offset += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
		_clamp_offset()
	_world.position = _offset.round()
	for c in _crew:
		_place(c)
	_sort()
	for p in _painters:
		(p as Control).queue_redraw()


# Draw order: farther back first, so nearer things stand in front.
func _sort() -> void:
	var kids := _world.get_children()
	kids.sort_custom(func(a: Node, b: Node) -> bool: return float(a.get_meta("depth", 0.0)) < float(b.get_meta("depth", 0.0)))
	for i in kids.size():
		if kids[i].get_index() != i:
			_world.move_child(kids[i], i)


func _feet(job: String, t: float) -> Vector2:
	if PATHS.has(job):
		var path: Array = PATHS[job]
		var u := pingpong(t * float(path[3]), 1.0)
		return Vector2(lerpf(path[0], path[1], u), path[2])
	if job == "chase":
		var a := t * 0.9
		return CHASE + Vector2(cos(a) * 90.0, sin(a) * 14.0)
	return FEET.get(job, SHIP_AT + Vector2(0, 300))


# Where each critter is this frame: `centre` is the middle of its body.
func _place(c: Dictionary) -> void:
	var icon: TSIcon = c["icon"]
	var s: float = c["size"]
	var t: float = _t + float(c["phase"])
	var job: String = c["job"]
	var stand := s * 0.43          # from the feet up to the middle of the body
	var feet := _feet(job, t)
	var centre := feet + Vector2(0.0, -stand)
	var depth := feet.y
	icon.rotation = 0.0
	icon.scale = Vector2.ONE
	match job:
		"pilot":
			centre = _xf * (DOME + Vector2(sin(t * 0.9) * 8.0, -22.0))
			icon.rotation = SHIP_TILT + sin(t * 1.3) * 0.2
			depth = SHIP_DEPTH + 2.0
		"peek":
			centre = _xf * (PORTHOLES[1] + Vector2(sin(t * 0.8) * 5.0, 3.0 + sin(t * 1.4) * 6.0))
			icon.rotation = SHIP_TILT
			depth = SHIP_DEPTH + 2.0
		"bounce":
			var h := absf(sin(t * 2.6))
			centre = _xf * (DOME + Vector2(0.0, -DOME_R)) + Vector2(0.0, -stand - h * 60.0)
			var squash := maxf(0.0, 1.0 - h * 5.0)
			icon.scale = Vector2(1.0 + 0.18 * squash, 1.0 - 0.18 * squash)
			depth = SHIP_DEPTH + 4.0
		"nap":
			centre = _xf * Vector2(284.0, DECK_Y) + _ship_up() * (s * 0.36)
			icon.rotation = SHIP_TILT - PI * 0.5
			icon.scale = Vector2(1.0, 1.0 + sin(t * 1.5) * 0.04)
			depth = SHIP_DEPTH + 4.0
		"swing":
			centre = _xf * _antenna_tip() + Vector2(0.0, 30.0 + stand).rotated(sin(t * 1.8) * 0.5)
			icon.rotation = sin(t * 1.8) * 0.5
			depth = SHIP_DEPTH + 4.0
		"perch":
			centre = _xf * FIN_TIP + Vector2(0.0, -stand + 2.0)
			icon.rotation = sin(t * 0.7) * 0.08
			depth = SHIP_DEPTH + 4.0
		"bubbles":
			centre = _xf * HATCH + _ship_up() * (stand + 2.0)
			icon.rotation = SHIP_TILT * 0.5
			depth = SHIP_DEPTH + 4.0
		"mechanic":
			centre = _mechanic_spot() + Vector2(0.0, sin(t * 1.6) * 2.0)
			icon.rotation = -0.15 + sin(t * 6.0) * 0.05
			depth = SHIP_DEPTH + 4.0
		"walk", "stroll", "carry":
			var path: Array = PATHS[job]
			var right := fposmod(t * float(path[3]), 2.0) < 1.0
			centre.y -= absf(sin(t * 9.0)) * 5.0
			icon.scale.x = 1.0 if right else -1.0
		"chase":
			centre.y -= absf(sin(t * 10.0)) * 4.0
			icon.scale.x = -1.0 if sin(t * 0.9) > 0.0 else 1.0
		"crater":
			# Popping up out of a hole, and ducking back in.
			var up := clampf(sin(t * 1.1) * 1.6, -1.0, 1.0) * 0.5 + 0.5
			centre = CRATER + Vector2(0.0, s * 0.35 - up * s * 0.62)
		"dance":
			centre += Vector2(sin(t * 3.0) * 8.0, -absf(sin(t * 6.0)) * 10.0)
			icon.rotation = sin(t * 3.0) * 0.25
			icon.scale.x = 1.0 if sin(t * 1.5) > 0.0 else -1.0
		"juggle":
			centre.y -= absf(sin(t * 4.0)) * 4.0
		"dig":
			icon.rotation = sin(t * 4.0) * 0.12
		"sweep":
			centre.x += sin(t * 2.0) * 14.0
			icon.rotation = sin(t * 4.0) * 0.08
		"fish", "telescope":
			icon.scale.x = -1.0
		"flag":
			centre.y -= absf(sin(t * 3.0)) * 10.0
		"read":
			icon.rotation = sin(t * 0.6) * 0.06
	# A tapped critter hops and spins.
	if c.has("hop"):
		var since := _t - float(c["hop"])
		if since < 0.6:
			centre.y -= sin(since / 0.6 * PI) * 50.0
			icon.rotation += since / 0.6 * TAU
		else:
			c.erase("hop")
	# TSIcon draws a critter's body a little below the icon's middle.
	icon.position = centre - Vector2(s * 0.5, s * 0.56)
	icon.set_meta("depth", depth)
	c["centre"] = centre
	c["feet"] = feet


## A ship part's level (TSProfile.PARTS), as it was when Home opened.
func _lv(part: int) -> int:
	return int(_levels[part]) if part < _levels.size() else 0


func _antenna_tip() -> Vector2:
	return ANTENNA_TIP if _lv(TSProfile.PART_ANTENNA) == 0 else ANTENNA_UP


func _ship_up() -> Vector2:
	return Vector2(0.0, -1.0).rotated(SHIP_TILT)


func _mechanic_spot() -> Vector2:
	return _xf * NOZZLE + Vector2(16.0, 70.0)


# -- the world ------------------------------------------------------------------

func _draw_ground() -> void:
	var ci := _ground
	# The sky, lilac high up, fading to cream at the horizon.
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 420), Vector2(0, 420)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	for st in _stars:
		var r: float = float(st[1]) * (0.7 + 0.3 * sin(_t * 2.2 + float(st[2])))
		_sparkle(ci, st[0], r, Color(1.0, 0.8, 0.4, 0.85))
	# A ringed planet and a little moon.
	ci.draw_circle(PLANET, 60.0, Color(0.80, 0.70, 0.98), true, -1.0, true)
	ci.draw_arc(PLANET, 60.0, 0.0, TAU, 48, INK, 5.0, true)
	ci.draw_arc(PLANET + Vector2(-14, -14), 26.0, PI * 1.1, PI * 1.5, 10, Color(1, 1, 1, 0.7), 6.0, true)
	var ring := PackedVector2Array()
	for k in 49:
		var a := TAU * float(k) / 48.0
		ring.append(PLANET + Vector2(cos(a) * 100.0, sin(a) * 22.0).rotated(-0.3))
	ci.draw_polyline(ring, INK, 10.0, true)
	ci.draw_polyline(ring, Color(1.0, 0.82, 0.5), 5.0, true)
	ci.draw_circle(MOON, 32.0, Color(1.0, 0.97, 0.9), true, -1.0, true)
	ci.draw_arc(MOON, 32.0, 0.0, TAU, 32, INK, 4.0, true)
	for dimple in [[Vector2(-10, -6), 7.0], [Vector2(10, 10), 5.0], [Vector2(8, -14), 4.0]]:
		ci.draw_circle(MOON + dimple[0], dimple[1], Color(0.9, 0.86, 0.8), true, -1.0, true)

	# The planet's surface, curving away at the edges of the world.
	var ground := PackedVector2Array()
	for k in 41:
		var x := W * float(k) / 40.0
		ground.append(Vector2(x, _horizon(x)))
	var rim := ground.duplicate()
	ground.append(Vector2(W, H))
	ground.append(Vector2(0.0, H))
	ci.draw_colored_polygon(ground, GROUND)
	# A darker band along the horizon, for depth.
	var band := rim.duplicate()
	for k in range(40, -1, -1):
		var x := W * float(k) / 40.0
		band.append(Vector2(x, _horizon(x) + 26.0))
	ci.draw_colored_polygon(band, GROUND_DARK)
	ci.draw_polyline(rim, INK, 5.0, true)
	for item in _scatter:
		var p: Vector2 = item[1]
		var k: float = float(item[2]) * _depth_scale(p.y)
		match item[0]:
			"crater":
				_ellipse(ci, p, 46.0 * k, 12.0 * k, GROUND_DARK, false)
				ci.draw_arc(p + Vector2(0, 2.0 * k), 40.0 * k, PI * 1.1, PI * 1.9, 12, Color(INK, 0.25), 3.0, true)
			"pebble":
				_ellipse(ci, p, 12.0 * k, 7.0 * k, Color(0.78, 0.76, 0.82))
			"sprout":
				ci.draw_line(p, p + Vector2(0, -20.0 * k), Color(0.36, 0.62, 0.44), 4.0, true)
				ci.draw_circle(p + Vector2(0, -23.0 * k), 6.5 * k, Color(1.0, 0.62, 0.74), true, -1.0, true)
	# The crater pond.
	_ellipse(ci, POND, 170.0, 42.0, WATER)
	var shimmer := sin(_t * 1.5) * 10.0
	ci.draw_line(POND + Vector2(-60 + shimmer, -4), POND + Vector2(-26 + shimmer, -4), Color(1, 1, 1, 0.7), 4.0, true)
	ci.draw_line(POND + Vector2(16 - shimmer, 8), POND + Vector2(46 - shimmer, 8), Color(1, 1, 1, 0.6), 4.0, true)
	if _jobs.has("crater"):
		_ellipse(ci, CRATER, 50.0, 15.0, INK.lightened(0.25), false)
	# Soft shadows: under the ship, and under everyone standing on the ground.
	_ellipse(ci, SHIP_AT + Vector2(-20.0, 68.0), 250.0, 30.0, SHADOW, false)
	for c in _crew:
		if ON_SHIP.has(c["job"]) or c["job"] == "crater":
			continue
		var s: float = c["size"]
		var lift := (c["feet"] as Vector2).y - ((c["centre"] as Vector2).y + s * 0.43)
		var shrink := clampf(1.0 - lift / 120.0, 0.5, 1.0)
		_ellipse(ci, c["feet"], s * 0.36 * shrink, s * 0.09 * shrink, SHADOW, false)


func _draw_ship() -> void:
	var ci := _ship_layer
	ci.draw_set_transform_matrix(_xf)
	var engine := _lv(TSProfile.PART_ENGINE)
	var fins := _lv(TSProfile.PART_FINS)
	var antenna := _lv(TSProfile.PART_ANTENNA)
	var hull_lv := _lv(TSProfile.PART_HULL)
	var ports := _lv(TSProfile.PART_PORTHOLES)
	# Engine: a flame once it runs (rainbow at the top), twin boosters, and a
	# nozzle that goes from sooty to clean to chrome.
	if engine >= 1:
		var flick := 1.0 + 0.2 * sin(_t * 23.0) + 0.1 * sin(_t * 37.0)
		var reach := (22.0 if engine < 4 else 44.0) * flick
		var outer := Color.from_hsv(fposmod(_t * 0.3, 1.0), 0.55, 1.0) if engine >= 4 else Color(1.0, 0.6, 0.3, 0.9)
		_blob(ci, [NOZZLE + Vector2(0, -16), NOZZLE + Vector2(-reach, 0), NOZZLE + Vector2(0, 16)], outer, false)
		_blob(ci, [NOZZLE + Vector2(0, -8), NOZZLE + Vector2(-reach * 0.55, 0), NOZZLE + Vector2(0, 8)], BUTTER, false)
	var nozzle_col := Color(0.62, 0.6, 0.68) if engine == 0 else (Color(0.8, 0.78, 0.86) if engine == 1 else CHROME)
	if engine >= 3:
		for y in [-46.0, 46.0]:
			var b := Vector2(0.0, y)
			_blob(ci, [Vector2(98, 188) + b, Vector2(80, 184) + b, Vector2(80, 216) + b, Vector2(98, 212) + b], nozzle_col)
			var r := 12.0 * (1.0 + 0.2 * sin(_t * 29.0 + y))
			_blob(ci, [Vector2(80, 192) + b, Vector2(80 - r, 200) + b, Vector2(80, 208) + b], Color(1.0, 0.7, 0.4, 0.9), false)
	_blob(ci, [Vector2(92, 176), Vector2(66, 166), Vector2(66, 234), Vector2(92, 224)], nozzle_col)
	if engine >= 2:
		ci.draw_line(Vector2(72, 174), Vector2(72, 196), Color(1, 1, 1, 0.8), 3.0, true)
	# Fins, behind the hull: the top one bent until fixed; stripes, tip lights
	# and gold as they are upgraded.
	var fin_col := GOLD if fins >= 4 else _trim
	var top_fin := [Vector2(118, 152), Vector2(88, 108), FIN_TIP, Vector2(128, 104), Vector2(196, 150)] if fins == 0 \
		else [Vector2(118, 152), Vector2(90, 96), Vector2(128, 96), Vector2(196, 150)]
	_blob(ci, top_fin, fin_col)
	_blob(ci, [Vector2(118, 248), Vector2(90, 306), Vector2(128, 306), Vector2(196, 250)], fin_col)
	if fins >= 2:
		ci.draw_line(Vector2(108, 128), Vector2(150, 128), ACCENT, 6.0, true)
		ci.draw_line(Vector2(108, 272), Vector2(150, 272), ACCENT, 6.0, true)
	if fins >= 3:
		var on := fposmod(_t, 1.2) < 0.6
		for tip in [Vector2(109, 96), Vector2(109, 304)]:
			ci.draw_circle(tip, 7.0, INK, true, -1.0, true)
			ci.draw_circle(tip, 5.0, Color(0.6, 1.0, 0.6) if on else Color(0.5, 0.6, 0.5), true, -1.0, true)
	# Antenna: bent and flickering until fixed; then a steady blink, a dish, a
	# second mast, and a glowing orb.
	var tip := _antenna_tip()
	if antenna == 0:
		ci.draw_polyline(PackedVector2Array([Vector2(176, DECK_Y), Vector2(176, 122), tip]), INK, 5.0, true)
		var flicker := 0.5 + 0.5 * sin(_t * 7.0) if fposmod(_t, 3.0) < 1.2 else 0.0
		ci.draw_circle(tip, 9.0, INK, true, -1.0, true)
		ci.draw_circle(tip, 6.5, Color(0.7, 0.66, 0.72).lerp(Color(1.0, 0.45, 0.55), flicker), true, -1.0, true)
	else:
		if antenna >= 3:
			ci.draw_line(Vector2(198, DECK_Y), Vector2(198, 112), INK, 4.0, true)
			ci.draw_circle(Vector2(198, 110), 6.0, Color(0.62, 0.8, 1.0), true, -1.0, true)
		if antenna >= 2:
			ci.draw_line(Vector2(150, DECK_Y), Vector2(150, 128), INK, 4.0, true)
			ci.draw_arc(Vector2(150, 122), 13.0, PI * 0.8, PI * 2.2, 14, INK, 7.0, true)
			ci.draw_arc(Vector2(150, 122), 13.0, PI * 0.8, PI * 2.2, 14, CHROME, 4.0, true)
		ci.draw_line(Vector2(176, DECK_Y), tip, INK, 5.0, true)
		var glow := 0.5 + 0.5 * sin(_t * 2.0)
		if antenna >= 4:
			ci.draw_circle(tip, 20.0, Color(1.0, 0.9, 0.5, 0.25 + 0.2 * glow), true, -1.0, true)
			ci.draw_circle(tip, 12.0, INK, true, -1.0, true)
			ci.draw_circle(tip, 9.5, BUTTER.lerp(Color.WHITE, glow * 0.5), true, -1.0, true)
		else:
			ci.draw_circle(tip, 9.0, INK, true, -1.0, true)
			ci.draw_circle(tip, 6.5, Color(1.0, 0.45, 0.55).lerp(Color(1.0, 0.8, 0.85), glow), true, -1.0, true)
	# The hull: a rounded tail, a flat deck on top and a rounded nose.
	var hull := PackedVector2Array()
	for k in 17:
		var a := PI * 0.5 + PI * float(k) / 16.0
		hull.append(Vector2(145.0, 200.0) + Vector2(cos(a), sin(a)) * 55.0)
	for k in 17:
		var u := float(k) / 16.0
		hull.append(Vector2(380.0, DECK_Y).lerp(Vector2(470.0, 200.0), u) + Vector2(sin(u * PI) * 16.0, -sin(u * PI) * 6.0))
	for k in 17:
		var u := float(k) / 16.0
		hull.append(Vector2(470.0, 200.0).lerp(Vector2(380.0, 255.0), u) + Vector2(sin(u * PI) * 16.0, sin(u * PI) * 6.0))
	ci.draw_colored_polygon(hull, _hull)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(104, 226), Vector2(452, 226), Vector2(446, 238), Vector2(112, 238)]), GOLD if hull_lv >= 4 else _trim)
	if hull_lv >= 2:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(108, 212), Vector2(456, 212), Vector2(454, 218), Vector2(110, 218)]), ACCENT)
	ci.draw_line(Vector2(150, 158), Vector2(330, 158), Color(1, 1, 1, 0.55 if hull_lv < 4 else 0.9), 5.0, true)
	if hull_lv == 0:
		for spot in [[Vector2(118, 186), 12.0], [Vector2(132, 214), 8.0]]:
			ci.draw_circle(spot[0], spot[1], Color(INK, 0.22), true, -1.0, true)
	if hull_lv >= 3:
		for decal in [Vector2(150, 180), Vector2(400, 176), Vector2(428, 202)]:
			_sparkle(ci, decal, 11.0, BUTTER)
	hull.append(hull[0])
	ci.draw_polyline(hull, INK, 5.0, true)
	if hull_lv == 0:
		# A dent with a sticking plaster over it.
		for turn in [0.6, -0.6]:
			var band := PackedVector2Array()
			for corner in [Vector2(-22, -7), Vector2(22, -7), Vector2(22, 7), Vector2(-22, 7)]:
				band.append(PATCH + (corner as Vector2).rotated(turn))
			ci.draw_colored_polygon(band, Color(1.0, 0.86, 0.72))
			band.append(band[0])
			ci.draw_polyline(band, INK, 3.0, true)
	# Deck hatch, open.
	ci.draw_rect(Rect2(HATCH + Vector2(-16, -6), Vector2(32, 8)), INK)
	ci.draw_line(HATCH + Vector2(16, -2), HATCH + Vector2(30, -20), _trim, 7.0, true)
	# Portholes: dark (cracked) glass, then clean, then lit warm from inside.
	for hole in PORTHOLES:
		ci.draw_circle(hole, PORTHOLE_R, Color(1.0, 0.86, 0.5) if ports >= 2 else Color(0.26, 0.3, 0.5), true, -1.0, true)
	# The back of the cockpit dome, behind the pilot.
	ci.draw_colored_polygon(_half_circle(DOME, DOME_R), Color(0.42, 0.56, 0.82))
	ci.draw_set_transform_matrix(Transform2D())


# Over the ship: the heap round its nose, and the mechanic's ladder and the
# claimed flag.
func _draw_ship_props() -> void:
	var ci := _props_layer
	var heap := PackedVector2Array()
	for k in 19:
		var a := PI + PI * float(k) / 18.0
		heap.append(MOUND + Vector2(cos(a) * 80.0, sin(a) * 36.0 + 10.0))
	ci.draw_colored_polygon(heap, DIRT)
	ci.draw_polyline(heap, INK, 5.0, true)
	for clod in [Vector2(-40, -6), Vector2(16, -20), Vector2(46, 0)]:
		ci.draw_circle(MOUND + clod, 6.0, DIRT.darkened(0.2), true, -1.0, true)
	if _jobs.has("mechanic"):
		var top := _mechanic_spot() + Vector2(0.0, 28.0)
		var foot := Vector2(top.x - 18.0, SHIP_DEPTH + 45.0)
		for side in [-13.0, 13.0]:
			ci.draw_line(foot + Vector2(side, 0), top + Vector2(side, 0), WOOD, 6.0, true)
		for k in 5:
			var p := foot.lerp(top, (float(k) + 0.5) / 5.0)
			ci.draw_line(p + Vector2(-13, 0), p + Vector2(13, 0), WOOD, 5.0, true)
	if _jobs.has("flag"):
		var base := MOUND + Vector2(14.0, -26.0)
		var top := base + Vector2(0.0, -90.0)
		ci.draw_line(base, top, INK, 5.0, true)
		var cloth := PackedVector2Array()
		for k in 7:
			var u := float(k) / 6.0
			cloth.append(top + Vector2(u * 54.0, sin(u * 5.0 - _t * 6.0) * 5.0 * u))
		for k in range(6, -1, -1):
			var u := float(k) / 6.0
			cloth.append(top + Vector2(u * 54.0, 32.0 + sin(u * 5.0 - _t * 6.0) * 5.0 * u))
		ci.draw_colored_polygon(cloth, Color(1.0, 0.62, 0.74))
		ci.draw_polyline(cloth, INK, 3.5, true)
		ci.draw_circle(top + Vector2(22.0, 16.0), 6.0, Color.WHITE, true, -1.0, true)


# The dome's glass and the porthole rims, over the critters inside: cracked
# until fixed, then clear, tinted, a headlamp and gold; porthole cracks and a
# boarded-up window until fixed, then curtains and gold rims.
func _draw_ship_glass() -> void:
	var ci := _glass_layer
	var cockpit := _lv(TSProfile.PART_COCKPIT)
	var ports := _lv(TSProfile.PART_PORTHOLES)
	ci.draw_set_transform_matrix(_xf)
	var glass := _half_circle(DOME, DOME_R)
	ci.draw_colored_polygon(glass, Color(GLASS.darkened(0.15), 0.5) if cockpit >= 2 else Color(GLASS, 0.35))
	var frame := GOLD if cockpit >= 4 else _trim
	ci.draw_polyline(glass, INK, 5.0, true)
	if cockpit >= 4:
		ci.draw_polyline(glass, GOLD, 2.5, true)
	ci.draw_arc(DOME, DOME_R - 10.0, PI * 1.2, PI * 1.45, 8, Color(1, 1, 1, 0.8), 4.0, true)
	if cockpit >= 2:
		ci.draw_arc(DOME, DOME_R - 18.0, PI * 1.25, PI * 1.4, 6, Color(1, 1, 1, 0.7), 3.0, true)
	if cockpit == 0:
		ci.draw_polyline(PackedVector2Array([DOME + Vector2(14, -40), DOME + Vector2(8, -28), DOME + Vector2(18, -20), DOME + Vector2(10, -10)]), Color.WHITE, 2.5, true)
	if cockpit >= 3:
		# A headlamp on top, its beam sweeping ahead.
		var lamp := DOME + Vector2(0.0, -DOME_R - 4.0)
		var sweep := sin(_t * 0.8) * 0.25
		var beam := PackedVector2Array([lamp, lamp + Vector2(160, -40).rotated(sweep), lamp + Vector2(160, 30).rotated(sweep)])
		ci.draw_colored_polygon(beam, Color(1.0, 0.95, 0.6, 0.22))
		ci.draw_circle(lamp, 9.0, INK, true, -1.0, true)
		ci.draw_circle(lamp, 6.5, BUTTER, true, -1.0, true)
	ci.draw_line(DOME + Vector2(-DOME_R - 6.0, 0), DOME + Vector2(DOME_R + 6.0, 0), frame, 8.0, true)
	ci.draw_line(DOME + Vector2(-DOME_R - 6.0, 4), DOME + Vector2(DOME_R + 6.0, 4), INK, 3.0, true)
	var rim := GOLD if ports >= 4 else _trim
	for k in PORTHOLES.size():
		var hole: Vector2 = PORTHOLES[k]
		if ports == 0:
			ci.draw_polyline(PackedVector2Array([hole + Vector2(-8, -12), hole + Vector2(0, -2), hole + Vector2(-6, 6), hole + Vector2(4, 14)]), Color(1, 1, 1, 0.8), 2.0, true)
			if k == 2:
				# Boarded up.
				ci.draw_rect(Rect2(hole + Vector2(-PORTHOLE_R - 4, -5), Vector2(PORTHOLE_R * 2 + 8, 10)), WOOD)
				ci.draw_rect(Rect2(hole + Vector2(-PORTHOLE_R - 4, -5), Vector2(PORTHOLE_R * 2 + 8, 10)), INK, false, 2.5)
		if ports >= 3:
			# Little pink curtains, tied back.
			for side in [-1.0, 1.0]:
				_blob(ci, [hole + Vector2(side * PORTHOLE_R * 0.95, -PORTHOLE_R * 0.7), hole + Vector2(side * 4.0, -PORTHOLE_R * 0.8), hole + Vector2(side * PORTHOLE_R * 0.7, PORTHOLE_R * 0.5)], Color(1.0, 0.62, 0.74), false)
		ci.draw_arc(hole, PORTHOLE_R, 0.0, TAU, 28, rim, 7.0, true)
		ci.draw_arc(hole, PORTHOLE_R + 4.0, 0.0, TAU, 28, INK, 3.0, true)
		ci.draw_arc(hole, PORTHOLE_R - 6.0, PI * 1.15, PI * 1.45, 6, Color(1, 1, 1, 0.7), 3.0, true)
	ci.draw_set_transform_matrix(Transform2D())


func _draw_fire() -> void:
	var ci := _fire_layer
	_ellipse(ci, FIRE + Vector2(0, 8), 44.0, 10.0, SHADOW, false)
	for turn in [0.4, -0.4]:
		ci.draw_line(FIRE + Vector2(-26, 6).rotated(turn), FIRE + Vector2(26, 6).rotated(turn), WOOD, 10.0, true)
	var flick := 1.0 + 0.15 * sin(_t * 17.0)
	_blob(ci, [FIRE + Vector2(-20, 0), FIRE + Vector2(0, -50.0 * flick), FIRE + Vector2(20, 0)], Color(1.0, 0.55, 0.3))
	_blob(ci, [FIRE + Vector2(-10, 0), FIRE + Vector2(0, -26.0 * flick), FIRE + Vector2(10, 0)], BUTTER, false)


# The crater's front lip, over the critter popping out of it.
func _draw_crater_lip() -> void:
	var ci := _lip_layer
	var lip := PackedVector2Array()
	for k in 17:
		var a := PI * float(k) / 16.0
		lip.append(CRATER + Vector2(cos(a) * 50.0, sin(a) * 15.0))
	for k in range(16, -1, -1):
		var a := PI * float(k) / 16.0
		lip.append(CRATER + Vector2(cos(a) * 60.0, sin(a) * 15.0 + 14.0))
	ci.draw_colored_polygon(lip, GROUND)
	ci.draw_arc(CRATER, 50.0, 0.0, PI, 16, INK, 4.0, true)


# Over everything: smoke, tools, lines and fun.
func _draw_overlay() -> void:
	var ci := _overlay
	var nozzle := _xf * NOZZLE
	# Smoke puffs from the engine while it is broken.
	for k in (6 if _lv(TSProfile.PART_ENGINE) == 0 else 0):
		var age := fposmod(_t * 0.35 + float(k) / 6.0, 1.0)
		var p := nozzle + Vector2(-age * 70.0 + sin(age * 7.0 + k) * 10.0, -age * 190.0)
		ci.draw_circle(p, 12.0 + age * 26.0, Color(0.62, 0.6, 0.66, (1.0 - age) * 0.55), true, -1.0, true)
	for c in _crew:
		var centre: Vector2 = c["centre"]
		var s: float = c["size"]
		var k := s / 44.0              # tools scale with their critter
		var t: float = _t + float(c["phase"])
		match c["job"]:
			"pilot":
				for i in 3:
					var a := t * 3.0 + TAU * float(i) / 3.0
					_sparkle(ci, centre + Vector2(cos(a) * 22.0, -s * 0.55 + sin(a) * 6.0), 7.0, BUTTER)
			"mechanic":
				var turn := sin(t * 6.0) * 0.6
				var head := nozzle + Vector2(14.0, 16.0)
				var hand := centre + Vector2(-10.0, -14.0)
				ci.draw_line(hand, head, INK, 11.0, true)
				ci.draw_line(hand, head, Color(0.8, 0.8, 0.86), 6.0, true)
				ci.draw_arc(head, 9.0, turn - PI * 0.8, turn + PI * 0.8, 10, INK, 7.0, true)
				if sin(t * 6.0) > 0.85:
					for i in 3:
						var a := PI + (float(i) - 1.0) * 0.6
						_sparkle(ci, head + Vector2(cos(a), sin(a)) * 22.0, 7.0, Color(1.0, 0.8, 0.3))
			"dig":
				var dig := sin(t * 4.0)
				var blade := centre + Vector2(46.0, 18.0 + dig * 8.0) * k
				ci.draw_line(centre + Vector2(8, -14) * k, blade, WOOD, 5.0, true)
				_blob(ci, [blade + Vector2(-8, -3) * k, blade + Vector2(10, -8) * k, blade + Vector2(16, 10) * k, blade + Vector2(-2, 14) * k], Color(0.8, 0.8, 0.86))
				for i in 3:
					var age := fposmod(t * 0.8 + float(i) / 3.0, 1.0)
					var p := MOUND + Vector2(-50.0 - age * 110.0, -16.0 - sin(age * PI) * 80.0)
					ci.draw_circle(p, 6.0, DIRT.darkened(0.15), true, -1.0, true)
			"fish":
				var grip := centre + Vector2(-12.0, -6.0) * k
				var tip := grip + Vector2(-64.0, -50.0)
				ci.draw_line(grip, tip, WOOD, 5.0, true)
				var bob := POND + Vector2(80.0, -4.0 + sin(t * 2.4) * 4.0)
				ci.draw_line(tip, bob, Color(INK, 0.7), 2.0, true)
				ci.draw_circle(bob, 7.0, Color(1.0, 0.45, 0.55), true, -1.0, true)
				ci.draw_arc(bob, 7.0, 0.0, TAU, 12, INK, 2.5, true)
			"campfire":
				var end := FIRE + Vector2(-6.0, -40.0)
				ci.draw_line(centre + Vector2(10, -2) * k, end, WOOD, 4.5, true)
				var toast := Color(1.0, 0.98, 0.94).lerp(Color(0.86, 0.62, 0.4), 0.5 + 0.5 * sin(t * 0.7))
				ci.draw_rect(Rect2(end + Vector2(-9, -7), Vector2(18, 14)), toast)
				ci.draw_rect(Rect2(end + Vector2(-9, -7), Vector2(18, 14)), INK, false, 2.5)
			"nap":
				for i in 3:
					var age := fposmod(t * 0.4 + float(i) / 3.0, 1.0)
					_text(ci, centre + Vector2(14.0 + age * 34.0, -24.0 - age * 60.0), "z", 20.0 + age * 16.0, Color(INK, 1.0 - age))
			"swing":
				ci.draw_line(_xf * _antenna_tip(), centre + Vector2(0.0, -s * 0.4).rotated(sin(t * 1.8) * 0.5), INK, 3.0, true)
			"bubbles":
				for i in 4:
					var age := fposmod(t * 0.35 + float(i) / 4.0, 1.0)
					var p := centre + Vector2(16.0 + sin(age * 6.0 + i) * 14.0, -20.0 - age * 140.0)
					var r := 6.0 + age * 10.0
					ci.draw_arc(p, r, 0.0, TAU, 16, Color(0.5, 0.7, 1.0, 1.0 - age), 2.5, true)
					ci.draw_arc(p, r * 0.6, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 1.0 - age), 2.0, true)
			"kite":
				var kite := KITE_SKY + Vector2(sin(t * 0.7) * 40.0, sin(t * 1.1) * 18.0)
				var line := PackedVector2Array()
				for i in 13:
					var u := float(i) / 12.0
					line.append(centre.lerp(kite, u) + Vector2(sin(u * PI) * 24.0, 0.0))
				ci.draw_polyline(line, Color(INK, 0.7), 2.0, true)
				var tilt := sin(t * 1.3) * 0.25
				var pts: Array = []
				for d in [Vector2(0, -26), Vector2(19, 0), Vector2(0, 32), Vector2(-19, 0)]:
					pts.append(kite + (d as Vector2).rotated(tilt))
				_blob(ci, pts, Color(0.62, 0.8, 1.0))
				for i in 3:
					_sparkle(ci, kite + Vector2(sin(t * 3.0 + i) * 9.0, 38.0 + i * 15.0).rotated(tilt), 6.0, Color(1.0, 0.62, 0.74))
			"telescope":
				# A spyglass on a tripod, trained on the ringed planet.
				var eye := centre + Vector2(-12.0, -10.0) * k
				var lens := eye + (PLANET - eye).normalized() * 50.0 * k
				for leg in [-12.0, 12.0]:
					ci.draw_line(eye.lerp(lens, 0.4), Vector2(eye.lerp(lens, 0.4).x + leg, (c["feet"] as Vector2).y), WOOD, 4.0, true)
				ci.draw_line(eye, lens, INK, 15.0, true)
				ci.draw_line(eye, lens, Color(0.66, 0.62, 0.9), 9.0, true)
				ci.draw_circle(lens, 8.0, INK, true, -1.0, true)
			"carry":
				var box := Rect2(centre + Vector2(-20.0, -s * 0.5 - 30.0), Vector2(40, 30))
				ci.draw_rect(box, Color(0.86, 0.68, 0.48))
				ci.draw_rect(box, INK, false, 3.5)
				ci.draw_line(box.position + Vector2(0, 10), box.position + Vector2(40, 10), INK, 2.5, true)
			"paint":
				var dab := _xf * Vector2(250.0, 244.0)
				var brush := dab + Vector2(sin(t * 3.0) * 12.0, 4.0)
				ci.draw_line(centre + Vector2(6, -16) * k, brush, WOOD, 4.5, true)
				ci.draw_circle(dab, 18.0, _hull.lightened(0.15), true, -1.0, true)
				ci.draw_circle(brush, 6.0, _hull.darkened(0.1), true, -1.0, true)
				_blob(ci, [centre + Vector2(12, 20) * k, centre + Vector2(38, 20) * k, centre + Vector2(36, 2) * k, centre + Vector2(14, 2) * k], Color(0.86, 0.86, 0.9))
			"juggle":
				for i in 3:
					var a := t * 3.2 + TAU * float(i) / 3.0
					var p := centre + Vector2(cos(a) * 26.0, -s * 0.6 - absf(sin(a)) * 44.0)
					ci.draw_circle(p, 8.0, [Color(1.0, 0.62, 0.74), BUTTER, Color(0.62, 0.8, 1.0)][i], true, -1.0, true)
					ci.draw_arc(p, 8.0, 0.0, TAU, 12, INK, 2.5, true)
			"sweep":
				var swish := sin(t * 4.0) * 0.4
				var head := centre + Vector2(30.0, 26.0) * k + Vector2(swish * 14.0, 0.0)
				ci.draw_line(centre + Vector2(4, -12) * k, head, WOOD, 5.0, true)
				_blob(ci, [head + Vector2(-11, -3), head + Vector2(11, -3), head + Vector2(16, 11), head + Vector2(-16, 11)], BUTTER)
				ci.draw_circle(head + Vector2(26, 8), 6.0 + absf(swish) * 9.0, Color(0.7, 0.62, 0.56, 0.4), true, -1.0, true)
			"chase":
				var a := t * 0.9 + 0.5
				var bug := CHASE + Vector2(cos(a) * 90.0, sin(a) * 14.0 - 40.0 + sin(t * 9.0) * 6.0)
				ci.draw_circle(bug, 11.0, Color(1.0, 0.95, 0.6, 0.4), true, -1.0, true)
				ci.draw_circle(bug, 5.0, BUTTER, true, -1.0, true)
				for side in [-1.0, 1.0]:
					ci.draw_circle(bug + Vector2(side * 6.0, -6.0 + sin(t * 30.0) * 2.0), 3.5, Color(1, 1, 1, 0.8), true, -1.0, true)
			"read":
				var book := centre + Vector2(0.0, 8.0) * k
				for side in [-1.0, 1.0]:
					_blob(ci, [book, book + Vector2(side * 20.0, -4.0), book + Vector2(side * 20.0, 16.0), book + Vector2(0.0, 20.0)], Color(1.0, 0.98, 0.94))
			"dance":
				for i in 2:
					var age := fposmod(t * 0.5 + float(i) * 0.5, 1.0)
					_text(ci, centre + Vector2(-30.0 + i * 44.0, -40.0 - age * 50.0), "♪", 28.0, Color(INK, 1.0 - age))


# -- drawing helpers -------------------------------------------------------------

func _half_circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 25:
		var a := PI + PI * float(k) / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, outline := true) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * float(k) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, fill)
	if outline:
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 3.0, true)


func _sparkle(ci: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := TAU * float(k) / 8.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.35))
	ci.draw_colored_polygon(pts, color)


func _text(ci: CanvasItem, p: Vector2, text: String, size_px: float, color: Color) -> void:
	ci.draw_string(TSToon.hand_font(), p, text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(size_px), color)


# A filled shape with an ink outline.
func _blob(ci: CanvasItem, pts: Array, fill: Color, outline := true) -> void:
	var packed := PackedVector2Array(pts)
	ci.draw_colored_polygon(packed, fill)
	if outline:
		packed.append(packed[0])
		ci.draw_polyline(packed, INK, 4.0, true)
