class_name TSIcon
extends Control

## Every picture in the menus, drawn in code in the hand-drawn style: pastel
## fills with a round-capped ink outline. No image files. Also draws the
## critters (a round blob with big eyes, cheeks and an accessory), little
## eggs, the ship parts (broken or fixed) and the club badges.
##
##   TSIcon.make("coin", 40)
##   TSIcon.make("critter", 120, 5)       # Blueberry
##   TSIcon.make("chest", 80, 0, "rare")
##   TSIcon.make("part", 90, TSProfile.PART_ENGINE, "broken")

var icon: String = "coin"
var index: int = 0 # critter / shell / badge index
var variant: String = "" # chest rarity, etc.
var silhouette: bool = false # a locked collectible: a soft grey shape with a lock
var tint: Color = Color(0, 0, 0, 0) # overrides an icon's main colour when set

const INK := Color(0.27, 0.16, 0.19)
const GOLD := Color(1.00, 0.82, 0.30)
const GOLD_DARK := Color(0.93, 0.62, 0.16)
const PINK := Color(1.00, 0.55, 0.70)
const WHITE := Color(1, 1, 1)

var _s := 1.0
var _o := Vector2.ZERO


static func make(name: String, px: float, idx: int = 0, var_name: String = "") -> TSIcon:
	var ic := TSIcon.new()
	ic.icon = name
	ic.index = idx
	ic.variant = var_name
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_icon(name: String, idx: int = 0, var_name: String = "") -> void:
	icon = name
	index = idx
	variant = var_name
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# -- drawing helpers, in unit coordinates (0..1 across the icon's square) --------

func _u(v: Vector2) -> Vector2:
	return _o + v * _s


func _w() -> float:
	return clampf(_s * 0.05, 1.6, 5.5)


const SILHOUETTE := Color(0.70, 0.64, 0.68) # locked shapes: readable, not a black hole


func _fill(c: Color) -> Color:
	return SILHOUETTE if silhouette else c


func _pts(unit: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in unit:
		out.append(_u(p))
	return out


func _poly(unit: Array, fill: Color, outline := true) -> void:
	var pts := _pts(unit)
	draw_colored_polygon(pts, _fill(fill))
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, INK, _w(), true)


func _circle(c: Vector2, r: float, fill: Color, outline := true) -> void:
	draw_circle(_u(c), r * _s, _fill(fill), true, -1.0, true)
	if outline:
		draw_arc(_u(c), r * _s, 0.0, TAU, 40, INK, _w(), true)


func _ellipse_pts(c: Vector2, rx: float, ry: float, n := 28, rot := 0.0) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


func _ellipse(c: Vector2, rx: float, ry: float, fill: Color, outline := true, rot := 0.0) -> void:
	_poly(_ellipse_pts(c, rx, ry, 28, rot), fill, outline)


func _rrect_pts(r: Rect2, rad: float) -> Array:
	var out: Array = []
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI * 0.5],
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for k in 6:
			var a: float = c[1] + (PI * 0.5) * float(k) / 5.0
			out.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return out


func _rrect(r: Rect2, rad: float, fill: Color, outline := true) -> void:
	_poly(_rrect_pts(r, rad), fill, outline)


func _line(unit: Array, color: Color = INK, width_scale := 1.0) -> void:
	draw_polyline(_pts(unit), color, _w() * width_scale, true)


func _star_pts(c: Vector2, r_out: float, r_in: float, n := 5, rot := -PI / 2.0) -> Array:
	var out: Array = []
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _heart_pts(c: Vector2, s: float) -> Array:
	var out: Array = []
	for i in 32:
		var t := TAU * float(i) / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		out.append(c + Vector2(x, -y) * s / 17.0)
	return out


func _text(pos: Vector2, text: String, size_unit: float, color: Color) -> void:
	var font := TSToon.hand_font()
	var fs := int(size_unit * _s)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, _u(pos) - Vector2(w * 0.5, -fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _col(default: Color) -> Color:
	return tint if tint.a > 0.0 else default


func _draw() -> void:
	_s = minf(size.x, size.y)
	_o = (size - Vector2(_s, _s)) * 0.5
	match icon:
		"coin": _draw_coin()
		"star": _poly(_star_pts(Vector2(0.5, 0.54), 0.44, 0.2), _col(GOLD))
		"heart": _poly(_heart_pts(Vector2(0.5, 0.52), 0.4), _col(PINK))
		"heart_empty": _poly(_heart_pts(Vector2(0.5, 0.52), 0.4), Color(0.88, 0.84, 0.84))
		"bomb": _draw_bomb()
		"swap": _draw_any_piece()   # the Any Piece booster (saved under its old id, "swap")
		"rocks": _draw_rocks()
		"chest": _draw_chest()
		"gift": _draw_gift()
		"flame": _draw_flame()
		"calendar": _draw_calendar()
		"pass": _draw_pass()
		"hunt": _draw_hunt()
		"tag": _draw_tag()
		"cog": _draw_cog()
		"home": _draw_home()
		"shop": _draw_shop()
		"collection": _draw_critter(0, Vector2(0.5, 0.56), 0.4)
		"trophy": _draw_trophy()
		"clubs": _draw_clubs()
		"back": _poly([Vector2(0.18, 0.5), Vector2(0.52, 0.18), Vector2(0.52, 0.36), Vector2(0.84, 0.36), Vector2(0.84, 0.64), Vector2(0.52, 0.64), Vector2(0.52, 0.82)], _col(WHITE))
		"info": _draw_info()
		"lock": _draw_lock()
		"check": _draw_check()
		"close": _draw_close()
		"clock": _draw_clock()
		"crown": _draw_crown(Vector2(0.5, 0.56), 0.8)
		"pause": _draw_pause()
		"play": _poly([Vector2(0.3, 0.2), Vector2(0.82, 0.5), Vector2(0.3, 0.8)], _col(WHITE))
		"ad": _draw_ad()
		"noads": _draw_noads()
		"music": _draw_music()
		"sound": _draw_sound()
		"vibrate": _draw_vibrate()
		"help": _draw_help()
		"plus": _draw_plus()
		"egg": _draw_shell(index, Vector2(0.5, 0.52), 0.44)
		"part": _draw_part(index, variant == "broken")
		"critter": _draw_critter(index, Vector2(0.5, 0.56), 0.4)
		"badge": _draw_badge(index)
		_: _circle(Vector2(0.5, 0.5), 0.4, _col(GOLD))
	if silhouette and icon != "lock":
		_draw_lock_at(Vector2(0.76, 0.8), 0.62)


# -- icons ----------------------------------------------------------------------

func _draw_coin() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(GOLD))
	draw_arc(_u(Vector2(0.5, 0.5)), 0.3 * _s, 0.0, TAU, 32, GOLD_DARK, _w() * 0.8, true)
	_poly(_star_pts(Vector2(0.5, 0.52), 0.17, 0.08), GOLD_DARK, false)
	draw_arc(_u(Vector2(0.5, 0.5)), 0.35 * _s, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.8), _w() * 0.9, true)


