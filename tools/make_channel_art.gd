# The YouTube channel's art, into store/youtube/: banner.png (2560 x 1440,
# everything that matters inside YouTube's 1546 x 423 middle strip, the part
# every screen shows) and avatar.png (800 x 800, the app icon -- YouTube
# crops it to a circle, so the critters sit in the middle). Built from the
# same key art and helpers as the ad images (tools/make_ads.gd). Run with:
#   Godot.exe --path . res://tools/make_channel_art.tscn
extends Node

const ADS := preload("res://tools/make_ads.gd")
const OUT := "res://store/youtube/"
const BANNER := Vector2i(2560, 1440)
const SAFE := Rect2(507, 508, 1546, 423)   # YouTube's always-visible strip

var _art: Node


func _ready() -> void:
	_art = ADS.new()
	_art.setup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _banner()
	_avatar()
	get_tree().quit(0)


func _banner() -> void:
	var sub := SubViewport.new()
	sub.size = BANNER
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var root := Control.new()
	root.size = Vector2(BANNER)
	sub.add_child(root)
	_art._sky(root, Vector2(BANNER))
	# The title on the left of the strip, the ship of critters on the right,
	# a line between them; the critters spill out beyond on wide screens.
	var tr: Rect2i = ADS.TITLE_RECT
	var title_w := 820.0
	var title_h := title_w * tr.size.y / tr.size.x
	_art._sprite(root, _art._crop(tr), Rect2(SAFE.position + Vector2(20, 0), Vector2(title_w, title_h)), 0.16)
	_art._headline(root, "Spin. Match. Escape!", 66, Rect2(SAFE.position.x + 20.0, SAFE.position.y + title_h - 10.0, title_w, SAFE.size.y - title_h + 10.0))
	var sr: Rect2i = ADS.SHIP_RECT
	var ship_h := SAFE.size.y + 60.0
	var ship_w := ship_h * sr.size.x / sr.size.y
	_art._sprite(root, _art._crop(sr), Rect2(Vector2(SAFE.end.x - ship_w, SAFE.position.y - 30.0), Vector2(ship_w, ship_h)), 0.12)
	# Critters out to the sides, for the TV and desktop widths.
	var crit := [1, 2, 4, 8, 11, 15, 20, 33]
	for k in crit.size():
		var left := k < 4
		var i := k % 4
		var s := 210.0 - i * 18.0
		var c := TSIcon.make("critter", s, crit[k])
		c.size = Vector2(s, s)
		var x := (SAFE.position.x - 140.0 - i * 120.0) if left else (SAFE.end.x + 70.0 + i * 120.0)
		c.position = Vector2(x - s * 0.5, BANNER.y * 0.5 - s * 0.5 + (i % 2) * 90.0 - 40.0)
		c.pivot_offset = c.size * 0.5
		c.rotation = deg_to_rad([-10.0, 8.0, -6.0, 10.0][i])
		root.add_child(c)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := sub.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + "banner.png"))
	print("ART_OK banner")
	sub.queue_free()


func _avatar() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://store/icon_512.png"))
	img.convert(Image.FORMAT_RGB8)
	img.resize(800, 800, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + "avatar.png"))
	print("ART_OK avatar")
