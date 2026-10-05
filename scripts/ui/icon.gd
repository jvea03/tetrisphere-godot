class_name TSIcon
extends Control

## Every picture in the menus, drawn in code in the hand-drawn style: pastel
## fills with a round-capped ink outline. The critters are the one exception:
## each is a sticker from icons/critters/. Also draws little eggs, the ship
## parts (broken or fixed) and the club badges.
##
##   TSIcon.make("coin", 40)
##   TSIcon.make("critter", 120, 5)       # Grad
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


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # a sticker shrunk to a 40px builder stays smooth


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
		"tie": _draw_tie()
		"chest": _draw_chest()
		"gift": _draw_gift()
		"flame": _draw_flame()
		"calendar": _draw_calendar()
		"pass": _draw_pass()
		"hunt": _draw_hunt()
		"materials": _draw_materials()
		"coin_pack": _draw_coin_pack(index)
		"material_pack": _draw_material_pack(index)
		"skip": _draw_skip()
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


# The tie-down: a stake-brown tile with a row of cream layer dots, as it sits
# on the egg.
func _draw_tie() -> void:
	_rrect(Rect2(0.14, 0.14, 0.72, 0.72), 0.16, _col(Color(0.58, 0.38, 0.26)))
	for k in 3:
		_rrect(Rect2(0.2 + float(k) * 0.21, 0.4, 0.17, 0.2), 0.05, Color(1.0, 0.93, 0.78))


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
		_:
			_draw_camp_spot(i, broken)


