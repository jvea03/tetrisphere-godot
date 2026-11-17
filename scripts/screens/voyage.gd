extends "res://scripts/screens/intro.gd"

## The voyage, each new Battle Pass season (TSProfile.voyage_due): the ship
## lifts off the old planet -- dressed for its season -- climbs away in a roar
## of flame and smoke, cruises through space, sputters, and crash-lands on the
## next planet, dressed for the new season (TSShipScene.THEMES), where the eggs
## burst out across the ground. The reward and the new planet are banked as it
## starts (TSProfile.take_voyage); a tap at the end (or a wait) goes Home.
## The flight and the crash are the opening cutscene's (intro.gd), played on
## after LIFT seconds of lift-off.
##
## How it goes depends on the ship (TSProfile.last_voyage_ship_ready): left
## unfinished, a patched-up wreck -- planks, tape and a wooden fin -- wobbles
## off its pad coughing smoke, sputters all the way, sheds bits as it goes and
## falls out of the sky on its own. Fully fixed, a gleaming gold-trimmed ship
## blasts off on a rainbow trail and cruises easily through space -- until
## something hits it (the season's own: a giant snowball at Christmas; see
## HAZARDS), and down it goes.

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
var _grand := false           # the ship was finished: the gleaming launch, and the asteroid
var _bits: Array = []         # planks and bolts falling off the patched-up ship: {pos, vel, spin, size, col}
var _bit_timer := 0.0
var _lift_at := PAD           # where the ship is during lift-off
var _plank_dropped := false

const ROCK_FROM := CRUISE_END - 0.8   # (flight time) the asteroid comes into view...
const ROCK_START := Vector2(900.0, 640.0)
const ROCK_HIT := Vector2(400.0, 430.0)   # ...and hits the ship's nose at CRUISE_END
const ROCK_RADIUS := 50.0
const CRUISE_SLOW := 0.45     # the finished ship's cruise, slowed, until the asteroid shows
const GOLD := Color(1.0, 0.8, 0.28)
const PLANK := Color(0.74, 0.53, 0.34)
## What hits the finished ship, by the season ahead (see _hazard): its shape,
## what the captions call it, the sound it hits with, its tail and burst colours.
const HAZARDS := {
	"autumn": {"kind": "acorn", "name": "a giant acorn", "hit": "BONK! A giant acorn hit the ship!",
		"tail": [Color(1.0, 0.56, 0.22), Color(0.94, 0.36, 0.26), Color(1.0, 0.78, 0.3)], "burst": [Color(0.78, 0.5, 0.26), Color(1.0, 0.56, 0.22), Color(0.72, 0.66, 0.68)]},
	"christmas": {"kind": "snowball", "name": "a giant snowball", "hit": "WHUMP! A giant snowball hit the ship!",
		"tail": [Color(1, 1, 1), Color(0.86, 0.92, 1.0)], "burst": [Color(1, 1, 1), Color(0.9, 0.95, 1.0), Color(0.8, 0.88, 1.0)]},
	"newyear": {"kind": "firework", "name": "a runaway firework", "hit": "BANG! A firework hit the ship!",
		"tail": [Color(1.0, 0.84, 0.36), Color(0.86, 0.72, 1.0), Color(0.62, 0.8, 1.0)], "burst": [Color(1.0, 0.84, 0.36), Color(0.86, 0.72, 1.0), Color(1.0, 0.5, 0.5)]},
	"valentine": {"kind": "heart", "name": "a giant candy heart", "hit": "BOINK! A candy heart hit the ship!",
		"tail": [Color(1.0, 0.72, 0.82), Color(1.0, 0.86, 0.9), Color(0.98, 0.56, 0.7)], "burst": [Color(1.0, 0.5, 0.66), Color(1.0, 0.86, 0.9), Color(1, 1, 1)]},
	"": {"kind": "asteroid", "name": "an asteroid", "hit": "BONK! An asteroid hit the ship!",
		"tail": [Color(1.0, 0.55, 0.3), Color(1.0, 0.78, 0.4)], "burst": [Color(1.0, 0.7, 0.4), Color(0.72, 0.66, 0.68)]},
}
const RAINBOW := [Color(1.0, 0.42, 0.45), Color(1.0, 0.66, 0.3), Color(1.0, 0.9, 0.38), Color(0.5, 0.88, 0.5), Color(0.45, 0.72, 1.0), Color(0.72, 0.55, 1.0)]


