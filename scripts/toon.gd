# The hand-drawn look: flat pastel cel shading with a faint pencil grain on the
# shadow side, a clean, even ink outline (it can "boil" -- wobble and re-draw
# like a pencil line -- through `boil`, but stays steady for a cleaner look),
# soft rounded pieces, and a paper background. Every
# material, tile mesh and the font come from here.
class_name TSToon
extends RefCounted

# Ink: the colour of every outline and of the HUD's lettering.
const INK := Color(0.27, 0.16, 0.19)
# Paper: the background, and the outline round the HUD's lettering.
const PAPER := Color(1.0, 0.96, 0.88)
# What the shadow side of a surface is multiplied by: a soft lilac, never grey.
const SHADE := Color(0.72, 0.62, 0.84)
const OUTLINE_WIDTH := 0.07    # world units

# Tile rounding, in the tile's own unit-box units along x (across a column),
# y (the layer's thickness) and z (along a row). Tiles are stretched unevenly
# (a cell is wider than it is thick), so these differ to give roughly round
# corners in the world.
const ROUND := Vector3(0.14, 0.36, 0.17)

# Board tiles are "bent": the mesh is one cell's unit box, and the vertex
# shader carries each vertex onto the curved egg shell itself, from the cell
# (column, row, depth) in INSTANCE_CUSTOM.xyz. Neighbouring cells of a piece
# then share exactly the same curved surface, so a piece is one smooth bar
# with no seam or overlap between its cells. This is the same mapping as
# TSBoardView.cell_transform() and egg(), in GLSL; the numbers are filled in
# from those scripts' constants.
const _SHELL := """
const float COLS = %.1f;
const float ROWS = %.1f;
const float LAT_SPAN = %.5f;
const float CORE_RADIUS = %.5f;
const float LAYER_H = %.5f;
const float THICK = %.5f;
const float EGG_TALL = %.5f;
const float EGG_TAPER = %.5f;

vec3 egg_of(vec3 p) {
	float k = 1.0 - EGG_TAPER * p.y / max(length(p), 0.00001);
	return vec3(p.x * k, p.y * EGG_TALL, p.z * k);
}

// A point of the shell from continuous grid coordinates: columns and rows
// (cell corners at whole numbers) and depth in layers from the core.
vec3 shell(vec3 g) {
	float theta = 6.28318531 * g.x / COLS;
	float phi = mix(-LAT_SPAN, LAT_SPAN, g.y / ROWS);
	float radius = CORE_RADIUS + g.z * LAYER_H;
	return egg_of(radius * vec3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta)));
}

// Moves a vertex of a cell's unit box (+x east, +y out, -z north) onto the
// shell, and its normal with it.
void bend(inout vec3 v, inout vec3 n, vec3 cell) {
	vec3 g = cell + vec3(0.5 + v.x, 0.5 - v.z, 0.5 + v.y * THICK);
	float e = 0.02;
	vec3 jx = (shell(g + vec3(e, 0.0, 0.0)) - shell(g - vec3(e, 0.0, 0.0))) / (2.0 * e);
	vec3 jz = -(shell(g + vec3(0.0, e, 0.0)) - shell(g - vec3(0.0, e, 0.0))) / (2.0 * e);
	vec3 jy = (shell(g + vec3(0.0, 0.0, e)) - shell(g - vec3(0.0, 0.0, e))) / (2.0 * e) * THICK;
	n = normalize(n.x * cross(jy, jz) + n.y * cross(jz, jx) + n.z * cross(jx, jy));
	v = shell(g);
}
"""