func _draw_bomb() -> void:
	var c := Vector2(0.46, 0.58)
	_circle(c, 0.32, _col(Color(0.36, 0.33, 0.52)))
	_circle(c + Vector2(-0.12, -0.12), 0.07, Color(1, 1, 1, 0.8), false)
	var cap := c + Vector2(0.2, -0.24)
	_poly([cap + Vector2(-0.1, 0.02), cap + Vector2(0.02, -0.1), cap + Vector2(0.1, -0.02), cap + Vector2(-0.02, 0.1)], Color(0.78, 0.76, 0.86))
	_line([cap + Vector2(0.05, -0.05), cap + Vector2(0.12, -0.14), cap + Vector2(0.2, -0.18)])
	_poly(_star_pts(cap + Vector2(0.22, -0.2), 0.1, 0.045, 8), Color(1.0, 0.62, 0.25))
	if not silhouette:
		for side in [-1.0, 1.0]:
			draw_circle(_u(c + Vector2(side * 0.1, 0.02)), 0.04 * _s, INK, true, -1.0, true)
		draw_arc(_u(c + Vector2(0, 0.08)), 0.05 * _s, 0.2, PI - 0.2, 10, INK, _w() * 0.7, true)


# The Any Piece: a wild block -- a cream tile holding a little square of each
# piece colour, with a gold sparkle on its corner. It becomes whatever it
# matches.
func _draw_any_piece() -> void:
	_rrect(Rect2(0.14, 0.2, 0.66, 0.66), 0.14, _col(Color(1.0, 0.97, 0.88)))
	var colours := [Color(1.0, 0.83, 0.36), Color(0.50, 0.86, 0.56), Color(0.52, 0.80, 0.98), Color(1.0, 0.56, 0.72)]
	for i in 4:
		var cell := Vector2(0.23 + float(i % 2) * 0.25, 0.29 + float(i >> 1) * 0.25)
		_rrect(Rect2(cell, Vector2(0.23, 0.23)), 0.06, colours[i], false)
	_poly(_star_pts(Vector2(0.78, 0.22), 0.17, 0.07, 4), GOLD)


# Rocks: two round pebbles flying in from the top left, speed lines behind,
# the big one smiling.
func _draw_rocks() -> void:
	for streak in [[Vector2(0.06, 0.3), Vector2(0.2, 0.36)], [Vector2(0.1, 0.48), Vector2(0.3, 0.5)], [Vector2(0.3, 0.1), Vector2(0.38, 0.22)]]:
		_line(streak, Color(INK, 0.6), 1.0)
	var grey := _col(Color(0.72, 0.70, 0.76))
	_poly([Vector2(0.3, 0.2), Vector2(0.44, 0.16), Vector2(0.52, 0.26), Vector2(0.48, 0.38), Vector2(0.34, 0.4), Vector2(0.25, 0.3)], grey.lightened(0.08))
	var big := [Vector2(0.44, 0.5), Vector2(0.62, 0.4), Vector2(0.82, 0.46), Vector2(0.9, 0.66), Vector2(0.78, 0.86), Vector2(0.54, 0.88), Vector2(0.4, 0.72)]
	_poly(big, grey)
	_circle(Vector2(0.56, 0.52), 0.035, Color(1, 1, 1, 0.8), false)
	if not silhouette:
		for side in [-1.0, 1.0]:
			draw_circle(_u(Vector2(0.65 + side * 0.07, 0.64)), 0.028 * _s, INK, true, -1.0, true)
		draw_arc(_u(Vector2(0.65, 0.7)), 0.04 * _s, 0.2, PI - 0.2, 10, INK, _w() * 0.7, true)