func _ready() -> void:
	TSProfile.ensure_loaded()
	_from_theme = TSShipScene.theme_name()
	_from_number = TSProfile.planet_number
	# Off to the next planet: banked now, so quitting halfway loses nothing.
	_reward = TSProfile.take_voyage()
	_grand = TSProfile.last_voyage_ship_ready
	if _reward == 0:   # not due (a preview): show this season's planet anyway
		_from_number = maxi(TSProfile.planet_number - 1, 1)
		_reward = TSProfile.last_voyage_reward if TSProfile.last_voyage_reward > 0 else TSProfile.launch_reward()
		_grand = TSProfile.is_ship_ready()
	if OS.get_environment("VOYAGE_SHIP") != "":   # (captures: "fixed" or "patched")
		_grand = OS.get_environment("VOYAGE_SHIP") == "fixed"
	_to_theme = TSProfile.season_theme()
	if OS.get_environment("VOYAGE_THEME") != "":   # (captures)
		_to_theme = OS.get_environment("VOYAGE_THEME")
	super()
	_caption_label.text = "Yay, we did it! The ship is fully fixed -- blast off!" if _grand else "Time to go! The patched-up ship will have to do..."
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
		if not _grand and not _plank_dropped and _v >= LIFT_RUMBLE + 0.8:
			# A plank comes loose on the way up.
			_plank_dropped = true
			_drop_bit(_lift_at + Vector2(40.0, 30.0), Vector2(220.0, -120.0))
			TSSfx.play("click", 0.6)
		_update_bits(delta)
		var wobble := 3.0 if _v < LIFT_RUMBLE else 6.0 * clampf(1.0 - (_v - LIFT_RUMBLE) / 1.4, 0.0, 1.0)
		if not _grand:
			wobble *= 1.6
		_stage.position = _stage_origin() + Vector2(sin(_v * 53.0), cos(_v * 47.0)) * wobble
		_stage.queue_redraw()
		return
	var was := _t
	# The finished ship cruises at its ease (slowed) until the asteroid shows.
	super(delta * (CRUISE_SLOW if _grand and _t < ROCK_FROM else 1.0))
	_update_bits(delta)
	if _grand:
		if was < CRUISE_END and _t >= CRUISE_END:
			_hazard_hit()
		if _t >= CRUISE_END and _t < IMPACT:
			var since := _t - CRUISE_END
			_flash.modulate.a = maxf(_flash.modulate.a, 0.65 * clampf(1.0 - since / 0.25, 0.0, 1.0))
			_stage.position += Vector2(sin(_t * 61.0), cos(_t * 57.0)) * 22.0 * exp(-since * 6.0)
	elif _t < IMPACT:
		# Bits keep falling off the patched-up ship all the way down.
		_bit_timer -= delta
		if _bit_timer <= 0.0:
			_bit_timer = _rng.randf_range(0.25, 0.45)
			var pose := _ship_pose()
			_drop_bit(pose[0] + Vector2(_rng.randf_range(-70.0, 90.0), _rng.randf_range(-30.0, 30.0)).rotated(float(pose[1])),
				Vector2(_rng.randf_range(-300.0, -80.0), _rng.randf_range(-220.0, -40.0)))
			if _rng.randf() < 0.5:
				TSSfx.play("click", 0.5 + _rng.randf() * 0.4)


func _captions() -> Array:
	var land: String = PLANET_NAMES.get(_to_theme, "New")
	if _grand:
		return [
			[0.2, "Smooth flying -- the ship is working perfectly!"],
			[ROCK_FROM + 0.1, "Look out! It's %s!" % str(_hazard()["name"])],
			[CRUISE_END, str(_hazard()["hit"])],
			[IMPACT + 0.5, "CRASH! Welcome to the %s Planet!" % land],
			[DONE, "+%s coins for fixing the ship! A new camp to build and a new ship to fix." % TSProfile.fmt_coins(_reward)],
		]
	return [
		[0.2, "Rattle, clank, wobble... it's barely holding together!"],
		[CRUISE_END, "Uh-oh! Bits are falling off!"],
		[IMPACT + 0.5, "CRASH! Welcome to the %s Planet!" % land],
		[DONE, "+%s coins! A new camp to build and a new ship to fix." % TSProfile.fmt_coins(_reward)],
	]


