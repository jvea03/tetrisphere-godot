class_name TSShipScene
extends Control

## The lift-off animation (launch) has finished: the ship is out of sight.
signal launched
## A camp spot's or ship part's build node was tapped (TSProfile.PARTS index).
signal part_tapped(part: int)

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
## bigger and in front, each on its own soft shadow. The camp spots and ship parts
## (TSProfile.PARTS) look as far as they are built -- broken, fixed or
## upgraded, from a smoking engine to rainbow thrusters. Everything is drawn
## in code, in the menus' hand-drawn style, and animated from one clock in
## _process.
##
## Build nodes float over every camp spot (and, once the camp is finished,
## every ship part) that has a step left: a hammer to build or fix it, an
## arrow to upgrade it, with the price under it. Tapping one fires
## `part_tapped`; Home opens the card that spends the coins. Nodes off the
## open part of Home (`node_area`) are gathered into an arrow at its edge,
## which glides the world over to them.

const W := 2600.0                # the world, in the menus' 720-wide units
const H := 2300.0                # deep enough to scroll the far south up into view
const INK := Color(0.27, 0.16, 0.19)
const GLASS := Color(0.62, 0.84, 1.0)
const DIRT := Color(0.74, 0.58, 0.44)
const WATER := Color(0.60, 0.82, 1.0)
const WOOD := Color(0.64, 0.44, 0.30)
const BUTTER := Color(1.0, 0.86, 0.45)
const SHADOW := Color(0.27, 0.16, 0.19, 0.16)
## A new planet's colours after every launch (TSProfile.planet_number), in turn.
const PLANETS := [
	{"ground": Color(0.72, 0.88, 0.70), "ground_dark": Color(0.60, 0.79, 0.61), "sky_top": Color(0.90, 0.86, 1.0), "sky_low": Color(1.0, 0.95, 0.88)},
	{"ground": Color(0.96, 0.80, 0.70), "ground_dark": Color(0.88, 0.68, 0.60), "sky_top": Color(0.80, 0.88, 1.0), "sky_low": Color(1.0, 0.94, 0.90)},
	{"ground": Color(0.80, 0.76, 0.96), "ground_dark": Color(0.68, 0.64, 0.88), "sky_top": Color(1.0, 0.86, 0.92), "sky_low": Color(1.0, 0.96, 0.90)},
	{"ground": Color(0.98, 0.90, 0.64), "ground_dark": Color(0.90, 0.80, 0.52), "sky_top": Color(0.78, 0.92, 0.94), "sky_low": Color(1.0, 0.97, 0.88)},
]
const GOLD := Color(1.0, 0.8, 0.3)
const CHROME := Color(0.88, 0.9, 0.96)
const ACCENT := Color(0.62, 0.8, 1.0)     # the hull's racing stripe, the fins' stripes

# The ship is drawn in its own coordinates (the flying pose, nose right) and
# placed by _xf: tipped nose-down and dropped so the nose is in the ground and
# the bottom fin rests on it.
const SHIP_TILT := 0.3                        # the crashed pose (see _set_pose)
const SHIP_PIN := Vector2(270.0, 200.0)     # ship point that lands at SHIP_AT
const SHIP_AT := Vector2(1300.0, 720.0)
const SHIP_DEPTH := SHIP_AT.y + 55.0         # where the crashed ship meets the ground
const PAD := SHIP_AT + Vector2(0.0, 40.0)    # the launch pad's middle, once the ship is readied
const LAUNCH_RUMBLE := 1.0                    # seconds of rumble on the pad before lift-off
const LAUNCH_ACCEL := 700.0                   # how hard the ship climbs, world units / s²
const LAUNCH_SECONDS := 4.2                   # from the button to `launched`
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
const SUN := Vector2(1100.0, 290.0)   # the time of day's sun or moon, in view as Home opens
const SUN_R := 62.0
const SPOT_BEAM := Color(0.95, 0.95, 0.84)   # the floodlights on the ship at night: a cool white
const KITE_SKY := Vector2(340.0, 250.0)     # where the kite flies
const POND := Vector2(560.0, 1000.0)
const MOUND := SHIP_AT + Vector2(195.0, 62.0)
const FIRE := Vector2(2060.0, 1060.0)
const CRATER := Vector2(1250.0, 1500.0)
# The camp spots (TSProfile.PARTS) round the crash, and the solar panels' stand.
const TENT := Vector2(2260.0, 960.0)
const BENCH := Vector2(1860.0, 1120.0)
const GARDEN := Vector2(2340.0, 1300.0)
const WELL := Vector2(300.0, 1010.0)
const LOOKOUT := Vector2(2480.0, 640.0)
const SOLAR := Vector2(470.0, 700.0)

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
var _sky_layer: Control         # the sky: its time of day, stars, sun or moon, the ringed planet
var _ground: Control            # ground, scenery and shadows
var _lights: Control            # night only: the fire's glow, the ship's lights, lanterns
var _painters: Array = []       # layers that redraw every frame
var _ship_layer: Control
var _props_layer: Control       # over the ship: the heap, ladder and flag
var _glass_layer: Control       # the dome glass and porthole rims, over the crew inside
var _lip_layer: Control         # the crater's front lip
var _overlay: Control           # tools, lines, smoke: over everything
var _crew: Array = []           # {icon, job, size, phase, centre, feet}
var _jobs := {}                 # job -> its crew entry, for the props
var _hull := Color(1.0, 0.74, 0.82)   # the ship's pink and cream
var _trim := Color(1.0, 0.97, 0.9)
var _stars: Array = []          # [position, size, phase]
var _levels: Array = []         # each ship part's level (TSProfile.PARTS): 0 broken
var _planet: Dictionary = PLANETS[0]   # this planet's colours
var _sky: Dictionary = TSToon.SKIES[0]   # the time of day, as on the current level
## How far launch prep has come: 0 crashed, 1 righted on its legs amid
## scaffolding, 2 upright on the launch pad (every part fixed).
var _stage := 0
var _tilt := SHIP_TILT          # the ship's pose for the stage
var _ship_at := SHIP_AT
var _ship_depth := SHIP_DEPTH   # where the ship meets the ground, for draw order
var _pose := Transform2D()      # _xf before any lift-off
var _launch_start := -1.0       # when lift-off began (see launch), or -1
var _pad_layer: Control         # behind the ship: scaffolding, launch pad, gantry
var _scatter: Array = []        # ground decoration: [kind, position, size]

## Where the build nodes on the ground float, in world coordinates (above each
## camp spot, and the solar panels' stand), by TSProfile.PARTS index.
const GROUND_NODES := {0: FIRE + Vector2(0.0, -150.0), 1: TENT + Vector2(0.0, -230.0), 2: BENCH + Vector2(0.0, -190.0), 3: GARDEN + Vector2(0.0, -150.0), 4: WELL + Vector2(0.0, -210.0), 5: LOOKOUT + Vector2(0.0, -330.0), 14: SOLAR + Vector2(0.0, -190.0)}
## The ship parts' nodes ring the ship (too many to sit on the hull itself):
## each at its own angle round SHIP_MIDDLE, in ship coordinates (0 towards the
## nose, 90 the belly), on an oval SHIP_RING across, with a dotted line in to
## where its part is (SHIP_SPOTS).
const SHIP_MIDDLE := Vector2(270.0, 180.0)
const SHIP_RING := Vector2(270.0, 190.0)
const SHIP_SLOTS := {12: 0.0, 7: 45.0, 13: 90.0, 11: 135.0, 6: 180.0, 10: 225.0, 9: 270.0, 8: 315.0}
const SHIP_SPOTS := {6: NOZZLE, 7: PATCH, 8: DOME, 9: ANTENNA_UP, 10: FIN_TIP, 11: Vector2(256.0, 204.0), 12: Vector2(466.0, 200.0), 13: Vector2(270.0, 262.0)}
const NODE_R := 32.0            # a node's circle, on screen
const EDGE_INSET := 44.0        # how far inside node_area an edge arrow sits

## Home turns the nodes on (once the camp is open to the player) and says
## which part of the screen its menus leave open, in this control's space.
var nodes_enabled := false
var node_area := Rect2()
var _nodes: Control             # the build nodes and edge arrows, over the world
var _node_hits: Array = []      # [rect, part] for the nodes drawn last frame
var _edge_hits: Array = []      # [rect, part] for the edge arrows
var _glide_to = null            # an offset the world is gliding to, or null

