# Visual QA for egg landscapes (TSBoard.shape_terrain): opens a level and saves
# terrain_<level>.png once the egg is in view.
#   OUT=<folder> Godot.exe --path . res://tests/terrain_capture.tscn -- 15
extends "res://scripts/game.gd"

var _frames := 0
var _lvl := 15


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_lvl = int(args[0]) if args.size() > 0 else 15
	TSProfile.use_test_profile(_lvl)
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 70:
		print("TERRAIN level %d: %s" % [_lvl, str(level.get("terrain", "none"))])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join("terrain_%d.png" % _lvl))
		get_tree().quit()
