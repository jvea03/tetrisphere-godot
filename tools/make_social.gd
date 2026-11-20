# Builds the launch images for a personal social account into store/social/:
# a feed post (1080 x 1350, 4:5) and a story (1080 x 1920, 9:16, with the top
# and bottom kept clear for the app's bars and a link sticker). It reuses
# tools/make_ads.gd's key art, sky, phone and headline helpers.
# The phone shows store/ads/src/game_tied.png: level 20 with the shell dug away
# round its first tie-down, the egg turned a column past it, so the critter sits
# in plain view in its chains (a posed 1080 x 1920 capture, not a played board).
# Run:
#   Godot.exe --path . res://tools/make_social.tscn
extends "res://tools/make_ads.gd"

const SOCIAL_OUT := "res://store/social/"
const SHAPES := {
	"post": Vector2i(1080, 1350),
	"story": Vector2i(1080, 1920),
}


func _ready() -> void:
	setup()
	for shape: String in SHAPES:
		await _render_social(shape)
	get_tree().quit(0)


func _render_social(shape: String) -> void:
	var size: Vector2i = SHAPES[shape]
	var sub := SubViewport.new()
	sub.size = size
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var root := Control.new()
	root.size = Vector2(size)
	sub.add_child(root)
	_compose_social(root, shape, Vector2(size))
	for i in 6:
		await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(SOCIAL_OUT + "egg_escape_%s_%dx%d.png" % [shape, size.x, size.y])
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	print("SOCIAL_OK ", path)
	sub.queue_free()


func _compose_social(root: Control, shape: String, s: Vector2) -> void:
	_sky(root, s)
	var story := shape == "story"
	# The story keeps ~250 px clear at the top and ~380 px at the bottom.
	var top := 250.0 if story else 30.0
	var bottom := s.y - (380.0 if story else 30.0)
	_headline(root, "I made a game!", 74, Rect2(40, top, s.x - 80, 100))
	var title_w := 820.0 if story else 700.0
	var title_h := title_w * TITLE_RECT.size.y / TITLE_RECT.size.x
	var title_y := top + 100.0
	_sprite(root, _crop(TITLE_RECT), Rect2(Vector2((s.x - title_w) / 2.0, title_y), Vector2(title_w, title_h)), 0.16)
	var rib_h := 150.0
	var rib_y := bottom - rib_h
	var hero := Rect2(0, title_y + title_h + 4.0, s.x, rib_y - (title_y + title_h + 4.0) + 30.0)
	_phone_hero(root, {"shot": "game_tied.png", "critters": [8, 1]}, hero, false)
	var rib := TSUI.ribbon("Out now, free!", TSUI.PINK, 52, 560.0)
	rib.position = Vector2((s.x - 560.0) / 2.0, rib_y)
	root.add_child(rib)
	var ls := LabelSettings.new()
	ls.font = TSToon.hand_font()
	ls.font_size = 34
	ls.font_color = Color.WHITE
	ls.outline_size = 10
	ls.outline_color = INK
	var l := Label.new()
	l.text = "iPhone  &  Android"
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, rib_y + 96.0)
	l.size = Vector2(s.x, 50)
	root.add_child(l)
