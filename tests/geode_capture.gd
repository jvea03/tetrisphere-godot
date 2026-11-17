# Visual QA for a geode cracking open: starts a level with geodes (default 13),
# faces the first one, saves geode_before.png, cracks it (as its last hit
# would) so its rock flies, and saves geode_after.png once it has landed.
#   OUT=<folder> Godot.exe --path . res://tests/geode_capture.tscn -- 13
extends "res://scripts/game.gd"

var _frames := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	TSProfile.use_test_profile(int(args[0]) if args.size() > 0 else 13)
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 5 and not board.geodes.is_empty():
		var id: int = board.geodes.keys()[0]
		_face(Vector2(board.plate_cols[id][0]))
	if _frames == 90:
		_shot("geode_before")
		var id: int = board.geodes.keys()[0]
		var at: Vector2i = board.plate_cols[id][0]
		board.geodes[id] = 1
		var doomed := {id: true}
		var fx: Array = []
		board._geode_breaks.clear()
		board._destroy(doomed, 1, fx)
		var res := board._chain(board._settle(), fx, 2)
		res["geode_shots"] = board._geode_breaks.duplicate()
		print("shots ", res["geode_shots"], " at ", at)
		view.rebuild()
		_crack_geodes(res)
	if _frames == 200:
		_shot("geode_after")
		get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join(name + ".png"))