## A camp spot or ship part (TSProfile.PARTS), in the ship's pink and cream or
## the camp's wood and canvas -- or, broken, dull and damaged: cracks, a bend,
## smoke, a heap of planks.
func _draw_part(i: int, broken: bool) -> void:
	var hull := Color(0.62, 0.6, 0.66) if broken else _col(Color(1.0, 0.74, 0.82))
	var trim := Color(0.8, 0.78, 0.82) if broken else Color(1.0, 0.97, 0.9)
	var glass := Color(0.36, 0.38, 0.5) if broken else Color(0.62, 0.84, 1.0)
	match i:
		TSProfile.PART_ENGINE:
			if broken:
				for k in 3:
					_circle(Vector2(0.3 - k * 0.08, 0.34 - k * 0.1), 0.08 + k * 0.03, Color(0.7, 0.68, 0.74, 0.8), false)
			else:
				_poly([Vector2(0.34, 0.38), Vector2(0.08, 0.5), Vector2(0.34, 0.62)], Color(1.0, 0.62, 0.3))
				_poly([Vector2(0.34, 0.44), Vector2(0.2, 0.5), Vector2(0.34, 0.56)], Color(1.0, 0.9, 0.45), false)
			_poly([Vector2(0.34, 0.3), Vector2(0.62, 0.36), Vector2(0.62, 0.64), Vector2(0.34, 0.7)], trim)
			_rrect(Rect2(0.6, 0.28, 0.3, 0.44), 0.08, hull)
		TSProfile.PART_HULL:
			_rrect(Rect2(0.1, 0.3, 0.8, 0.4), 0.2, hull)
			_rrect(Rect2(0.14, 0.52, 0.72, 0.07), 0.03, trim, false)
			if broken:
				_circle(Vector2(0.34, 0.44), 0.07, Color(INK, 0.3), false)
				for turn in [0.6, -0.6]:
					var pts: Array = []
					for corner in [Vector2(-0.12, -0.04), Vector2(0.12, -0.04), Vector2(0.12, 0.04), Vector2(-0.12, 0.04)]:
						pts.append(Vector2(0.62, 0.42) + (corner as Vector2).rotated(turn))
					_poly(pts, Color(1.0, 0.86, 0.72))
		TSProfile.PART_COCKPIT:
			var dome: Array = []
			for k in 17:
				var a := PI + PI * float(k) / 16.0
				dome.append(Vector2(0.5, 0.62) + Vector2(cos(a), sin(a)) * 0.34)
			_poly(dome, glass)
			_rrect(Rect2(0.1, 0.6, 0.8, 0.1), 0.04, trim)
			if broken:
				_line([Vector2(0.56, 0.3), Vector2(0.5, 0.42), Vector2(0.6, 0.48), Vector2(0.52, 0.58)], WHITE, 0.8)
			else:
				draw_arc(_u(Vector2(0.5, 0.62)), 0.24 * _s, PI * 1.2, PI * 1.45, 8, Color(1, 1, 1, 0.8), _w() * 0.9, true)
		TSProfile.PART_ANTENNA:
			var tip := Vector2(0.72, 0.28) if broken else Vector2(0.5, 0.18)
			_line([Vector2(0.5, 0.78), Vector2(0.5, 0.46), tip], INK, 1.3)
			_circle(tip, 0.08, Color(0.7, 0.66, 0.72) if broken else Color(1.0, 0.45, 0.55))
			_rrect(Rect2(0.34, 0.76, 0.32, 0.1), 0.04, hull)
		TSProfile.PART_FINS:
			if broken:
				_poly([Vector2(0.2, 0.8), Vector2(0.3, 0.3), Vector2(0.52, 0.18), Vector2(0.46, 0.4), Vector2(0.8, 0.8)], hull)
			else:
				_poly([Vector2(0.2, 0.8), Vector2(0.34, 0.16), Vector2(0.52, 0.16), Vector2(0.8, 0.8)], trim)
				_line([Vector2(0.36, 0.5), Vector2(0.62, 0.5)], _col(Color(1.0, 0.74, 0.82)), 1.4)
		TSProfile.PART_PORTHOLES:
			_circle(Vector2(0.5, 0.5), 0.34, trim)
			_circle(Vector2(0.5, 0.5), 0.24, glass)
			if broken:
				_line([Vector2(0.4, 0.34), Vector2(0.5, 0.46), Vector2(0.42, 0.56), Vector2(0.56, 0.66)], WHITE, 0.8)
				_rrect(Rect2(0.18, 0.44, 0.64, 0.1), 0.02, Color(0.64, 0.44, 0.3))
			else:
				draw_arc(_u(Vector2(0.5, 0.5)), 0.16 * _s, PI * 1.15, PI * 1.45, 8, Color(1, 1, 1, 0.8), _w() * 0.9, true)
		TSProfile.PART_NOSE:
			_poly([Vector2(0.2, 0.3), Vector2(0.58, 0.3), Vector2(0.9, 0.5), Vector2(0.58, 0.7), Vector2(0.2, 0.7)], hull)
			_poly([Vector2(0.58, 0.3), Vector2(0.9, 0.5), Vector2(0.58, 0.7)], trim)
			if broken:
				_poly([Vector2(0.1, 0.66), Vector2(0.9, 0.66), Vector2(0.84, 0.86), Vector2(0.16, 0.86)], Color(0.74, 0.58, 0.44))
		TSProfile.PART_LEGS:
			if broken:
				_line([Vector2(0.2, 0.3), Vector2(0.44, 0.56)], INK, 2.2)
				_line([Vector2(0.56, 0.62), Vector2(0.84, 0.82)], INK, 2.2)
				_line([Vector2(0.2, 0.3), Vector2(0.44, 0.56)], trim, 1.2)
				_line([Vector2(0.56, 0.62), Vector2(0.84, 0.82)], trim, 1.2)
			else:
				for x in [0.3, 0.7]:
					_line([Vector2(x, 0.18), Vector2(x + (0.12 if x > 0.5 else -0.12), 0.74)], INK, 2.2)
					_line([Vector2(x, 0.18), Vector2(x + (0.12 if x > 0.5 else -0.12), 0.74)], trim, 1.2)
					_ellipse(Vector2(x + (0.12 if x > 0.5 else -0.12), 0.78), 0.1, 0.05, hull)
		TSProfile.PART_SOLAR:
			var panel := Color(0.4, 0.46, 0.68) if broken else Color(0.36, 0.5, 0.9)
			if broken:
				_poly([Vector2(0.14, 0.52), Vector2(0.44, 0.44), Vector2(0.4, 0.7), Vector2(0.12, 0.72)], panel)
				_poly([Vector2(0.52, 0.5), Vector2(0.86, 0.56), Vector2(0.8, 0.78), Vector2(0.5, 0.72)], panel)
			else:
				_line([Vector2(0.5, 0.86), Vector2(0.5, 0.6)], INK, 1.4)
				_poly([Vector2(0.12, 0.3), Vector2(0.88, 0.3), Vector2(0.8, 0.62), Vector2(0.2, 0.62)], panel)
				for x in [0.37, 0.63]:
					_line([Vector2(x, 0.31), Vector2(x - 0.03, 0.61)], Color(0.7, 0.8, 1.0), 0.7)
				_line([Vector2(0.16, 0.46), Vector2(0.84, 0.46)], Color(0.7, 0.8, 1.0), 0.7)
		TSProfile.CAMP_FIRE:
			for turn in [0.35, -0.35]:
				var a := Vector2(0.24, 0.0).rotated(turn)
				_line([Vector2(0.5, 0.72) - a, Vector2(0.5, 0.72) + a], Color(0.4, 0.3, 0.26) if broken else Color(0.64, 0.44, 0.3), 2.0)
			if broken:
				_ellipse(Vector2(0.5, 0.72), 0.2, 0.06, Color(0.7, 0.68, 0.72), false)
				_circle(Vector2(0.42, 0.52), 0.05, Color(0.7, 0.68, 0.74, 0.7), false)
				_circle(Vector2(0.5, 0.38), 0.07, Color(0.7, 0.68, 0.74, 0.5), false)
			else:
				_poly([Vector2(0.36, 0.7), Vector2(0.5, 0.22), Vector2(0.64, 0.7)], Color(1.0, 0.55, 0.3))
				_poly([Vector2(0.43, 0.7), Vector2(0.5, 0.42), Vector2(0.57, 0.7)], Color(1.0, 0.9, 0.45), false)
		TSProfile.CAMP_TENT:
			if broken:
				_line([Vector2(0.24, 0.8), Vector2(0.3, 0.46)], Color(0.64, 0.44, 0.3), 1.4)
				_poly([Vector2(0.14, 0.8), Vector2(0.3, 0.5), Vector2(0.62, 0.66), Vector2(0.86, 0.8)], Color(0.8, 0.7, 0.72))
			else:
				_poly([Vector2(0.12, 0.8), Vector2(0.5, 0.2), Vector2(0.88, 0.8)], Color(1.0, 0.62, 0.74))
				_poly([Vector2(0.42, 0.8), Vector2(0.5, 0.5), Vector2(0.58, 0.8)], Color(0.5, 0.3, 0.34))
		TSProfile.CAMP_BENCH:
			var wood := Color(0.62, 0.5, 0.44) if broken else Color(0.78, 0.56, 0.38)
			if broken:
				for k in 3:
					_rrect(Rect2(0.12 + k * 0.06, 0.5 + k * 0.1, 0.56, 0.08), 0.02, wood)
			else:
				_rrect(Rect2(0.12, 0.4, 0.76, 0.1), 0.02, wood)
				for x in [0.18, 0.74]:
					_rrect(Rect2(x, 0.5, 0.08, 0.34), 0.02, wood)
				_line([Vector2(0.3, 0.4), Vector2(0.3, 0.26), Vector2(0.4, 0.22)], Color(0.7, 0.7, 0.78), 1.2)
		TSProfile.CAMP_GARDEN:
			_ellipse(Vector2(0.5, 0.66), 0.38, 0.18, Color(0.64, 0.48, 0.36))
			if not broken:
				for x in [0.32, 0.5, 0.68]:
					_line([Vector2(x, 0.66), Vector2(x, 0.44)], Color(0.36, 0.62, 0.44), 1.2)
					_ellipse(Vector2(x - 0.05, 0.44), 0.06, 0.03, Color(0.56, 0.86, 0.5), true, 0.5)
					_ellipse(Vector2(x + 0.05, 0.44), 0.06, 0.03, Color(0.56, 0.86, 0.5), true, -0.5)
		TSProfile.CAMP_WELL:
			var stone := Color(0.72, 0.7, 0.76)
			if broken:
				for p in [Vector2(0.34, 0.72), Vector2(0.52, 0.74), Vector2(0.68, 0.7), Vector2(0.44, 0.6), Vector2(0.6, 0.6)]:
					_ellipse(p, 0.1, 0.07, stone)
			else:
				_rrect(Rect2(0.24, 0.5, 0.52, 0.3), 0.05, stone)
				_ellipse(Vector2(0.5, 0.5), 0.26, 0.07, Color(0.3, 0.34, 0.5))
				for x in [0.28, 0.72]:
					_line([Vector2(x, 0.5), Vector2(x, 0.2)], Color(0.64, 0.44, 0.3), 1.2)
				_poly([Vector2(0.18, 0.24), Vector2(0.5, 0.08), Vector2(0.82, 0.24)], Color(1.0, 0.62, 0.58))
		TSProfile.CAMP_LOOKOUT:
			var logs := Color(0.64, 0.44, 0.3)
			if broken:
				for k in 3:
					_rrect(Rect2(0.16 + k * 0.05, 0.56 + k * 0.1, 0.66, 0.08), 0.04, logs)
			else:
				for x in [0.28, 0.72]:
					_line([Vector2(x, 0.86), Vector2(x, 0.34)], INK, 1.8)
					_line([Vector2(x, 0.86), Vector2(x, 0.34)], logs, 1.0)
				_rrect(Rect2(0.18, 0.28, 0.64, 0.1), 0.02, logs)
				_poly([Vector2(0.16, 0.28), Vector2(0.5, 0.08), Vector2(0.84, 0.28)], Color(0.62, 0.8, 1.0))