var _offset := Vector2.ZERO     # where the world sits on screen
const ZOOM := 0.85              # the world drawn a little small, so more of the camp shows
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
	_planet = PLANETS[(TSProfile.planet_number - 1) % PLANETS.size()]
	_sky = TSToon.sky_for_level(TSProfile.last_level)
	_set_pose()
	_make_scenery()

	_world = Control.new()
	_world.size = Vector2(W, H)
	_world.scale = Vector2.ONE * ZOOM
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_sky_layer = _layer(_draw_sky, -2.0)
	_ground = _layer(_draw_ground, -1.0)
	_pad_layer = _spot_layer(_draw_pad, _ship_depth - 2.0)
	_ship_layer = _layer(_draw_ship, _ship_depth)
	_props_layer = _layer(_draw_ship_props, _ship_depth + 1.0)
	_glass_layer = _layer(_draw_ship_glass, _ship_depth + 3.0)
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
	# The camp spots and the solar panels, each sorted in where it stands.
	for spot in [[_draw_campfire, FIRE], [_draw_tent, TENT], [_draw_bench, BENCH], [_draw_garden, GARDEN], [_draw_well, WELL], [_draw_lookout, LOOKOUT], [_draw_solar, SOLAR]]:
		_spot_layer(spot[0], (spot[1] as Vector2).y)
	if _jobs.has("crater"):
		_lip_layer = _layer(_draw_crater_lip, CRATER.y + 1.0)
	# The time of day, as on the player's current level (TSToon.SKIES): the
	# sky draws itself, and everything under it takes the light -- moonlit at
	# night, warm at sunset.
	# Two floodlights stand on the ground by the ship at night (their beams
	# are on the lights layer); the lamps themselves take the moonlight.
	if float(_sky["stars"]) > 0.5:
		_spot_layer(_draw_spot_lamps, _ship_depth + 40.0)
	for child in _world.get_children():
		if child != _sky_layer:
			(child as CanvasItem).modulate = _sky["world"]
	# At night the camp lights up: the fire, the ship, lanterns. Added on
	# top, untinted, brightening what is under them.
	if float(_sky["stars"]) > 0.5:
		_lights = _layer(_draw_lights, 1.0e9)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lights.material = add
	# The build nodes: on screen, over the world (and its night tint).
	_nodes = Control.new()
	_nodes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nodes.draw.connect(_draw_nodes)
	add_child(_nodes)
	_home_view()
	_process(0.0)


## A layer whose painter draws on it (it is passed the layer).
func _spot_layer(painter: Callable, depth: float) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter.bind(c))
	c.set_meta("depth", depth)
	_world.add_child(c)
	_painters.append(c)
	return c


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
	var keep_clear := [SHIP_AT, POND, MOUND, FIRE, CRATER, Vector2(1250, 930), CHASE, TENT, BENCH, GARDEN, WELL, LOOKOUT, SOLAR]
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
	# Centred on the ship as it stands (tall when it is upright on the pad).
	_offset = Vector2(view.x * 0.56, view.y * (0.39 if _stage < 2 else 0.33)) - (_ship_at + Vector2(-10.0, -10.0)) * ZOOM
	_clamp_offset()


func _view_size() -> Vector2:
	return size if size.x > 0.0 else Vector2(720.0, 1280.0)


func _clamp_offset() -> void:
	var view := _view_size()
	_offset.x = clampf(_offset.x, view.x - W * ZOOM, 0.0)
	_offset.y = clampf(_offset.y, view.y - H * ZOOM, 0.0)


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
			_glide_to = null
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
	for hit in _node_hits:
		if (hit[0] as Rect2).has_point(at):
			TSSfx.play("tap")
			part_tapped.emit(int(hit[1]))
			return
	for hit in _edge_hits:
		if (hit[0] as Rect2).has_point(at):
			TSSfx.play("tap")
			glide_to_part(int(hit[1]))
			return
	for c in _crew:
		var icon: TSIcon = c["icon"]
		if icon.get_global_rect().has_point(at):
			c["hop"] = _t
			TSSfx.play("tap")
			return


# -- build nodes ------------------------------------------------------------------

## Which parts show a node now: camp spots with a step left and -- only once
## the camp is finished -- ship parts with one left. None during lift-off.
func _node_parts() -> Array:
	var out: Array = []
	if not nodes_enabled or _launch_start != -1.0:
		return out
	for i in TSProfile.PART_COUNT:
		if TSProfile.is_part_available(i) and not TSProfile.is_part_max_level(i):
			out.append(i)
	return out


## Where a part's node floats, in world coordinates.
func _node_world(i: int) -> Vector2:
	if GROUND_NODES.has(i):
		return GROUND_NODES[i]
	var a := deg_to_rad(float(SHIP_SLOTS[i]))
	return _xf * (SHIP_MIDDLE + Vector2(cos(a) * SHIP_RING.x, sin(a) * SHIP_RING.y))


## Where a part's node is on screen (this control's space).
func node_screen_position(i: int) -> Vector2:
	return _world.position + _node_world(i) * ZOOM


## The open part of Home the nodes keep to.
func _area() -> Rect2:
	return node_area if node_area.has_area() else Rect2(Vector2.ZERO, _view_size())


## Glides the world over so a part's node sits in the middle of the open area
## (for a ship part, the ship and its whole ring of nodes).
func glide_to_part(i: int) -> void:
	var at := _xf * SHIP_MIDDLE if SHIP_SLOTS.has(i) else _node_world(i)
	var o := _area().get_center() - at * ZOOM
	var view := _view_size()
	_glide_to = Vector2(clampf(o.x, view.x - W * ZOOM, 0.0), clampf(o.y, view.y - H * ZOOM, 0.0))
	_velocity = Vector2.ZERO


## The part levels have changed (a node was spent): the scene catches up --
## and if enough of the ship is fixed, it is righted or set on its pad.
func refresh_parts() -> void:
	for i in TSProfile.PART_COUNT:
		_levels[i] = TSProfile.part_level_of(i)
	if launch_stage() != _stage:
		_set_pose()
		_pad_layer.set_meta("depth", _ship_depth - 2.0)
		_ship_layer.set_meta("depth", _ship_depth)
		_props_layer.set_meta("depth", _ship_depth + 1.0)
		_glass_layer.set_meta("depth", _ship_depth + 3.0)


func _draw_nodes() -> void:
	_node_hits.clear()
	_edge_hits.clear()
	var parts := _node_parts()
	if parts.is_empty():
		return
	var area := _area()
	var inner := area.grow(-NODE_R - 6.0)
	var off := {}   # side -> [how many, the nearest part, its distance]
	# The ship's dotted lines first, under every node.
	for i in parts:
		if SHIP_SPOTS.has(i) and inner.has_point(node_screen_position(i)):
			_leader(node_screen_position(i), _world.position + _xf * (SHIP_SPOTS[i] as Vector2) * ZOOM)
	for i in parts:
		var p := node_screen_position(i)
		if inner.has_point(p):
			_draw_node(i, p + Vector2(0.0, sin(_t * 2.4 + float(i)) * 4.0))
			continue
		var side := _side_of(p, inner)
		var d := p.distance_to(inner.get_center())
		if not off.has(side):
			off[side] = [0, i, d]
		off[side][0] += 1
		if d < float(off[side][2]):
			off[side][1] = i
			off[side][2] = d
	for side in off:
		_draw_edge_arrow(side, area, int(off[side][0]), int(off[side][1]))


## Which edge of the open area a point past it lies beyond (the farther-out one).
func _side_of(p: Vector2, inner: Rect2) -> Vector2:
	var past := Vector2(minf(p.x - inner.position.x, 0.0) + maxf(p.x - inner.end.x, 0.0), minf(p.y - inner.position.y, 0.0) + maxf(p.y - inner.end.y, 0.0))
	if absf(past.x) >= absf(past.y):
		return Vector2(signf(past.x), 0.0)
	return Vector2(0.0, signf(past.y))


