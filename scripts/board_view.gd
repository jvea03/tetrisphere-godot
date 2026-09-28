# Renders the board model onto an egg-shaped band, in the hand-drawn style of
# TSToon. Each Tetris piece lying on the ball is drawn as one soft, rounded
# bar in its own pastel colour with an ink outline. Every cell is a rounded
# tile that the shader bends onto the curved shell; it is open and runs to
# the cell edge where the piece carries on into the next cell, so a piece has
# no seams inside it and only its own silhouette is rounded and inked.
# Neighbouring pieces stay distinct and each piece reads by its silhouette, as
# in the original. One MultiMesh per tile shape, coloured per instance,
# rebuilt whenever the board changes.
class_name TSBoardView
extends Node3D

const CORE_RADIUS := 3.0
const LAYER_H := 0.62
# Latitude is capped short of the poles. A full sphere squeezes cells to
# nothing at the caps; the original dodged this the same way, with shapes that
# never actually close over the top.
const LAT_SPAN := 1.02
const RIM_GAP := 0.05     # how far a piece stops short of its cell where it ends
const TILE_THICK := 0.88  # how much of its layer a tile fills, out from the core
# The ball is an egg: the grid is laid out on a sphere, then every point is
# pushed through egg(), which stretches it tall and tapers it toward the top.
# EGG_TALL is the height over the width; EGG_TAPER how much narrower the top
# half is than the bottom (0 = a plain ellipsoid).
const EGG_TALL := 1.22
const EGG_TAPER := 0.13
# The poles past LAT_SPAN hold no cells. Caps close them over -- scenery only,
# never part of the board -- so the ball reads as a whole egg and you cannot
# look in at the top and out at the bottom. Each cap is a dome level with the
# top of a fresh shell, a trim ring where it meets the band, and a wall under
# the trim down to the core, so digging the last row never opens a gap under
# the cap.
# The caps stand level with a fresh shell, however deep this ball is (see
# _cap_radius); they are rebuilt when a ball of another depth is loaded.
const CAP_TRIM := 0.07      # latitude the trim ring covers, in radians

# One colour per piece, in TSBoard.SHAPES order: soft pastels, kept far enough
# apart in hue to tell at a glance. The two lines keep the footage's pairing --
# yellow flat bars, green upright bars -- and blockers are pebble grey. The
# other pieces take the rest of the sweet-shop palette: the O square (from
# Intermediate) is sky blue, the plus (from Expert) strawberry pink and the
# capital-L piece lilac.
# I flat, I upright, O, T, S, Z, J, L, blocker, plus.
const TYPE_COLORS := [
	Color(1.00, 0.83, 0.36),   # I flat: butter
	Color(0.50, 0.86, 0.56),   # I upright: mint
	Color(0.52, 0.80, 0.98),   # O: sky
	Color(1.00, 0.68, 0.44),   # T: peach (unused)
	Color(1.00, 0.66, 0.82),   # S (unused)
	Color(0.98, 0.52, 0.52),   # Z (unused)
	Color(0.56, 0.64, 0.98),   # J (unused)
	Color(0.74, 0.60, 0.95),   # L: lilac
	Color(0.74, 0.72, 0.78),   # blocker: pebble grey
	Color(1.00, 0.56, 0.72),   # plus: strawberry
]
## An armoured blocker (TSBoard.armored): dark steel until a hit knocks the
## armour off and leaves it pebble grey.
const ARMOR_COLOR := Color(0.42, 0.45, 0.58)

var board: TSBoard
var max_radius := CORE_RADIUS   # outermost occupied layer, used to frame the camera

var _tile_sets := {}   # tile shape key -> MultiMeshInstance3D
var _fx_root: Node3D
var _fx_rng := RandomNumberGenerator.new()
var _caps: Array = []      # the cap meshes, rebuilt for a ball of another depth
var _caps_depth := -1


func setup(b: TSBoard) -> void:
	board = b
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_caps()


func _cap_radius() -> float:
	return CORE_RADIUS + board.shell_depth * LAYER_H + 0.04


