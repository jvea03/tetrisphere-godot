# Memory and frame cost of each main screen, one after another in the same
# run (so what a screen leaves behind shows in the next row): static (script
# and engine) memory, texture memory, total video memory, nodes, draw calls
# and uncapped fps. Not a pass/fail test -- run it windowed and compare:
#   Godot.exe --path . --resolution 720x1280 res://tests/mem_probe.tscn
extends Node

const SCENES := ["res://scenes/home.tscn", "res://main.tscn", "res://scenes/home.tscn", "res://scenes/collection.tscn",
	"res://scenes/battle_pass.tscn", "res://scenes/shop.tscn", "res://scenes/voyage.tscn", "res://main.tscn", "res://scenes/home.tscn"]


func _ready() -> void:
	TSProfile.use_test_profile(int(OS.get_environment("LEVEL")) if OS.get_environment("LEVEL") != "" else 40)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	_run.call_deferred()


func _mb(monitor: Performance.Monitor) -> float:
	return Performance.get_monitor(monitor) / 1048576.0


func _run() -> void:
	# Uncapped, so fps is the frame's real cost (on this PC; a phone is slower).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("MEM %-18s %7s %7s %7s %6s %5s %6s" % ["screen", "static", "tex", "video", "nodes", "draws", "fps"])
	for path in SCENES:
		var s: Node = (load(path) as PackedScene).instantiate()
		add_child(s)
		await get_tree().create_timer(3.0).timeout
		var start := Time.get_ticks_usec()
		for i in 300:
			await get_tree().process_frame
		var fps := 300.0 / ((Time.get_ticks_usec() - start) / 1000000.0)
		print("MEM %-18s %6.1fM %6.1fM %6.1fM %6d %5d %6d" % [path.get_file(), _mb(Performance.MEMORY_STATIC),
			_mb(Performance.RENDER_TEXTURE_MEM_USED), _mb(Performance.RENDER_VIDEO_MEM_USED),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			roundi(fps)])
		s.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()