## One node: a hammer (build or fix) or an arrow (upgrade) on a green disc
## when the coins are there (grey when not), its price on a pill below.
func _draw_node(i: int, p: Vector2) -> void:
	var ci := _nodes
	var cost := TSProfile.part_next_cost(i)
	var can := TSProfile.coin_count >= cost
	var r := NODE_R * (1.0 + 0.06 * sin(_t * 5.0) if can else 1.0)
	_ellipse(ci, p + Vector2(0.0, r + 6.0), r * 0.8, 7.0, SHADOW, false)
	ci.draw_circle(p, r + 4.0, INK, true, -1.0, true)
	ci.draw_circle(p, r, Color(0.56, 0.87, 0.58) if can else Color(0.86, 0.84, 0.86), true, -1.0, true)
	ci.draw_arc(p + Vector2(-4.0, -5.0), r * 0.62, PI * 1.05, PI * 1.55, 10, Color(1, 1, 1, 0.55), 4.0, true)
	if TSProfile.part_level_of(i) == 0:
		_hammer(ci, p, r * 0.62)
	else:
		_up_arrow(ci, p, r * 0.62)
	# The price.
	var font := TSToon.hand_font()
	var text := TSProfile.fmt_coins(cost)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var pill := Rect2(p + Vector2(-(tw + 34.0) * 0.5, r + 2.0), Vector2(tw + 34.0, 28.0))
	_round_rect(ci, pill, 14.0, Color(1.0, 0.98, 0.93), INK)
	ci.draw_circle(pill.position + Vector2(15.0, 14.0), 8.0, BUTTER, true, -1.0, true)
	ci.draw_arc(pill.position + Vector2(15.0, 14.0), 8.0, 0.0, TAU, 16, INK, 2.0, true)
	ci.draw_string(font, pill.position + Vector2(27.0, 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK if can else Color(INK, 0.5))
	_node_hits.append([Rect2(p - Vector2(r + 8.0, r + 8.0), Vector2(2.0 * r + 16.0, 2.0 * r + 46.0)), i])


## Nodes past an edge of the open area: an arrow at that edge, with how many,
## that glides the world to the nearest.
func _draw_edge_arrow(side: Vector2, area: Rect2, count: int, nearest: int) -> void:
	var ci := _nodes
	# Left and right arrows sit high, in the sky, clear of the ship's ring of
	# nodes; up is top middle, down the bottom right corner.
	var p := Vector2(area.get_center().x, area.position.y + EDGE_INSET)
	if side.x < 0.0:
		p = Vector2(area.position.x + EDGE_INSET, area.position.y + EDGE_INSET + 30.0)
	elif side.x > 0.0:
		p = Vector2(area.end.x - EDGE_INSET, area.position.y + EDGE_INSET + 30.0)
	elif side.y > 0.0:
		p = area.end - Vector2(EDGE_INSET, EDGE_INSET)
	p += side * (3.0 + 3.0 * sin(_t * 4.0))
	var r := 28.0
	ci.draw_circle(p, r + 4.0, INK, true, -1.0, true)
	ci.draw_circle(p, r, BUTTER, true, -1.0, true)
	var tip := p + side * r * 0.55
	var back := p - side * r * 0.35
	var across := Vector2(-side.y, side.x) * r * 0.5
	ci.draw_colored_polygon(PackedVector2Array([tip, back + across, back - across]), INK)
	# How many are that way.
	var badge := p + Vector2(r * 0.75, -r * 0.75)
	ci.draw_circle(badge, 13.0, INK, true, -1.0, true)
	ci.draw_circle(badge, 10.5, Color(1.0, 0.45, 0.5), true, -1.0, true)
	var font := TSToon.hand_font()
	var n := str(count)
	ci.draw_string(font, badge + Vector2(-font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x * 0.5, 6.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	_edge_hits.append([Rect2(p - Vector2(r + 10.0, r + 10.0), Vector2(2.0 * r + 20.0, 2.0 * r + 20.0)), nearest])


## A dotted line from a ship node in to its part, ending in a small ring.
func _leader(from: Vector2, to: Vector2) -> void:
	var d := to - from
	var n := int(d.length() / 14.0)
	for k in range(2, n):
		_nodes.draw_circle(from + d * float(k) / float(n), 3.0, Color(INK, 0.55), true, -1.0, true)
	_nodes.draw_arc(to, 9.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 4.0, true)
	_nodes.draw_arc(to, 9.0, 0.0, TAU, 20, Color(INK, 0.6), 2.0, true)


func _hammer(ci: CanvasItem, c: Vector2, s: float) -> void:
	var handle_a := c + Vector2(-0.75, 0.75) * s
	var handle_b := c + Vector2(0.25, -0.25) * s
	ci.draw_line(handle_a, handle_b, INK, s * 0.42, true)
	ci.draw_line(handle_a, handle_b, WOOD, s * 0.24, true)
	var head := [Vector2(-0.15, -0.95), Vector2(0.95, 0.15), Vector2(0.55, 0.55), Vector2(-0.55, -0.55)]
	var pts := PackedVector2Array()
	for h in head:
		pts.append(c + (h as Vector2) * s * 0.75 + Vector2(0.18, -0.18) * s)
	ci.draw_colored_polygon(pts, CHROME)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 3.0, true)


func _up_arrow(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0.0, -1.0) * s, c + Vector2(0.85, 0.0) * s, c + Vector2(0.35, 0.0) * s, c + Vector2(0.35, 0.9) * s, c + Vector2(-0.35, 0.9) * s, c + Vector2(-0.35, 0.0) * s, c + Vector2(-0.85, 0.0) * s])
	ci.draw_colored_polygon(pts, Color.WHITE)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 3.5, true)


func _round_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, line: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


# -- the crew ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if not _dragging and _velocity.length() > 5.0:
		_offset += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
		_clamp_offset()
	if _glide_to != null and not _dragging:
		_offset = _offset.lerp(_glide_to, minf(1.0, delta * 6.0))
		_clamp_offset()
		if _offset.distance_to(_glide_to) < 1.0:
			_glide_to = null
	_world.position = _offset.round()
	# Lift-off: a rumble on the pad, then the climb, crew and all.
	_xf = _pose
	if _launch_start >= 0.0:
		var since := _t - _launch_start
		if since < LAUNCH_RUMBLE:
			_xf.origin.x += sin(_t * 70.0) * 3.0
		_xf.origin.y -= _launch_lift()
		if since >= LAUNCH_SECONDS:
			_launch_start = -2.0   # done: the ship stays gone
			launched.emit()
	elif _launch_start < -1.0:
		_xf.origin.y -= 100000.0
	for c in _crew:
		_place(c)
	_sort()
	for p in _painters:
		(p as Control).queue_redraw()
	_nodes.queue_redraw()


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
			icon.rotation = _tilt + sin(t * 1.3) * 0.2
			depth = _ship_depth + 2.0
		"peek":
			centre = _xf * (PORTHOLES[1] + Vector2(sin(t * 0.8) * 5.0, 3.0 + sin(t * 1.4) * 6.0))
			icon.rotation = _tilt
			depth = _ship_depth + 2.0
		"bounce":
			var h := absf(sin(t * 2.6))
			centre = _xf * (DOME + Vector2(0.0, -DOME_R)) + Vector2(0.0, -stand - h * 60.0)
			var squash := maxf(0.0, 1.0 - h * 5.0)
			icon.scale = Vector2(1.0 + 0.18 * squash, 1.0 - 0.18 * squash)
			depth = _ship_depth + 4.0
		"nap":
			centre = _xf * Vector2(284.0, DECK_Y) + _ship_up() * (s * 0.36)
			icon.rotation = _tilt - PI * 0.5
			icon.scale = Vector2(1.0, 1.0 + sin(t * 1.5) * 0.04)
			depth = _ship_depth + 4.0
		"swing":
			centre = _xf * _antenna_tip() + Vector2(0.0, 30.0 + stand).rotated(sin(t * 1.8) * 0.5)
			icon.rotation = sin(t * 1.8) * 0.5
			depth = _ship_depth + 4.0
		"perch":
			centre = _xf * FIN_TIP + Vector2(0.0, -stand + 2.0)
			icon.rotation = sin(t * 0.7) * 0.08
			depth = _ship_depth + 4.0
		"bubbles":
			centre = _xf * HATCH + _ship_up() * (stand + 2.0)
			icon.rotation = _tilt * 0.5
			depth = _ship_depth + 4.0
		"mechanic":
			centre = _mechanic_spot() + Vector2(0.0, sin(t * 1.6) * 2.0)
			icon.rotation = -0.15 + sin(t * 6.0) * 0.05
			depth = _ship_depth + 4.0
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
	# Upright on the pad, the deck and dome face sideways, so the critters that
	# lounged on them move to the gantry and the pad. They stay behind at
	# lift-off; the pilot, the peeker and the antenna swinger ride along.
	if _stage == 2:
		match job:
			"bounce":
				var h := absf(sin(t * 2.6))
				centre = PAD + Vector2(120.0, -stand - h * 60.0)
				depth = PAD.y + 1.0
			"nap":
				centre = Vector2(PAD.x + 160.0, PAD.y - 150.0 - s * 0.36)
				icon.rotation = -PI * 0.5
				depth = PAD.y + 1.0
			"bubbles":
				centre = Vector2(PAD.x + 160.0, PAD.y - 330.0 - stand)
				icon.rotation = 0.0
				depth = PAD.y + 1.0
			"perch":
				centre = Vector2(PAD.x + 180.0, PAD.y - 520.0 - stand)
				depth = PAD.y + 1.0
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
	return Vector2(0.0, -1.0).rotated(_tilt)


func _mechanic_spot() -> Vector2:
	# On the pad the engine is at the bottom, so the mechanic stands beside it.
	if _stage == 2:
		return _xf * NOZZLE + Vector2(80.0, 10.0)
	return _xf * NOZZLE + Vector2(16.0, 70.0)


# -- launch prep ------------------------------------------------------------------

## The stage of launch prep: crashed until half the ship's parts are fixed,
## then righted on its legs amid scaffolding, then -- every part fixed --
## upright on the launch pad.
static func launch_stage() -> int:
	if TSProfile.is_ship_ready():
		return 2
	var fixed := 0
	var parts := 0
	for i in TSProfile.PART_COUNT:
		if not TSProfile.is_camp(i):
			parts += 1
			if TSProfile.is_part_fixed(i):
				fixed += 1
	return 1 if fixed * 2 >= parts else 0


# Where the ship sits for the stage: tipped nose-down in the dirt, level on
# its legs, or standing nose-up on the pad (the ship is drawn flying right, so
# upright is a quarter turn back).
func _set_pose() -> void:
	_stage = launch_stage()
	match _stage:
		0:
			_tilt = SHIP_TILT
			_ship_at = SHIP_AT
			_ship_depth = SHIP_DEPTH
		1:
			_tilt = 0.0
			_ship_at = SHIP_AT + Vector2(0.0, -24.0)
			_ship_depth = SHIP_AT.y + 70.0
		_:
			_tilt = -PI * 0.5
			_ship_at = PAD + Vector2(0.0, -250.0)
			_ship_depth = PAD.y
	_pose = Transform2D(_tilt, Vector2.ONE, 0.0, Vector2.ZERO)
	_pose.origin = _ship_at - _pose.basis_xform(SHIP_PIN)
	_xf = _pose