## The patched-up ship's engine fails from the start: it sputters, and the
## alarm blinks, even on the pad.
func _failing() -> bool:
	return _t >= CRUISE_END or not _grand


func _planet() -> Dictionary:
	return TSShipScene.planet_colours(_from_number + 1, _to_theme)


func _dress_crash_site() -> void:
	_dress(_to_theme, _t, 800.0)


## Not the opening: not counted, and Home loads as it always has.
func _start_ahead() -> void:
	pass


## Home, on the new planet, and the voyage is done.
func _finish(_how := "tap") -> void:
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
		_draw_bits()
		if _grand and _t >= ROCK_FROM and _t < CRUISE_END:
			_draw_hazard()
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
	var lean := -PI * 0.5
	var flame := 0.5 + 0.5 * clampf(_v / LIFT_RUMBLE, 0.0, 1.0)
	if not _grand:
		# The patched-up ship rocks as it goes, its flame coughing.
		lean += sin(_v * 6.0) * 0.12 * clampf(climb * 2.0, 0.0, 1.0)
		at.x += sin(_v * 3.0) * 30.0 * clampf(climb, 0.0, 1.0)
		flame *= 0.35 + 0.65 * absf(sin(_v * 13.0))
	_lift_at = at
	_stage.draw_set_transform(at, lean, Vector2.ONE)
	var reach := (90.0 + 30.0 * sin(_v * 31.0)) * flame
	_blob([Vector2(-118, -24), Vector2(-118 - reach, 0), Vector2(-118, 24)], Color(1.0, 0.6, 0.3, 0.95))
	_blob([Vector2(-118, -12), Vector2(-118 - reach * 0.6, 0), Vector2(-118, 12)], BUTTER)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ship(at, lean, 1.0)
	var smoke := Color(0.95, 0.94, 0.97) if _grand else Color(0.58, 0.55, 0.6)
	for p in _lift_smoke:
		var fade := 1.0 - float(p["age"]) / float(p["life"])
		_stage.draw_circle((p["pos"] as Vector2) + Vector2(0.0, drop), float(p["r"]), Color(smoke, 0.85 * fade), true, -1.0, true)
	_draw_bits()


# -- the ship, finished or patched up ------------------------------------------------

## The ship as intro.gd draws it, dressed for how it was left: the finished
## one gold-trimmed on a rainbow trail (dented once it is hit), the
## unfinished one grimy, planked, taped and cracked, with a wooden fin.
func _draw_ship(at: Vector2, angle: float, zoom: float) -> void:
	var clean := _grand and (_v < LIFT or _t < CRUISE_END)
	if clean:
		_draw_rainbow(at, angle, zoom)
	super(at, angle, zoom)
	_stage.draw_set_transform(at, angle, Vector2.ONE * zoom)
	if _grand:
		_draw_gold_trim()
		if _v >= LIFT and _t >= CRUISE_END:
			# Where it was struck: a scorched dent and cracks.
			_stage.draw_circle(Vector2(118, -26), 17.0, Color(0.36, 0.3, 0.34), true, -1.0, true)
			_stage.draw_circle(Vector2(114, -30), 9.0, Color(0.22, 0.18, 0.22), true, -1.0, true)
			for c in [[Vector2(118, -26), Vector2(88, -40)], [Vector2(118, -26), Vector2(100, -4)], [Vector2(118, -26), Vector2(140, -6)]]:
				_stage.draw_line(c[0], c[1], INK, 3.0, true)
	else:
		_draw_patches()
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if clean:
		# Twinkles round a ship in perfect shape.
		for k in 5:
			var p := fposmod(_v * 1.3 + float(k) * 0.2, 1.0)
			var c := at + Vector2(cos(float(k) * 2.4) * 150.0, sin(float(k) * 1.7) * 90.0) * zoom
			_star(c, 12.0 * sin(p * PI), Color(1.0, 0.96, 0.7, sin(p * PI)))


