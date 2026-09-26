# Draws the app icons with the game's own art (TSIcon), so there are no image
# files to keep in sync by hand: a critter sitting in a pink egg on a butter
# background. Writes res://icons/icon.png (512, the project and launcher icon)
# and, for Android's adaptive icon, icon_foreground.png (the egg and critter,
# kept inside the middle two thirds so no mask shape crops it) and
# icon_background.png (plain butter). Needs a window, as it renders. Run with:
#   Godot.exe --path . --script res://tools/make_icons.gd
extends SceneTree

const BUTTER := Color(1.0, 0.86, 0.5)

var _frames := 0
var _shots: Array = []   # [viewport, file]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))
	_shots.append([_scene(512, true, 0.8), "res://icons/icon.png"])
	_shots.append([_scene(432, false, 0.62), "res://icons/icon_foreground.png"])
	_shots.append([_scene(432, true, 0.0), "res://icons/icon_background.png"])


# One icon: optional butter background, then the egg and critter scaled to
# `art` of the size (0 draws no art).
func _scene(px: int, background: bool, art: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if background:
		var bg := ColorRect.new()
		bg.color = BUTTER
		bg.size = Vector2(px, px)
		vp.add_child(bg)
	if art > 0.0:
		var s := px * art
		var egg := TSIcon.make("egg", s, 0)
		egg.size = Vector2(s, s)
		egg.position = Vector2(px - s, px - s) * 0.5 + Vector2(0.0, s * 0.06)
		vp.add_child(egg)
		var critter := TSIcon.make("critter", s * 0.62, 0)
		critter.size = Vector2(s, s) * 0.62
		critter.position = Vector2(px * 0.5 - s * 0.31, px * 0.5 - s * 0.46)
		vp.add_child(critter)
	return vp


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		for shot in _shots:
			var img := (shot[0] as SubViewport).get_texture().get_image()
			img.save_png(shot[1])
			print("wrote ", shot[1])
		quit()
	return false