## The camp's later waves (TSProfile.CAMP_HAMMOCK on): built, or their makings.
func _draw_camp_spot(i: int, broken: bool) -> void:
	var wood := Color(0.62, 0.5, 0.44) if broken else Color(0.78, 0.56, 0.38)
	var pink := Color(0.8, 0.7, 0.72) if broken else Color(1.0, 0.7, 0.78)
	var leaf := Color(0.6, 0.7, 0.6) if broken else Color(0.48, 0.78, 0.5)
	var stone := Color(0.74, 0.72, 0.78)
	match i:
		TSProfile.CAMP_HAMMOCK:
			for x in [0.16, 0.84]:
				_line([Vector2(x, 0.84), Vector2(x, 0.3)], wood, 1.6)
			if broken:
				_line([Vector2(0.3, 0.8), Vector2(0.42, 0.72), Vector2(0.5, 0.82), Vector2(0.62, 0.74)], Color(0.9, 0.84, 0.7), 1.0)
			else:
				_poly([Vector2(0.16, 0.36), Vector2(0.5, 0.5), Vector2(0.84, 0.36), Vector2(0.5, 0.66)], pink)
		TSProfile.CAMP_PICNIC:
			if broken:
				_rrect(Rect2(0.14, 0.56, 0.72, 0.18), 0.08, wood)
			else:
				_rrect(Rect2(0.12, 0.42, 0.76, 0.1), 0.02, Color(1.0, 0.62, 0.66))
				for x in [0.2, 0.72]:
					_rrect(Rect2(x, 0.52, 0.08, 0.3), 0.02, wood)
				_rrect(Rect2(0.08, 0.66, 0.84, 0.07), 0.02, wood)
		TSProfile.CAMP_CLOTHESLINE:
			for x in [0.14, 0.86]:
				_line([Vector2(x, 0.86), Vector2(x, 0.24)], wood, 1.4)
			if broken:
				_line([Vector2(0.14, 0.26), Vector2(0.4, 0.7), Vector2(0.7, 0.8)], WHITE, 0.8)
			else:
				_line([Vector2(0.14, 0.26), Vector2(0.5, 0.34), Vector2(0.86, 0.26)], INK, 0.7)
				_rrect(Rect2(0.28, 0.3, 0.16, 0.26), 0.03, Color(0.62, 0.8, 1.0))
				_rrect(Rect2(0.54, 0.31, 0.2, 0.34), 0.03, WHITE)
		TSProfile.CAMP_MAILBOX:
			if broken:
				_poly([Vector2(0.24, 0.66), Vector2(0.7, 0.58), Vector2(0.76, 0.76), Vector2(0.28, 0.82)], stone)
			else:
				_line([Vector2(0.5, 0.88), Vector2(0.5, 0.56)], wood, 1.6)
				_rrect(Rect2(0.22, 0.28, 0.56, 0.3), 0.12, pink)
				_poly([Vector2(0.76, 0.3), Vector2(0.76, 0.14), Vector2(0.9, 0.2)], Color(1.0, 0.36, 0.42))
		TSProfile.CAMP_WINDMILL:
			_poly([Vector2(0.32, 0.88), Vector2(0.68, 0.88), Vector2(0.6, 0.4), Vector2(0.4, 0.4)], Color(1.0, 0.95, 0.86))
			if not broken:
				for a in [0.4, 0.4 + PI * 0.5, 0.4 + PI, 0.4 + PI * 1.5]:
					_line([Vector2(0.5, 0.38), Vector2(0.5, 0.38) + Vector2.from_angle(a) * 0.32], pink, 1.6)
				_circle(Vector2(0.5, 0.38), 0.05, INK, false)
		TSProfile.CAMP_DOCK:
			_ellipse(Vector2(0.5, 0.4), 0.42, 0.14, Color(0.6, 0.82, 1.0), false)
			if broken:
				for k in 3:
					_rrect(Rect2(0.2 + k * 0.18, 0.58 + (k % 2) * 0.08, 0.2, 0.06), 0.02, wood)
			else:
				for k in 4:
					_rrect(Rect2(0.36, 0.38 + k * 0.12, 0.28, 0.09), 0.02, wood)
		TSProfile.CAMP_PLAYGROUND:
			if broken:
				_rrect(Rect2(0.3, 0.7, 0.4, 0.08), 0.02, wood)
			else:
				for x in [0.2, 0.8]:
					_line([Vector2(x - 0.08, 0.86), Vector2(x, 0.2), Vector2(x + 0.08, 0.86)], Color(1.0, 0.6, 0.4), 1.4)
				_line([Vector2(0.2, 0.2), Vector2(0.8, 0.2)], INK, 1.4)
				_line([Vector2(0.44, 0.2), Vector2(0.44, 0.62)], INK, 0.6)
				_line([Vector2(0.58, 0.2), Vector2(0.58, 0.62)], INK, 0.6)
				_rrect(Rect2(0.4, 0.62, 0.22, 0.06), 0.02, wood)
		TSProfile.CAMP_TREEHOUSE:
			_rrect(Rect2(0.42, 0.42, 0.16, 0.46), 0.04, wood)
			if broken:
				_line([Vector2(0.5, 0.5), Vector2(0.24, 0.26)], wood, 1.4)
				_line([Vector2(0.5, 0.44), Vector2(0.76, 0.22)], wood, 1.4)
			else:
				_circle(Vector2(0.5, 0.3), 0.26, leaf)
				_rrect(Rect2(0.3, 0.26, 0.4, 0.22), 0.03, Color(1.0, 0.86, 0.66))
				_poly([Vector2(0.26, 0.28), Vector2(0.5, 0.1), Vector2(0.74, 0.28)], Color(1.0, 0.5, 0.56))
		TSProfile.CAMP_STALL:
			if broken:
				_rrect(Rect2(0.18, 0.56, 0.3, 0.28), 0.03, wood)
				_rrect(Rect2(0.5, 0.6, 0.3, 0.24), 0.03, wood)
			else:
				_rrect(Rect2(0.16, 0.54, 0.68, 0.3), 0.03, wood)
				for k in 4:
					_poly([Vector2(0.12 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.34), Vector2(0.12 + k * 0.19, 0.34)], pink if k % 2 == 0 else WHITE)
				for x in [0.18, 0.82]:
					_line([Vector2(x, 0.34), Vector2(x, 0.54)], wood, 1.0)
		TSProfile.CAMP_GREENHOUSE:
			if broken:
				for p in [Vector2(0.3, 0.74), Vector2(0.5, 0.7), Vector2(0.7, 0.76)]:
					_poly([p, p + Vector2(0.1, -0.05), p + Vector2(0.05, 0.06)], Color(0.8, 0.92, 1.0))
			else:
				_poly([Vector2(0.14, 0.84), Vector2(0.86, 0.84), Vector2(0.86, 0.44), Vector2(0.5, 0.18), Vector2(0.14, 0.44)], Color(0.78, 0.92, 1.0))
				_circle(Vector2(0.36, 0.68), 0.1, leaf)
				_circle(Vector2(0.64, 0.66), 0.1, leaf)
		TSProfile.CAMP_SPRING:
			_ellipse(Vector2(0.5, 0.64), 0.38 if not broken else 0.2, 0.14 if not broken else 0.07, Color(0.62, 0.88, 0.94))
			if not broken:
				for x in [0.38, 0.52, 0.66]:
					_line([Vector2(x, 0.48), Vector2(x - 0.04, 0.36), Vector2(x + 0.02, 0.24)], WHITE, 0.8)
		TSProfile.CAMP_OBSERVATORY:
			if broken:
				for p in [Vector2(0.32, 0.72), Vector2(0.56, 0.74), Vector2(0.46, 0.6)]:
					_ellipse(p, 0.12, 0.08, stone)
			else:
				_rrect(Rect2(0.2, 0.5, 0.6, 0.36), 0.03, Color(0.96, 0.94, 1.0))
				var dome: Array = []
				for k in 17:
					var a := PI + PI * float(k) / 16.0
					dome.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.3)
				_poly(dome, Color(0.62, 0.66, 0.9))
				_line([Vector2(0.5, 0.36), Vector2(0.8, 0.14)], Color(0.88, 0.9, 0.96), 1.6)
		TSProfile.CAMP_OVEN:
			var clay := Color(0.76, 0.56, 0.48) if broken else Color(0.88, 0.58, 0.44)
			if broken:
				_ellipse(Vector2(0.5, 0.7), 0.3, 0.16, clay)
			else:
				var dome: Array = []
				for k in 17:
					var a := PI + PI * float(k) / 16.0
					dome.append(Vector2(0.5, 0.82) + Vector2(cos(a), sin(a)) * 0.38)
				_poly(dome, clay)
				_rrect(Rect2(0.38, 0.62, 0.24, 0.2), 0.1, Color(0.32, 0.22, 0.24))
				_rrect(Rect2(0.62, 0.22, 0.12, 0.26), 0.02, clay)
		TSProfile.CAMP_STATUE:
			if broken:
				_poly([Vector2(0.2, 0.84), Vector2(0.8, 0.84), Vector2(0.7, 0.4), Vector2(0.5, 0.3), Vector2(0.28, 0.44)], stone)
			else:
				_rrect(Rect2(0.24, 0.7, 0.52, 0.16), 0.02, Color(0.92, 0.9, 0.96))
				_poly([Vector2(0.32, 0.36), Vector2(0.26, 0.14), Vector2(0.42, 0.28)], stone)
				_poly([Vector2(0.68, 0.36), Vector2(0.74, 0.14), Vector2(0.58, 0.28)], stone)
				_circle(Vector2(0.5, 0.46), 0.24, stone)
				_circle(Vector2(0.42, 0.44), 0.025, INK, false)
				_circle(Vector2(0.58, 0.44), 0.025, INK, false)


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


