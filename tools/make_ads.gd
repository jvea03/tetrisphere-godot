# Builds the Google Ads (App campaign) images into store/ads/: five ideas,
# each in the three shapes App campaigns take -- landscape 1200 x 628
# (1.91:1), square 1200 x 1200 and portrait 1200 x 1500 (4:5). They are put
# together from the key art (its title and its ship of critters), the game's
# own screens (store/ads/src, rendered by tools/store_shot) and its critters.
# Render the screens first (see store/ads/README.md), then run:
#   Godot.exe --path . res://tools/make_ads.tscn
extends Node

const KEY_ART := "res://icons/loading_screen.webp"
const SRC := "res://store/ads/src/"
const OUT := "res://store/ads/"
const TITLE_RECT := Rect2i(20, 160, 905, 330)   # the key art's title, ring and all
const SHIP_RECT := Rect2i(0, 520, 941, 700)     # and its ship of critters
const INK := Color(0.27, 0.16, 0.19)

const SIZES := {"landscape": Vector2i(1200, 628), "square": Vector2i(1200, 1200), "portrait": Vector2i(1200, 1500)}

## Each idea: its headline, what fills the hero spot (a phone showing one of
## the game's screens, the ship, or a crowd of critters) and the critters
## around it.
const IDEAS := [
	{"name": "01_crack", "headline": "Crack the egg.\nFree the critter!", "hero": "phone", "shot": "game.png", "critters": [8, 1]},
	{"name": "02_rescue", "headline": "Can you save\nthem all?", "hero": "phone", "shot": "win.png", "critters": [4, 15]},
	{"name": "03_collect", "headline": "Collect 84\ncute critters!", "hero": "crowd", "critters": [1, 2, 4, 8, 11, 15, 0, 20, 33]},
	{"name": "04_adventure", "headline": "A cozy puzzle\nadventure", "hero": "ship", "critters": []},
	{"name": "05_spin", "headline": "Spin. Match.\nEscape!", "hero": "phone", "shot": "game_prism.png", "critters": [11, 2]},
]

const FEATHER := """
shader_type canvas_item;
uniform float feather = 0.1;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	c.a *= smoothstep(0.0, feather, e);
	COLOR = c;
}
"""

var _key: Image
var _sky_top: Color
var _sky_bottom: Color
var _feather: Shader


func _ready() -> void:
	_key = Image.load_from_file(ProjectSettings.globalize_path(KEY_ART))
	_key.convert(Image.FORMAT_RGBA8)
	_sky_top = _key.get_pixel(20, 60)
	_sky_bottom = _key.get_pixel(20, 1100)
	_feather = Shader.new()
	_feather.code = FEATHER
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for idea: Dictionary in IDEAS:
		if only != "" and not str(idea["name"]).begins_with(only):
			continue
		for shape: String in SIZES:
			await _render(idea, shape)
	get_tree().quit(0)


func _render(idea: Dictionary, shape: String) -> void:
	var size: Vector2i = SIZES[shape]
	var sub := SubViewport.new()
	sub.size = size
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var root := Control.new()
	root.size = Vector2(size)
	sub.add_child(root)
	_compose(root, idea, shape, Vector2(size))
	for i in 6:
		await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT + "%s_%s_%dx%d.png" % [idea["name"], shape, size.x, size.y])
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)   # no alpha: Google Ads wants plain images
	img.save_png(path)
	print("AD_OK ", path)
	sub.queue_free()


# -- layout -------------------------------------------------------------------

func _compose(root: Control, idea: Dictionary, shape: String, s: Vector2) -> void:
	_sky(root, s)
	var landscape := shape == "landscape"
	var hero := str(idea["hero"])
	# Where things go: text on the left and the hero on the right when wide;
	# title, headline and hero top to bottom otherwise.
	var title_w: float
	var title_at: Vector2
	var head_size: int
	var head_rect: Rect2
	var hero_rect: Rect2
	var ribbon_at: Vector2
	var ribbon_w: float
	if landscape:
		title_w = 600.0
		title_at = Vector2(40, 18)
		head_size = 56
		head_rect = Rect2(40, 262, 600, 200)
		ribbon_at = Vector2(110, 488)
		ribbon_w = 460.0
		hero_rect = Rect2(660, 14, 520, 600)
	else:
		var tall := shape == "portrait"
		title_w = 860.0 if tall else 760.0
		title_at = Vector2((s.x - title_w) / 2.0, 22)
		head_size = 76 if tall else 64
		var head_y := title_w * TITLE_RECT.size.y / TITLE_RECT.size.x + 20.0
		head_rect = Rect2(60, head_y, s.x - 120, head_size * 2.6)
		var hero_y := head_rect.end.y + 10.0
		ribbon_w = 520.0
		ribbon_at = Vector2((s.x - ribbon_w) / 2.0, s.y - 138)
		hero_rect = Rect2(0, hero_y, s.x, ribbon_at.y - hero_y + 40)
	_sprite(root, _crop(TITLE_RECT), Rect2(title_at, Vector2(title_w, title_w * TITLE_RECT.size.y / TITLE_RECT.size.x)), 0.16)
	match hero:
		"phone": _phone_hero(root, idea, hero_rect, landscape)
		"ship": _sprite(root, _crop(SHIP_RECT), _fit(SHIP_RECT.size, hero_rect.grow(-6)), 0.12)
		"crowd": _crowd(root, idea["critters"], hero_rect)
	_headline(root, str(idea["headline"]), head_size, head_rect)
	var rib := TSUI.ribbon("Play free!", TSUI.PINK, 44 if landscape else 50, ribbon_w)
	rib.position = ribbon_at
	root.add_child(rib)


