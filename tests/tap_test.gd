# Checks the touch controls: tap-to-aim (projects known cells to the screen,
# taps there, and checks the aim lands on them), then the gestures -- swipe to
# turn, double-tap to drop, hold and drag to slide. Run with:
#   Godot.exe --path . res://tests/tap_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0
var _drops := 0
var _dropped_at := Vector2i(-1, -1)


func _ready() -> void:
	TSProfile.use_test_profile()
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 90:   # let the camera settle on the aim
		_run()


func _drop() -> void:
	_drops += 1
	_dropped_at = cursor
	super()


func _run() -> void:
	_run_tap_aim()
	_run_egg()
	_run_bomb_button()
	_run_gestures()
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_tap_aim() -> void:
	var centre := _piece_centre()
	# Both pieces: an upright line near a rim is where the clamp kicks in.
	for kind in [TSBoard.I_FLAT, TSBoard.I_UPRIGHT]:
		cur_type = kind
		for step in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(-2, -1), Vector2i(1, 3)]:
			var r := clampi(int(round(centre.y)) + step.y, 0, TSBoard.ROWS - 1)
			var target := Vector2i(board.wrap_col(int(round(centre.x)) + step.x), r)
			_tap_aim(_screen_of(target))
			# The piece must cover the tapped cell. It cannot always be centred
			# on it: near a rim the aim is clamped so the piece stays on the ball.
			var covered := board.footprint_cells(current_offsets(), cursor)
			_check("%s: tap on %s puts the piece over it" % [TSBoard.SHAPES[kind]["name"], target], covered.has(target))

	var before := cursor
	_tap_aim(Vector2(4.0, 4.0))
	_check("tap off the ball leaves the aim alone", cursor == before)


func _run_gestures() -> void:
	var mid := get_viewport().get_visible_rect().size * 0.5

	# Swipe: turns the ball, never aims or drops.
	var cursor_before := cursor
	var theta_before := _cam_target_theta
	_touch(mid, true)
	_drag_to(mid, mid + Vector2(200.0, 0.0), 10)
	_touch(mid + Vector2(200.0, 0.0), false)
	var turned := wrapf(_cam_target_theta - theta_before, -PI, PI)
	_check("swipe right turns the ball (%.2f rad)" % turned, absf(turned + 200.0 * TURN_RATE) < 0.01)
	_check("swipe leaves the aim alone", cursor == cursor_before)
	_touch(mid, true)
	_drag_to(mid, mid + Vector2(0.0, 2000.0), 20)
	_touch(mid + Vector2(0.0, 2000.0), false)
	_check("a long swipe down stops at the tilt limit", is_equal_approx(_cam_target_phi, TILT_LIMIT))
	_check("swipes drop nothing", _drops == 0)
	# Put the view back so the rest of the taps land on the ball.
	_face(_piece_centre())
	_cam_theta = _cam_target_theta
	_cam_phi = _cam_target_phi
	_process(0.0)

	# Single tap and two far-apart taps: aim only.
	_last_tap_ms = -100000
	_tap_at(mid)
	_check("one tap does not drop", _drops == 0)
	_tap_at(mid + Vector2(200.0, 0.0))
	_check("two taps far apart do not drop", _drops == 0)

	# Hold on a piece like yours, then drag: slides it one cell per step.
	_last_tap_ms = -100000
	# On a fresh ball every upright is boxed in by its neighbours; flats can move.
	cur_type = TSBoard.I_FLAT
	var grip := _find_slidable()
	_check("found a slidable piece on screen", grip["cell"] != Vector2i(-1, -1))
	if grip["cell"] != Vector2i(-1, -1):
		var cell: Vector2i = grip["cell"]
		var dir: Vector2i = grip["dir"]
		var id := board.top_piece(cell.x, cell.y)
		var from := _screen_of(cell)
		_touch(from, true)
		_touch_ms -= 1000   # as if held for a second
		_process(0.0)
		_check("hold grabs the piece", _gesture == Gesture.SLIDING and selected == id)
		var towards := _screen_of(Vector2i(board.wrap_col(cell.x + dir.x), cell.y + dir.y)) - from
		_drag_to(from, from + towards.normalized() * (SLIDE_STEP + 4.0), 4)
		var moved_to := Vector2i(board.wrap_col(cell.x + dir.x), cell.y + dir.y)
		_check("dragging slides it %s" % dir, board.plate_cols[id].has(moved_to))
		_touch(from + towards.normalized() * (SLIDE_STEP + 4.0), false)
		_check("letting go puts it down", _gesture == Gesture.NONE and selected == TSBoard.HOLE)
		_check("sliding drops nothing", _drops == 0)

	# Hold on something you can't slide: nothing is grabbed, and dragging on
	# turns the ball instead.
	var bad := _find_unslidable()
	if bad != Vector2i(-1, -1):
		var at := _screen_of(bad)
		_touch(at, true)
		_touch_ms -= 1000
		_process(0.0)
		_check("hold on a piece unlike yours grabs nothing", _gesture == Gesture.IGNORE and selected == TSBoard.HOLE)
		theta_before = _cam_target_theta
		_drag_to(at, at + Vector2(-120.0, 0.0), 6)
		_check("...and dragging then turns the ball", _gesture == Gesture.TURNING and _cam_target_theta != theta_before)
		_touch(at + Vector2(-120.0, 0.0), false)
		_face(_piece_centre())
		_cam_theta = _cam_target_theta
		_cam_phi = _cam_target_phi
		_process(0.0)

	# Double tap: drops, at the aim the first tap set.
	_last_tap_ms = -100000
	var target := _screen_of(Vector2i(int(round(_piece_centre().x)), int(round(_piece_centre().y))))
	_tap_at(target)
	var aimed := cursor
	_tap_at(target + Vector2(10.0, 6.0))
	_check("double tap drops", _drops == 1)
	_check("...where the first tap aimed", _dropped_at == aimed)
	_tap_at(target)
	_check("a third tap does not drop again", _drops == 1)




