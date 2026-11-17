# Visual QA for the season voyage: plays the cutscene (as a preview, nothing
# banked) and saves frames at the given seconds. Env: OUT (folder),
# VOYAGE_SHIP (fixed / patched), VOYAGE_THEME (autumn, christmas, newyear,
# valentine). Run with:
#   OUT=shots VOYAGE_SHIP=fixed VOYAGE_THEME=christmas Godot.exe --path . res://tests/voyage_capture.tscn -- 1.5 4.2 5.6
extends Node

var _shots: Array = []
var _v := 0.0
var _scene: Node


func _ready() -> void:
	TSProfile.use_test_profile(20)
	for a in OS.get_cmdline_user_args():
		_shots.append(float(a))
	if _shots.is_empty():
		_shots = [1.5, 4.0, 5.2, 6.5, 9.0]
	_scene = (load("res://scenes/voyage.tscn") as PackedScene).instantiate()
	add_child(_scene)


func _process(delta: float) -> void:
	_v += delta
	if not _shots.is_empty() and _v >= float(_shots[0]):
		var at := float(_shots.pop_front())
		await RenderingServer.frame_post_draw
		var name := "%s_%s_%.1f.png" % [OS.get_environment("VOYAGE_SHIP"), OS.get_environment("VOYAGE_THEME"), at]
		get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join(name))
		if _shots.is_empty():
			get_tree().quit()