## Lift-off: the ship roars up out of sight with its crew aboard, then
## `launched` fires. Only once it is on the pad.
func launch() -> void:
	if _stage == 2 and _launch_start < 0.0:
		_launch_start = _t


func _launch_lift() -> float:
	if _launch_start < 0.0:
		return 0.0
	var since := _t - _launch_start
	var burn := maxf(since - LAUNCH_RUMBLE, 0.0)
	return 0.5 * LAUNCH_ACCEL * burn * burn


# Behind the ship: the scaffolding while it is righted, and the launch pad,
# gantry, fuel hose and countdown board once it is on the pad -- with bunting
# when it is nearly done and sweeping searchlights when it is fully upgraded.
func _draw_pad(ci: Control) -> void:
	var readiness := TSProfile.ship_readiness()
	if _stage == 1:
		for x in [-230.0, -60.0, 110.0, 250.0]:
			ci.draw_line(_ship_at + Vector2(x, 100), _ship_at + Vector2(x, -120), WOOD, 8.0, true)
		for y in [-100.0, 10.0]:
			ci.draw_line(_ship_at + Vector2(-250, y), _ship_at + Vector2(270, y), WOOD.lightened(0.1), 10.0, true)
		for x in [-230.0, 110.0]:
			ci.draw_line(_ship_at + Vector2(x, -100), _ship_at + Vector2(x + 170, 10), WOOD.darkened(0.1), 5.0, true)
		_sign(ci, _ship_at + Vector2(-60.0, -100.0), "LAUNCH PREP", ACCENT)   # up on the scaffold, clear of the crew
		return
	if _stage != 2:
		return
	if readiness >= 1.0 and _launch_start < 0.0:
		for side in [-1.0, 1.0]:
			var sweep := sin(_t * 0.6 + side) * 0.35
			var foot := PAD + Vector2(side * 150.0, 0.0)
			var dir := Vector2(0.0, -1.0).rotated(sweep + side * 0.25)
			var beam := PackedVector2Array([foot, foot + dir.rotated(-0.08) * 900.0, foot + dir.rotated(0.08) * 900.0])
			ci.draw_colored_polygon(beam, Color(1.0, 0.97, 0.7, 0.18))
	# The gantry: a lattice tower with arms reaching to the ship.
	var gx := PAD.x + 180.0
	var top := PAD.y - 520.0
	for x in [gx - 30.0, gx + 30.0]:
		ci.draw_line(Vector2(x, PAD.y), Vector2(x, top), INK, 9.0, true)
		ci.draw_line(Vector2(x, PAD.y), Vector2(x, top), Color(1.0, 0.6, 0.4), 5.0, true)
	for n in 8:
		var y0 := PAD.y - n * 65.0
		ci.draw_line(Vector2(gx - 30, y0), Vector2(gx + 30, y0 - 65), Color(1.0, 0.6, 0.4), 3.0, true)
	for y in [PAD.y - 150.0, PAD.y - 330.0]:
		ci.draw_line(Vector2(gx - 30, y), Vector2(PAD.x + 80.0, y), INK, 8.0, true)
		ci.draw_line(Vector2(gx - 30, y), Vector2(PAD.x + 80.0, y), CHROME, 4.0, true)
	if readiness >= 0.75:
		var colours := [Color(1.0, 0.62, 0.74), BUTTER, ACCENT, Color(0.62, 0.9, 0.66)]
		for side in [-1.0, 1.0]:
			var from := Vector2(gx, top)
			var to := PAD + Vector2(side * 260.0 + (80.0 if side > 0 else 0.0), 20.0)
			for n in 10:
				var u := (float(n) + 0.5) / 10.0
				var p := from.lerp(to, u) + Vector2(0.0, sin(u * PI) * 40.0)
				_blob(ci, [p + Vector2(-8, 0), p + Vector2(8, 0), p + Vector2(0, 14)], colours[n % 4], false)
	# The pad, with a fuel tank and hose.
	_ellipse(ci, PAD + Vector2(0, 14), 220.0, 44.0, SHADOW, false)
	_ellipse(ci, PAD, 200.0, 40.0, Color(0.8, 0.8, 0.86))
	_ellipse(ci, PAD, 130.0, 24.0, Color(0.9, 0.9, 0.94), false)
	for n in 6:
		var a := TAU * float(n) / 6.0 + 0.3
		ci.draw_line(PAD + Vector2(cos(a) * 140.0, sin(a) * 28.0), PAD + Vector2(cos(a) * 190.0, sin(a) * 38.0), BUTTER, 6.0, true)
	var tank := PAD + Vector2(-260.0, 30.0)
	_blob(ci, [tank + Vector2(-34, -80), tank + Vector2(34, -80), tank + Vector2(34, 0), tank + Vector2(-34, 0)], Color(0.94, 0.94, 0.98))
	ci.draw_line(tank + Vector2(-34, -40), tank + Vector2(34, -40), Color(1.0, 0.45, 0.5), 8.0, true)
	var hose := PackedVector2Array()
	for n in 9:
		var u := float(n) / 8.0
		hose.append((tank + Vector2(30.0, -20.0)).lerp(_ship_at + Vector2(-70.0, 120.0), u) + Vector2(0.0, sin(u * PI) * 30.0))
	if _launch_start < 0.0:
		ci.draw_polyline(hose, INK, 7.0, true)
		ci.draw_polyline(hose, Color(0.5, 0.52, 0.6), 4.0, true)
	# The countdown board, bolted across the gantry and out past its right leg
	# so it shows in Home's opening view.
	var lines: Array[String] = []
	var colour := ACCENT
	if TSProfile.can_launch():
		lines = ["LAUNCH!"]
		colour = Color(1.0, 0.45, 0.5) if fposmod(_t, 1.0) < 0.6 else BUTTER
	elif TSProfile.has_launched_this_season():
		lines = ["NEXT", "SEASON"]
	else:
		var days := TSProfile.days_to_launch_window()
		lines = ["LAUNCH IN", "%d DAY%s" % [days, "" if days == 1 else "S"]]
	_gantry_board(ci, Vector2(gx - 30.0, PAD.y - 505.0), lines, colour)


# A board bolted to the gantry at `left_top`, its lines shrunk to fit.
func _gantry_board(ci: Control, left_top: Vector2, lines: Array[String], colour: Color) -> void:
	var font := TSToon.hand_font()
	var width := 200.0
	var fs := 40
	for line in lines:
		while fs > 14 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width - 20.0:
			fs -= 1
	var line_h := float(fs) + 6.0
	var board := Rect2(left_top, Vector2(width, line_h * lines.size() + 18.0))
	ci.draw_rect(board, colour)
	ci.draw_rect(board, INK, false, 4.0)
	for n in lines.size():
		var w := font.get_string_size(lines[n], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, Vector2(board.get_center().x - w * 0.5, board.position.y + 9.0 + line_h * (n + 1) - 6.0), lines[n], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


# A signboard on a post.
func _sign(ci: Control, foot: Vector2, text: String, colour: Color) -> void:
	var font := TSToon.hand_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 36.0
	ci.draw_line(foot, foot + Vector2(0, -80), WOOD, 8.0, true)
	var board := Rect2(foot + Vector2(-width * 0.5, -140), Vector2(width, 64))
	ci.draw_rect(board, colour)
	ci.draw_rect(board, INK, false, 4.0)
	ci.draw_string(font, board.position + Vector2(18.0, 43.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)


# -- the world ------------------------------------------------------------------

## The sky at the time of day of the player's current level, as in the game
## (TSToon.SKIES): its colours top to horizon, soft sparkles by day that turn
## into bright twinkling stars at night, the sun -- or a crescent moon -- and
## this world's own ringed planet and little moon.
func _draw_sky() -> void:
	var ci := _sky_layer
	var top: Color = _sky["top"]
	var low: Color = _sky["bottom"]
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 420), Vector2(0, 420)]),
		PackedColorArray([top, top, low, low]))
	var night := float(_sky["stars"]) > 0.5
	for st in _stars:
		var r: float = float(st[1]) * (0.7 + 0.3 * sin(_t * 2.2 + float(st[2])))
		_sparkle(ci, st[0], r, Color(1.0, 0.9, 0.6, 0.95) if night else Color(_sky["dots"], 0.9))
	var orb: Color = _sky["orb"]
	if orb.a > 0.0:
		ci.draw_circle(SUN, SUN_R * 1.8, Color(orb, 0.2 * orb.a), true, -1.0, true)
		ci.draw_circle(SUN, SUN_R, Color(orb, orb.a), true, -1.0, true)
		if float(_sky["crescent"]) > 0.5:
			# The bite out of the moon: a disc of the sky behind it.
			var bite := SUN + Vector2(SUN_R * 0.45, -SUN_R * 0.3)
			ci.draw_circle(bite, SUN_R * 0.82, top.lerp(low, bite.y / 420.0), true, -1.0, true)
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


