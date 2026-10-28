# Where Home's frame goes: uncapped fps with the camp as it is, with its
# per-frame repaint stopped (the cost of re-recording the drawing), and
# hidden (the cost of drawing it at all).
#   Godot.exe --path . --resolution 720x1280 res://tests/home_cost_probe.tscn
extends Node


func _ready() -> void:
	TSProfile.use_test_profile(40)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	_run.call_deferred()


func _fps() -> float:
	var start := Time.get_ticks_usec()
	for i in 300:
		await get_tree().process_frame
	return 300.0 / ((Time.get_ticks_usec() - start) / 1000000.0)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var home: Node = (load("res://scenes/home.tscn") as PackedScene).instantiate()
	add_child(home)
	await get_tree().create_timer(3.0).timeout
	var camp: Node = null
	for n in home.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("ship_scene.gd"):
			camp = n
	camp.set("_awake_until", INF)   # uncapped: Home otherwise drops to its IDLE_FPS when left alone
	print("COST as is: %d fps, %d draws" % [roundi(await _fps()), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	camp.set_process(false)
	print("COST no repaint: %d fps, %d draws" % [roundi(await _fps()), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	(camp as CanvasItem).visible = false
	print("COST camp hidden: %d fps, %d draws" % [roundi(await _fps()), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()
