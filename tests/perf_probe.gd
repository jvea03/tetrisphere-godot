# Frame cost on the busiest screens (Home at night is the heaviest): script
# time, draw calls and fps after each settles. Not a pass/fail test -- run it
# windowed after art or effects work and compare. LEVEL=<n> picks the sky.
#   Godot.exe --path . --resolution 720x1280 res://tests/perf_probe.tscn
extends Node
func _ready() -> void:
	TSProfile.use_test_profile(int(OS.get_environment("LEVEL")) if OS.get_environment("LEVEL") != "" else 40)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSProfile.coin_count = 50000
	for i in [1, 2, 4, 8, 11, 15]:
		TSProfile.critter_unlocked[i] = true
		TSProfile.critter_level[i] = 3
	TSProfile.part_level = []
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level.append(2 if i < 15 else 0)
	_run.call_deferred()


func _measure(path: String) -> void:
	var s: Node = (load(path) as PackedScene).instantiate()
	add_child(s)
	await get_tree().create_timer(3.0).timeout
	var proc := 0.0
	var worst := 0.0
	var frames := 180
	for i in frames:
		await get_tree().process_frame
		var t := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		proc += t
		worst = maxf(worst, t)
	print("PERF %s: script %.2f ms/frame avg, %.2f worst; nodes %d; draw calls %d; objects %d; fps %d" % [path.get_file(), proc / frames, worst,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Engine.get_frames_per_second()])
	s.queue_free()
	await get_tree().process_frame


func _run() -> void:
	for p in ["res://scenes/home.tscn", "res://tests/demo.tscn", "res://scenes/collection.tscn", "res://scenes/battle_pass.tscn", "res://scenes/shop.tscn"]:
		await _measure(p)
	get_tree().quit()