## The camp's lights at night, drawn additively over the moonlit world. Each
## is a faint halo where it hangs and a pool of light it casts on the ground
## below, flattened to lie on the floor: a big warm flickering one round the
## campfire (bigger once upgraded), a lantern's at every camp spot built, and
## a faint one under the ship from its lit portholes -- with red and green
## lights blinking on its fins and a red one on the antenna.
func _draw_lights() -> void:
	var ci := _lights
	var flick := 0.9 + 0.07 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)
	var fire := _lv(TSProfile.CAMP_FIRE)
	if fire >= 1:
		var k := _depth_scale(FIRE.y)
		var reach := (440.0 if fire >= 4 else 340.0) * flick * k
		_pool(ci, FIRE + Vector2(0, 6) * k, reach, Color(1.0, 0.58, 0.25), 0.34)
		_glow(ci, FIRE + Vector2(0, -26) * k, 90.0 * flick * k, Color(1.0, 0.7, 0.35), 0.22)
	if _launch_start < 0.0:
		if _lv(TSProfile.PART_PORTHOLES) >= 1:
			_pool(ci, Vector2(_ship_at.x, _ship_depth), 300.0, Color(1.0, 0.8, 0.5), 0.12)
			for p in PORTHOLES:
				_glow(ci, _xf * (p as Vector2), 40.0, Color(1.0, 0.8, 0.45), 0.18)
		var blink := fposmod(_t, 1.2) < 0.6
		_glow(ci, _xf * FIN_TIP, 24.0, Color(1.0, 0.25, 0.25) if blink else Color(0.25, 1.0, 0.4), 0.45)
		_glow(ci, _xf * Vector2(100.0, 306.0), 24.0, Color(0.25, 1.0, 0.4) if blink else Color(1.0, 0.25, 0.25), 0.45)
		if _lv(TSProfile.PART_ANTENNA) >= 1 and fposmod(_t, 0.9) < 0.3:
			_glow(ci, _xf * _antenna_tip(), 20.0, Color(1.0, 0.3, 0.3), 0.5)
		# The floodlights' beams: bright at the lens, fading as they widen up
		# to the hull, where each leaves a lit patch drifting along it.
		for s in _spotlights():
			var lamp: Vector2 = s[0]
			var aim: Vector2 = s[1]
			var dir := (aim - lamp).normalized()
			var across := Vector2(-dir.y, dir.x)
			var lens := lamp + dir * 18.0
			ci.draw_polygon(PackedVector2Array([lens + across * 9.0, lens - across * 9.0, aim - across * 80.0, aim + across * 80.0]),
				PackedColorArray([Color(SPOT_BEAM, 0.32), Color(SPOT_BEAM, 0.32), Color(SPOT_BEAM, 0.05), Color(SPOT_BEAM, 0.05)]))
			_glow(ci, aim, 100.0, SPOT_BEAM, 0.3)
			_glow(ci, lens, 24.0, Color(1.0, 1.0, 0.92), 0.7)
			_pool(ci, lamp + Vector2(0, 30), 110.0, SPOT_BEAM, 0.14)
	for spot in [[TSProfile.CAMP_TENT, TENT, Vector2(-66, -70)], [TSProfile.CAMP_BENCH, BENCH, Vector2(70, -60)],
			[TSProfile.CAMP_GARDEN, GARDEN, Vector2(-70, -50)], [TSProfile.CAMP_WELL, WELL, Vector2(0, -130)],
			[TSProfile.CAMP_LOOKOUT, LOOKOUT, Vector2(0, -175)]]:
		if _lv(int(spot[0])) < 1:
			continue
		var at: Vector2 = spot[1]
		var k := _depth_scale(at.y)
		var lamp: Vector2 = at + (spot[2] as Vector2) * k
		_pool(ci, Vector2(lamp.x, at.y + 6.0 * k), 190.0 * flick * k, Color(1.0, 0.75, 0.42), 0.24)
		_glow(ci, lamp, 56.0 * flick * k, Color(1.0, 0.75, 0.4), 0.2)
		ci.draw_circle(lamp, 5.0 * k, Color(1.0, 0.88, 0.6, 0.7), true, -1.0, true)


## The ship's two floodlights at night: [where the lamp stands, the point on
## the hull it lights], one each side in front of the ship, their aim drifting
## slowly along the hull. They follow the ship's pose (_xf).
func _spotlights() -> Array:
	var out: Array = []
	for side in [-1.0, 1.0]:
		var s: float = side
		var lamp := Vector2(_ship_at.x + s * 330.0, _ship_depth + 70.0)
		var aim := _xf * Vector2(245.0 + s * 80.0 + sin(_t * 0.5 + s) * 35.0, 200.0)
		out.append([lamp, aim])
	return out


## The floodlights themselves: a lamp on a little stand, turned to its aim.
func _draw_spot_lamps(ci: Control) -> void:
	for s in _spotlights():
		var lamp: Vector2 = s[0]
		var aim: Vector2 = s[1]
		for leg in [-16.0, 16.0]:
			ci.draw_line(lamp, lamp + Vector2(leg, 36.0), INK, 5.0, true)
		ci.draw_set_transform(lamp, (aim - lamp).angle(), Vector2.ONE)
		_blob(ci, [Vector2(-20, -14), Vector2(16, -18), Vector2(16, 18), Vector2(-20, 14)], Color(0.38, 0.39, 0.46))
		ci.draw_rect(Rect2(14.0, -16.0, 6.0, 32.0), Color(0.96, 0.95, 0.84))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# A soft halo of light: rings of `colour`, adding up to `strength` at the
# middle and fading smoothly to nothing at `radius` (on the additive layer).
func _glow(ci: CanvasItem, at: Vector2, radius: float, colour: Color, strength: float) -> void:
	for k in 10:
		ci.draw_circle(at, radius * (1.0 - float(k) * 0.095), Color(colour, strength / 10.0), true, -1.0, true)


# The light a lamp casts on the ground: a halo squashed flat to lie on the
# floor, as seen from the camera's low angle.
func _pool(ci: CanvasItem, at: Vector2, radius: float, colour: Color, strength: float) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(1.0, 0.34))
	_glow(ci, Vector2.ZERO, radius, colour, strength)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ground() -> void:
	var ci := _ground
	# The planet's surface, curving away at the edges of the world.
	var ground := PackedVector2Array()
	for k in 41:
		var x := W * float(k) / 40.0
		ground.append(Vector2(x, _horizon(x)))
	var rim := ground.duplicate()
	ground.append(Vector2(W, H))
	ground.append(Vector2(0.0, H))
	ci.draw_colored_polygon(ground, _planet["ground"])
	# A darker band along the horizon, for depth.
	var band := rim.duplicate()
	for k in range(40, -1, -1):
		var x := W * float(k) / 40.0
		band.append(Vector2(x, _horizon(x) + 26.0))
	ci.draw_colored_polygon(band, _planet["ground_dark"])
	ci.draw_polyline(rim, INK, 5.0, true)
	for item in _scatter:
		var p: Vector2 = item[1]
		var k: float = float(item[2]) * _depth_scale(p.y)
		match item[0]:
			"crater":
				_ellipse(ci, p, 46.0 * k, 12.0 * k, _planet["ground_dark"], false)
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
	if _stage < 2:
		_ellipse(ci, Vector2(_ship_at.x - 20.0, _ship_depth + 13.0), 250.0, 30.0, SHADOW, false)
	for c in _crew:
		if ON_SHIP.has(c["job"]) or c["job"] == "crater":
			continue
		var s: float = c["size"]
		var lift := (c["feet"] as Vector2).y - ((c["centre"] as Vector2).y + s * 0.43)
		var shrink := clampf(1.0 - lift / 120.0, 0.5, 1.0)
		_ellipse(ci, c["feet"], s * 0.36 * shrink, s * 0.09 * shrink, SHADOW, false)


