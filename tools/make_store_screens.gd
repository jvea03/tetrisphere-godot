# The Play listing's phone screenshots with captions, into
# store/screenshots_captioned/ at 1080 x 1920: a big headline over the key
# art's sky, then the game's screen in a phone with critters peeking round it.
# The first two carry the page (most visitors never scroll), so they show the
# egg mid-match and the rescue. Built with tools/make_ads.gd's helpers from
# raw screens rendered by tools/store_shot (see store/aso.md for the commands).
#   Godot.exe --path . res://tools/make_store_screens.tscn
extends Node

const ADS := preload("res://tools/make_ads.gd")
const SRC := "../../screenshots_src/"   # relative to make_ads.gd's SRC
const OUT := "res://store/screenshots_captioned/"
const SIZE := Vector2i(1080, 1920)

const SHOTS := [
	{"name": "01", "headline": "Spin the egg &\nmatch blocks!", "shot": "game.png", "critters": [8, 1]},
	{"name": "02", "headline": "Free the cute\ncritters!", "shot": "win.png", "critters": [4, 15]},
	{"name": "03", "headline": "Collect 84\nadorable critters", "shot": "collection.png", "critters": [11, 2]},
	{"name": "04", "headline": "Rebuild your\ncamp & ship", "shot": "camp.png", "critters": [20, 33]},
	{"name": "05", "headline": "Clever blockers\nto crack", "shot": "vines.png", "critters": [1, 11]},
	{"name": "06", "headline": "Hundreds of cozy\nbrain teasers", "shot": "night.png", "critters": [15, 4]},
]

var _art: Node


func _ready() -> void:
	_art = ADS.new()
	_art.setup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for s in SHOTS:
		await _make(s)
	get_tree().quit(0)


func _make(s: Dictionary) -> void:
	var sub := SubViewport.new()
	sub.size = SIZE
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var root := Control.new()
	root.size = Vector2(SIZE)
	sub.add_child(root)
	_art._sky(root, Vector2(SIZE))
	_art._headline(root, str(s["headline"]), 104, Rect2(30, 40, SIZE.x - 60, 340))
	var idea := {"shot": SRC + str(s["shot"]), "critters": s["critters"]}
	_art._phone_hero(root, idea, Rect2(0, 400, SIZE.x, SIZE.y - 430), false)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + str(s["name"]) + ".png"))
	print("SHOT_OK ", s["name"])
	sub.queue_free()
