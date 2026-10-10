# Plays level 2's sliding lesson the way fingers really do it: a patient hold
# and drag, an impatient drag that starts moving before the hold registers,
# and a hold that wobbles. The lesson's spotlight is fixed to where the line
# was when the step began and blocks every touch outside it, so a gesture that
# turned the ball instead of grabbing the line used to strand the player.
# Run with:
#   Godot.exe --path . res://tests/slide_lesson_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	_touch_input(ev)


func _drag_by(from: Vector2, by: Vector2, steps: int) -> Vector2:
	var last := from
	for i in steps:
		var p := from + by * float(i + 1) / float(steps)
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = p
		ev.relative = p - last
		_touch_input(ev)
		last = p
	return last


func _screen_of(cell: Vector2i) -> Vector2:
	var top := float(board.height(cell.x, cell.y)) - 0.5
	return _camera.unproject_position(TSBoardView.cell_transform(cell.x, cell.y, top).origin)


func _touchable(cell: Vector2i) -> bool:
	var at := _screen_of(cell)
	if _on_booster_button(at) or _pause_btn.get_global_rect().has_point(at):
		return false
	return _cell_at(at) == cell


# Starts the lesson fresh and works out where a finger would press and which
# way it should drag to slide the line.
func _fresh_lesson() -> Dictionary:
	TSProfile.slide_tutorial_seen = false
	_close_cards()
	_start_level(2)
	for _i in 4:
		await get_tree().process_frame
	var id := _slide_example(TSBoard.I_FLAT)
	var out := {"ok": false}
	if not _tutorial.on_step("slide") or id == TSBoard.HOLE:
		return out
	for col in board.plate_cols[id]:
		var cell: Vector2i = col
		if not _touchable(cell):
			continue
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var d: Vector2i = dir
			var next := Vector2i(board.wrap_col(cell.x + d.x), cell.y + d.y)
			if board.slide_preview(id, d) >= 0 and board.in_rows(next.y) and _touchable(next):
				var from := _screen_of(cell)
				return {"ok": true, "id": id, "grip": cell, "from": from,
					"towards": (_screen_of(next) - from).normalized(), "hole": _piece_rect(id).grow(14.0), "theta": _cam_target_theta, "phi": _cam_target_phi}
	return out


func _lesson_passed() -> bool:
	return not _tutorial.on_step("slide")


# Whether the player could still do the lesson now: the line is on screen,
# inside the spotlight, and pressing it grabs it.
func _still_doable(lesson: Dictionary) -> bool:
	var cell: Vector2i = lesson["grip"]
	var at := _screen_of(cell)
	return (lesson["hole"] as Rect2).has_point(at) and _cell_at(at) == cell and board.top_piece(cell.x, cell.y) == int(lesson["id"])


func _run() -> void:
	# 1. Patient: hold, then drag.
	var l: Dictionary = await _fresh_lesson()
	_check("level 2 opens the sliding lesson with a line to slide", l["ok"])
	if l["ok"]:
		_touch(l["from"], true)
		_touch_ms -= 600
		_process(0.0)
		var end := _drag_by(l["from"], (l["towards"] as Vector2) * (SLIDE_STEP + 6.0), 4)
		_touch(end, false)
		for _i in 3:
			await get_tree().process_frame
		_check("a patient hold and drag passes the lesson", _lesson_passed())

	# 2. Impatient: the finger starts moving at once, before the hold registers.
	l = await _fresh_lesson()
	if l["ok"]:
		_touch(l["from"], true)
		var end2 := _drag_by(l["from"], (l["towards"] as Vector2) * (SLIDE_STEP + 6.0), 4)
		_touch(end2, false)
		for _i in 90:   # the camera eases toward a swipe's target over a second or so
			await get_tree().process_frame
		_check("an impatient drag (no hold) slides the line and passes the lesson", _lesson_passed())
		_check("and it did not turn the ball", is_equal_approx(_cam_target_theta, l["theta"]) and is_equal_approx(_cam_target_phi, l["phi"]))

	# 3. A wobbly hold: the finger drifts a little while it waits.
	for wobble in [10.0, 22.0, 40.0]:
		l = await _fresh_lesson()
		if l["ok"]:
			_touch(l["from"], true)
			_drag_by(l["from"], Vector2(wobble, 0.0), 2)
			_touch_ms -= 600
			_process(0.0)
			var back := l["from"] as Vector2
			var end3 := _drag_by(back, (l["towards"] as Vector2) * (SLIDE_STEP + 6.0), 4)
			_touch(end3, false)
			for _i in 90:
				await get_tree().process_frame
			_check("a hold that wobbles %d px still passes the lesson" % int(wobble), _lesson_passed())
			_check("and the wobble did not turn the ball", is_equal_approx(_cam_target_theta, l["theta"]) and is_equal_approx(_cam_target_phi, l["phi"]))

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