func _draw_ship() -> void:
	var ci := _ship_layer
	# Landing legs, behind the hull: standing once fixed, with springs, foot
	# lights and gold as they are upgraded. (Snapped, one lies in the dirt;
	# see _draw_ship_props.)
	var legs := _lv(TSProfile.PART_LEGS)
	if legs >= 1:
		var leg_col := GOLD if legs >= 4 else CHROME
		var hips := [Vector2(96.0, 150.0), Vector2(96.0, 250.0)] if _stage == 2 else [Vector2(210.0, 250.0), Vector2(330.0, 254.0)]
		for leg_i in hips.size():
			var hip: Vector2 = hips[leg_i]
			var top: Vector2 = _xf * hip
			var foot := top + Vector2(-50.0 if leg_i == 0 else 50.0, 60.0) if _stage == 2 else Vector2(top.x - 14.0, _ship_depth + (26.0 if _stage == 0 else 10.0))
			ci.draw_line(top, foot, INK, 12.0, true)
			ci.draw_line(top, foot, leg_col, 7.0, true)
			if legs >= 2:
				var coil := PackedVector2Array()
				for n in 9:
					var u := 0.25 + 0.3 * float(n) / 8.0
					coil.append(top.lerp(foot, u) + Vector2(9.0 if n % 2 == 0 else -9.0, 0.0))
				ci.draw_polyline(coil, INK, 3.0, true)
			_ellipse(ci, foot, 22.0, 7.0, leg_col)
			if legs >= 3:
				var on := fposmod(_t + hip.x * 0.01, 1.0) < 0.5
				ci.draw_circle(foot + Vector2(0, -6), 5.0, Color(0.6, 1.0, 0.6) if on else Color(0.4, 0.5, 0.4), true, -1.0, true)
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
		if _launch_start >= 0.0:
			reach = (70.0 if _t - _launch_start < LAUNCH_RUMBLE else 190.0) * flick   # lift-off!
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
	# The nose cone, once dug out: painted, then a racing stripe, a blinking
	# nose light and a gold tip.
	var nose := _lv(TSProfile.PART_NOSE)
	if nose >= 1:
		var cone := [Vector2(438, 150), Vector2(466, 166), Vector2(486, 200), Vector2(466, 234), Vector2(438, 250)]
		_blob(ci, cone, GOLD if nose >= 4 else _trim)
		if nose >= 2:
			ci.draw_line(Vector2(452, 158), Vector2(452, 242), ACCENT, 7.0, true)
		if nose >= 3:
			var on := fposmod(_t, 1.0) < 0.5
			ci.draw_circle(Vector2(482, 200), 8.0, INK, true, -1.0, true)
			ci.draw_circle(Vector2(482, 200), 5.5, Color(1.0, 0.45, 0.55) if on else Color(0.6, 0.4, 0.45), true, -1.0, true)
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
	# The heap the nose ploughed into: half of it dug away once the nose cone
	# is fixed.
	var dug: float = [1.0 if _lv(TSProfile.PART_NOSE) == 0 else 0.55, 0.45, 0.3][_stage]
	var heap := PackedVector2Array()
	for k in 19:
		var a := PI + PI * float(k) / 18.0
		heap.append(MOUND + Vector2(20.0 * (1.0 - dug), 0.0) + Vector2(cos(a) * 80.0, sin(a) * 36.0 * dug + 10.0))
	ci.draw_colored_polygon(heap, DIRT)
	ci.draw_polyline(heap, INK, 5.0, true)
	for clod in [Vector2(-40, -6), Vector2(16, -20), Vector2(46, 0)]:
		ci.draw_circle(MOUND + Vector2(clod.x, clod.y * dug), 6.0, DIRT.darkened(0.2), true, -1.0, true)
	if _lv(TSProfile.PART_LEGS) == 0:
		# A snapped landing leg in the dirt beside the ship.
		var leg := SHIP_AT + Vector2(-120.0, 100.0)
		ci.draw_line(leg, leg + Vector2(-70, -10), INK, 11.0, true)
		ci.draw_line(leg, leg + Vector2(-70, -10), Color(0.7, 0.7, 0.76), 6.0, true)
		ci.draw_line(leg + Vector2(12, 4), leg + Vector2(60, 16), INK, 11.0, true)
		ci.draw_line(leg + Vector2(12, 4), leg + Vector2(60, 16), Color(0.7, 0.7, 0.76), 6.0, true)
		_ellipse(ci, leg + Vector2(66, 18), 18.0, 6.0, Color(0.7, 0.7, 0.76))
	if _jobs.has("mechanic") and _stage < 2:
		var top := _mechanic_spot() + Vector2(0.0, 28.0)
		var foot := Vector2(top.x - 18.0, _ship_depth + 45.0)
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


# -- the camp (TSProfile.PARTS' camp spots) and the ground-side ship parts ----------
# Each spot is drawn at its level: 0 is a wreck or a heap of makings, 1 built,
# and each upgrade adds something. `ci` is the spot's own layer, sorted into
# the scene by how far back it stands.

func _draw_campfire(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_FIRE)
	var k := _depth_scale(FIRE.y)
	_ellipse(ci, FIRE + Vector2(0, 8) * k, 50.0 * k, 12.0 * k, SHADOW, false)
	if lv >= 2:
		for n in 8:
			var a := TAU * float(n) / 8.0
			_ellipse(ci, FIRE + Vector2(cos(a) * 44.0, sin(a) * 12.0 + 6.0) * k, 11.0 * k, 7.0 * k, Color(0.74, 0.72, 0.78))
	for turn in [0.4, -0.4]:
		ci.draw_line(FIRE + Vector2(-26, 6).rotated(turn) * k, FIRE + Vector2(26, 6).rotated(turn) * k, WOOD.darkened(0.45) if lv == 0 else WOOD, 10.0 * k, true)
	if lv == 0:
		_ellipse(ci, FIRE + Vector2(0, 4) * k, 24.0 * k, 7.0 * k, Color(0.7, 0.68, 0.72), false)
		var age := fposmod(_t * 0.25, 1.0)
		ci.draw_circle(FIRE + Vector2(sin(age * 6.0) * 8.0, -20.0 - age * 70.0) * k, (6.0 + age * 12.0) * k, Color(0.66, 0.64, 0.7, (1.0 - age) * 0.5), true, -1.0, true)
		return
	var big := 1.6 if lv >= 4 else 1.0
	var flick := (1.0 + 0.15 * sin(_t * 17.0)) * big
	_blob(ci, [FIRE + Vector2(-20 * big, 0) * k, FIRE + Vector2(0, -50.0 * flick) * k, FIRE + Vector2(20 * big, 0) * k], Color(1.0, 0.55, 0.3))
	_blob(ci, [FIRE + Vector2(-10 * big, 0) * k, FIRE + Vector2(0, -26.0 * flick) * k, FIRE + Vector2(10 * big, 0) * k], BUTTER, false)
	if lv >= 3:
		# A pot on a tripod, bubbling.
		for leg in [-1.0, 1.0]:
			ci.draw_line(FIRE + Vector2(leg * 40.0, 8.0) * k, FIRE + Vector2(0, -70.0) * k, INK, 4.0 * k, true)
		var pot := FIRE + Vector2(0, -44.0) * k
		ci.draw_line(FIRE + Vector2(0, -70.0) * k, pot + Vector2(0, -12.0) * k, INK, 2.0 * k, true)
		_blob(ci, [pot + Vector2(-18, -10) * k, pot + Vector2(18, -10) * k, pot + Vector2(14, 12) * k, pot + Vector2(-14, 12) * k], Color(0.42, 0.4, 0.5))
		for n in 3:
			var age := fposmod(_t * 0.6 + float(n) / 3.0, 1.0)
			ci.draw_arc(pot + Vector2(-8.0 + n * 8.0, -16.0 - age * 30.0) * k, (3.0 + age * 4.0) * k, 0.0, TAU, 10, Color(1, 1, 1, 1.0 - age), 2.0, true)
	if lv >= 4:
		for n in 4:
			var age := fposmod(_t * 0.7 + float(n) / 4.0, 1.0)
			_sparkle(ci, FIRE + Vector2(sin(age * 9.0 + n) * 20.0, -60.0 - age * 90.0) * k, 5.0 * k * (1.0 - age), Color(1.0, 0.7, 0.3))


func _draw_tent(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_TENT)
	var k := _depth_scale(TENT.y)
	var w := (100.0 if lv >= 4 else 80.0) * k
	var h := (130.0 if lv >= 4 else 110.0) * k
	_ellipse(ci, TENT + Vector2(0, 6) * k, w * 1.15, 16.0 * k, SHADOW, false)
	if lv == 0:
		ci.draw_line(TENT + Vector2(-50, 0) * k, TENT + Vector2(-40, -44) * k, WOOD, 5.0 * k, true)
		_blob(ci, [TENT + Vector2(-90, 4) * k, TENT + Vector2(-40, -40) * k, TENT + Vector2(30, -14) * k, TENT + Vector2(90, 6) * k], Color(0.84, 0.72, 0.76))
		ci.draw_line(TENT + Vector2(-20, -20) * k, TENT + Vector2(10, -4) * k, INK, 2.0, true)
		return
	var canvas := Color(1.0, 0.62, 0.74)
	_blob(ci, [TENT + Vector2(-w, 0), TENT + Vector2(0, -h), TENT + Vector2(w, 0)], canvas)
	_blob(ci, [TENT + Vector2(-22, 0) * k, TENT + Vector2(0, -h * 0.55), TENT + Vector2(22, 0) * k], Color(0.5, 0.3, 0.34) if lv < 4 else Color(1.0, 0.86, 0.5))
	if lv >= 2:
		var top := TENT + Vector2(0, -h)
		ci.draw_line(top, top + Vector2(0, -44) * k, INK, 4.0 * k, true)
		var cloth := PackedVector2Array()
		for n in 5:
			var u := float(n) / 4.0
			cloth.append(top + Vector2(u * 34.0, -44.0 + sin(u * 5.0 - _t * 6.0) * 3.0 * u) * k)
		for n in range(4, -1, -1):
			var u := float(n) / 4.0
			cloth.append(top + Vector2(u * 34.0, -26.0 + sin(u * 5.0 - _t * 6.0) * 3.0 * u) * k)
		ci.draw_colored_polygon(cloth, ACCENT)
		ci.draw_polyline(cloth, INK, 2.5, true)
	if lv >= 3:
		var bulbs := [Color(1.0, 0.86, 0.4), Color(0.62, 0.8, 1.0), Color(1.0, 0.62, 0.74), Color(0.62, 0.9, 0.66)]
		for side in [-1.0, 1.0]:
			for n in 5:
				var u := (float(n) + 0.5) / 5.0
				var p := TENT + Vector2(side * w * (1.0 - u), -h * u)
				var on := fposmod(_t * 2.0 + n + side, 2.0) < 1.4
				ci.draw_circle(p, 5.0 * k, bulbs[n % 4] if on else bulbs[n % 4].darkened(0.4), true, -1.0, true)
	if lv >= 4:
		# A lantern by the door, glowing.
		var lamp := TENT + Vector2(-w - 16.0 * k, -40.0 * k)
		ci.draw_line(lamp + Vector2(0, 40) * k, lamp, WOOD, 4.0 * k, true)
		ci.draw_circle(lamp, 16.0 * k, Color(1.0, 0.9, 0.5, 0.3 + 0.1 * sin(_t * 3.0)), true, -1.0, true)
		ci.draw_circle(lamp, 7.0 * k, BUTTER, true, -1.0, true)