const _BODY := """
shader_type spatial;
render_mode cull_back%s;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.72, 0.62, 0.84, 1.0);
uniform float glow = 0.0;
// How much darker the deepest layer is drawn, so the layers read apart.
uniform float depth_dim = 0.22;

varying float v_dim;
%s
void vertex() {
	v_dim = 0.0;
	%s
}

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb * (1.0 - v_dim);
	ALBEDO = base;
	EMISSION = base * glow;
	%s
}

void light() {
	// Two hard-edged steps of light instead of a smooth falloff.
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.08, ndl) * 0.6 + smoothstep(0.55, 0.62, ndl) * 0.4;
	vec3 tone = mix(shade.rgb, vec3(1.0), lit);
	// A faint pencil grain across the shadow side.
	float hatch = step(0.6, fract((FRAGCOORD.x - FRAGCOORD.y) * 0.14));
	tone *= 1.0 - hatch * 0.04 * (1.0 - lit);   // a faint grain, not stripes
	DIFFUSE_LIGHT += tone * LIGHT_COLOR / PI;
	// A small, hard, cartoon shine.
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += smoothstep(0.955, 0.965, dot(NORMAL, h)) * LIGHT_COLOR * 0.12;
}
"""

const _BEND_BODY := """
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	bend(v, n, INSTANCE_CUSTOM.xyz);
	VERTEX = v;
	NORMAL = n;
	v_dim = clamp(INSTANCE_CUSTOM.w, 0.0, 1.0) * depth_dim;
"""

const _INK := """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.27, 0.16, 0.19, 1.0);
uniform float width = 0.07;
uniform float boil = 0.0;   // 0: a steady, even line; ~0.35: a wobbly, re-drawn pencil line
%s
void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	%s
	// Grow the mesh along its normals by `width` world units (undoing any
	// uneven scale), wobbling the width a little from place to place and
	// re-drawing that wobble five times a second, like a pencil line.
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float frame = floor(TIME * 5.0);
	float n = fract(sin(dot(floor(wp * 2.5) + frame, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	VERTEX += NORMAL * width * (1.0 + boil * (n * 2.0 - 1.0)) / s;
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""

const _BEND_INK := """
	vec3 v = VERTEX;
	vec3 nn = NORMAL;
	bend(v, nn, INSTANCE_CUSTOM.xyz);
	VERTEX = v;
	NORMAL = nn;
"""

const _PAPER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 paper : source_color = vec4(1.0, 0.96, 0.88, 1.0);   // the sky at the top
uniform vec4 blush : source_color = vec4(1.0, 0.88, 0.89, 1.0);   // ... and at the bottom
uniform vec4 dots : source_color = vec4(0.99, 0.89, 0.89, 1.0);
uniform float dot_px = 110.0;
uniform float stars = 0.0;        // 1: the dots are small twinkling stars (night)
uniform vec4 orb : source_color = vec4(1.0, 1.0, 1.0, 0.0);   // the sun or moon; alpha 0 for none
uniform vec2 orb_uv = vec2(0.82, 0.24);
uniform float orb_px = 44.0;
uniform float crescent = 0.0;     // 1: a crescent moon
uniform float grad_start = 0.45;  // how far down the sky starts to turn

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// The sky: top colour into bottom colour down the screen.
	vec3 col = mix(paper.rgb, blush.rgb, smoothstep(grad_start, 1.0, SCREEN_UV.y));
	// Scattered polka dots, one per grid cell, some cells left empty -- or at
	// night, small stars twinkling at their own pace.
	vec2 grid = FRAGCOORD.xy / dot_px;
	vec2 cell = floor(grid);
	vec2 centre = vec2(hash(cell), hash(cell + 7.0)) * 0.6 + 0.2;
	float r = mix(0.08 + 0.06 * hash(cell + 3.0), 0.03 + 0.03 * hash(cell + 3.0), stars);
	float d = distance(fract(grid), centre);
	float dot_mask = (1.0 - smoothstep(r - 0.015, r, d)) * step(mix(0.5, 0.35, stars), hash(cell + 11.0));
	dot_mask *= mix(1.0, 0.55 + 0.45 * sin(TIME * (1.2 + 2.0 * hash(cell + 5.0)) + hash(cell) * 6.28), stars);
	// By day the dots are a soft texture, half way to the sky; at night, bright stars.
	col = mix(col, dots.rgb, dot_mask * mix(0.5, 1.0, stars));
	// The sun or moon: a disc with a soft glow round it; a crescent moon has a
	// bite taken out of it by a second disc of sky.
	vec2 px = SCREEN_UV * VIEWPORT_SIZE;
	vec2 at = orb_uv * VIEWPORT_SIZE;
	float od = distance(px, at);
	float disc = 1.0 - smoothstep(orb_px - 1.5, orb_px, od);
	if (crescent > 0.5) {
		disc *= smoothstep(orb_px * 0.82 - 1.5, orb_px * 0.82, distance(px, at + vec2(orb_px * 0.45, -orb_px * 0.3)));
	}
	float glow = (1.0 - smoothstep(orb_px, orb_px * 2.2, od)) * 0.25;
	col = mix(col, orb.rgb, (disc + glow * (1.0 - disc)) * orb.a);
	// Paper grain.
	col *= 1.0 - 0.04 * hash(floor(FRAGCOORD.xy / 2.0));
	ALBEDO = col;
}
"""