## The caps take the egg's colours (TSProfile.EGG_PAINTS), and
## stand level with the top of a fresh shell of this ball's depth.
func _build_caps() -> void:
	for mi in _caps:
		(mi as Node).queue_free()
	_caps.clear()
	_caps_depth = board.shell_depth
	var cap_r := _cap_radius()
	var shell: Dictionary = TSProfile.EGG_PAINTS[0]
	var cap: Color = shell["cap"]
	var dome_mat := make_material(cap, 1.0)
	var trim_mat := make_material(shell["trim"], 1.0, 0.0, false)
	var wall_mat := make_material(cap.darkened(0.25), 1.0, 0.0, false)
	var outward := func(p: Vector3) -> Vector3: return p
	for side in [1.0, -1.0]:
		var s: float = side
		var edge := LAT_SPAN * s
		# Dome: from just inside the trim up to the pole.
		var dome := func(u: float, v: float) -> Vector3:
			return _sphere_dir(u * TAU, lerpf(edge + CAP_TRIM * 0.5 * s, PI * 0.5 * s, v)) * cap_r
		_add_cap_part(dome, outward, 64, 14, dome_mat)
		# Trim: a ring standing a little proud of the dome, over the band's edge.
		var trim := func(u: float, v: float) -> Vector3:
			return _sphere_dir(u * TAU, lerpf(edge - 0.01 * s, edge + CAP_TRIM * s, v)) * (cap_r + 0.06)
		_add_cap_part(trim, outward, 64, 2, trim_mat)
		# Wall: the band's end face, from the core out to the trim, facing the
		# equator (where you look from when you dig the last row out).
		var wall := func(u: float, v: float) -> Vector3:
			return _sphere_dir(u * TAU, edge) * lerpf(CORE_RADIUS * 0.98, cap_r + 0.06, v)
		var toward_equator := func(p: Vector3) -> Vector3:
			var theta := atan2(p.x, p.z)
			return -s * Vector3(-sin(edge) * sin(theta), cos(edge), -sin(edge) * cos(theta))
		_add_cap_part(wall, toward_equator, 64, 3, wall_mat)


static func _sphere_dir(theta: float, phi: float) -> Vector3:
	return Vector3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta))


# One piece of a cap: a grid over (u, v) in [0, 1]^2, where `point` gives each
# grid point on the sphere the board is laid out on and `facing` which way
# its visible side points there. Points go through egg() like every cell does.
func _add_cap_part(point: Callable, facing: Callable, nu: int, nv: int, material: Material) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var h := 0.001
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / float(nu)
			var v := float(j) / float(nv)
			var p: Vector3 = point.call(u, v)
			var du := egg(point.call(u + h, v)) - egg(point.call(u - h, v))
			var dv := egg(point.call(u, v + h)) - egg(point.call(u, v - h))
			var n := du.cross(dv)
			var want: Vector3 = facing.call(p)
			if n.length() < 0.000001:
				n = want   # at the pole the grid pinches to a point
			n = n.normalized()
			if n.dot(want) < 0.0:
				n = -n
			verts.append(egg(p))
			normals.append(n)

	var indices := PackedInt32Array()
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var quad := [a, a + 1, a + nu + 2, a + nu + 1]
			for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var t0: int = tri[0]
				var t1: int = tri[1]
				var t2: int = tri[2]
				# Godot's front faces wind clockwise as seen, so the geometric
				# normal must point away from the side that shows.
				var fn := (verts[t1] - verts[t0]).cross(verts[t2] - verts[t0])
				if fn.dot(normals[t0] + normals[t1] + normals[t2]) > 0.0:
					indices.append_array([t0, t2, t1])
				else:
					indices.append_array([t0, t1, t2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	_caps.append(mi)


# A hand-drawn material (see TSToon): `glow` makes it shine, and a solid one
# gets an ink outline unless `outline` is off.
static func make_material(c: Color, alpha := 1.0, glow := 0.0, outline := true, bent := false) -> ShaderMaterial:
	return TSToon.material(c, alpha, glow, false, outline, bent)


# Places a unit-sized mesh at (col, row, depth): local +Y points out of the
# ball, +X follows longitude (next column), -Z is up the ball (next row). The
# cell is worked out on a sphere -- width tapering with cos(phi) so rows stay
# flush toward the caps -- then carried onto the egg, basis and all, so tiles
# still meet edge to edge after the stretch.
static func cell_transform(c: int, r: int, depth: float) -> Transform3D:
	var theta := TAU * (float(c) + 0.5) / float(TSBoard.COLS)
	var phi := lerpf(-LAT_SPAN, LAT_SPAN, (float(r) + 0.5) / float(TSBoard.ROWS))
	var radius := CORE_RADIUS + (depth + 0.5) * LAYER_H

	var up := Vector3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta))
	var east := Vector3(cos(theta), 0.0, -sin(theta))
	var south := east.cross(up)   # keeps the basis right-handed

	var cell_w := radius * cos(phi) * TAU / float(TSBoard.COLS)
	var cell_h := radius * (2.0 * LAT_SPAN / float(TSBoard.ROWS))

	var at := up * radius
	var basis := Basis(
		_egg_push(at, east * cell_w), _egg_push(at, up * (LAYER_H * TILE_THICK)), _egg_push(at, south * cell_h)
	)
	return Transform3D(basis, egg(at))


