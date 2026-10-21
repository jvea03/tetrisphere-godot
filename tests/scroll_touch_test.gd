# Opens every screen with a scrolling list and drags it as a finger would:
# nothing inside swallows a touch before the list sees it, a drag scrolls the
# list wherever it starts -- on a button, a card or a gap -- a drag that
# starts on a button never presses it, and a plain tap on one still does.
# (On a phone the Battle Pass and the Collection, nearly all buttons, hardly
# scrolled.) Run with:
#   Godot.exe --path . res://tests/scroll_touch_test.tscn
extends Node

const SCREENS := ["shop", "collection", "battle_pass", "leaderboard", "clubs", "hunt", "streak"]

var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(30)
	TSProfile.collection_tutorial_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 50000
	call_deferred("_run")


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


## A finger: down at `from` (canvas coordinates), `dy` up or down, and off.
func _touch(from: Vector2, dy: float) -> void:
	var xf := get_tree().root.get_final_transform()
	var t := InputEventScreenTouch.new()
	t.position = xf * from
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	if dy != 0.0:
		for k in 12:
			var d := InputEventScreenDrag.new()
			d.position = xf * (from + Vector2(0, dy * (k + 1) / 12.0))
			d.relative = Vector2(0, dy / 12.0) * xf.get_scale()
			Input.parse_input_event(d)
			await get_tree().process_frame
	var u := InputEventScreenTouch.new()
	u.position = xf * (from + Vector2(0, dy))
	u.pressed = false
	Input.parse_input_event(u)
	for _i in 3:
		await get_tree().process_frame


func _long_list(scene: Node) -> ScrollContainer:
	for l in scene.find_children("*", "ScrollContainer", true, false):
		var sc := l as ScrollContainer
		if sc.is_visible_in_tree() and sc.get_v_scroll_bar().max_value > sc.size.y + 50:
			return sc
	return null


## A visible button wholly inside the list's view, nearest its middle.
func _button_in(sc: ScrollContainer) -> BaseButton:
	var view := sc.get_global_rect()
	var best: BaseButton = null
	for n in sc.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and not b.disabled and view.grow(-20).encloses(b.get_global_rect()):
			if best == null or absf(b.get_global_rect().get_center().y - view.get_center().y) < absf(best.get_global_rect().get_center().y - view.get_center().y):
				best = b
	return best


func _run() -> void:
	for name in SCREENS:
		var scene: Control = (load("res://scenes/%s.tscn" % name) as PackedScene).instantiate()
		get_tree().root.add_child(scene)
		for _i in 20:
			await get_tree().process_frame
		var lists := scene.find_children("*", "ScrollContainer", true, false)
		var swallowing := 0
		var plain := 0
		for l in lists:
			if l is TSScroll:
				swallowing += (l as TSScroll).swallowing_controls().size()
			else:
				plain += 1
		_check("%s: %d scroll list(s), all touch-friendly" % [name, lists.size()], plain == 0)
		_check("%s: nothing inside its lists swallows a touch (%d found)" % [name, swallowing], swallowing == 0)
		var sc := _long_list(scene)
		if sc != null:
			# Drags from a spread of points: whatever is under them, the list moves.
			var view := sc.get_global_rect()
			var stuck := 0
			for f in [Vector2(0.15, 0.35), Vector2(0.5, 0.5), Vector2(0.85, 0.65)]:
				sc.scroll_vertical = int((sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) / 3)   # a third of the way down its travel
				await get_tree().create_timer(1.2).timeout   # any fling settles
				var before := sc.scroll_vertical
				await _touch(view.position + view.size * f, -220)
				# A short list has little room to move: most of what's left counts.
				var bar := sc.get_v_scroll_bar()
				var room := bar.max_value - bar.page - before
				stuck += 1 if sc.scroll_vertical <= before + minf(100.0, room * 0.6) else 0
			_check("%s: a drag scrolls its list from anywhere (%d of 3 stuck)" % [name, stuck], stuck == 0)
			# From a button: it scrolls, and the button isn't pressed.
			sc.scroll_vertical = int((sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) / 3)   # a third of the way down its travel
			await get_tree().create_timer(1.2).timeout
			var b := _button_in(sc)
			if b != null:
				var hits := [0]
				b.pressed.connect(func(): hits[0] += 1)
				var before := sc.scroll_vertical
				await _touch(b.get_global_rect().get_center(), -220)
				_check("%s: a drag from a button scrolls without pressing it (%d -> %d, pressed %d, %s)" % [name, before, sc.scroll_vertical, hits[0], b.text], sc.scroll_vertical > before + 100 and hits[0] == 0)
				# A short drag -- the finger still on the button as it lets go.
				await get_tree().create_timer(1.2).timeout
				b = _button_in(sc)
				var nudged := [0]
				b.pressed.connect(func(): nudged[0] += 1)
				await _touch(b.get_global_rect().get_center(), -30)
				_check("%s: nor does a short drag on one" % name, nudged[0] == 0)
				if name == "collection":   # a tap there only picks a critter to look at
					await get_tree().create_timer(1.2).timeout
					b = _button_in(sc)
					var taps := [0]
					b.pressed.connect(func(): taps[0] += 1)
					await _touch(b.get_global_rect().get_center(), 0.0)
					_check("%s: a tap on a button still presses it, once (%d)" % [name, taps[0]], taps[0] == 1)
		scene.queue_free()
		await get_tree().process_frame
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
