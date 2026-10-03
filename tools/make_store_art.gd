# Builds the Play Store listing graphics into store/ (ignored by Godot, so
# none of it is bundled into the game):
#   icon_512.png          the 512 x 512 store icon: the app icon art full
#                         bleed (Play rounds the corners itself), its white
#                         corners filled with the art's own deep blue
#   feature_1024x500.png  the feature graphic: the key art's title on the
#                         left and its ship of critters on the right, over
#                         the key art's night sky
# Run with:
#   Godot.exe --headless --path . --script res://tools/make_store_art.gd
extends SceneTree

const ICON_ART := "res://art/app_icon.png"
const KEY_ART := "res://icons/loading_screen.webp"
const OUT := "res://store"
const INSET := 9.0 / 1254.0     # as tools/make_icons.gd: the icon art's rounded square...
const RADIUS := 315.0 / 1254.0  # ...and its corners
const SPACE := Color(0.14, 0.12, 0.58)

# Where the key art (941 x 1672) keeps its title and its ship.
const TITLE_RECT := Rect2i(60, 185, 840, 315)
const SHIP_RECT := Rect2i(0, 520, 941, 700)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := _icon() and _feature()
	quit(0 if ok else 1)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("can't read %s" % path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _icon() -> bool:
	var art := _load(ICON_ART)
	if art == null:
		return false
	var n := art.get_width()
	var inset := INSET * n
	var r := RADIUS * n
	var lo := inset + r
	var hi := n - inset - r
	# Outside the rounded square is white fringe: paint it the art's space.
	for y in n:
		for x in n:
			var c := Vector2(clampf(x, lo, hi), clampf(y, lo, hi))
			var d := Vector2(x, y).distance_to(c)
			if d > r - 2.0:
				var keep := clampf((r - d) / 2.0, 0.0, 1.0)
				art.set_pixel(x, y, SPACE.lerp(art.get_pixel(x, y), keep))
	art.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	return art.save_png(ProjectSettings.globalize_path(OUT + "/icon_512.png")) == OK


func _feature() -> bool:
	var key := _load(KEY_ART)
	if key == null:
		return false
	var out := Image.create(1024, 500, false, Image.FORMAT_RGBA8)
	# The night sky: the key art's own top-to-bottom blue, sampled down its
	# left edge clear of the planet.
	var top := key.get_pixel(20, 60)
	var bottom := key.get_pixel(20, 1100)
	for y in 500:
		var c := top.lerp(bottom, float(y) / 499.0)
		for x in 1024:
			out.set_pixel(x, y, c)
	_paste_feathered(out, key, SHIP_RECT, Rect2i(460, 20, 560, 460), 40.0, 150.0)
	_paste_feathered(out, key, TITLE_RECT, Rect2i(24, 150, 440, 170), 30.0, 30.0)
	return out.save_png(ProjectSettings.globalize_path(OUT + "/feature_1024x500.png")) == OK


# Copies `src` of `img` into `dest` of `out` (fitted, keeping its shape and
# centred), fading its edges over `feather` px (its left edge over
# `feather_left`, past the ship's rocket flame) so its sky melts into ours.
func _paste_feathered(out: Image, img: Image, src: Rect2i, dest: Rect2i, feather: float, feather_left: float) -> void:
	var part := img.get_region(src)
	var s := minf(float(dest.size.x) / src.size.x, float(dest.size.y) / src.size.y)
	var w := int(src.size.x * s)
	var h := int(src.size.y * s)
	part.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var at := dest.position + (dest.size - Vector2i(w, h)) / 2
	for y in h:
		for x in w:
			var oy := at.y + y
			var ox := at.x + x
			if ox < 0 or oy < 0 or ox >= out.get_width() or oy >= out.get_height():
				continue
			var edge := minf(w - 1 - x, minf(y, h - 1 - y))
			var a := minf(clampf(edge / feather, 0.0, 1.0), clampf(x / feather_left, 0.0, 1.0))
			a = a * a * (3.0 - 2.0 * a)
			out.set_pixel(ox, oy, out.get_pixel(ox, oy).lerp(part.get_pixel(x, y), a))
