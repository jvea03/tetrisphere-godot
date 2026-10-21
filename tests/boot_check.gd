# Boots the game from its real opening screen and reports where it ends up
# after SECS seconds -- with FRESH=1 a brand-new player (crash cutscene, then
# level 1: res://main.tscn), else a returning one (Home) -- so any error on
# the way shows in the output. A throwaway profile; the save is not touched.
#   FRESH=1 SECS=25 Godot.exe --path . res://tests/boot_check.tscn
extends Node
func _ready() -> void:
	var fresh := OS.get_environment("FRESH") == "1"
	TSProfile.use_test_profile(1 if fresh else 30)
	if fresh:
		TSProfile.intro_seen = false
		TSProfile.tutorial_seen = false
		TSProfile.ship_story_seen = false
	var w: Node = (load("res://tests/boot_check_watch.gd") as GDScript).new()
	w.secs = float(OS.get_environment("SECS"))
	get_tree().root.add_child.call_deferred(w)
	get_tree().change_scene_to_file.call_deferred("res://scenes/opening.tscn")
