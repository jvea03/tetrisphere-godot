class_name TSHolidayBanner
extends Control

## The Christmas season's Battle Pass banner, drawn rather than painted (the
## autumn one is a picture): a night sky with snow falling, a string of
## twinkling lights swagged across the top, snowy hills with a decorated tree,
## and the season's critters lined up along the bottom. Sized like the picture
## banner it stands in for; its parent rounds its corners (clip_children).

const INK := Color(0.27, 0.16, 0.19)
const SKY_TOP := Color(0.15, 0.19, 0.42)
const SKY_LOW := Color(0.45, 0.38, 0.66)
const SNOW := Color(0.99, 0.99, 1.0)
const SNOW_SHADE := Color(0.84, 0.88, 0.98)
const PINE := Color(0.24, 0.58, 0.36)
const PINE_DARK := Color(0.17, 0.44, 0.28)
const BULBS := [Color(1.0, 0.36, 0.4), Color(1.0, 0.84, 0.36), Color(0.5, 0.9, 0.56), Color(0.56, 0.78, 1.0)]
## The critters along the bottom: Santa, Elf, Snowman, Ginger, Polar, Frost Queen.
const CRITTERS := [91, 29, 70, 3, 97, 71]

var _t := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# The sky, deep blue into twilight violet.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	# Stars, twinkling.
	for i in 26:
		var p := Vector2(_hash(i) * w, _hash(i + 50.0) * h * 0.6)
		var a := 0.45 + 0.4 * sin(_t * (1.5 + _hash(i + 9.0) * 2.0) + i)
		draw_circle(p, 1.4 + _hash(i + 3.0) * 1.6, Color(1.0, 0.96, 0.8, a), true, -1.0, true)
	# Snowy hills: a far one in shade, a near one in white, both inked.
	_hill(h * 0.66, h * 0.07, 0.9, SNOW_SHADE)
	_tree(Vector2(w * 0.84, h * 0.7), h * 0.5)
	_hill(h * 0.8, h * 0.05, 2.3, SNOW)
	# The critters, bobbing a little.
	var n := CRITTERS.size()
	var s := minf(h * 0.42, w / float(n) * 0.95)
	for k in n:
		var tex := TSProfile.critter_art(int(CRITTERS[k]))
		var x := w * (0.1 + 0.8 * float(k) / float(n - 1))
		var bob := sin(_t * 2.2 + k * 1.3) * h * 0.012
		draw_texture_rect(tex, Rect2(Vector2(x - s * 0.5, h - s * 1.02 + bob), Vector2(s, s)), false)
	# A string of lights swagged across the top, under the season's title.
	var wire := PackedVector2Array()
	for i in 41:
		var u := float(i) / 40.0
		var sag := 4.0 * u * (1.0 - u)
		wire.append(Vector2(u * w, h * 0.06 + sag * h * 0.12 + sin(u * TAU * 3.0) * h * 0.012))
	draw_polyline(wire, PINE_DARK, 3.0, true)
	for i in range(1, 40, 3):
		var at := wire[i] + Vector2(0, 7)
		var c: Color = BULBS[(i / 3) % BULBS.size()]
		var lit := 0.55 + 0.45 * sin(_t * 3.0 + i * 0.9)
		draw_circle(at, 11.0, Color(c, 0.25 * lit), true, -1.0, true)
		draw_circle(at, 5.5, c.lerp(Color.WHITE, 0.3 * lit), true, -1.0, true)
		draw_arc(at, 5.5, 0.0, TAU, 14, INK, 1.5, true)
	# Snow falling over everything.
	for i in 46:
		var speed := 18.0 + _hash(i + 20.0) * 26.0
		var y := fposmod(_hash(i + 70.0) * h + _t * speed, h + 8.0) - 4.0
		var x := fposmod(_hash(i + 30.0) * w + sin(_t * 0.8 + i) * 8.0, w)
		draw_circle(Vector2(x, y), 1.6 + _hash(i + 5.0) * 2.2, Color(1, 1, 1, 0.85), true, -1.0, true)


## A rolling snowy hill whose top sits around `base`, filled down to the bottom.
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
