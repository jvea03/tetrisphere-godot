class_name TSHolidayBanner
extends Control

## A holiday season's Battle Pass banner, drawn rather than painted (the
## autumn one is a picture), for `holiday`:
## - "christmas": a night sky with snow falling, a string of twinkling lights
##   swagged across the top, snowy hills with a decorated tree;
## - "newyear": fireworks bursting over a midnight sky, gold and silver bunting,
##   confetti tumbling down over violet hills;
## - "valentine": a rosy sky with hearts floating up, heart bunting, a heart
##   balloon over pink hills;
## and the season's critters lined up along the bottom of each. Sized like
## the picture banner it stands in for; its parent rounds its corners
## (clip_children) in sky_color().

const INK := Color(0.27, 0.16, 0.19)
const SNOW := Color(0.99, 0.99, 1.0)
const SNOW_SHADE := Color(0.84, 0.88, 0.98)
const PINE := Color(0.24, 0.58, 0.36)
const PINE_DARK := Color(0.17, 0.44, 0.28)
const BULBS := [Color(1.0, 0.36, 0.4), Color(1.0, 0.84, 0.36), Color(0.5, 0.9, 0.56), Color(0.56, 0.78, 1.0)]
const CONFETTI := [Color(1.0, 0.84, 0.36), Color(1.0, 0.5, 0.66), Color(0.56, 0.8, 1.0), Color(0.62, 0.92, 0.66), Color(0.86, 0.72, 1.0)]
const PINKS := [Color(1.0, 0.42, 0.56), Color(1.0, 0.62, 0.74), Color(0.96, 0.3, 0.42), Color(1.0, 0.8, 0.86)]
## Per theme: the sky (top and low) and the critters along the bottom.
const THEMES := {
	"christmas": {"top": Color(0.15, 0.19, 0.42), "low": Color(0.45, 0.38, 0.66),
		"critters": [91, 29, 70, 3, 97, 71]},   # Santa, Elf, Snowman, Ginger, Polar, Frost Queen
	"newyear": {"top": Color(0.08, 0.07, 0.22), "low": Color(0.32, 0.2, 0.48),
		"critters": [49, 32, 98, 4, 10, 56]},   # Party, Firework, Groovy, Goldie, King, Flurry
	"valentine": {"top": Color(1.0, 0.7, 0.8), "low": Color(1.0, 0.9, 0.86),
		"critters": [87, 42, 11, 73, 101, 34]},   # Rosie, Cupid, Smooch, Berry, Princess, Kitty
}

var holiday := "christmas"   # (not "theme": every Control has one)
var _t := 0.0


## The colour behind a theme's banner: its frame is filled with it.
static func sky_color(for_theme: String) -> Color:
	return THEMES.get(for_theme, THEMES["christmas"])["top"]


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var look: Dictionary = THEMES.get(holiday, THEMES["christmas"])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([look["top"], look["top"], look["low"], look["low"]]))
	match holiday:
		"newyear":
			_stars(30)
			_fireworks()
			_hill(h * 0.68, h * 0.07, 0.9, Color(0.36, 0.27, 0.56))
			_hill(h * 0.8, h * 0.05, 2.3, Color(0.5, 0.38, 0.66))
		"valentine":
			_rising_hearts()
			_hill(h * 0.68, h * 0.07, 0.9, Color(0.99, 0.76, 0.84))
			_balloon(Vector2(w * 0.86, h * 0.36), h * 0.17)
			_hill(h * 0.8, h * 0.05, 2.3, Color(1.0, 0.88, 0.92))
		_:
			_stars(26)
			_hill(h * 0.66, h * 0.07, 0.9, SNOW_SHADE)
			_tree(Vector2(w * 0.84, h * 0.7), h * 0.5)
			_hill(h * 0.8, h * 0.05, 2.3, SNOW)
	_critters(look["critters"])
	match holiday:
		"newyear":
			_bunting(false)
			_confetti()
		"valentine":
			_bunting(true)
		_:
			_lights()
			_snow()


# -- the parts --------------------------------------------------------------

func _stars(count: int) -> void:
	for i in count:
		var p := Vector2(_hash(i) * size.x, _hash(i + 50.0) * size.y * 0.6)
		var a := 0.45 + 0.4 * sin(_t * (1.5 + _hash(i + 9.0) * 2.0) + i)
		draw_circle(p, 1.4 + _hash(i + 3.0) * 1.6, Color(1.0, 0.96, 0.8, a), true, -1.0, true)


