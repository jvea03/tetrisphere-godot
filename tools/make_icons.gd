# Builds the app icons from the icon art, art/app_icon.png (1254 px: the pink
# ship of critters in space, on a rounded square whose corners are white).
# Writes res://icons/icon.png (512, the project and launcher icon: the art
# with its corners cut away to transparent) and, for Android's adaptive icon,
# icon_foreground.png (the same art scaled into the middle two thirds, the
# part every launcher mask shows) and icon_background.png (the deep blue of
# its space, filling behind it out to the edges). art/ is ignored by Godot, so
# the full-size art is not bundled into the game. Run with:
#   Godot.exe --headless --path . --script res://tools/make_icons.gd
extends SceneTree

const SOURCE := "res://art/app_icon.png"
const INSET := 9.0 / 1254.0     # the art's rounded square, just inside its edge (past a white fringe)...
const RADIUS := 315.0 / 1254.0  # ...with corners this round (as a share of its size)
const SPACE := Color(0.14, 0.12, 0.58)   # the adaptive icon's background
const FOREGROUND_ART := 312     # px of the 432 foreground: just past the 288 a mask shows


func _initialize() -> void:
	var art := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if art == null:
		push_error("no icon art at %s" % SOURCE)
		quit(1)
		return
	art.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))

	_rounded(art, 512).save_png(ProjectSettings.globalize_path("res://icons/icon.png"))

	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	var inner := _rounded(art, FOREGROUND_ART)
	var at := (432 - FOREGROUND_ART) / 2
	fg.blend_rect(inner, Rect2i(0, 0, FOREGROUND_ART, FOREGROUND_ART), Vector2i(at, at))
	fg.save_png(ProjectSettings.globalize_path("res://icons/icon_foreground.png"))

	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(SPACE)
	bg.save_png(ProjectSettings.globalize_path("res://icons/icon_background.png"))
	print("icons written")
	quit()


# The art at `px`, with everything outside its rounded square -- the white
# corners -- faded to transparent over a pixel, so the edge stays smooth.
func _rounded(art: Image, px: int) -> Image:
	var img := art.duplicate() as Image
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var inset := INSET * px
	var radius := RADIUS * px
	var lo := inset + radius
	var hi := float(px) - inset - radius
	for y in px:
		for x in px:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var q := Vector2(clampf(p.x, lo, hi), clampf(p.y, lo, hi))
			var outside := p.distance_to(q) - radius   # > 0 past the rounded edge
			var keep := clampf(0.5 - outside, 0.0, 1.0)
			if keep < 1.0:
				var c := img.get_pixel(x, y)
				c.a *= keep
				img.set_pixel(x, y, c)
	return img