const CHEST_COLORS := {
	"common": [Color(0.86, 0.64, 0.44), Color(1.0, 0.84, 0.44)],
	"rare": [Color(0.56, 0.74, 1.0), Color(1.0, 0.92, 0.6)],
	"legendary": [Color(0.8, 0.64, 1.0), Color(1.0, 0.82, 0.3)],
	"locked": [Color(0.78, 0.76, 0.8), Color(0.9, 0.88, 0.9)],
}


func _draw_chest() -> void:
	var key := variant if CHEST_COLORS.has(variant) else "common"
	var body: Color = CHEST_COLORS[key][0]
	var trim: Color = CHEST_COLORS[key][1]
	if variant == "open":
		body = CHEST_COLORS["common"][0]
		# light pouring out, then the chest, lid thrown back
		_poly([Vector2(0.28, 0.5), Vector2(0.12, 0.05), Vector2(0.88, 0.05), Vector2(0.72, 0.5)], Color(1.0, 0.95, 0.6, 0.7), false)
		_rrect(Rect2(0.14, 0.18, 0.72, 0.2), 0.08, body)
		_rrect(Rect2(0.14, 0.46, 0.72, 0.36), 0.06, body)
		_circle(Vector2(0.4, 0.46), 0.08, GOLD)
		_circle(Vector2(0.56, 0.44), 0.08, GOLD)
		_rrect(Rect2(0.14, 0.46, 0.72, 0.1), 0.03, trim)
		return
	_rrect(Rect2(0.12, 0.44, 0.76, 0.4), 0.06, body)
	_poly([Vector2(0.12, 0.46), Vector2(0.12, 0.34), Vector2(0.2, 0.22), Vector2(0.8, 0.22), Vector2(0.88, 0.34), Vector2(0.88, 0.46)], body.lightened(0.12))
	_rrect(Rect2(0.12, 0.42, 0.76, 0.08), 0.03, trim)
	_rrect(Rect2(0.44, 0.36, 0.12, 0.22), 0.03, trim)
	if variant == "locked":
		_draw_lock_at(Vector2(0.5, 0.66), 0.5)


func _draw_gift() -> void:
	var box := _col(Color(0.62, 0.84, 1.0))
	_rrect(Rect2(0.16, 0.42, 0.68, 0.44), 0.05, box)
	_rrect(Rect2(0.12, 0.3, 0.76, 0.16), 0.05, box.lightened(0.15))
	_rrect(Rect2(0.44, 0.3, 0.12, 0.56), 0.02, PINK)
	_ellipse(Vector2(0.38, 0.24), 0.12, 0.07, PINK, true, 0.4)
	_ellipse(Vector2(0.62, 0.24), 0.12, 0.07, PINK, true, -0.4)