# The egg: the stretch must undo exactly, or taps would land on the wrong cell.
func _run_egg() -> void:
	var worst := 0.0
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var theta := TAU * (float(c) + 0.5) / float(TSBoard.COLS)
			var phi := lerpf(-TSBoardView.LAT_SPAN, TSBoardView.LAT_SPAN, (float(r) + 0.5) / float(TSBoard.ROWS))
			var p := Vector3(cos(phi) * sin(theta), sin(phi), cos(phi) * cos(theta)) * 4.5
			worst = maxf(worst, TSBoardView.egg_inverse(TSBoardView.egg(p)).distance_to(p))
	_check("egg shape undoes exactly (worst error %.6f)" % worst, worst < 0.001)
	var top := TSBoardView.cell_transform(0, TSBoard.ROWS - 1, 0.0).origin
	var bottom := TSBoardView.cell_transform(0, 0, 0.0).origin
	_check("the egg is narrower at the top than the bottom", Vector2(top.x, top.z).length() < Vector2(bottom.x, bottom.z).length())


# The bomb button is a real button; a touch on it is not a tap on the ball.
func _run_bomb_button() -> void:
	var before := cursor
	var at := _btn_bomb.get_global_rect().get_center()
	_touch(at, true)
	_check("a touch on the bomb button starts no gesture", _gesture == Gesture.NONE)
	_touch(at, false)
	_check("...and does not move the aim", cursor == before)
	var armed := bomb_armed
	_btn_bomb.pressed.emit()
	_check("pressing it arms a bomb", bomb_armed != armed)
	_btn_bomb.pressed.emit()


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	_touch_input(ev)


func _drag_to(from: Vector2, to: Vector2, steps: int) -> void:
	var last := from
	for i in steps:
		var p := from.lerp(to, float(i + 1) / float(steps))
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = p
		ev.relative = p - last
		_touch_input(ev)
		last = p


func _tap_at(pos: Vector2) -> void:
	_touch(pos, true)
	_touch(pos, false)


func _screen_of(cell: Vector2i) -> Vector2:
	var top := float(board.height(cell.x, cell.y)) - 0.5
	return _camera.unproject_position(TSBoardView.cell_transform(cell.x, cell.y, top).origin)


func _visible(cell: Vector2i) -> bool:
	return _cell_at(_screen_of(cell)) == cell


# A visible cell whose top piece you may slide, and a direction it can go.
func _find_slidable() -> Dictionary:
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var cell := Vector2i(c, r)
			var id := board.top_piece(c, r)
			if not board.can_slide(id, cur_type) or not _visible(cell):
				continue
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var d: Vector2i = dir
				var next := Vector2i(board.wrap_col(c + d.x), r + d.y)
				if board.slide_preview(id, d) >= 0 and next.y >= 0 and next.y < TSBoard.ROWS and _visible(next):
					return {"cell": cell, "dir": d}
	return {"cell": Vector2i(-1, -1), "dir": Vector2i.ZERO}


func _find_unslidable() -> Vector2i:
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var id := board.top_piece(c, r)
			if id != TSBoard.HOLE and not board.can_slide(id, cur_type) and _visible(Vector2i(c, r)):
				return Vector2i(c, r)
	return Vector2i(-1, -1)


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1