# Sphere space to egg space. It depends only on the direction, scaled by the
# length, so each layer of the shell is the same egg at a larger size.
static func egg(p: Vector3) -> Vector3:
	var r := p.length()
	if r < 0.00001:
		return p
	var k := 1.0 - EGG_TAPER * (p.y / r)
	return Vector3(p.x * k, p.y * EGG_TALL, p.z * k)


# Carries a small offset `v` at sphere point `p` into egg space (the
# derivative of egg() along v), so a tile keeps meeting its neighbours.
static func _egg_push(p: Vector3, v: Vector3) -> Vector3:
	var h := 0.001
	return (egg(p + v * h) - egg(p - v * h)) / (2.0 * h)


# Egg space back to sphere space: the inverse of egg(). Longitude is
# untouched; the latitude is found by bisection, since the egg's outline
# angle climbs steadily with it.
static func egg_inverse(q: Vector3) -> Vector3:
	var h := Vector2(q.x, q.z).length()
	if h < 0.00001 and absf(q.y) < 0.00001:
		return q
	var want := atan2(q.y, h)
	var lo := -PI * 0.5
	var hi := PI * 0.5
	for _i in 40:
		var mid := (lo + hi) * 0.5
		var s := sin(mid)
		if atan2(s * EGG_TALL, cos(mid) * (1.0 - EGG_TAPER * s)) < want:
			lo = mid
		else:
			hi = mid
	var phi := (lo + hi) * 0.5
	var sp := sin(phi)
	var cp := cos(phi)
	# Radius from whichever of height or width is better conditioned here.
	var radius := q.y / (sp * EGG_TALL) if absf(sp) > 0.7 else h / (cp * (1.0 - EGG_TAPER * sp))
	var theta := atan2(q.x, q.z)
	return Vector3(cp * sin(theta), sp, cp * cos(theta)) * radius


# The tile shape for a cell: rounded on the sides that end its piece. `same`
# says, for each direction in TSBoard.DIRS order (east, north, west, south),
# whether the neighbour there is part of the same piece.
static func tile_key(same: Array) -> int:
	var key := 0
	for i in 4:
		if same[i]:
			key |= 1 << i
	return key


static func _key_sides(key: int) -> Array:
	var same: Array = []
	for i in 4:
		same.append(key & (1 << i) != 0)
	return same


# How far down the shell depth `d` is, for the darkening of deeper tiles:
# 0 at a fresh ball's surface, 1 at the bottom layer. A one-layer ball is all
# surface.
static func depth_shade(d: int, depth: int) -> float:
	if depth <= 1:
		return 0.0
	return clampf(float(depth - 1 - d) / float(depth - 1), 0.0, 1.0)


