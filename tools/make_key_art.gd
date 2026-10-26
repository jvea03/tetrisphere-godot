# The key art (icons/loading_screen.webp) under the game's name. The painted
# original (icons/key_art_original.webp) reads "Egg Escape: Puzzle Break"; this
# keeps its "Egg Escape:" and lays a ribbon in the game's own style
# (TSUI.ribbon, as on the Rescued! card) over the second line, reading
# "Block Puzzle Match" -- the Play listing's title. Everything built from the
# key art (the loading screen, tools/make_ads, make_store_art,
# make_channel_art, make_video) then carries the new name. Run with:
#   Godot.exe --path . res://tools/make_key_art.tscn
extends Node

const ORIGINAL := "res://icons/key_art_original.webp"
const OUT := "res://icons/loading_screen.webp"
const SUBTITLE := "Block Puzzle Match"
## Over the painted "Puzzle Break" and its glow (x 175-870, y 360-515 on the
## 941 x 1672 art): the band's height is set by RIBBON_BAND_FONT, the words in
## it by TEXT_FONT, so they fit inside the band.
const RIBBON_AT := Vector2(30, 354)
const RIBBON_W := 880.0
const RIBBON_BAND_FONT := 100
const TEXT_FONT := 70


func _ready() -> void:
	var art := Image.load_from_file(ProjectSettings.globalize_path(ORIGINAL))
	var sub := SubViewport.new()
	sub.size = art.get_size()
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(art)
	bg.size = Vector2(art.get_size())
	sub.add_child(bg)
	var ribbon := TSUI.ribbon(SUBTITLE, TSUI.PINK, RIBBON_BAND_FONT, RIBBON_W)
	ribbon.position = RIBBON_AT
	ribbon.size = ribbon.custom_minimum_size
	# The game's own lettering (screens get it from their theme; this has none).
	var words := ribbon.get_child(0) as Label
	words.add_theme_font_override("font", TSToon.hand_font())
	words.add_theme_font_size_override("font_size", TEXT_FONT)
	words.add_theme_constant_override("outline_size", 18)
	sub.add_child(ribbon)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_webp(ProjectSettings.globalize_path(OUT), true, 0.92)
	print("KEY_ART_OK ", OUT)
	get_tree().quit(0)