## A rainbow streaming from the nozzle, rippling (in the ship's frame).
func _draw_rainbow(at: Vector2, angle: float, zoom: float) -> void:
	_stage.draw_set_transform(at, angle, Vector2.ONE * zoom)
	var steps := 14
	for b in RAINBOW.size():
		var y0 := -17.5 + 7.0 * float(b)
		var prev := Vector2(-110.0, y0)
		for k in range(1, steps + 1):
			var x := -110.0 - 300.0 * float(k) / float(steps)
			var p := Vector2(x, y0 + sin(x * 0.025 + _v * 9.0) * 7.0 * float(k) / float(steps))
			_stage.draw_line(prev, p, Color(RAINBOW[b], 0.9 * (1.0 - float(k) / float(steps + 1))), 7.5, true)
			prev = p
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gold_trim() -> void:
	_stage.draw_line(Vector2(-86, -30), Vector2(116, -30), GOLD, 7.0, true)
	_stage.draw_line(Vector2(-88, -46), Vector2(-88, 46), GOLD, 8.0, true)
	for fin in [[Vector2(-60, -40), Vector2(-100, -90), Vector2(-60, -90)], [Vector2(-60, 40), Vector2(-100, 90), Vector2(-60, 90)]]:
		_stage.draw_polyline(PackedVector2Array(fin), GOLD, 5.0, true)
	_star(Vector2(140, -2), 13.0, GOLD)
	# A glint sweeping along the hull.
	var g := fposmod(_v * 0.8, 1.6) - 0.3
	if g >= 0.0 and g <= 1.0:
		var x := lerpf(-70.0, 120.0, g)
		_stage.draw_line(Vector2(x - 8.0, -38.0), Vector2(x + 8.0, 38.0), Color(1, 1, 1, 0.5), 9.0, true)


func _draw_patches() -> void:
	# Grime over the hull, and rust spots.
	var hull := PackedVector2Array()
	for k in 25:
		var a := -PI * 0.5 + PI * float(k) / 24.0
		hull.append(Vector2(60.0 + cos(a) * 116.0, sin(a) * 46.0))
	hull.append(Vector2(-86, 46))
	hull.append(Vector2(-86, -46))
	_stage.draw_colored_polygon(hull, Color(0.42, 0.32, 0.28, 0.28))
	for r in [[Vector2(-62, 30), 8.0], [Vector2(46, 38), 6.0], [Vector2(150, -14), 5.0]]:
		_stage.draw_circle(r[0], r[1], Color(0.7, 0.42, 0.3, 0.75), true, -1.0, true)
	# A wooden fin in place of the bottom one.
	_blob([Vector2(-56, 42), Vector2(-104, 94), Vector2(-66, 96), Vector2(6, 44)], PLANK)
	_stage.draw_line(Vector2(-70, 60), Vector2(-30, 52), PLANK.darkened(0.3), 3.0, true)
	# A plank nailed (crooked) over a hole.
	var tilt := Transform2D(-0.14, Vector2(-14, -36))
	_blob([tilt * Vector2(-38, -10), tilt * Vector2(38, -10), tilt * Vector2(38, 10), tilt * Vector2(-38, 10)], PLANK)
	for n in [Vector2(-30, 0), Vector2(30, 0)]:
		_stage.draw_circle(tilt * n, 3.5, Color(0.55, 0.55, 0.6), true, -1.0, true)
	# Tape across a crack near the nose.
	_stage.draw_line(Vector2(104, -8), Vector2(140, 26), Color(0.86, 0.85, 0.78), 10.0, true)
	_stage.draw_line(Vector2(104, 26), Vector2(140, -8), Color(0.86, 0.85, 0.78), 10.0, true)
	# A cracked porthole.
	_stage.draw_polyline(PackedVector2Array([Vector2(72, -22), Vector2(82, -10), Vector2(78, -2), Vector2(92, 6)]), INK, 2.5, true)


## A four-point twinkle.
func _star(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.5:
		return
	_stage.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
		c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28)]), col)