func _draw_flame() -> void:
	var outer := [
		Vector2(0.55, 0.06), Vector2(0.68, 0.26), Vector2(0.8, 0.46), Vector2(0.83, 0.63),
		Vector2(0.77, 0.8), Vector2(0.63, 0.91), Vector2(0.5, 0.93), Vector2(0.37, 0.91),
		Vector2(0.23, 0.8), Vector2(0.17, 0.63), Vector2(0.21, 0.46), Vector2(0.3, 0.34),
		Vector2(0.36, 0.46), Vector2(0.44, 0.28),
	]
	_poly(outer, _col(Color(1.0, 0.56, 0.3)))
	var inner: Array = []
	for p in outer:
		inner.append(Vector2(0.5, 0.8) + (p - Vector2(0.5, 0.8)) * 0.55)
	_poly(inner, Color(1.0, 0.86, 0.4), false)


func _draw_calendar() -> void:
	_rrect(Rect2(0.14, 0.2, 0.72, 0.66), 0.08, WHITE)
	_rrect(Rect2(0.14, 0.2, 0.72, 0.18), 0.08, _col(Color(1.0, 0.5, 0.56)))
	for x in [0.32, 0.68]:
		_rrect(Rect2(x - 0.03, 0.12, 0.06, 0.16), 0.03, WHITE)
	_draw_shell(0, Vector2(0.5, 0.62), 0.17)


func _draw_pass() -> void:
	_poly([Vector2(0.3, 0.5), Vector2(0.22, 0.92), Vector2(0.36, 0.84), Vector2(0.44, 0.94), Vector2(0.48, 0.56)], PINK)
	_poly([Vector2(0.7, 0.5), Vector2(0.78, 0.92), Vector2(0.64, 0.84), Vector2(0.56, 0.94), Vector2(0.52, 0.56)], PINK)
	_circle(Vector2(0.5, 0.42), 0.3, _col(GOLD))
	_poly(_star_pts(Vector2(0.5, 0.44), 0.18, 0.08), WHITE)


func _draw_hunt() -> void:
	var colors := [Color(1.0, 0.72, 0.84), Color(0.62, 0.84, 1.0), Color(1.0, 0.9, 0.5)]
	for i in 3:
		_ellipse(Vector2(0.32 + i * 0.18, 0.42 - (0.06 if i == 1 else 0.0)), 0.11, 0.14, colors[i])
	_poly([Vector2(0.1, 0.48), Vector2(0.9, 0.48), Vector2(0.78, 0.88), Vector2(0.22, 0.88)], _col(Color(0.86, 0.64, 0.44)))
	_line([Vector2(0.16, 0.62), Vector2(0.84, 0.62)], INK, 0.7)
	_line([Vector2(0.2, 0.75), Vector2(0.8, 0.75)], INK, 0.7)
	draw_arc(_u(Vector2(0.5, 0.48)), 0.34 * _s, PI, TAU, 20, INK, _w(), true)


func _draw_tag() -> void:
	var pts := [Vector2(0.14, 0.42), Vector2(0.46, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.54), Vector2(0.58, 0.86)]
	_poly(pts, _col(Color(1.0, 0.44, 0.5)))
	_circle(Vector2(0.74, 0.26), 0.06, WHITE)
	_text(Vector2(0.54, 0.52), "%", 0.34, WHITE)


func _draw_cog() -> void:
	var pts: Array = []
	for i in 48:
		var a := TAU * float(i) / 48.0
		var tooth := 1.0 if (i / 3) % 2 == 0 else 0.0
		pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * (0.33 + 0.1 * tooth))
	_poly(pts, _col(Color(0.8, 0.78, 0.92)))
	_circle(Vector2(0.5, 0.5), 0.13, WHITE)


func _draw_home() -> void:
	_poly([Vector2(0.1, 0.5), Vector2(0.5, 0.14), Vector2(0.9, 0.5)], _col(Color(1.0, 0.55, 0.62)))
	_rrect(Rect2(0.22, 0.46, 0.56, 0.4), 0.04, Color(1.0, 0.95, 0.84))
	_rrect(Rect2(0.42, 0.6, 0.16, 0.26), 0.05, Color(0.86, 0.64, 0.44))


func _draw_shop() -> void:
	_poly([Vector2(0.18, 0.34), Vector2(0.82, 0.34), Vector2(0.88, 0.88), Vector2(0.12, 0.88)], _col(Color(0.62, 0.84, 1.0)))
	draw_arc(_u(Vector2(0.5, 0.36)), 0.17 * _s, PI, TAU, 16, INK, _w() * 1.2, true)
	_poly(_heart_pts(Vector2(0.5, 0.62), 0.14), PINK)


func _draw_trophy() -> void:
	var g := _col(GOLD)
	draw_arc(_u(Vector2(0.24, 0.36)), 0.12 * _s, PI * 0.5, PI * 1.5, 12, INK, _w() * 1.3, true)
	draw_arc(_u(Vector2(0.76, 0.36)), 0.12 * _s, -PI * 0.5, PI * 0.5, 12, INK, _w() * 1.3, true)
	_poly([Vector2(0.24, 0.16), Vector2(0.76, 0.16), Vector2(0.7, 0.46), Vector2(0.56, 0.6), Vector2(0.44, 0.6), Vector2(0.3, 0.46)], g)
	_rrect(Rect2(0.42, 0.58, 0.16, 0.14), 0.02, g)
	_rrect(Rect2(0.28, 0.72, 0.44, 0.14), 0.04, Color(0.86, 0.64, 0.44))
	_poly(_star_pts(Vector2(0.5, 0.34), 0.1, 0.045), WHITE, false)


func _draw_clubs() -> void:
	_draw_critter(5, Vector2(0.34, 0.6), 0.24)
	_draw_critter(4, Vector2(0.66, 0.6), 0.24)
	_poly(_heart_pts(Vector2(0.5, 0.24), 0.14), PINK)


func _draw_info() -> void:
	_circle(Vector2(0.5, 0.5), 0.4, _col(Color(0.62, 0.84, 1.0)))
	_text(Vector2(0.5, 0.52), "i", 0.52, INK)