func _draw_bench(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_BENCH)
	var k := _depth_scale(BENCH.y)
	var plank := Color(0.78, 0.56, 0.38)
	_ellipse(ci, BENCH + Vector2(0, 6) * k, 90.0 * k, 14.0 * k, SHADOW, false)
	if lv == 0:
		for n in 3:
			var at := BENCH + Vector2(-60.0 + n * 30.0, -4.0 - n * 6.0) * k
			var pts: Array = []
			for c in [Vector2(-40, -6), Vector2(40, -6), Vector2(40, 6), Vector2(-40, 6)]:
				pts.append(at + (c as Vector2).rotated(-0.3 + n * 0.3) * k)
			_blob(ci, pts, plank.darkened(0.15))
		return
	if lv >= 4:
		# A striped awning over it all.
		for x in [-80.0, 80.0]:
			ci.draw_line(BENCH + Vector2(x, 0) * k, BENCH + Vector2(x, -130) * k, WOOD, 5.0 * k, true)
		for n in 6:
			var x0 := -90.0 + n * 30.0
			_blob(ci, [BENCH + Vector2(x0, -140) * k, BENCH + Vector2(x0 + 30, -140) * k, BENCH + Vector2(x0 + 30, -118) * k, BENCH + Vector2(x0 + 15, -110) * k, BENCH + Vector2(x0, -118) * k], Color(1.0, 0.62, 0.74) if n % 2 == 0 else Color.WHITE)
	if lv >= 2:
		# A tool rack behind: a wrench and a hammer.
		_blob(ci, [BENCH + Vector2(-60, -110) * k, BENCH + Vector2(60, -110) * k, BENCH + Vector2(60, -62) * k, BENCH + Vector2(-60, -62) * k], plank.darkened(0.2))
		ci.draw_line(BENCH + Vector2(-30, -100) * k, BENCH + Vector2(-30, -70) * k, CHROME, 6.0 * k, true)
		ci.draw_line(BENCH + Vector2(20, -100) * k, BENCH + Vector2(20, -72) * k, WOOD, 5.0 * k, true)
		ci.draw_line(BENCH + Vector2(8, -100) * k, BENCH + Vector2(32, -100) * k, Color(0.5, 0.5, 0.56), 8.0 * k, true)
	for x in [-56.0, 56.0]:
		ci.draw_line(BENCH + Vector2(x, 0) * k, BENCH + Vector2(x, -48) * k, INK, 9.0 * k, true)
		ci.draw_line(BENCH + Vector2(x, 0) * k, BENCH + Vector2(x, -48) * k, plank, 5.0 * k, true)
	_blob(ci, [BENCH + Vector2(-72, -60) * k, BENCH + Vector2(72, -60) * k, BENCH + Vector2(72, -46) * k, BENCH + Vector2(-72, -46) * k], plank)
	if lv >= 3:
		var lamp := BENCH + Vector2(46, -76) * k
		ci.draw_circle(lamp, 22.0 * k, Color(1.0, 0.9, 0.5, 0.25 + 0.1 * sin(_t * 2.5)), true, -1.0, true)
		ci.draw_line(BENCH + Vector2(46, -60) * k, lamp, INK, 3.0 * k, true)
		ci.draw_circle(lamp, 8.0 * k, BUTTER, true, -1.0, true)


func _draw_garden(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_GARDEN)
	var k := _depth_scale(GARDEN.y)
	_ellipse(ci, GARDEN, 110.0 * k, 36.0 * k, Color(0.66, 0.5, 0.38))
	if lv == 0:
		return
	for row in 3:
		for n in 5:
			var p := GARDEN + Vector2(-72.0 + n * 36.0 + row * 6.0, -18.0 + row * 16.0) * k
			var sway := sin(_t * 1.5 + n + row) * 2.0
			ci.draw_line(p, p + Vector2(sway, -16) * k, Color(0.36, 0.62, 0.44), 3.0 * k, true)
			_ellipse(ci, p + Vector2(sway - 5, -16) * k, 6.0 * k, 3.0 * k, Color(0.56, 0.86, 0.5), false)
			_ellipse(ci, p + Vector2(sway + 5, -16) * k, 6.0 * k, 3.0 * k, Color(0.56, 0.86, 0.5), false)
			var kind := (n + row) % 3
			if lv >= 2 and kind == 0:
				ci.draw_circle(p + Vector2(sway, -22) * k, 6.0 * k, [Color(1.0, 0.62, 0.74), BUTTER][n % 2], true, -1.0, true)
			if lv >= 3 and kind == 1:
				_blob(ci, [p + Vector2(-5, -2) * k, p + Vector2(5, -2) * k, p + Vector2(0, 10) * k], Color(1.0, 0.6, 0.3), false)
	if lv >= 4:
		for p in [GARDEN + Vector2(-100, 20) * k, GARDEN + Vector2(96, 16) * k]:
			_ellipse(ci, p, 22.0 * k, 16.0 * k, Color(1.0, 0.6, 0.3))
			ci.draw_line(p + Vector2(0, -16) * k, p + Vector2(4, -24) * k, Color(0.36, 0.62, 0.44), 4.0 * k, true)
		var stem := GARDEN + Vector2(0, -20) * k
		ci.draw_line(stem, stem + Vector2(0, -90) * k, Color(0.36, 0.62, 0.44), 5.0 * k, true)
		for n in 10:
			var a := TAU * float(n) / 10.0 + _t * 0.2
			ci.draw_circle(stem + Vector2(0, -90) * k + Vector2(cos(a), sin(a)) * 16.0 * k, 8.0 * k, BUTTER, true, -1.0, true)
		ci.draw_circle(stem + Vector2(0, -90) * k, 10.0 * k, Color(0.5, 0.34, 0.24), true, -1.0, true)


func _draw_well(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_WELL)
	var k := _depth_scale(WELL.y)
	var stone := Color(0.74, 0.72, 0.78)
	_ellipse(ci, WELL + Vector2(0, 6) * k, 70.0 * k, 14.0 * k, SHADOW, false)
	if lv == 0:
		for p in [Vector2(-30, -4), Vector2(0, 0), Vector2(30, -6), Vector2(-14, -24), Vector2(16, -26), Vector2(0, -46)]:
			_ellipse(ci, WELL + p * k, 18.0 * k, 12.0 * k, stone)
		return
	# The stone ring: its back rim, the water, then the front wall.
	_ellipse(ci, WELL + Vector2(0, -60) * k, 52.0 * k, 16.0 * k, stone)
	_ellipse(ci, WELL + Vector2(0, -60) * k, 40.0 * k, 10.0 * k, Color(0.36, 0.5, 0.8), false)
	_blob(ci, [WELL + Vector2(-52, -60) * k, WELL + Vector2(52, -60) * k, WELL + Vector2(52, 0) * k, WELL + Vector2(-52, 0) * k], stone)
	for row in 2:
		for n in 3:
			ci.draw_line(WELL + Vector2(-52 + n * 35 + row * 16, -40 + row * 20) * k, WELL + Vector2(-52 + n * 35 + row * 16, -20 + row * 20) * k, Color(INK, 0.35), 2.0, true)
	if lv >= 2:
		for x in [-44.0, 44.0]:
			ci.draw_line(WELL + Vector2(x, -60) * k, WELL + Vector2(x, -150) * k, WOOD, 6.0 * k, true)
		_blob(ci, [WELL + Vector2(-66, -140) * k, WELL + Vector2(0, -180) * k, WELL + Vector2(66, -140) * k], Color(1.0, 0.62, 0.58))
		var crank := _t * 1.5 if lv >= 3 else 0.0
		var drop := 30.0 + (sin(crank) * 18.0 if lv >= 3 else 0.0)
		ci.draw_line(WELL + Vector2(-44, -120) * k, WELL + Vector2(44, -120) * k, WOOD, 5.0 * k, true)
		ci.draw_line(WELL + Vector2(0, -120) * k, WELL + Vector2(0, -120 + drop) * k, INK, 2.0, true)
		var bucket := WELL + Vector2(0, -120 + drop) * k
		_blob(ci, [bucket + Vector2(-10, 0) * k, bucket + Vector2(10, 0) * k, bucket + Vector2(8, 16) * k, bucket + Vector2(-8, 16) * k], GOLD if lv >= 4 else CHROME)
		if lv >= 3:
			var handle := WELL + Vector2(52, -120) * k
			ci.draw_line(handle, handle + Vector2(cos(crank), sin(crank)) * 16.0 * k, INK, 4.0 * k, true)
	if lv >= 4:
		for side in [-1.0, 1.0]:
			var box := WELL + Vector2(side * 70.0, -8.0) * k
			_blob(ci, [box + Vector2(-16, -6) * k, box + Vector2(16, -6) * k, box + Vector2(16, 8) * k, box + Vector2(-16, 8) * k], WOOD)
			for n in 3:
				ci.draw_circle(box + Vector2(-10 + n * 10, -12) * k, 5.0 * k, [Color(1.0, 0.62, 0.74), BUTTER, Color(0.8, 0.7, 0.98)][n], true, -1.0, true)