## The season's critters along the bottom, bobbing a little.
func _critters(ids: Array) -> void:
	var w := size.x
	var h := size.y
	var n := ids.size()
	var s := minf(h * 0.42, w / float(n) * 0.95)
	for k in n:
		var tex := TSProfile.critter_art(int(ids[k]))
		var x := w * (0.1 + 0.8 * float(k) / float(n - 1))
		var bob := sin(_t * 2.2 + k * 1.3) * h * 0.012
		draw_texture_rect(tex, Rect2(Vector2(x - s * 0.5, h - s * 1.02 + bob), Vector2(s, s)), false)


## A rolling hill whose top sits around `base`, filled down to the bottom.
func _hill(base: float, amp: float, waves: float, fill: Color) -> void:
	var w := size.x
	var top := PackedVector2Array()
	for i in 33:
		var u := float(i) / 32.0
		top.append(Vector2(u * w, base - amp * sin(u * TAU * waves * 0.5 + waves)))
	var poly := top.duplicate()
	poly.append(Vector2(w, size.y))
	poly.append(Vector2(0, size.y))
	draw_colored_polygon(poly, fill)
	draw_polyline(top, INK, 2.5, true)


## A cord swagged across the top, under the season's title.
func _swag() -> PackedVector2Array:
	var wire := PackedVector2Array()
	for i in 41:
		var u := float(i) / 40.0
		var sag := 4.0 * u * (1.0 - u)
		wire.append(Vector2(u * size.x, size.y * 0.06 + sag * size.y * 0.12 + sin(u * TAU * 3.0) * size.y * 0.012))
	return wire


# Christmas: twinkling bulbs on a green wire, and snow falling.
func _lights() -> void:
	var wire := _swag()
	draw_polyline(wire, PINE_DARK, 3.0, true)
	for i in range(1, 40, 3):
		var at := wire[i] + Vector2(0, 7)
		var c: Color = BULBS[(i / 3) % BULBS.size()]
		var lit := 0.55 + 0.45 * sin(_t * 3.0 + i * 0.9)
		draw_circle(at, 11.0, Color(c, 0.25 * lit), true, -1.0, true)
		draw_circle(at, 5.5, c.lerp(Color.WHITE, 0.3 * lit), true, -1.0, true)
		draw_arc(at, 5.5, 0.0, TAU, 14, INK, 1.5, true)


func _snow() -> void:
	for i in 46:
		var speed := 18.0 + _hash(i + 20.0) * 26.0
		var y := fposmod(_hash(i + 70.0) * size.y + _t * speed, size.y + 8.0) - 4.0
		var x := fposmod(_hash(i + 30.0) * size.x + sin(_t * 0.8 + i) * 8.0, size.x)
		draw_circle(Vector2(x, y), 1.6 + _hash(i + 5.0) * 2.2, Color(1, 1, 1, 0.85), true, -1.0, true)


## A Christmas tree standing at `foot`, `tall` high: three inked tiers of pine,
## round ornaments, and a gold star that glows.
func _tree(foot: Vector2, tall: float) -> void:
	var half := tall * 0.36
	draw_rect(Rect2(foot + Vector2(-tall * 0.05, -tall * 0.12), Vector2(tall * 0.1, tall * 0.14)), Color(0.55, 0.36, 0.24))
	for k in 3:
		var tier_top := foot.y - tall * (0.45 + 0.27 * k)
		var tier_bottom := foot.y - tall * (0.1 + 0.27 * k)
		var wide := half * (1.0 - 0.24 * k)
		var tri := PackedVector2Array([Vector2(foot.x, tier_top), Vector2(foot.x + wide, tier_bottom), Vector2(foot.x - wide, tier_bottom)])
		draw_colored_polygon(tri, PINE if k % 2 == 0 else PINE.lerp(PINE_DARK, 0.4))
		tri.append(tri[0])
		draw_polyline(tri, INK, 2.5, true)
		for j in 3:
			var o := Vector2(foot.x + (float(j) - 1.0) * wide * 0.55, tier_bottom - tall * 0.05)
			draw_circle(o, tall * 0.035, BULBS[(j + k) % BULBS.size()], true, -1.0, true)
			draw_arc(o, tall * 0.035, 0.0, TAU, 12, INK, 1.5, true)
	var star := foot + Vector2(0, -tall * 1.0)
	draw_circle(star, tall * 0.12, Color(1.0, 0.86, 0.36, 0.25 + 0.15 * sin(_t * 2.0)), true, -1.0, true)
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(star + Vector2(cos(a), sin(a)) * tall * (0.08 if i % 2 == 0 else 0.035))
	draw_colored_polygon(pts, Color(1.0, 0.84, 0.3))
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0, true)