func _draw_lock_at(c: Vector2, scale: float) -> void:
	draw_arc(_u(c + Vector2(0, -0.12 * scale)), 0.16 * scale * _s, PI, TAU, 16, INK, _w() * 1.4 * scale, true)
	_rrect(Rect2(c + Vector2(-0.24, -0.12) * scale, Vector2(0.48, 0.38) * scale), 0.06 * scale, GOLD)
	_circle(c + Vector2(0, 0.05) * scale, 0.05 * scale, INK, false)


func _draw_lock() -> void:
	_draw_lock_at(Vector2(0.5, 0.56), 1.3)


func _draw_check() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(Color(0.55, 0.85, 0.55)))
	_line([Vector2(0.3, 0.52), Vector2(0.44, 0.66), Vector2(0.7, 0.36)], WHITE, 1.8)


func _draw_close() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(Color(1.0, 0.5, 0.56)))
	_line([Vector2(0.34, 0.34), Vector2(0.66, 0.66)], WHITE, 1.8)
	_line([Vector2(0.66, 0.34), Vector2(0.34, 0.66)], WHITE, 1.8)


func _draw_clock() -> void:
	_rrect(Rect2(0.42, 0.06, 0.16, 0.12), 0.03, _col(Color(0.8, 0.78, 0.92)))
	_circle(Vector2(0.5, 0.56), 0.36, WHITE)
	_line([Vector2(0.5, 0.56), Vector2(0.5, 0.34)], INK, 1.2)
	_line([Vector2(0.5, 0.56), Vector2(0.66, 0.62)], INK, 1.2)


func _draw_crown(c: Vector2, s: float) -> void:
	var pts := [
		c + Vector2(-0.34, 0.18) * s, c + Vector2(-0.38, -0.2) * s, c + Vector2(-0.18, 0.0) * s,
		c + Vector2(0, -0.28) * s, c + Vector2(0.18, 0.0) * s, c + Vector2(0.38, -0.2) * s, c + Vector2(0.34, 0.18) * s,
	]
	_poly(pts, _col(GOLD))
	_circle(c + Vector2(0, 0.06) * s, 0.05 * s, PINK)


func _draw_pause() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(WHITE))
	_rrect(Rect2(0.34, 0.3, 0.1, 0.4), 0.03, INK, false)
	_rrect(Rect2(0.56, 0.3, 0.1, 0.4), 0.03, INK, false)


func _draw_ad() -> void:
	_rrect(Rect2(0.12, 0.22, 0.76, 0.56), 0.08, _col(Color(0.62, 0.84, 1.0)))
	_poly([Vector2(0.42, 0.36), Vector2(0.64, 0.5), Vector2(0.42, 0.64)], WHITE)


func _draw_noads() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, WHITE)
	_text(Vector2(0.5, 0.52), "AD", 0.3, INK)
	draw_arc(_u(Vector2(0.5, 0.5)), 0.4 * _s, 0.0, TAU, 32, Color(0.92, 0.3, 0.36), _w() * 1.3, true)
	_line([Vector2(0.24, 0.24), Vector2(0.76, 0.76)], Color(0.92, 0.3, 0.36), 1.3)


func _draw_music() -> void:
	_line([Vector2(0.38, 0.7), Vector2(0.38, 0.2), Vector2(0.74, 0.14), Vector2(0.74, 0.62)], INK, 1.2)
	_ellipse(Vector2(0.3, 0.72), 0.11, 0.08, _col(PINK))
	_ellipse(Vector2(0.66, 0.64), 0.11, 0.08, _col(PINK))


func _draw_sound() -> void:
	_poly([Vector2(0.14, 0.4), Vector2(0.3, 0.4), Vector2(0.5, 0.22), Vector2(0.5, 0.78), Vector2(0.3, 0.6), Vector2(0.14, 0.6)], _col(Color(0.62, 0.84, 1.0)))
	draw_arc(_u(Vector2(0.5, 0.5)), 0.16 * _s, -0.8, 0.8, 10, INK, _w(), true)
	draw_arc(_u(Vector2(0.5, 0.5)), 0.3 * _s, -0.8, 0.8, 10, INK, _w(), true)


func _draw_vibrate() -> void:
	_rrect(Rect2(0.34, 0.14, 0.32, 0.72), 0.06, _col(Color(0.8, 0.78, 0.92)))
	for side in [-1.0, 1.0]:
		_line([Vector2(0.5 + side * 0.26, 0.34), Vector2(0.5 + side * 0.34, 0.42), Vector2(0.5 + side * 0.26, 0.5), Vector2(0.5 + side * 0.34, 0.58)])


func _draw_help() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(Color(1.0, 0.86, 0.5)))
	_text(Vector2(0.5, 0.52), "?", 0.5, INK)


func _draw_plus() -> void:
	_circle(Vector2(0.5, 0.5), 0.42, _col(Color(0.55, 0.85, 0.55)))
	_line([Vector2(0.5, 0.3), Vector2(0.5, 0.7)], WHITE, 1.8)
	_line([Vector2(0.3, 0.5), Vector2(0.7, 0.5)], WHITE, 1.8)


# -- collectibles -----------------------------------------------------------------

