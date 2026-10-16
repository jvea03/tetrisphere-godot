extends "res://scripts/screens/intro.gd"

## The voyage, each new Battle Pass season (TSProfile.voyage_due): the ship
## lifts off the old planet -- dressed for its season -- climbs away in a roar
## of flame and smoke, cruises through space, sputters, and crash-lands on the
## next planet, dressed for the new season (TSShipScene.THEMES), where the eggs
## burst out across the ground. The reward and the new planet are banked as it
## starts (TSProfile.take_voyage); a tap at the end (or a wait) goes Home.
## The flight and the crash are the opening cutscene's (intro.gd), played on
## after LIFT seconds of lift-off.

const LIFT := 2.6            # seconds of lift-off before the flight
const LIFT_RUMBLE := 0.7     # the engine fires up, the ship shakes on its pad
const PAD := Vector2(360.0, 820.0)   # where the ship stands, nose up

## The name a season's planet goes by in the captions.
const PLANET_NAMES := {"autumn": "Autumn", "christmas": "Snowy", "newyear": "Starry", "valentine": "Sweetheart"}

var _from_theme := "autumn"   # the planet left behind
var _to_theme := "autumn"     # the one ahead
var _from_number := 1
var _reward := 0
var _v := 0.0                 # time since the cutscene began (intro's _t starts after LIFT)
var _lift_smoke: Array = []   # {pos, vel, r, life, age}


func _ready() -> void:
	TSProfile.ensure_loaded()
	_from_theme = TSShipScene.theme_name()
	_from_number = TSProfile.planet_number
	# Off to the next planet: banked now, so quitting halfway loses nothing.
	_reward = TSProfile.take_voyage()
	if _reward == 0:   # not due (a preview): show this season's planet anyway
		_from_number = maxi(TSProfile.planet_number - 1, 1)
		_reward = TSProfile.last_voyage_reward if TSProfile.last_voyage_reward > 0 else TSProfile.launch_reward()
	_to_theme = TSProfile.season_theme()
	super()
	_caption_label.text = "A new season! The ship is ready to fly!"
	_caption.create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)
	_tap_hint.text = "Tap to explore!"
	TSSfx.play("windup", 0.7)


func _process(delta: float) -> void:
	_v += delta
	if _v < LIFT:
		if _v >= LIFT_RUMBLE and _v - delta < LIFT_RUMBLE:
			TSSfx.play("whoosh", 0.8)
			TSHaptics.heavy()
		_update_lift_smoke(delta)
		_stage.position = _stage_origin() + Vector2(sin(_v * 53.0), cos(_v * 47.0)) * (3.0 if _v < LIFT_RUMBLE else 6.0 * clampf(1.0 - (_v - LIFT_RUMBLE) / 1.4, 0.0, 1.0))
		_stage.queue_redraw()
		return
	super(delta)


func _captions() -> Array:
	var land: String = PLANET_NAMES.get(_to_theme, "New")
	return [
		[0.2, "Up, up and away -- off to a new planet!"],
		[CRUISE_END, "Uh-oh! Engine trouble again!"],
		[IMPACT + 0.5, "CRASH! Welcome to the %s Planet!" % land],
		[DONE, "+%s coins! A new camp to build and a new ship to fix." % TSProfile.fmt_coins(_reward)],
	]


func _planet() -> Dictionary:
	return TSShipScene.planet_colours(_from_number + 1, _to_theme)


func _dress_crash_site() -> void:
	_dress(_to_theme, _t, 800.0)


## Home, on the new planet, and the voyage is done.
func _finish() -> void:
	if _done:
		return
	_done = true
	while SceneFlow.in_flight:   # (still fading in: a change asked for now would be dropped)
		await get_tree().process_frame
	SceneFlow.go(SceneFlow.HOME)


func _unhandled_input(event: InputEvent) -> void:
	if _v >= LIFT:
		super(event)


# -- lift-off --------------------------------------------------------------------

func _update_lift_smoke(delta: float) -> void:
	if _v >= LIFT_RUMBLE * 0.5:
		for i in 2:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			_lift_smoke.append({"pos": PAD + Vector2(side * _rng.randf_range(10.0, 60.0), 40.0), "vel": Vector2(side * _rng.randf_range(160.0, 420.0), _rng.randf_range(-60.0, 10.0)),
				"r": _rng.randf_range(26.0, 44.0), "life": _rng.randf_range(1.0, 1.8), "age": 0.0})
	for p in _lift_smoke:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * (1.0 - minf(1.0, delta * 1.5))
		p["r"] = float(p["r"]) + 30.0 * delta
	_lift_smoke = _lift_smoke.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))