# -- what hits the finished ship, and falling bits ------------------------------------

## What comes at the finished ship, for the season ahead: a giant acorn in
## autumn, a giant snowball at Christmas, a runaway firework at New Year, a
## giant candy heart for Valentine's -- an asteroid otherwise.
func _hazard() -> Dictionary:
	return HAZARDS.get(_to_theme, HAZARDS[""])


## Where it is on its way in (flight time ROCK_FROM .. CRUISE_END).
func _hazard_at() -> Vector2:
	var u := clampf((_t - ROCK_FROM) / (CRUISE_END - ROCK_FROM), 0.0, 1.0)
	return ROCK_START.lerp(ROCK_HIT, u)


func _draw_hazard() -> void:
	var at := _hazard_at()
	var back := (ROCK_START - ROCK_HIT).normalized()
	var look := _hazard()
	var tail: Array = look["tail"]
	# A streaming tail behind it, in its colours.
	for k in range(7, 0, -1):
		var f := float(k) / 7.0
		var wob := Vector2(-back.y, back.x) * sin(_t * 14.0 + float(k)) * 8.0 * f
		_stage.draw_circle(at + back * 32.0 * float(k) + wob, ROCK_RADIUS * (1.0 - f * 0.6), Color(tail[k % tail.size()], 0.55 * (1.0 - f) + 0.1), true, -1.0, true)
	var spin := _t * 3.0
	match str(look["kind"]):
		"snowball":
			var r := ROCK_RADIUS * 1.25
			var lumps := PackedVector2Array()
			for k in 14:
				var a := spin * 0.5 + TAU * float(k) / 14.0
				lumps.append(at + Vector2(cos(a), sin(a)) * r * (0.94 + 0.08 * sin(float(k) * 3.1)))
			_poly(lumps, Color(0.97, 0.98, 1.0))
			_stage.draw_circle(at + Vector2(r * 0.22, r * 0.24), r * 0.62, Color(0.8, 0.88, 1.0, 0.7), true, -1.0, true)
			_stage.draw_circle(at + Vector2(-r * 0.3, -r * 0.32), r * 0.22, Color(1, 1, 1), true, -1.0, true)
			for k in 3:
				_star(at + Vector2(cos(float(k) * 2.1 + _t * 2.0), sin(float(k) * 2.1 + _t * 2.0)) * r * 1.25, 9.0 * absf(sin(_t * 6.0 + float(k))), Color(1, 1, 1, 0.9))
		"acorn":
			_stage.draw_set_transform(at, spin * 0.6, Vector2.ONE)
			_ellipse(Vector2(0, 12), ROCK_RADIUS * 0.82, ROCK_RADIUS, Color(0.78, 0.5, 0.26), true)
			_stage.draw_circle(Vector2(-12, 14), 10.0, Color(0.88, 0.62, 0.36), true, -1.0, true)
			_ellipse(Vector2(0, -26), ROCK_RADIUS * 0.98, ROCK_RADIUS * 0.46, Color(0.5, 0.33, 0.2), true)
			for k in 5:
				_stage.draw_line(Vector2(-36.0 + float(k) * 18.0, -44), Vector2(-46.0 + float(k) * 18.0, -10), Color(0.36, 0.23, 0.14), 3.0, true)
			_stage.draw_line(Vector2(0, -48), Vector2(8, -68), INK, 9.0, true)
			_stage.draw_line(Vector2(0, -48), Vector2(8, -68), Color(0.5, 0.33, 0.2), 5.0, true)
			_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"firework":
			# Nose first at the ship, sparks fizzing from its tail.
			var ang := (-back).angle()
			_stage.draw_set_transform(at, ang + sin(_t * 20.0) * 0.08, Vector2.ONE)
			_blob([Vector2(-60, -20), Vector2(30, -20), Vector2(30, 20), Vector2(-60, 20)], Color(0.92, 0.28, 0.36))
			for k in 3:
				_stage.draw_line(Vector2(-44.0 + float(k) * 26.0, -18), Vector2(-34.0 + float(k) * 26.0, 18), GOLD, 7.0, true)
			_blob([Vector2(30, -26), Vector2(72, 0), Vector2(30, 26)], Color(0.62, 0.45, 0.95))
			_star(Vector2(52, 0), 9.0, GOLD)
			_stage.draw_line(Vector2(-60, 0), Vector2(-96, 0), Color(0.5, 0.38, 0.3), 4.0, true)
			_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 6:
				var a := TAU * float(k) / 6.0 + _t * 9.0
				_star(at + back * 100.0 + Vector2(cos(a), sin(a)) * (10.0 + 14.0 * absf(sin(_t * 11.0 + float(k)))), 7.0, tail[k % tail.size()])
		"heart":
			var pts := PackedVector2Array()
			var s := ROCK_RADIUS / 15.0 * (1.0 + 0.06 * sin(_t * 12.0))   # it throbs
			for k in 32:
				var a := TAU * float(k) / 32.0
				var p := Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)))
				pts.append(at + p.rotated(sin(_t * 4.0) * 0.3) * s)
			_poly(pts, Color(1.0, 0.5, 0.66))
			_stage.draw_circle(at + Vector2(-20, -14), 9.0, Color(1, 1, 1, 0.7), true, -1.0, true)
			_stage.draw_line(at + Vector2(-16, 8), at + Vector2(16, 8), Color(1, 1, 1, 0.85), 5.0, true)
		_:
			var pts := PackedVector2Array()
			for k in 11:
				var a := spin + TAU * float(k) / 11.0
				pts.append(at + Vector2(cos(a), sin(a)) * ROCK_RADIUS * (0.84 + 0.2 * sin(float(k) * 2.7)))
			_poly(pts, Color(0.6, 0.52, 0.5))
			for c in [[Vector2(-14, -10), 11.0], [Vector2(16, 8), 8.0], [Vector2(-4, 20), 6.0]]:
				_stage.draw_circle(at + (c[0] as Vector2).rotated(spin), c[1], Color(0.46, 0.39, 0.38), true, -1.0, true)