## A time skip: a sky-blue clock with a fast-forward mark on its face.
func _draw_skip() -> void:
	_circle(Vector2(0.5, 0.52), 0.38, _col(Color(0.62, 0.8, 1.0)))
	_circle(Vector2(0.5, 0.52), 0.29, WHITE, false)
	_rrect(Rect2(0.44, 0.06, 0.12, 0.1), 0.03, _col(Color(0.62, 0.8, 1.0)))
	for x in [0.33, 0.5]:
		_poly([Vector2(x, 0.38), Vector2(x + 0.17, 0.52), Vector2(x, 0.66)], _col(Color(0.36, 0.5, 0.9)), false)


## Building materials: a grey stone block with two wooden planks crossed over
## it, a nail in each.
func _draw_materials() -> void:
	var wood := _col(Color(0.82, 0.6, 0.4))
	_rrect(Rect2(0.2, 0.5, 0.6, 0.32), 0.05, Color(0.76, 0.74, 0.82))
	_line([Vector2(0.24, 0.66), Vector2(0.76, 0.66)], Color(INK, 0.35), 0.6)
	_line([Vector2(0.5, 0.52), Vector2(0.5, 0.64)], Color(INK, 0.35), 0.6)
	for turn in [-0.42, 0.42]:
		var pts: Array = []
		for c in [Vector2(-0.4, -0.08), Vector2(0.4, -0.08), Vector2(0.4, 0.08), Vector2(-0.4, 0.08)]:
			pts.append(Vector2(0.5, 0.42) + (c as Vector2).rotated(turn))
		_poly(pts, wood)
		_circle(Vector2(0.5, 0.42) + Vector2(0.28, 0.0).rotated(turn), 0.025, INK, false)


