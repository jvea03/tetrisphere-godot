# Builds the Christmas season's Battle Pass banner, icons/battle_pass_banner_christmas.png
# (1100 x 390, the same shape as the autumn icons/battle_pass_banner.png): the
# season's critters crowded behind a gingham table under fairy lights, snowy
# pines and falling snow, from the critters' own stickers. The Shop's pass card
# and the Battle Pass screen pick it while the Christmas season runs
# (TSProfile.season_banner). Run:
#   Godot.exe --path . res://tools/make_pass_banner.tscn
extends Node

const SIZE := Vector2i(1100, 390)
const OUT := "res://icons/battle_pass_banner_christmas.png"
## The cast: critter index, centre, size, tilt (degrees), back row first.
const CAST := [
	[91, Vector2(165, 205), 230, -6.0],    # Santa
	[88, Vector2(372, 196), 210, 4.0],     # Rudy
	[70, Vector2(560, 186), 236, -2.0],    # Snowman, in the middle
	[71, Vector2(752, 196), 214, 5.0],     # Frost Queen
	[29, Vector2(950, 205), 226, -5.0],    # Elf
	[3, Vector2(92, 300), 170, 8.0],       # Ginger, in front at the left
	[37, Vector2(455, 312), 150, -4.0],    # Cocoa
	[56, Vector2(1012, 302), 168, -8.0],   # Flurry, in front at the right
]


func _ready() -> void:
	var sub := SubViewport.new()
	sub.size = SIZE
	sub.transparent_bg = false
	sub.msaa_2d = Viewport.MSAA_4X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var back := Scene.new()
	back.size = Vector2(SIZE)
	back.layer = "back"
	sub.add_child(back)
	for c: Array in CAST:
		var tex: Texture2D = TSProfile.critter_art(int(c[0]))
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var px := float(c[2])
		t.size = Vector2(px, px)
		t.position = (c[1] as Vector2) - t.size * 0.5
		t.pivot_offset = t.size * 0.5
		t.rotation = deg_to_rad(float(c[3]))
		sub.add_child(t)
		if c == CAST[4]:   # the table goes in front of the back row, behind the front one
			var table := Scene.new()
			table.size = Vector2(SIZE)
			table.layer = "table"
			sub.add_child(table)
	var front := Scene.new()
	front.size = Vector2(SIZE)
	front.layer = "front"
	sub.add_child(front)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("BANNER_OK ", ProjectSettings.globalize_path(OUT))
	get_tree().quit(0)