func _draw_stage() -> void:
	if _v >= LIFT:
		super()
		return
	# The old planet, its sky and its season, and the ship climbing away.
	var planet := TSShipScene.planet_colours(_from_number, _from_theme)
	var climb := maxf(_v - LIFT_RUMBLE, 0.0)
	var rise := climb * climb * 420.0          # the ship accelerates up
	var drop := minf(rise * 0.35, 900.0)        # and the ground falls away below
	_stage.draw_polygon(PackedVector2Array([Vector2(-WIDE, -40), Vector2(720 + WIDE, -40), Vector2(720 + WIDE, 1320 + TALL), Vector2(-WIDE, 1320 + TALL)]),
		PackedColorArray([planet["sky_top"].lerp(SPACE_TOP, clampf(climb / 1.6, 0.0, 1.0)), planet["sky_top"].lerp(SPACE_TOP, clampf(climb / 1.6, 0.0, 1.0)), planet["sky_low"], planet["sky_low"]]))
	var horizon := HORIZON + drop
	var ground := PackedVector2Array([Vector2(-WIDE, 1320.0 + TALL + drop)])
	for k in int((720.0 + WIDE * 2.0) / 34.0) + 2:
		var x := -WIDE + float(k) * 34.0
		ground.append(Vector2(x, horizon - 18.0 * sin(x * 0.012) - 10.0 * sin(x * 0.031 + 1.0)))
	ground.append(Vector2(720.0 + WIDE + 34.0, 1320.0 + TALL + drop))
	_stage.draw_colored_polygon(ground, planet["ground"])
	_stage.draw_polyline(ground.slice(1, ground.size() - 1), INK, 5.0, true)
	_dress(_from_theme, _v, horizon)
	# The launch pad, sinking with the ground.
	_ellipse(PAD + Vector2(0.0, 60.0 + drop), 170.0, 34.0, Color(0.8, 0.8, 0.86), true)
	# The ship, nose up, on a pillar of flame.
	var at := PAD + Vector2(0.0, drop - rise) + (Vector2(sin(_v * 40.0) * 3.0, 0.0) if _v < LIFT_RUMBLE else Vector2.ZERO)
	var flame := 0.5 + 0.5 * clampf(_v / LIFT_RUMBLE, 0.0, 1.0)
	_stage.draw_set_transform(at, -PI * 0.5, Vector2.ONE)
	var reach := (90.0 + 30.0 * sin(_v * 31.0)) * flame
	_blob([Vector2(-118, -24), Vector2(-118 - reach, 0), Vector2(-118, 24)], Color(1.0, 0.6, 0.3, 0.95))
	_blob([Vector2(-118, -12), Vector2(-118 - reach * 0.6, 0), Vector2(-118, 12)], BUTTER)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ship(at, -PI * 0.5, 1.0)
	for p in _lift_smoke:
		var fade := 1.0 - float(p["age"]) / float(p["life"])
		_stage.draw_circle((p["pos"] as Vector2) + Vector2(0.0, drop), float(p["r"]), Color(0.95, 0.94, 0.97, 0.85 * fade), true, -1.0, true)


# -- the season's dressing --------------------------------------------------------

## A planet's season over its ground: a line of the season's trees along the
## horizon (at `horizon`), and what drifts through its sky -- leaves, snow,
## confetti under fireworks, or hearts. `time` animates it.
func _dress(season: String, time: float, horizon: float) -> void:
	var look: Dictionary = TSShipScene.THEMES.get(season, TSShipScene.THEMES["autumn"])
	var leaves: Array = look["leaves"]
	if season == "newyear":
		for k in 3:   # fireworks bursting in turn over the hills
			var p := fposmod(time * 0.6 + float(k) * 0.33, 1.0)
			var c := Vector2(140.0 + 220.0 * float(k), 220.0 + 70.0 * float(k % 2))
			for s in 12:
				var a := TAU * float(s) / 12.0
				_stage.draw_circle(c + Vector2(cos(a), sin(a)) * 90.0 * p, 4.0, Color(leaves[(k + s) % leaves.size()], 1.0 - p), true, -1.0, true)
	for n in 9:
		var x := -40.0 + float(n) * 100.0 + sin(float(n) * 2.3) * 24.0
		var foot := Vector2(x, horizon - 14.0 * sin(x * 0.012) + 6.0)
		var k := 0.55 + 0.1 * sin(float(n) * 1.7)
		_stage.draw_line(foot, foot + Vector2(0, -70) * k, INK, 16.0 * k, true)
		_stage.draw_line(foot, foot + Vector2(0, -70) * k, Color(0.62, 0.42, 0.28), 10.0 * k, true)
		for c in [[Vector2(0, -130), 44.0], [Vector2(-36, -96), 38.0], [Vector2(36, -96), 38.0]]:
			_stage.draw_circle(foot + (c[0] as Vector2) * k, float(c[1]) * k + 3.0, INK, true, -1.0, true)
		for j in 3:
			var c: Array = [[Vector2(0, -130), 44.0], [Vector2(-36, -96), 38.0], [Vector2(36, -96), 38.0]][j]
			_stage.draw_circle(foot + (c[0] as Vector2) * k, float(c[1]) * k, leaves[(n + j) % leaves.size()], true, -1.0, true)
	# Drifting down over everything.
	for i in 30:
		var y := fposmod(_rng_hash(i + 70.0) * 1300.0 + time * (60.0 + _rng_hash(i) * 50.0), 1300.0) - 20.0
		var x := fposmod(_rng_hash(i + 30.0) * 720.0 + sin(time + float(i)) * 20.0, 720.0)
		match look["fall"]:
			"snow":
				_stage.draw_circle(Vector2(x, y), 3.0 + _rng_hash(i + 5.0) * 3.0, Color(1, 1, 1, 0.9), true, -1.0, true)
			_:
				var col: Color = leaves[i % leaves.size()]
				_stage.draw_set_transform(Vector2(x, y), time * 1.5 + float(i), Vector2.ONE)
				_stage.draw_colored_polygon(PackedVector2Array([Vector2(0, -9), Vector2(5, -2), Vector2(4, 4), Vector2(0, 8), Vector2(-4, 4), Vector2(-5, -2)]), col)
				_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rng_hash(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)