## A critter: a soft blob with big shiny eyes, pink cheeks, a little smile
## and its accessory. c/r in unit coordinates.
func _draw_critter(i: int, c: Vector2, r: float) -> void:
	var data: Dictionary = TSProfile.CRITTERS[clampi(i, 0, TSProfile.CRITTER_COUNT - 1)]
	var body: Color = tint if tint.a > 0.0 else data["color"]
	var acc: String = data["acc"]
	# accessories behind the body
	match acc:
		"cat":
			for side in [-1.0, 1.0]:
				_poly([c + Vector2(side * 0.62, -0.5) * r, c + Vector2(side * 0.8, -1.12) * r, c + Vector2(side * 0.2, -0.82) * r], body)
		"bunny":
			for side in [-1.0, 1.0]:
				_ellipse(c + Vector2(side * 0.38, -1.12) * r, 0.2 * r, 0.52 * r, body, true, side * 0.25)
				if not silhouette:
					_ellipse(c + Vector2(side * 0.38, -1.1) * r, 0.09 * r, 0.34 * r, Color(1.0, 0.72, 0.8), false, side * 0.25)
		"bear":
			for side in [-1.0, 1.0]:
				_circle(c + Vector2(side * 0.68, -0.72) * r, 0.26 * r, body)
		"frog":
			for side in [-1.0, 1.0]:
				_circle(c + Vector2(side * 0.46, -0.78) * r, 0.3 * r, body)
		"dino":
			for k in 3:
				var x := (-0.4 + k * 0.4) * r
				_poly([c + Vector2(x - 0.16 * r, -0.86 * r), c + Vector2(x, -1.2 * r), c + Vector2(x + 0.16 * r, -0.86 * r)], Color(1.0, 0.8, 0.4))
		"horns":
			for side in [-1.0, 1.0]:
				_poly([c + Vector2(side * 0.36, -0.78) * r, c + Vector2(side * 0.62, -1.24) * r, c + Vector2(side * 0.6, -0.7) * r], Color(1.0, 0.94, 0.8))
		"ghost":
			pass
	# the body: a slightly bottom-heavy blob, or a ghost with a wavy hem
	var pts: Array = []
	for k in 40:
		var a := TAU * float(k) / 40.0
		var rr := r * (1.0 + 0.06 * sin(a))
		var p := c + Vector2(cos(a) * rr * 1.06, sin(a) * rr * 0.94)
		if acc == "ghost" and sin(a) > 0.2:
			p.y = c.y + r * (0.9 + 0.12 * sin(a * 6.0))
		pts.append(p)
	_poly(pts, body)
	if silhouette:
		return
	# patterns
	match acc:
		"bee":
			for yy in [0.2, 0.52]:
				_ellipse(c + Vector2(0, yy) * r, 0.82 * r, 0.1 * r, INK, false)
		"freckles":
			for side in [-1.0, 1.0]:
				for k in 3:
					draw_circle(_u(c + Vector2(side * (0.46 + k * 0.08), 0.2 + (k % 2) * 0.06) * r), 0.025 * r * _s, Color(0.86, 0.56, 0.4), true, -1.0, true)
		"rainbow":
			var bands := [Color(1.0, 0.56, 0.6), Color(1.0, 0.86, 0.5), Color(0.62, 0.9, 0.66), Color(0.62, 0.8, 1.0)]
			for k in bands.size():
				draw_arc(_u(c + Vector2(0, 0.95) * r), (0.9 - k * 0.12) * r * _s, PI * 1.12, PI * 1.88, 24, bands[k], 0.1 * r * _s, true)
	# face
	var eye_y := -0.06 * r
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 0.34 * r, eye_y)
		_ellipse(e, 0.15 * r, 0.19 * r, INK, false)
		draw_circle(_u(e + Vector2(-0.05, -0.07) * r), 0.06 * r * _s, WHITE, true, -1.0, true)
		draw_circle(_u(e + Vector2(0.05, 0.06) * r), 0.028 * r * _s, WHITE, true, -1.0, true)
		_ellipse(c + Vector2(side * 0.6 * r, 0.22 * r), 0.13 * r, 0.07 * r, Color(1.0, 0.58, 0.68, 0.8), false)
	draw_arc(_u(c + Vector2(0, 0.14) * r), 0.1 * r * _s, 0.25, PI - 0.25, 12, INK, _w() * 0.8, true)
	# accessories in front
	match acc:
		"sprout":
			_line([c + Vector2(0, -0.92) * r, c + Vector2(0, -1.2) * r], Color(0.36, 0.7, 0.4))
			_ellipse(c + Vector2(-0.16, -1.24) * r, 0.18 * r, 0.09 * r, Color(0.56, 0.86, 0.5), true, 0.5)
			_ellipse(c + Vector2(0.16, -1.24) * r, 0.18 * r, 0.09 * r, Color(0.56, 0.86, 0.5), true, -0.5)
		"bow":
			_poly([c + Vector2(0.3, -0.86) * r, c + Vector2(0.62, -1.1) * r, c + Vector2(0.62, -0.72) * r], Color(1.0, 0.44, 0.6))
			_poly([c + Vector2(0.3, -0.86) * r, c + Vector2(0.0, -1.06) * r, c + Vector2(0.04, -0.7) * r], Color(1.0, 0.44, 0.6))
			_circle(c + Vector2(0.3, -0.86) * r, 0.08 * r, Color(1.0, 0.7, 0.8))
		"flower":
			for k in 5:
				var a2 := TAU * float(k) / 5.0
				_circle(c + Vector2(0.5, -0.8) * r + Vector2(cos(a2), sin(a2)) * 0.14 * r, 0.1 * r, WHITE)
			_circle(c + Vector2(0.5, -0.8) * r, 0.08 * r, Color(1.0, 0.86, 0.4))
		"bee":
			for side in [-1.0, 1.0]:
				_line([c + Vector2(side * 0.2, -0.9) * r, c + Vector2(side * 0.34, -1.26) * r])
				_circle(c + Vector2(side * 0.34, -1.3) * r, 0.08 * r, INK)
			_ellipse(c + Vector2(-0.9, -0.3) * r, 0.2 * r, 0.12 * r, Color(1, 1, 1, 0.8), true, -0.5)
		"halo":
			draw_arc(_u(c + Vector2(0, -1.12) * r), 0.36 * r * _s, 0.0, TAU, 28, Color(1.0, 0.86, 0.36), 0.1 * r * _s, true)
		"crown":
			_draw_crown(c + Vector2(0, -0.98) * r, r * 1.4)
		"party":
			_poly([c + Vector2(-0.26, -0.82) * r, c + Vector2(0.06, -1.5) * r, c + Vector2(0.3, -0.84) * r], Color(0.62, 0.84, 1.0))
			_circle(c + Vector2(0.06, -1.5) * r, 0.09 * r, Color(1.0, 0.86, 0.4))
		"glasses":
			for side in [-1.0, 1.0]:
				draw_arc(_u(c + Vector2(side * 0.34 * r, eye_y)), 0.24 * r * _s, 0.0, TAU, 20, INK, _w() * 0.9, true)
			_line([c + Vector2(-0.1, eye_y / r) * r, c + Vector2(0.1, eye_y / r) * r])
		"star":
			_line([c + Vector2(0, -0.92) * r, c + Vector2(0.1, -1.3) * r])
			_poly(_star_pts(c + Vector2(0.12, -1.4) * r, 0.2 * r, 0.09 * r), Color(1.0, 0.86, 0.36))
		"cloud":
			for k in 3:
				_circle(c + Vector2(-0.3 + k * 0.3, -0.96 - (0.1 if k == 1 else 0.0)) * r, 0.2 * r, WHITE)
		"pumpkin":
			_rrect(Rect2(c + Vector2(-0.07, -1.16) * r, Vector2(0.14, 0.28) * r), 0.04 * r, Color(0.44, 0.66, 0.36))
			_ellipse(c + Vector2(0.26, -1.08) * r, 0.18 * r, 0.08 * r, Color(0.56, 0.86, 0.5), true, -0.4)
		"beanie":
			_poly([c + Vector2(-0.86, -0.46) * r, c + Vector2(-0.6, -0.98) * r, c + Vector2(0.0, -1.14) * r, c + Vector2(0.6, -0.98) * r, c + Vector2(0.86, -0.46) * r], Color(0.62, 0.8, 1.0))
			_rrect(Rect2(c + Vector2(-0.9, -0.56) * r, Vector2(1.8, 0.2) * r), 0.08 * r, Color(1.0, 0.72, 0.8))
			_circle(c + Vector2(0, -1.18) * r, 0.14 * r, WHITE)
		"horns":
			pass