## One layer of the picture: the sky, pines and lights behind everyone; the
## gingham table and its presents between the rows; the snow over it all.
class Scene extends Control:
	const CREAM := Color(1.0, 0.97, 0.92)
	const RED := Color(0.93, 0.36, 0.38)
	const INK := Color(0.27, 0.16, 0.19)
	var layer := "back"

	func _draw() -> void:
		match layer:
			"back": _back()
			"table": _table()
			"front": _front()

	func _back() -> void:
		# A soft winter sky, deeper at the top, warm near the table.
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([Color(0.6, 0.74, 0.96), Color(0.6, 0.74, 0.96), Color(1.0, 0.93, 0.88), Color(1.0, 0.93, 0.88)]))
		# Two rows of snowy pines, pale with distance.
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for row in 2:
			var col := Color(0.62, 0.78, 0.8) if row == 0 else Color(0.48, 0.7, 0.66)
			var base := 250.0 + 25.0 * float(row)
			var x := -30.0 + float(row) * 45.0
			while x < size.x + 60.0:
				var h := rng.randf_range(120.0, 170.0) - float(row) * 10.0
				_pine(Vector2(x, base), h, col)
				x += rng.randf_range(70.0, 105.0)
		# Fairy lights, swagged across the top.
		var bulbs := [Color(1.0, 0.36, 0.38), Color(1.0, 0.82, 0.3), Color(0.45, 0.82, 0.5), Color(0.5, 0.72, 1.0)]
		for swag in 4:
			var a := Vector2(size.x * float(swag) / 4.0, 12.0)
			var b := Vector2(size.x * float(swag + 1) / 4.0, 12.0)
			var pts := PackedVector2Array()
			for i in 21:
				var u := float(i) / 20.0
				pts.append(a.lerp(b, u) + Vector2(0, 46.0 * sin(u * PI)))
			draw_polyline(pts, Color(0.3, 0.42, 0.36), 3.0, true)
			for i in range(2, 20, 3):
				var p := pts[i] + Vector2(0, 9)
				var bc: Color = bulbs[(i / 3 + swag) % bulbs.size()]
				draw_circle(p, 16.0, Color(bc, 0.25), true, -1.0, true)
				draw_circle(p, 7.0, bc, true, -1.0, true)
				draw_circle(p + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.8), true, -1.0, true)

	func _pine(base: Vector2, h: float, col: Color) -> void:
		for k in 3:
			var y0 := base.y - h * 0.27 * float(k)
			var half := h * (0.34 - 0.08 * float(k))
			var tip := Vector2(base.x, y0 - h * 0.42)
			draw_colored_polygon(PackedVector2Array([Vector2(base.x - half, y0), Vector2(base.x + half, y0), tip]), col)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-half * 0.4, h * 0.15), Vector2(base.x, tip.y + h * 0.11), tip + Vector2(half * 0.4, h * 0.15)]), Color(1, 1, 1, 0.9))

	func _table() -> void:
		# A red-and-cream gingham cloth, its checks widening toward the front.
		var top := 292.0
		draw_rect(Rect2(0, top, size.x, size.y - top), CREAM)
		# Gingham: red bands across and down, half-see-through, so the checks
		# where they cross come out darker. The rows deepen toward the front.
		var rows := 4
		for r in rows:
			var y0 := top + pow(float(r) / rows, 1.25) * (size.y - top)
			var y1 := top + pow(float(r + 1) / rows, 1.25) * (size.y - top)
			draw_rect(Rect2(0, y0, size.x, (y1 - y0) * 0.5), Color(RED, 0.42))
		var cx := size.x * 0.5
		for k in range(-14, 15):
			# Each band fans out a little toward the front, for depth.
			var xt := cx + float(k) * 40.0
			var xb := cx + float(k) * 52.0
			draw_colored_polygon(PackedVector2Array([Vector2(xt, top), Vector2(xt + 20.0, top), Vector2(xb + 26.0, size.y), Vector2(xb, size.y)]), Color(RED, 0.42))
		draw_line(Vector2(0, top), Vector2(size.x, top), Color(RED, 0.8), 3.0)
		# Presents on the table.
		for g: Array in [[Vector2(250, 330), 70.0, Color(0.45, 0.78, 0.5), Color(1.0, 0.36, 0.38)],
				[Vector2(640, 338), 62.0, Color(1.0, 0.42, 0.45), Color(1.0, 0.85, 0.35)],
				[Vector2(850, 326), 76.0, Color(0.55, 0.72, 1.0), Color(1.0, 1.0, 1.0)]]:
			_present(g[0], g[1], g[2], g[3])

	func _present(at: Vector2, s: float, box: Color, ribbon: Color) -> void:
		var r := Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s * 0.82))
		draw_rect(r, box)
		draw_rect(r, INK, false, 3.0)
		draw_rect(Rect2(Vector2(at.x - s * 0.08, r.position.y), Vector2(s * 0.16, r.size.y)), ribbon)
		draw_rect(Rect2(Vector2(r.position.x, at.y - s * 0.12), Vector2(s, s * 0.14)), ribbon)
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(at.x + side * s * 0.16, r.position.y - s * 0.06), s * 0.13, ribbon, true, -1.0, true)
			draw_circle(Vector2(at.x + side * s * 0.16, r.position.y - s * 0.06), s * 0.13, INK, false, 2.5, true)

	func _front() -> void:
		# Snow falling over everything, and a few sparkles.
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 70:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.85)
			draw_circle(p, rng.randf_range(2.5, 6.0), Color(1, 1, 1, rng.randf_range(0.65, 0.95)), true, -1.0, true)
		for i in 10:
			var p := Vector2(rng.randf() * size.x, rng.randf_range(60.0, 200.0))
			var s := rng.randf_range(7.0, 13.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.28, 0), p + Vector2(0, s), p + Vector2(-s * 0.28, 0)]), Color(1, 1, 1, 0.95))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, s * 0.28), p + Vector2(s, 0), p + Vector2(0, -s * 0.28)]), Color(1, 1, 1, 0.95))