# New Year's: fireworks bursting in turn -- a ring of sparks flying out and
# fading -- gold and silver pennants, and confetti tumbling down.
func _fireworks() -> void:
	for k in 5:
		var period := 2.6 + _hash(k + 40.0)
		var p := fposmod(_t + _hash(k + 60.0) * period, period) / period
		if p > 0.75:
			continue
		var c := Vector2((0.12 + 0.19 * k) * size.x, (0.22 + 0.2 * _hash(k + 11.0)) * size.y)
		var grow := 1.0 - pow(1.0 - p / 0.75, 3.0)
		var fade := 1.0 - p / 0.75
		var col: Color = CONFETTI[k % CONFETTI.size()]
		var radius := size.y * (0.12 + 0.05 * _hash(k + 2.0)) * grow
		for s in 14:
			var a := TAU * float(s) / 14.0
			var at := c + Vector2(cos(a), sin(a)) * radius + Vector2(0, p * size.y * 0.04)
			draw_line(at - Vector2(cos(a), sin(a)) * radius * 0.25, at, Color(col, fade * 0.7), 2.0, true)
			draw_circle(at, 2.6, Color(col.lerp(Color.WHITE, 0.4), fade), true, -1.0, true)
		draw_circle(c, 6.0 * fade, Color(1, 1, 1, fade * 0.8), true, -1.0, true)


func _confetti() -> void:
	for i in 38:
		var speed := 22.0 + _hash(i + 20.0) * 30.0
		var y := fposmod(_hash(i + 70.0) * size.y + _t * speed, size.y + 10.0) - 5.0
		var x := fposmod(_hash(i + 30.0) * size.x + sin(_t * 1.1 + i) * 10.0, size.x)
		var spin := _t * (2.0 + _hash(i) * 4.0) + i
		var flip := absf(cos(spin))   # turning over as it falls
		var half := Vector2(4.0, 2.2 * flip + 0.4)
		var rot := Transform2D(spin * 0.5, Vector2(x, y))
		var quad := PackedVector2Array([rot * Vector2(-half.x, -half.y), rot * Vector2(half.x, -half.y), rot * Vector2(half.x, half.y), rot * Vector2(-half.x, half.y)])
		draw_colored_polygon(quad, CONFETTI[i % CONFETTI.size()])


## Pennants (New Year: gold and silver triangles) or little hearts
## (Valentine's: reds and pinks) hung along the swag.
func _bunting(hearts: bool) -> void:
	var wire := _swag()
	draw_polyline(wire, INK, 2.0, true)
	for i in range(1, 40, 3):
		var at := wire[i]
		if hearts:
			var c: Color = PINKS[(i / 3) % PINKS.size()]
			var sway := sin(_t * 2.0 + i) * 0.15
			_heart(at + Vector2(0, 10), 8.0, c, sway)
		else:
			var c := Color(1.0, 0.82, 0.32) if (i / 3) % 2 == 0 else Color(0.86, 0.88, 0.94)
			var tri := PackedVector2Array([at + Vector2(-8, 0), at + Vector2(8, 0), at + Vector2(0, 16)])
			draw_colored_polygon(tri, c)
			tri.append(tri[0])
			draw_polyline(tri, INK, 1.5, true)


# Valentine's: hearts drifting up, a heart balloon.
func _rising_hearts() -> void:
	for i in 18:
		var speed := 14.0 + _hash(i + 20.0) * 18.0
		var y := size.y - fposmod(_hash(i + 70.0) * size.y + _t * speed, size.y + 30.0) + 15.0
		var x := fposmod(_hash(i + 30.0) * size.x + sin(_t * 0.9 + i) * 12.0, size.x)
		var c: Color = PINKS[i % PINKS.size()]
		_heart(Vector2(x, y), 6.0 + _hash(i + 5.0) * 7.0, Color(c, 0.55), sin(_t + i) * 0.2, false)


func _balloon(c: Vector2, r: float) -> void:
	var bob := Vector2(0, sin(_t * 1.6) * r * 0.08)
	var string := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		string.append(c + bob + Vector2(sin(u * 5.0 + _t) * r * 0.08, r * 0.9 + u * r * 1.6))
	draw_polyline(string, INK, 1.5, true)
	_heart(c + bob, r, Color(0.96, 0.3, 0.42), sin(_t * 1.2) * 0.06)
	draw_circle(c + bob + Vector2(-r * 0.38, -r * 0.3), r * 0.14, Color(1, 1, 1, 0.6), true, -1.0, true)


## A heart centred at `c`, `r` across its lobes, tipped by `tilt` radians.
func _heart(c: Vector2, r: float, fill: Color, tilt := 0.0, inked := true) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var t := TAU * float(k) / 32.0
		var p := Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 16.0)
		pts.append(c + p.rotated(tilt))
	draw_colored_polygon(pts, fill)
	if inked:
		pts.append(pts[0])
		draw_polyline(pts, INK, 1.6, true)