## An egg: a little egg in one of the egg paints, with a band of pastel pieces.
func _draw_shell(i: int, c: Vector2, r: float) -> void:
	var data: Dictionary = TSProfile.EGG_PAINTS[clampi(i, 0, TSProfile.EGG_PAINT_COUNT - 1)]
	var cap: Color = data["cap"]
	var trim: Color = data["trim"]
	var outline: Array = []
	for k in 40:
		var a := TAU * float(k) / 40.0
		var y := sin(a)
		var width := 0.78 * (1.0 + 0.12 * y)
		outline.append(c + Vector2(cos(a) * r * width, y * r))
	_poly(outline, cap)
	if silhouette:
		return
	# the band of pieces across the middle
	var band: Array = []
	for p in outline:
		var q: Vector2 = p
		band.append(Vector2(q.x, clampf(q.y, c.y - 0.2 * r, c.y + 0.26 * r)))
	draw_colored_polygon(_pts(band), trim)
	var pieces := [Color(1.0, 0.83, 0.36), Color(0.5, 0.86, 0.56), Color(1.0, 0.83, 0.36)]
	for k in 3:
		var x := c.x + (-0.42 + k * 0.3) * r
		_rrect(Rect2(x, c.y - 0.12 * r, 0.24 * r, 0.3 * r), 0.06 * r, pieces[k])
	match i:
		8: # speckles
			for k in 7:
				draw_circle(_u(c + Vector2(sin(k * 2.3) * 0.46, -0.6 + (k % 3) * 0.08) * r), 0.03 * r * _s, INK, true, -1.0, true)
		9: # stars
			for k in 4:
				_poly(_star_pts(c + Vector2(-0.3 + k * 0.2, -0.52 - (k % 2) * 0.16) * r, 0.07 * r, 0.03 * r), Color(1.0, 0.9, 0.5), false)
		11: # sprinkles
			var sprinkle := [Color(0.62, 0.84, 1.0), Color(1, 1, 1), Color(0.56, 0.86, 0.5)]
			for k in 6:
				var p0 := c + Vector2(-0.34 + k * 0.13, -0.5 - (k % 2) * 0.14) * r
				_line([p0, p0 + Vector2(0.05, 0.04) * r], sprinkle[k % 3], 0.9)
	var closed := _pts(outline)
	closed.append(closed[0])
	draw_polyline(closed, INK, _w(), true)
	draw_arc(_u(c + Vector2(-0.3, -0.5) * r), 0.14 * r * _s, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.8), _w() * 0.9, true)


const BADGE_COLORS := [
	Color(1.0, 0.62, 0.72), Color(0.62, 0.84, 1.0), Color(0.62, 0.9, 0.66), Color(1.0, 0.86, 0.5),
	Color(0.8, 0.7, 0.98), Color(1.0, 0.72, 0.56), Color(0.66, 0.92, 0.9), Color(1.0, 0.78, 0.9),
	Color(0.86, 0.9, 0.62), Color(0.76, 0.8, 0.98),
]
const BADGE_EMBLEMS := ["star", "heart", "egg", "flower", "moon", "bolt", "clover", "crown", "leaf", "note"]


## A club badge: a round shield in its colour with an emblem.
func _draw_badge(i: int) -> void:
	i = posmod(i, BADGE_COLORS.size())
	var pts: Array = []
	for k in 40:
		var a := TAU * float(k) / 40.0
		var p := Vector2(0.5, 0.48) + Vector2(cos(a) * 0.4, sin(a) * 0.4)
		if sin(a) > 0.3:
			p.y += (sin(a) - 0.3) * 0.12
		pts.append(p)
	_poly(pts, BADGE_COLORS[i])
	var c := Vector2(0.5, 0.5)
	match BADGE_EMBLEMS[i]:
		"star": _poly(_star_pts(c, 0.2, 0.09), WHITE)
		"heart": _poly(_heart_pts(c, 0.18), WHITE)
		"egg": _ellipse(c, 0.14, 0.19, WHITE)
		"flower":
			for k in 5:
				var a2 := TAU * float(k) / 5.0
				_circle(c + Vector2(cos(a2), sin(a2)) * 0.11, 0.08, WHITE)
			_circle(c, 0.06, Color(1.0, 0.86, 0.4))
		"moon":
			_circle(c, 0.18, WHITE)
			_circle(c + Vector2(0.09, -0.06), 0.15, BADGE_COLORS[i], false)
		"bolt": _poly([Vector2(0.54, 0.26), Vector2(0.36, 0.54), Vector2(0.5, 0.54), Vector2(0.44, 0.76), Vector2(0.64, 0.44), Vector2(0.5, 0.44)], WHITE)
		"clover":
			for k in 4:
				var a3 := PI * 0.5 * float(k) + PI * 0.25
				_circle(c + Vector2(cos(a3), sin(a3)) * 0.09, 0.08, WHITE)
		"crown": _draw_crown(c + Vector2(0, 0.02), 0.6)
		"leaf": _ellipse(c, 0.2, 0.11, WHITE, true, -0.6)
		"note":
			_line([Vector2(0.46, 0.64), Vector2(0.46, 0.3), Vector2(0.62, 0.34)], WHITE, 1.4)
			_ellipse(Vector2(0.4, 0.64), 0.08, 0.06, WHITE)
