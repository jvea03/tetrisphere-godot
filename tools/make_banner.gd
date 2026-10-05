# Bakes the Battle Pass banner, icons/battle_pass_banner.png, from its art,
# art/battle_pass_banner.webp (art/ isn't bundled): a wide strip of it, the
# sky above the critters kept for the season's title, shrunk to size and
# with its corners rounded off to match the menus' cards.
# Run with:
#   Godot.exe --headless --path . --script res://tools/make_banner.gd
extends SceneTree

const ART := "res://art/battle_pass_banner.webp"
const OUT := "res://icons/battle_pass_banner.png"
const CROP := Rect2i(0, 110, 1834, 650)   # the critters along the bottom, the sky above
const WIDTH := 1100
const RADIUS := 30.0 / 672.0               # as the cards' corners, at the menus' width


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ART))
	img.convert(Image.FORMAT_RGBA8)
	img = img.get_region(CROP)
	img.resize(WIDTH, roundi(WIDTH * float(CROP.size.y) / CROP.size.x), Image.INTERPOLATE_LANCZOS)
	var r := RADIUS * WIDTH
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, r, w - r)
			var cy := clampf(y + 0.5, r, h - r)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d > r - 1.0:
				var c := img.get_pixel(x, y)
				c.a *= clampf(r - d, 0.0, 1.0)
				img.set_pixel(x, y, c)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("%s: %d x %d" % [OUT, w, h])
	quit(0)
