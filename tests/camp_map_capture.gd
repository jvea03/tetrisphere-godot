# Visual QA for the camp's layout: the whole crash site from above, every camp
# spot at one level, with a full crew, and each spot labelled. Run with a
# window (not headless):
#   Godot.exe --path . res://tests/camp_map_capture.tscn -- 4 OUT=folder
# The number is the camp spots' level (0 broken .. 4 finished; default 4);
# saves camp_map_<level>.png in the folder given by the OUT environment variable.
extends Node

const LABELS := {0: "Fire", 1: "Tent", 2: "Bench", 3: "Garden", 4: "Well", 5: "Lookout", 14: "Solar",
	15: "Hammock", 16: "Picnic", 17: "Clothesline", 18: "Mailbox", 19: "Windmill", 20: "Dock", 21: "Playground", 22: "Treehouse", 23: "Stall",
	24: "Greenhouse", 25: "Spring", 26: "Observatory", 27: "Oven", 28: "Statue"}

var _scene: TSShipScene
var _level := 4


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_level = int(a)
	TSProfile.use_test_profile(30)
	for i in TSProfile.CRITTER_COUNT:
		TSProfile.critter_unlocked[i] = true
		TSProfile.critter_level[i] = 1
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level[i] = _level if TSProfile.PARTS[i]["group"] == "camp" else 0
	var scale := 0.5
	get_window().size = Vector2i(roundi(TSShipScene.W * scale), roundi(TSShipScene.H * scale))
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var holder := Control.new()
	holder.size = Vector2(get_window().size)
	add_child(holder)
	_scene = TSShipScene.new()
	holder.add_child(_scene)
	_scene.set_deferred("size", holder.size)
	await get_tree().process_frame
	await get_tree().process_frame
	_scene._zoom = scale
	_scene._world.scale = Vector2.ONE * scale
	_scene._offset = Vector2.ZERO
	_scene._world.position = Vector2.ZERO
	var marks := Control.new()
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(func():
		var font := ThemeDB.fallback_font
		for i in LABELS:
			var p: Vector2 = TSShipScene.GROUND_NODES[i] * scale
			marks.draw_circle(p, 4.0, Color.RED)
			marks.draw_string_outline(font, p + Vector2(6, 16), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.WHITE)
			marks.draw_string(font, p + Vector2(6, 16), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK))
	holder.add_child(marks)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "":
		get_viewport().get_texture().get_image().save_png(out.path_join("camp_map_%d.png" % _level))
	get_tree().quit()
