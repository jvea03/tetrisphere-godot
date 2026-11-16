# The App Store's captioned screenshots, in the Play set's style
# (tools/make_store_screens.gd): a big headline over the key art's sky, then the
# game's screen in a phone with critters peeking round it. Rendered at Apple's
# sizes into build/store/ios_captioned/<size>/NN.png, from the raw screens in
# store/screenshots_src/ (1080 x 1920, tools/store_shot; the commands are in
# store/ios_listing.md). Upload with tools/asc.py screenshots.
#   Godot --path . res://tools/make_ios_screens.tscn
extends Node

const ADS := preload("res://tools/make_ads.gd")
const SRC := "../../screenshots_src/"   # relative to make_ads.gd's SRC
const OUT := "res://build/store/ios_captioned/"
## iPhone 6.7" (APP_IPHONE_67), iPhone 6.5" (APP_IPHONE_65), iPad 13" (APP_IPAD_PRO_3GEN_129).
const SIZES := [Vector2i(1290, 2796), Vector2i(1284, 2778), Vector2i(2048, 2732)]

## The first two carry the page (search shows them; most visitors never scroll).
const SHOTS := [
	{"name": "01", "headline": "Spin the egg &\nmatch blocks!", "shot": "game.png", "critters": [8, 1]},
	{"name": "02", "headline": "Free the cute\ncritters!", "shot": "win.png", "critters": [4, 15]},
	{"name": "03", "headline": "Race real players\n& send stickers!", "shot": "leaderboard.png", "critters": [11, 20]},
	{"name": "04", "headline": "Collect 80+\nadorable critters", "shot": "collection.png", "critters": [11, 2]},
	{"name": "05", "headline": "Rebuild your\ncamp & ship", "shot": "camp.png", "critters": [20, 33]},
	{"name": "06", "headline": "A new Battle Pass\nevery season", "shot": "battle_pass.png", "critters": [15, 33]},
	{"name": "07", "headline": "Clever blockers\nto crack", "shot": "vines.png", "critters": [1, 11]},
	{"name": "08", "headline": "Hundreds of cozy\nbrain teasers", "shot": "night.png", "critters": [15, 4]},
]

var _art: Node


func _ready() -> void:
	_art = ADS.new()
	_art.setup()
	for size in SIZES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "%dx%d" % [size.x, size.y]))
		for s in SHOTS:
			await _make(s, size)
	get_tree().quit(0)


func _make(s: Dictionary, size: Vector2i) -> void:
	var sub := SubViewport.new()
	sub.size = size
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var root := Control.new()
	root.size = Vector2(size)
	sub.add_child(root)
	# Scaled from the Play set's 1080 x 1920 layout by width; the taller iPhone
	# canvas gives the phone more room, the iPad a wider sky round it.
	var k := float(size.x) / 1080.0
	if size.x > 1500:
		k = float(size.y) / 1920.0 * 0.85   # iPad: by height, or the headline would be huge
	var head_h := 340.0 * k
	_art._sky(root, Vector2(size))
	_art._headline(root, str(s["headline"]), int(104 * k), Rect2(30 * k, 50 * k, size.x - 60 * k, head_h))
	var idea := {"shot": SRC + str(s["shot"]), "critters": s["critters"]}
	var top := 50 * k + head_h + 30 * k
	_art._phone_hero(root, idea, Rect2(0, top, size.x, size.y - top - 40 * k), false)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + "%dx%d/%s.png" % [size.x, size.y, s["name"]]))
	print("SHOT_OK %dx%d %s" % [size.x, size.y, s["name"]])
	sub.queue_free()
