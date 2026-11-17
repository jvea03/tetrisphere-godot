# Visual QA for tie-downs: starts a level with them (default 20), turns the egg
# to face the first one, and saves a PNG. Run with:
#   OUT=<folder> Godot.exe --path . res://tests/tie_capture.tscn -- 20 [dig]
# `dig` clears the shell beside the tie-down, down to the critter, to show its chains.
extends "res://scripts/game.gd"

var _frames := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	TSProfile.use_test_profile(int(args[0]) if args.size() > 0 else 20)
	var t0 := get_tree()
	t0.create_timer(float(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 3.0).timeout.connect(func():
		await RenderingServer.frame_post_draw
		var out := OS.get_environment("OUT")
		if out != "":
			t0.root.get_texture().get_image().save_png(out.path_join("tie_%d%s.png" % [current_level, "_dig" if "dig" in OS.get_cmdline_user_args() else ""]))
		t0.quit())
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 5 and not board.ties.is_empty():
		var id: int = board.ties.keys()[0]
		var cell: Vector2i = board.plate_cols[id][0]
		_face(Vector2(cell))
		if "dig" in OS.get_cmdline_user_args():
			for p in board.plate_kind.keys():
				if board.ties.has(p) or not board.plate_cols.has(p):
					continue
				var near := false
				var touches_tie := false
				for v: Vector2i in board.plate_cols[p]:
					var dc := absi(posmod(v.x - cell.x + TSBoard.COLS / 2, TSBoard.COLS) - TSBoard.COLS / 2)
					near = near or (dc >= 1 and dc <= 2)
					touches_tie = touches_tie or v == cell
				if near and not touches_tie:
					board._remove_plate(p)
			view.rebuild()
