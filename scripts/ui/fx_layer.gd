class_name TSFxLayer
extends Control

## The game screen's particle layer for the boosters' animations: sparks,
## puffs of dust or smoke, shockwave rings and flashes, all drawn here in one
## pass over the HUD (and under the cards). Everything is in screen pixels,
## fades out on its own, and the layer never takes a touch.

const INK := Color(0.27, 0.16, 0.19)
const RAINBOW := [Color(1.0, 0.56, 0.72), Color(1.0, 0.83, 0.36), Color(0.5, 0.86, 0.56), Color(0.52, 0.8, 0.98), Color(0.74, 0.6, 0.95)]

var _parts: Array = []   # {kind, pos, vel, size, grow, life, age, colour, gravity, spin}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


## A burst of `count` sparks flying out of `at`, each a random colour of
## `colours`; `star` draws four-pointed sparkles instead of round sparks.
func burst(at: Vector2, colours: Array, count: int, speed: float, life: float, size: float, gravity := 0.0, star := false) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * _rng.randf_range(0.45, 1.0)
		_add("star" if star else "spark", at, v, size * _rng.randf_range(0.6, 1.2), -size * 0.8,
			life * _rng.randf_range(0.7, 1.1), colours[_rng.randi() % colours.size()], gravity)


## One sparkle, drifting a little: for trails and shimmers.
func sparkle(at: Vector2, colour: Color, size: float, life: float) -> void:
	var a := _rng.randf() * TAU
	_add("star", at, Vector2(cos(a), sin(a)) * 30.0, size, -size * 0.6, life, colour, 0.0)


## A soft round puff that swells and fades: dust, smoke.
func puff(at: Vector2, colour: Color, size: float, life: float, drift := Vector2.ZERO) -> void:
	_add("puff", at, drift, size, size * 1.4, life, colour, 0.0)


## A ring growing from `from_r` to `to_r` and fading: a shockwave.
func ring(at: Vector2, colour: Color, from_r: float, to_r: float, life: float) -> void:
	_add("ring", at, Vector2.ZERO, from_r, (to_r - from_r) / life, life, colour, 0.0)


## The whole screen lit up in `colour` for a moment.
func flash(colour: Color, life: float) -> void:
	_add("flash", Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, life, colour, 0.0)


func _add(kind: String, at: Vector2, vel: Vector2, size: float, grow: float, life: float, colour: Color, gravity: float) -> void:
	_parts.append({"kind": kind, "pos": at, "vel": vel, "size": size, "grow": grow, "life": maxf(life, 0.01),
		"age": 0.0, "colour": colour, "gravity": gravity, "spin": _rng.randf() * TAU})


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	for p in _parts:
		p["age"] = float(p["age"]) + delta
		var v: Vector2 = p["vel"]
		v.y += float(p["gravity"]) * delta
		v *= 1.0 - minf(1.0, delta * 1.5)   # air drag, so bursts slow and settle
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * delta
		p["size"] = maxf(0.0, float(p["size"]) + float(p["grow"]) * delta)
		p["spin"] = float(p["spin"]) + delta * 4.0
	_parts = _parts.filter(func(p: Dictionary) -> bool: return float(p["age"]) < float(p["life"]))
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var t := float(p["age"]) / float(p["life"])
		var c: Color = p["colour"]
		var at: Vector2 = p["pos"]
		var s := float(p["size"])
		match String(p["kind"]):
			"spark":
				draw_circle(at, s, Color(c, c.a * (1.0 - t)), true, -1.0, true)
			"star":
				if s > 0.6:
					var pts := PackedVector2Array()
					for k in 8:
						var a := float(p["spin"]) + TAU * float(k) / 8.0
						pts.append(at + Vector2(cos(a), sin(a)) * (s if k % 2 == 0 else s * 0.32))
					draw_colored_polygon(pts, Color(c, c.a * (1.0 - t)))
			"puff":
				draw_circle(at, s, Color(c, c.a * 0.7 * (1.0 - t)), true, -1.0, true)
			"ring":
				draw_arc(at, s, 0.0, TAU, 48, Color(c, c.a * (1.0 - t)), 10.0 * (1.0 - t) + 2.0, true)
			"flash":
				draw_rect(Rect2(Vector2.ZERO, size), Color(c, c.a * (1.0 - t) * (1.0 - t)))
