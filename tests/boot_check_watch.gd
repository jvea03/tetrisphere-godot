# boot_check.gd's timer: lives on the root, so it outlasts the scene changes.
extends Node
var secs := 20.0
func _ready() -> void:
	get_tree().create_timer(secs).timeout.connect(func():
		var s := get_tree().current_scene
		print("BOOT_END scene=", s.scene_file_path if s else "none", " fps=", Engine.get_frames_per_second())
		get_tree().quit())