static var _shaders := {}
static var _ink_mats := {}
static var _tiles := {}
static var _font: SystemFont


# A cel-shaded material. `ghost` is for the aiming footprint: see-through and
# drawn over everything, so it shows even under an overhang. `bent` is for
# board tiles in a MultiMesh, which the shader carries onto the shell (see
# _SHELL); their colour comes from the instance colour.
static func material(colour: Color, alpha := 1.0, glow := 0.0, ghost := false, outline := true, bent := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _body_shader(alpha < 1.0 or ghost, ghost, bent)
	mat.set_shader_parameter("albedo", Color(colour.r, colour.g, colour.b, alpha))
	mat.set_shader_parameter("shade", SHADE)
	mat.set_shader_parameter("glow", glow)
	if ghost:
		mat.render_priority = 1
	elif outline and alpha >= 1.0:
		mat.next_pass = ink(OUTLINE_WIDTH, bent)
	return mat


# The ink outline pass, shared by everything of the same width and kind.
static func ink(width: float, bent := false) -> ShaderMaterial:
	var key := "%f/%s" % [width, bent]
	if _ink_mats.has(key):
		return _ink_mats[key]
	var shader := Shader.new()
	shader.code = _INK % [_shell_code() if bent else "", _BEND_INK if bent else ""]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("ink", INK)
	mat.set_shader_parameter("width", width)
	_ink_mats[key] = mat
	return mat


# The paper background, for a big quad hung far behind the ball from the
# camera. It is patterned by screen position, so it stays put as the ball
# turns. (The Compatibility renderer ignores a 2D background layer, and gives
# sky shaders no screen position, so a quad it is.)
## The sky behind the egg, a day passing as the levels go by: each block of
## SKY_LEVELS levels has its time of day, in this order, and then round again.
## `top`/`bottom` are the sky's gradient, `dots` its polka dots (stars at
## night), `orb` the sun or moon (alpha 0: none), `light` and `ambient` tint
## the light on the egg a touch -- never enough to change a piece's colour --
## and `world` tints the crash site on Home (moonlit at night, warm at sunset).
const SKY_LEVELS := 10
const SKIES := [
	{"name": "Morning", "top": Color(1.0, 0.96, 0.88), "bottom": Color(1.0, 0.88, 0.89), "grad": 0.45,
		"dots": Color(0.99, 0.89, 0.89), "stars": 0.0, "orb": Color(1.0, 0.9, 0.66, 0.55), "orb_uv": Vector2(0.84, 0.21), "crescent": 0.0,
		"light": Color(1.0, 0.97, 0.92), "ambient": Color(1.0, 0.92, 0.95), "world": Color(1.0, 1.0, 1.0)},
	{"name": "Day", "top": Color(0.78, 0.9, 1.0), "bottom": Color(1.0, 0.97, 0.9), "grad": 0.1,
		"dots": Color(0.9, 0.95, 1.0), "stars": 0.0, "orb": Color(1.0, 0.87, 0.45, 0.9), "orb_uv": Vector2(0.84, 0.21), "crescent": 0.0,
		"light": Color(1.0, 0.99, 0.95), "ambient": Color(0.95, 0.96, 1.0), "world": Color(1.0, 1.0, 1.0)},
	{"name": "Sunset", "top": Color(1.0, 0.76, 0.56), "bottom": Color(0.9, 0.66, 0.84), "grad": 0.1,
		"dots": Color(1.0, 0.84, 0.68), "stars": 0.0, "orb": Color(1.0, 0.66, 0.45, 0.85), "orb_uv": Vector2(0.84, 0.21), "crescent": 0.0,
		"light": Color(1.0, 0.9, 0.8), "ambient": Color(1.0, 0.88, 0.9), "world": Color(1.0, 0.9, 0.84)},
	{"name": "Night", "top": Color(0.14, 0.13, 0.3), "bottom": Color(0.32, 0.25, 0.47), "grad": 0.1,
		"dots": Color(1.0, 0.93, 0.7), "stars": 1.0, "orb": Color(0.99, 0.95, 0.82, 1.0), "orb_uv": Vector2(0.84, 0.21), "crescent": 1.0,
		"light": Color(0.92, 0.93, 1.0), "ambient": Color(0.86, 0.86, 1.0), "world": Color(0.62, 0.64, 0.86)},
	{"name": "Dawn", "top": Color(0.78, 0.74, 0.96), "bottom": Color(1.0, 0.85, 0.76), "grad": 0.15,
		"dots": Color(0.9, 0.84, 0.99), "stars": 0.0, "orb": Color(1.0, 0.8, 0.6, 0.75), "orb_uv": Vector2(0.84, 0.21), "crescent": 0.0,
		"light": Color(1.0, 0.95, 0.92), "ambient": Color(1.0, 0.92, 0.96), "world": Color(0.98, 0.93, 0.96)},
]


## The sky for a level: levels 1-10 morning, 11-20 day, 21-30 sunset, 31-40
## night, 41-50 dawn, then morning again from 51.
static func sky_for_level(level: int) -> Dictionary:
	return SKIES[(maxi(level, 1) - 1) / SKY_LEVELS % SKIES.size()]


## Paints the background material (from paper()) with a sky from SKIES.
static func apply_sky(mat: ShaderMaterial, sky: Dictionary) -> void:
	mat.set_shader_parameter("paper", sky["top"])
	mat.set_shader_parameter("blush", sky["bottom"])
	mat.set_shader_parameter("grad_start", sky["grad"])
	mat.set_shader_parameter("dots", sky["dots"])
	mat.set_shader_parameter("stars", sky["stars"])
	mat.set_shader_parameter("orb", sky["orb"])
	mat.set_shader_parameter("orb_uv", sky["orb_uv"])
	mat.set_shader_parameter("crescent", sky["crescent"])


static func paper() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = _PAPER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paper", PAPER)
	return mat


# A rounded, handwriting-style font from the device itself, so nothing needs
# bundling: Chalkboard on iPhones and Macs, Comic Sans on Windows, and
# Android's handwritten "casual" family, in bold for chunky, friendly letters.
# Where none of them exists it falls back to the default sans-serif.
static func hand_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Chalkboard SE", "Comic Sans MS", "casual", "Comic Neue", "sans-serif"])
		_font.font_weight = 700
	return _font


static func _shell_code() -> String:
	return _SHELL % [
		float(TSBoard.COLS), float(TSBoard.ROWS), TSBoardView.LAT_SPAN, TSBoardView.CORE_RADIUS,
		TSBoardView.LAYER_H, TSBoardView.TILE_THICK, TSBoardView.EGG_TALL, TSBoardView.EGG_TAPER,
	]


static func _body_shader(transparent: bool, ghost: bool, bent: bool) -> Shader:
	var key := int(transparent) + 2 * int(ghost) + 4 * int(bent)
	if _shaders.has(key):
		return _shaders[key]
	var modes := ", depth_test_disabled" if ghost else ""
	var alpha_line := "ALPHA = albedo.a * COLOR.a;" if transparent else ""
	var shader := Shader.new()
	shader.code = _BODY % [modes, _shell_code() if bent else "", _BEND_BODY if bent else "", alpha_line]
	_shaders[key] = shader
	return shader


# The mesh for one cell of a piece: the cell's unit box, rounded along every
# side that ends the piece and pulled in there by `gap` (so neighbouring
# pieces keep a little space between them), and running right to the cell's
# edge, open, on the sides where the piece carries on into the next cell
# (`square`, in TSBoard.DIRS order: east +x, north -z, west -x, south +z).
# Bent onto the shell, those open sides meet the next cell exactly, so a whole
# piece reads as one soft bar. The bottom, which faces the core, is flat.
# Cached per combination of sides.
static func tile(square: Array, gap: float) -> ArrayMesh:
	var key := "%f" % gap
	for i in 4:
		key += "1" if square[i] else "0"
	if _tiles.has(key):
		return _tiles[key]
	var sq_e: bool = square[0]
	var sq_n: bool = square[1]
	var sq_w: bool = square[2]
	var sq_s: bool = square[3]
	# The box that stays flat; outside it, corners round off by ROUND.
	var lo := Vector3(-0.5 + (0.0 if sq_w else ROUND.x), -0.5, -0.5 + (0.0 if sq_n else ROUND.z))
	var hi := Vector3(0.5 - (0.0 if sq_e else ROUND.x), 0.5 - ROUND.y, 0.5 - (0.0 if sq_s else ROUND.z))
	var axes := [
		_steps(lo.x, hi.x, ROUND.x),
		_steps(lo.y, hi.y, ROUND.y),
		_steps(lo.z, hi.z, ROUND.z),
	]
	# Where the tile's sides end up in the cell, after the gap.
	var x0 := -0.5 + (0.0 if sq_w else gap)
	var x1 := 0.5 - (0.0 if sq_e else gap)
	var z0 := -0.5 + (0.0 if sq_n else gap)
	var z1 := 0.5 - (0.0 if sq_s else gap)
	# Faces: +x, -x, +y, -y, +z, -z. Square (open) sides are left out.
	var faces := {
		Vector3(1, 0, 0): sq_e, Vector3(-1, 0, 0): sq_w,
		Vector3(0, 1, 0): false, Vector3(0, -1, 0): false,
		Vector3(0, 0, 1): sq_s, Vector3(0, 0, -1): sq_n,
	}

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for face in faces:
		if faces[face]:
			continue
		var fn: Vector3 = face
		var n_axis := 0 if fn.x != 0.0 else (1 if fn.y != 0.0 else 2)
		var a_axis := (n_axis + 1) % 3
		var b_axis := (n_axis + 2) % 3
		var a_steps: Array = axes[a_axis]
		var b_steps: Array = axes[b_axis]
		var base := verts.size()
		for j in b_steps.size():
			for i in a_steps.size():
				var p := Vector3.ZERO
				p[n_axis] = 0.5 * fn[n_axis]
				p[a_axis] = a_steps[i]
				p[b_axis] = b_steps[j]
				var q := p.clamp(lo, hi)
				var e := (p - q) / ROUND
				if fn.y < 0.0:
					e.y = 0.0   # the flat bottom only follows the rounded corners
				var n := fn
				if e.length() > 0.00001:
					var u := e.normalized()
					p = q + u * ROUND
					if fn.y >= 0.0:
						n = (u / ROUND).normalized()
				p.x = lerpf(x0, x1, p.x + 0.5)
				p.z = lerpf(z0, z1, p.z + 0.5)
				verts.append(p)
				normals.append(n)
		var w: int = a_steps.size()
		for j in b_steps.size() - 1:
			for i in w - 1:
				var a := base + j * w + i
				var quad := [a, a + 1, a + w + 1, a + w]
				for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
					var t0: int = tri[0]
					var t1: int = tri[1]
					var t2: int = tri[2]
					# Godot's front faces wind clockwise as seen from outside.
					var gn := (verts[t1] - verts[t0]).cross(verts[t2] - verts[t0])
					if gn.dot(fn) > 0.0:
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
	_tiles[key] = mesh
	return mesh


# Grid positions along one axis of the unit box: the ends, the edges of the
# flat part, and a midpoint in each rounded zone so the corner curves.
static func _steps(lo: float, hi: float, r: float) -> Array:
	var out: Array = [-0.5]
	if lo > -0.5 + 0.0001:
		out.append(-0.5 + r * 0.5)
		out.append(lo)
	if hi < 0.5 - 0.0001:
		out.append(hi)
		out.append(0.5 - r * 0.5)
	out.append(0.5)
	return out