# -- shop packs: a picture for each size of coin and materials pack -------------

const SACK := Color(0.86, 0.68, 0.46)
const WOOD := Color(0.82, 0.6, 0.4)
const WOOD_DARK := Color(0.64, 0.44, 0.3)
const STONE := Color(0.76, 0.74, 0.82)


## A small coin, face on.
func _mini_coin(c: Vector2, r: float) -> void:
	_circle(c, r, GOLD)
	_poly(_star_pts(c + Vector2(0.0, r * 0.05), r * 0.5, r * 0.22), GOLD_DARK, false)
	draw_arc(_u(c), r * 0.72 * _s, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.85), _w() * 0.6, true)


## A stack of `n` coins seen from the side, standing on `base`.
func _coin_stack(base: Vector2, rx: float, n: int) -> void:
	var step := rx * 0.34
	var ry := rx * 0.36
	var top := base.y - float(n) * step
	# the stack's side, one band, its coins' edges ridged across it
	var side: Array = [Vector2(base.x - rx, top)]
	for k in 13:
		var a := PI * float(k) / 12.0
		side.append(Vector2(base.x - cos(a) * rx, base.y + sin(a) * ry))
	side.append(Vector2(base.x + rx, top))
	_poly(side, Color(1.0, 0.72, 0.24))
	for k in range(1, n):
		var y := base.y - float(k) * step
		draw_arc(_u(Vector2(base.x, y)), rx * _s, 0.15, PI - 0.15, 16, Color(GOLD_DARK.darkened(0.2), 0.8), _w() * 0.5, true)
	_ellipse(Vector2(base.x, top), rx, ry, GOLD)
	_poly(_star_pts(Vector2(base.x, top), rx * 0.32, rx * 0.14), Color(1.0, 0.72, 0.24), false)


## Coins tumbling: face-on coins at these spots, each [x, y, r].
func _coins(spots: Array) -> void:
	for s in spots:
		_mini_coin(Vector2(s[0], s[1]), s[2])


## A four-point sparkle.
func _sparkle(c: Vector2, r: float, colour := Color(1.0, 0.95, 0.6)) -> void:
	_poly(_star_pts(c, r, r * 0.3, 4, 0.0), colour, false)


## A gem: a cut diamond shape.
func _gem(c: Vector2, r: float, colour: Color) -> void:
	_poly([c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r, -r * 0.3), c + Vector2(0.0, r)], colour)
	_line([c + Vector2(-r, -r * 0.3), c + Vector2(r, -r * 0.3)], INK, 0.5)


## A sack of coins, tied with a ribbon, its mouth heaped with them.
func _sack(c: Vector2, s: float, heap: int) -> void:
	var body := [Vector2(-0.2, -0.2), Vector2(-0.34, 0.02), Vector2(-0.36, 0.24), Vector2(-0.26, 0.36), Vector2(0.26, 0.36), Vector2(0.36, 0.24), Vector2(0.34, 0.02), Vector2(0.2, -0.2)]
	var pts: Array = []
	for p in body:
		pts.append(c + (p as Vector2) * s)
	_poly(pts, SACK)
	_ellipse(c + Vector2(0.0, -0.22) * s, 0.24 * s, 0.07 * s, SACK.darkened(0.2))
	for k in heap:
		var x := (float(k) - float(heap - 1) * 0.5) * 0.12
		_mini_coin(c + Vector2(x, -0.28 - 0.04 * float(k % 2)) * s, 0.09 * s)
	_rrect(Rect2(c + Vector2(-0.2, -0.17) * s, Vector2(0.4, 0.06) * s), 0.02 * s, Color(0.9, 0.36, 0.42))
	_circle(c + Vector2(0.0, 0.1) * s, 0.12 * s, GOLD)
	_poly(_star_pts(c + Vector2(0.0, 0.105) * s, 0.07 * s, 0.03 * s), GOLD_DARK, false)