func rebuild() -> void:
	if board.shell_depth != _caps_depth:
		_build_caps()
	var tallest := 1
	var sets := {}   # tile key -> [[colour, custom], ...]

	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var stack: Array = board.cells[c][r]
			tallest = maxi(tallest, stack.size())
			for d in stack.size():
				var p: int = stack[d]
				if p == TSBoard.HOLE:
					continue
				var kind: int = board.plate_kind[p]
				var key := tile_key(_same_sides(c, r, d, p))
				if not sets.has(key):
					sets[key] = []
				var colour: Color = ARMOR_COLOR if board.armored.has(p) else TYPE_COLORS[kind]
				sets[key].append([colour, Color(c, r, d, depth_shade(d, board.shell_depth))])

	for key in _tile_sets:
		if not sets.has(key):
			(_tile_sets[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key in sets:
		if not _tile_sets.has(key):
			_tile_sets[key] = _bent_tiles(key, make_material(Color.WHITE, 1.0, 0.0, true, true))
		_fill_multi((_tile_sets[key] as MultiMeshInstance3D).multimesh, sets[key])

	max_radius = CORE_RADIUS + float(tallest) * LAYER_H


# A MultiMesh of tiles of one shape, which the shader bends onto the shell:
# each instance carries its cell (column, row, depth) and depth shade in its
# custom data, and its colour. Instance transforms stay at the identity.
func _bent_tiles(key: int, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = TSToon.tile(_key_sides(key), RIM_GAP)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	# The mesh is one unit box at the origin until the shader moves it, so
	# give culling the whole egg instead.
	mmi.custom_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	add_child(mmi)
	return mmi


func _fill_multi(mm: MultiMesh, tiles: Array) -> void:
	mm.instance_count = tiles.size()
	for i in tiles.size():
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_color(i, tiles[i][0])
		mm.set_instance_custom_data(i, tiles[i][1])


func _same_sides(c: int, r: int, d: int, p: int) -> Array:
	var out: Array = []
	for dir in TSBoard.DIRS:
		var dv: Vector2i = dir
		var rr := r + dv.y
		if not board.in_rows(rr):
			out.append(false)
			continue
		var side: Array = board.cells[board.wrap_col(c + dv.x)][rr]
		out.append(d < side.size() and int(side[d]) == p)
	return out


# A free-standing piece, used for the aiming footprint. `cols` are its columns
# and `depths` the depth each block will settle at. It is see-through and
# draws through the shell, so a piece slid in under an overhang stays visible.
func make_plate(kind: int, cols: Array, depths: Array, alpha: float, glow: float) -> Node3D:
	var root := Node3D.new()
	var mat := TSToon.material(TYPE_COLORS[kind], alpha, glow, true, false, true)
	var sets := {}
	for i in cols.size():
		var v: Vector2i = cols[i]
		var same: Array = []
		for dir in TSBoard.DIRS:
			var dv: Vector2i = dir
			var j := cols.find(Vector2i(board.wrap_col(v.x + dv.x), v.y + dv.y))
			same.append(j >= 0 and depths[j] == depths[i])
		var key := tile_key(same)
		if not sets.has(key):
			sets[key] = []
		sets[key].append([Color.WHITE, Color(v.x, v.y, float(depths[i]), 0.0)])
	for key in sets:
		var mmi := _bent_tiles(key, mat)
		remove_child(mmi)
		root.add_child(mmi)
		_fill_multi(mmi.multimesh, sets[key])
	return root


func _tile(xform: Transform3D, material: Material, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.material_override = material
	return mi


# The clear from the reference footage: each block flashes white where it
# stood, then tumbles away from the ball in its own colour and shrinks out.
# `step` delays a block by that many beats (everything from one drop is step 1).
func spawn_clear_fx(fx: Array) -> void:
	var loose := TSToon.tile([false, false, false, false], RIM_GAP)
	for e in fx:
		var kind: int = e[3]
		var step: int = e[4]
		var xf := cell_transform(e[0], e[1], float(e[2]))
		var colour: Color = TYPE_COLORS[kind]

		var holder := Node3D.new()
		holder.position = xf.origin
		_fx_root.add_child(holder)
		var mat := make_material(Color.WHITE, 1.0, 0.6)
		holder.add_child(_tile(Transform3D(xf.basis, Vector3.ZERO), mat, loose))

		var outward := xf.origin.normalized()
		var drift := Vector3(
			_fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0)
		) * 0.9
		var spin := Vector3(
			_fx_rng.randf_range(-6.0, 6.0), _fx_rng.randf_range(-6.0, 6.0), _fx_rng.randf_range(-6.0, 6.0)
		)
		var delay := 0.14 + 0.22 * float(maxi(step - 1, 0))

		var tw := holder.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(mat, "shader_parameter/albedo", colour, 0.12)
		tw.parallel().tween_property(mat, "shader_parameter/glow", 0.15, 0.12)
		tw.tween_property(holder, "position", xf.origin + outward * 3.2 + drift, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(holder, "rotation", spin, 0.6)
		tw.parallel().tween_property(holder, "scale", Vector3.ONE * 0.1, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(holder.queue_free)


# Floating score over the clear, as in the footage: handwritten, in pink on a
# thick paper-coloured outline.
func spawn_popup(text: String, fx: Array) -> void:
	if fx.is_empty():
		return
	var centre := Vector3.ZERO
	for e in fx:
		centre += cell_transform(e[0], e[1], float(e[2])).origin
	centre /= float(fx.size())
	var where := centre + centre.normalized() * 1.2

	var label := Label3D.new()
	label.text = text
	label.font = TSToon.hand_font()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.pixel_size = 0.012
	label.outline_size = 28
	label.modulate = Color(1.0, 0.45, 0.60)
	label.outline_modulate = TSToon.PAPER
	label.position = where
	_fx_root.add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "position", where + where.normalized() * 2.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.tween_callback(label.queue_free)