func _draw_lookout(ci: Control) -> void:
	var lv := _lv(TSProfile.CAMP_LOOKOUT)
	var k := _depth_scale(LOOKOUT.y)
	_ellipse(ci, LOOKOUT + Vector2(0, 6) * k, 70.0 * k, 14.0 * k, SHADOW, false)
	if lv == 0:
		for n in 3:
			var y := -8.0 - n * 16.0
			_blob(ci, [LOOKOUT + Vector2(-60 + n * 8, y - 8) * k, LOOKOUT + Vector2(60 - n * 8, y - 8) * k, LOOKOUT + Vector2(60 - n * 8, y + 8) * k, LOOKOUT + Vector2(-60 + n * 8, y + 8) * k], WOOD)
		return
	var deck := -150.0
	for x in [-44.0, 44.0]:
		ci.draw_line(LOOKOUT + Vector2(x, 0) * k, LOOKOUT + Vector2(x * 0.8, deck) * k, INK, 10.0 * k, true)
		ci.draw_line(LOOKOUT + Vector2(x, 0) * k, LOOKOUT + Vector2(x * 0.8, deck) * k, WOOD, 6.0 * k, true)
	ci.draw_line(LOOKOUT + Vector2(-40, -50) * k, LOOKOUT + Vector2(38, -100) * k, WOOD, 4.0 * k, true)
	if lv >= 2:
		# A ladder up the front, and a rail round the deck.
		for x in [-12.0, 12.0]:
			ci.draw_line(LOOKOUT + Vector2(x - 20, 4) * k, LOOKOUT + Vector2(x, deck) * k, WOOD.lightened(0.15), 4.0 * k, true)
		for n in 6:
			var u := (float(n) + 0.5) / 6.0
			var p := (LOOKOUT + Vector2(-20, 4) * k).lerp(LOOKOUT + Vector2(0, deck) * k, u)
			ci.draw_line(p + Vector2(-12, 0) * k, p + Vector2(12, 0) * k, WOOD.lightened(0.15), 3.0 * k, true)
		for x in [-40.0, 0.0, 40.0]:
			ci.draw_line(LOOKOUT + Vector2(x, deck) * k, LOOKOUT + Vector2(x, deck - 30) * k, WOOD, 4.0 * k, true)
		ci.draw_line(LOOKOUT + Vector2(-44, deck - 30) * k, LOOKOUT + Vector2(44, deck - 30) * k, WOOD, 4.0 * k, true)
	_blob(ci, [LOOKOUT + Vector2(-50, deck - 8) * k, LOOKOUT + Vector2(50, deck - 8) * k, LOOKOUT + Vector2(50, deck + 8) * k, LOOKOUT + Vector2(-50, deck + 8) * k], WOOD)
	if lv >= 3:
		for x in [-40.0, 40.0]:
			ci.draw_line(LOOKOUT + Vector2(x, deck) * k, LOOKOUT + Vector2(x, deck - 70) * k, WOOD, 4.0 * k, true)
		_blob(ci, [LOOKOUT + Vector2(-62, deck - 66) * k, LOOKOUT + Vector2(0, deck - 110) * k, LOOKOUT + Vector2(62, deck - 66) * k], ACCENT)
	if lv >= 4:
		var top := LOOKOUT + Vector2(0, deck - 110) * k
		ci.draw_line(top, top + Vector2(0, -40) * k, INK, 3.0 * k, true)
		_blob(ci, [top + Vector2(0, -40) * k, top + Vector2(30, -32 + sin(_t * 5.0) * 3.0) * k, top + Vector2(0, -24) * k], Color(1.0, 0.62, 0.74))
		for n in 7:
			var u := float(n) / 6.0
			var p := (LOOKOUT + Vector2(-62, deck - 66) * k).lerp(LOOKOUT + Vector2(62, deck - 66) * k, u) + Vector2(0, sin(u * PI) * 10.0 * k)
			ci.draw_circle(p, 5.0 * k, [Color(1.0, 0.62, 0.74), BUTTER, ACCENT][n % 3], true, -1.0, true)


## The solar panels stand on the ground by the tail, wired to the ship --
## shards until fixed, then one panel, two, tracking the sun, gold frames.
func _draw_solar(ci: Control) -> void:
	var lv := _lv(TSProfile.PART_SOLAR)
	var k := _depth_scale(SOLAR.y)
	var panel := Color(0.36, 0.5, 0.9)
	_ellipse(ci, SOLAR + Vector2(20, 6) * k, 110.0 * k, 14.0 * k, SHADOW, false)
	if lv == 0:
		for n in 4:
			var at := SOLAR + Vector2(-60.0 + n * 40.0, -4.0 + (n % 2) * 8.0) * k
			var pts: Array = []
			for c in [Vector2(-18, -8), Vector2(14, -10), Vector2(18, 6), Vector2(-14, 10)]:
				pts.append(at + (c as Vector2).rotated(n * 0.9) * k)
			_blob(ci, pts, panel.darkened(0.3))
		return
	# A cable from the panels to the tail -- unplugged once the ship lifts off.
	var tail := _pose * Vector2(100.0, 250.0)
	var cable := PackedVector2Array()
	for n in 9:
		var u := float(n) / 8.0
		cable.append(SOLAR.lerp(tail, u) + Vector2(0, sin(u * PI) * 30.0))
	if _launch_start == -1.0:
		ci.draw_polyline(cable, INK, 3.0, true)
	for n in (2 if lv >= 2 else 1):
		var base := SOLAR + Vector2(-50.0 + n * 100.0, 0.0) * k
		var tilt := sin(_t * 0.4 + n) * 0.25 if lv >= 3 else 0.0
		ci.draw_line(base, base + Vector2(0, -60) * k, INK, 5.0 * k, true)
		var c := base + Vector2(0, -74) * k
		var pts: Array = []
		for p in [Vector2(-46, -18), Vector2(46, -18), Vector2(40, 18), Vector2(-40, 18)]:
			pts.append(c + (p as Vector2).rotated(tilt) * k)
		_blob(ci, pts, panel)
		if lv >= 4:
			var ring := PackedVector2Array(pts)
			ring.append(pts[0])
			ci.draw_polyline(ring, GOLD, 5.0, true)
		for x in [-15.0, 15.0]:
			ci.draw_line(c + Vector2(x, -18).rotated(tilt) * k, c + Vector2(x * 0.9, 18).rotated(tilt) * k, Color(0.7, 0.8, 1.0), 1.5, true)
		ci.draw_line(c + Vector2(-44, 0).rotated(tilt) * k, c + Vector2(44, 0).rotated(tilt) * k, Color(0.7, 0.8, 1.0), 1.5, true)
		if lv >= 3:
			var glint := fposmod(_t * 0.5 + n * 0.5, 1.0)
			_sparkle(ci, c + Vector2(lerpf(-40.0, 40.0, glint), -8).rotated(tilt) * k, 7.0 * k, Color(1, 1, 1, 0.9))


func _draw_crater_lip() -> void:
	var ci := _lip_layer
	var lip := PackedVector2Array()
	for k in 17:
		var a := PI * float(k) / 16.0
		lip.append(CRATER + Vector2(cos(a) * 50.0, sin(a) * 15.0))
	for k in range(16, -1, -1):
		var a := PI * float(k) / 16.0
		lip.append(CRATER + Vector2(cos(a) * 60.0, sin(a) * 15.0 + 14.0))
	ci.draw_colored_polygon(lip, _planet["ground"])
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
	# Lift-off: smoke billowing across the pad, and a trail behind the climb.
	if _launch_start >= 0.0:
		var since := _t - _launch_start
		for n in 14:
			var spread := minf(since * 1.2, 1.0)
			var side := -1.0 if n % 2 == 0 else 1.0
			var p := PAD + Vector2(side * (40.0 + float(n) * 26.0) * spread, -20.0 - float(n % 3) * 18.0)
			ci.draw_circle(p, 40.0 + float(n % 4) * 14.0, Color(0.94, 0.93, 0.96, 0.85), true, -1.0, true)
		var tail := _xf * NOZZLE
		for n in 10:
			var u := float(n) / 10.0
			ci.draw_circle(tail.lerp(PAD, u) + Vector2(sin(u * 12.0 + _t * 6.0) * 14.0, 0.0), 26.0 + u * 30.0, Color(0.9, 0.9, 0.94, 0.7 - u * 0.4), true, -1.0, true)
	for c in _crew:
		var centre: Vector2 = c["centre"]
		var s: float = c["size"]
		var k := s / 44.0              # tools scale with their critter
		if _launch_start >= 0.0 and (c["job"] == "mechanic" or c["job"] == "paint"):
			continue   # the ship has gone: no wrench or brush to reach it
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
	if r < 0.5:
		return   # a spark burnt down to nothing: too small to draw, and it can't be triangulated
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