## An open chest overflowing with coins (lilac and gem-studded when `grand`).
func _treasure(c: Vector2, s: float, grand: bool) -> void:
	var body := Color(0.86, 0.64, 0.44) if not grand else Color(0.8, 0.64, 1.0)
	var trim := Color(1.0, 0.84, 0.44)
	# the lid thrown back, behind
	_poly([c + Vector2(-0.36, -0.06) * s, c + Vector2(-0.3, -0.36) * s, c + Vector2(0.3, -0.36) * s, c + Vector2(0.36, -0.06) * s], body.lightened(0.12))
	_rrect(Rect2(c + Vector2(-0.3, -0.36) * s, Vector2(0.6, 0.07) * s), 0.02 * s, trim)
	# the heap, then the chest's front over its foot
	_ellipse(c + Vector2(0.0, -0.04) * s, 0.36 * s, 0.14 * s, GOLD)
	_coins([[c.x - 0.18 * s, c.y - 0.1 * s, 0.08 * s], [c.x + 0.02 * s, c.y - 0.14 * s, 0.08 * s], [c.x + 0.2 * s, c.y - 0.08 * s, 0.08 * s], [c.x - 0.06 * s, c.y - 0.04 * s, 0.07 * s]])
	if grand:
		_gem(c + Vector2(0.12, -0.2) * s, 0.06 * s, Color(1.0, 0.5, 0.66))
		_gem(c + Vector2(-0.24, -0.16) * s, 0.05 * s, Color(0.5, 0.82, 1.0))
	_rrect(Rect2(c + Vector2(-0.38, -0.02) * s, Vector2(0.76, 0.36) * s), 0.05 * s, body)
	_rrect(Rect2(c + Vector2(-0.38, -0.02) * s, Vector2(0.76, 0.08) * s), 0.03 * s, trim)
	_rrect(Rect2(c + Vector2(-0.06, 0.02) * s, Vector2(0.12, 0.16) * s), 0.03 * s, trim)


## The coin packs, smallest (0, the free one) to biggest (5): a stack, two
## stacks, a pouch, a sack spilling over, an open chest brimming, and a grand
## chest heaped with coins and gems, sparkling.
func _draw_coin_pack(tier: int) -> void:
	match clampi(tier, 0, 5):
		0:
			_coin_stack(Vector2(0.42, 0.78), 0.2, 3)
			_mini_coin(Vector2(0.68, 0.6), 0.16)
		1:
			_coin_stack(Vector2(0.3, 0.8), 0.17, 4)
			_coin_stack(Vector2(0.62, 0.84), 0.17, 2)
			_mini_coin(Vector2(0.72, 0.42), 0.15)
		2:
			_sack(Vector2(0.48, 0.58), 0.8, 3)
			_coins([[0.8, 0.82, 0.09], [0.2, 0.84, 0.08]])
		3:
			_sack(Vector2(0.44, 0.52), 0.95, 5)
			_coins([[0.74, 0.84, 0.1], [0.86, 0.72, 0.08], [0.6, 0.9, 0.08], [0.16, 0.86, 0.08]])
		4:
			_treasure(Vector2(0.5, 0.52), 1.0, false)
			_coins([[0.2, 0.9, 0.08], [0.78, 0.9, 0.09], [0.9, 0.76, 0.07]])
		5:
			_treasure(Vector2(0.5, 0.5), 1.08, true)
			_coins([[0.14, 0.88, 0.08], [0.3, 0.93, 0.07], [0.72, 0.92, 0.08], [0.88, 0.84, 0.09]])
			_sparkle(Vector2(0.12, 0.2), 0.08)
			_sparkle(Vector2(0.88, 0.18), 0.06)
			_sparkle(Vector2(0.5, 0.04), 0.05)


## A plank from a to b, `w` wide, with a line of grain.
func _plank(a: Vector2, b: Vector2, w: float) -> void:
	var n := (b - a).normalized().orthogonal() * w * 0.5
	_poly([a + n, b + n, b - n, a - n], WOOD)
	_line([a.lerp(b, 0.15), a.lerp(b, 0.75)], Color(WOOD_DARK, 0.6), 0.5)


func _stone(c: Vector2, r: float) -> void:
	_ellipse(c, r, r * 0.72, STONE)
	draw_arc(_u(c + Vector2(-r * 0.25, -r * 0.2)), r * 0.4 * _s, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.7), _w() * 0.6, true)