## It strikes: a bang, a flash (see _process), a burst in its colours,
## chunks of it, and a fin knocked off.
func _hazard_hit() -> void:
	var look := _hazard()
	var burst: Array = look["burst"]
	TSSfx.play("bomb", 1.2)
	TSHaptics.heavy()
	for i in 20:
		var a := _rng.randf() * TAU
		_puffs.append({"pos": ROCK_HIT, "vel": Vector2(cos(a), sin(a)) * _rng.randf_range(160.0, 500.0), "r": _rng.randf_range(16.0, 32.0),
			"grow": 36.0, "life": _rng.randf_range(0.6, 1.1), "age": 0.0, "col": burst[i % burst.size()]})
	for i in 10:
		var a := _rng.randf_range(-PI, 0.3)
		_drop_bit(ROCK_HIT + Vector2(cos(a), sin(a)) * 20.0, Vector2(cos(a), sin(a)) * _rng.randf_range(350.0, 750.0), burst[i % burst.size()], Vector2(14, 14))
	_drop_bit(ROCK_HIT + Vector2(-80.0, -40.0), Vector2(-160.0, -380.0), TRIM, Vector2(48, 30))


func _drop_bit(at: Vector2, vel: Vector2, col := PLANK, size := Vector2.ZERO) -> void:
	_bits.append({"pos": at, "vel": vel, "spin": _rng.randf() * TAU, "turn": _rng.randf_range(-8.0, 8.0),
		"size": size if size != Vector2.ZERO else Vector2(_rng.randf_range(34.0, 56.0), _rng.randf_range(10.0, 16.0)), "col": col})


func _update_bits(delta: float) -> void:
	for b in _bits:
		b["vel"] = (b["vel"] as Vector2) + Vector2(0.0, 1100.0) * delta
		b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
		b["spin"] = float(b["spin"]) + float(b["turn"]) * delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return (b["pos"] as Vector2).y < 1500.0)


func _draw_bits() -> void:
	for b in _bits:
		var h: Vector2 = (b["size"] as Vector2) * 0.5
		_stage.draw_set_transform(b["pos"], float(b["spin"]), Vector2.ONE)
		_blob([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)], b["col"])
		_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