## The key art's night sky, top to bottom, sprinkled with stars.
func _sky(root: Control, s: Vector2) -> void:
	var g := Gradient.new()
	g.set_color(0, _sky_top)
	g.set_color(1, _sky_bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = s
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dots := Control.new()
	dots.size = s
	dots.draw.connect(func():
		for i in int(s.x * s.y / 9000.0):
			var at := Vector2(rng.randf() * s.x, rng.randf() * s.y)
			var r := rng.randf_range(1.5, 4.5)
			var col := [Color(1, 1, 1), Color(0.7, 0.85, 1.0), Color(1.0, 0.8, 0.95)][rng.randi() % 3] as Color
			dots.draw_circle(at, r * 2.4, Color(col, 0.12))
			dots.draw_circle(at, r, Color(col, 0.8)))
	root.add_child(dots)


func _crop(r: Rect2i) -> ImageTexture:
	return ImageTexture.create_from_image(_key.get_region(r))


## A key-art crop, its edges melted into the sky.
func _sprite(root: Control, tex: Texture2D, rect: Rect2, feather: float) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = rect.position
	t.size = rect.size
	var m := ShaderMaterial.new()
	m.shader = _feather
	m.set_shader_parameter("feather", feather)
	t.material = m
	root.add_child(t)


## The biggest rect of shape `src` inside `box`, centred.
func _fit(src: Vector2i, box: Rect2) -> Rect2:
	var k := minf(box.size.x / src.x, box.size.y / src.y)
	var sz := Vector2(src) * k
	return Rect2(box.position + (box.size - sz) / 2.0, sz)


func _headline(root: Control, text: String, font_size: int, rect: Rect2) -> void:
	var ls := LabelSettings.new()
	ls.font = TSToon.hand_font()
	ls.font_size = font_size
	ls.font_color = Color.WHITE
	ls.outline_size = int(font_size * 0.28)
	ls.outline_color = INK
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, font_size * 0.08)
	ls.line_spacing = -font_size * 0.12
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = rect.position
	l.size = rect.size
	root.add_child(l)


## A phone showing the game, tilted a little, with critters peeking round it.
func _phone_hero(root: Control, idea: Dictionary, box: Rect2, landscape: bool) -> void:
	var shot := Image.load_from_file(ProjectSettings.globalize_path(SRC + str(idea["shot"])))
	var h := box.size.y - 20.0
	var w := h * 9.0 / 16.0
	var frame := Panel.new()
	var face := StyleBoxFlat.new()
	face.bg_color = INK
	face.set_corner_radius_all(int(w * 0.11))
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 24
	face.shadow_offset = Vector2(0, 12)
	frame.add_theme_stylebox_override("panel", face)
	frame.size = Vector2(w, h)
	frame.position = Vector2(box.get_center().x - w / 2.0, box.position.y + 10.0)
	frame.pivot_offset = frame.size / 2.0
	frame.rotation = deg_to_rad(4.0 if landscape else 0.0)
	root.add_child(frame)
	var pad := w * 0.035
	var screen := Panel.new()
	var sface := StyleBoxFlat.new()
	sface.bg_color = Color.WHITE
	sface.set_corner_radius_all(int(w * 0.085))
	screen.add_theme_stylebox_override("panel", sface)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	screen.position = Vector2(pad, pad)
	screen.size = frame.size - Vector2(pad, pad) * 2.0
	frame.add_child(screen)
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(shot)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = screen.size
	screen.add_child(t)
	# Critters at its sides, bobbing out from behind it.
	var crit: Array = idea["critters"]
	var cs := h * (0.3 if landscape else 0.26)
	for k in crit.size():
		var left := k % 2 == 0
		var c := TSIcon.make("critter", cs, int(crit[k]))
		c.size = Vector2(cs, cs)
		var x := frame.position.x - cs * 0.62 if left else frame.position.x + w - cs * 0.38
		var y := box.position.y + h * (0.62 if left else 0.3)
		c.position = Vector2(x, y)
		c.pivot_offset = c.size / 2.0
		c.rotation = deg_to_rad(-12.0 if left else 12.0)
		root.add_child(c)


## A happy crowd of critters, big to small, filling the hero spot.
func _crowd(root: Control, crit: Array, box: Rect2) -> void:
	var n := crit.size()
	var cols := 5 if box.size.x > box.size.y * 1.6 else 3
	if cols == 3 and n > 9:
		n = 9
	var rows := ceili(float(n) / cols)
	var cell := minf(box.size.x / cols, box.size.y / rows)
	var origin := box.position + (box.size - Vector2(cell * cols, cell * rows)) / 2.0
	for k in n:
		var r := k / cols
		var col := k % cols
		var in_row := mini(cols, n - r * cols)   # a short last row sits in the middle
		var shift := (cols - in_row) * cell / 2.0
		var sz := cell * (0.95 if (r + col) % 2 == 0 else 0.82)
		var c := TSIcon.make("critter", sz, int(crit[k]))
		c.size = Vector2(sz, sz)
		c.position = origin + Vector2(col * cell + shift, r * cell) + Vector2(cell - sz, cell - sz) / 2.0
		c.pivot_offset = c.size / 2.0
		c.rotation = deg_to_rad([-8.0, 6.0, -4.0, 9.0, -6.0][k % 5])
		root.add_child(c)