## A slatted wooden crate.
func _crate_box(r: Rect2) -> void:
	_rrect(r, 0.03, WOOD)
	for k in 2:
		var y := r.position.y + r.size.y * (0.34 + 0.33 * float(k))
		_line([Vector2(r.position.x + 0.02, y), Vector2(r.end.x - 0.02, y)], Color(WOOD_DARK, 0.7), 0.6)
	_line([r.position + Vector2(0.03, 0.03), r.end - Vector2(0.03, 0.03)], WOOD_DARK, 0.9)


## The materials packs, smallest (0, the free one) to biggest (5): a couple of
## planks and a stone, a bundle tied with rope, a crate, a crate overflowing,
## a wheelbarrow heaped up, and a sparkling stack of crates, planks and stone.
func _draw_material_pack(tier: int) -> void:
	match clampi(tier, 0, 5):
		0:
			_stone(Vector2(0.66, 0.74), 0.16)
			_plank(Vector2(0.14, 0.7), Vector2(0.62, 0.42), 0.12)
			_plank(Vector2(0.2, 0.84), Vector2(0.7, 0.6), 0.12)
		1:
			_stone(Vector2(0.78, 0.8), 0.14)
			for k in 3:
				var y := 0.46 + 0.1 * float(k)
				_plank(Vector2(0.12, y + 0.08), Vector2(0.8, y - 0.1), 0.11)
			for x in [0.34, 0.6]:
				_line([Vector2(x, 0.36), Vector2(x, 0.72)], Color(0.9, 0.36, 0.42), 1.4)
		2:
			_plank(Vector2(0.3, 0.44), Vector2(0.62, 0.12), 0.12)
			_crate_box(Rect2(0.18, 0.4, 0.64, 0.48))
		3:
			_plank(Vector2(0.22, 0.4), Vector2(0.4, 0.06), 0.11)
			_plank(Vector2(0.52, 0.4), Vector2(0.78, 0.1), 0.11)
			_stone(Vector2(0.5, 0.36), 0.13)
			_crate_box(Rect2(0.16, 0.38, 0.6, 0.48))
			_stone(Vector2(0.84, 0.82), 0.12)
		4:
			# a wheelbarrow, heaped
			_stone(Vector2(0.36, 0.34), 0.13)
			_stone(Vector2(0.58, 0.32), 0.12)
			_plank(Vector2(0.18, 0.4), Vector2(0.72, 0.2), 0.1)
			_poly([Vector2(0.1, 0.4), Vector2(0.86, 0.4), Vector2(0.74, 0.7), Vector2(0.2, 0.7)], Color(0.56, 0.74, 1.0))
			_line([Vector2(0.74, 0.62), Vector2(0.96, 0.76)], WOOD_DARK, 1.4)
			_line([Vector2(0.3, 0.7), Vector2(0.3, 0.88)], INK, 1.2)
			_circle(Vector2(0.62, 0.8), 0.1, Color(0.4, 0.36, 0.42))
			_circle(Vector2(0.62, 0.8), 0.035, STONE, false)
		5:
			_crate_box(Rect2(0.08, 0.5, 0.42, 0.4))
			_crate_box(Rect2(0.48, 0.5, 0.42, 0.4))
			_crate_box(Rect2(0.28, 0.16, 0.42, 0.36))
			_plank(Vector2(0.04, 0.48), Vector2(0.4, 0.3), 0.09)
			_stone(Vector2(0.84, 0.42), 0.12)
			_sparkle(Vector2(0.12, 0.18), 0.08)
			_sparkle(Vector2(0.88, 0.16), 0.06)


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

## A critter: its sticker, filling a little more than the blob it replaced
## (c/r in unit coordinates, r its body's radius). Locked, a faint shadow of
## it; tinted, the sticker multiplied by the tint.
func _draw_critter(i: int, c: Vector2, r: float) -> void:
	var art := TSProfile.critter_art(clampi(i, 0, TSProfile.CRITTER_COUNT - 1))
	var side := 2.4 * r
	var rect := Rect2(_u(c + Vector2(-0.5 * side, -0.5 * side - 0.15 * r)), Vector2(side, side) * _s)
	var shade := Color(0, 0, 0, 0.3) if silhouette else (tint if tint.a > 0.0 else Color.WHITE)
	draw_texture_rect(art, rect, false, shade)


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
