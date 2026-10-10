class_name TSTutorial
extends Control

## The blackout-spotlight walkthrough (Duckdoku's TutorialOverlay): everything
## but a hole around the current step's target goes dark, with a caption
## card beside it. start(steps) with [{"rect", "text"}, ...]; a tap anywhere,
## or Next, advances; Skip ends it. A step with "gate": true has no buttons
## and lets taps through only inside the hole -- the screen calls
## gate_passed() once the player has done the thing (a step's optional "id"
## lets it check which, with on_step). "rect" may be a Callable, re-read when
## its step shows. A gated step offers Skip after GATE_SKIP_SECONDS, so a
## lesson the player cannot complete never traps them behind the dark panels.

signal finished

const PAD := 12.0
const GAP := 18.0
const CAPTION_WIDTH := 460.0
const GATE_SKIP_SECONDS := 12.0   # a gated step with no buttons offers Skip after this long

var steps: Array = []
var step_index := 0
var _masks: Array[ColorRect] = []
var _caption: PanelContainer
var _text: Label
var _next: Button
var _skip: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 4:
		var m := ColorRect.new()
		m.color = Color(TSUI.INK, 0.72)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(m)
		_masks.append(m)
	_caption = TSUI.card(TSUI.CARD, 26, 20, 5)
	_caption.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	var v := TSUI.vbox(12)
	_caption.add_child(v)
	_text = TSUI.wrap(TSUI.label("", 26), CAPTION_WIDTH - 48.0)
	v.add_child(_text)
	var row := TSUI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	_skip = TSUI.button("Skip", TSUI.GREY, 22, Vector2(120, 56), 4)
	_next = TSUI.button("Next", TSUI.PINK, 22, Vector2(140, 56), 4)
	row.add_child(_skip)
	row.add_child(_next)
	_skip.pressed.connect(_finish)
	_next.pressed.connect(_advance)
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			_advance())


func start(p_steps: Array) -> void:
	if p_steps.is_empty():
		return
	steps = p_steps
	step_index = 0
	visible = true
	_show_step()


func gate_passed() -> void:
	if visible and step_index < steps.size() and steps[step_index].get("gate", false):
		_advance()


## Whether the walkthrough is showing the step with this "id" -- so the screen
## can tell which action a gated step is waiting for.
func on_step(id: String) -> bool:
	return visible and step_index < steps.size() and steps[step_index].get("id", "") == id


func _advance() -> void:
	step_index += 1
	if step_index >= steps.size():
		_finish()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if visible:
		_show_step()


func _finish() -> void:
	visible = false
	finished.emit()


func _show_step() -> void:
	var step: Dictionary = steps[step_index]
	var target: Rect2 = step["rect"].call() if step["rect"] is Callable else step["rect"]
	var hole := target.grow(PAD)
	# Whole pixels, so the four dark panels meet without a hairline gap.
	hole = Rect2(hole.position.floor(), (hole.end.ceil() - hole.position.floor()))
	var vp := size
	_masks[0].position = Vector2.ZERO
	_masks[0].size = Vector2(vp.x, maxf(hole.position.y, 0.0))
	_masks[1].position = Vector2(0.0, hole.end.y)
	_masks[1].size = Vector2(vp.x, maxf(vp.y - hole.end.y, 0.0))
	_masks[2].position = Vector2(0.0, hole.position.y)
	_masks[2].size = Vector2(maxf(hole.position.x, 0.0), hole.size.y)
	_masks[3].position = Vector2(hole.end.x, hole.position.y)
	_masks[3].size = Vector2(maxf(vp.x - hole.end.x, 0.0), hole.size.y)
	_text.text = step["text"]
	_next.text = "Got it!" if step_index == steps.size() - 1 else "Next"
	var gated: bool = step.get("gate", false)
	_next.visible = not gated
	_skip.visible = not gated
	if gated:
		var shown := step_index
		get_tree().create_timer(GATE_SKIP_SECONDS).timeout.connect(func():
			if visible and step_index == shown and steps[step_index].get("gate", false):
				_skip.visible = true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if gated else Control.MOUSE_FILTER_STOP
	for m in _masks:
		m.mouse_filter = Control.MOUSE_FILTER_STOP if gated else Control.MOUSE_FILTER_IGNORE
	_caption.mouse_filter = Control.MOUSE_FILTER_STOP if gated else Control.MOUSE_FILTER_PASS
	_caption.reset_size()
	var x := clampf(hole.get_center().x - _caption.size.x * 0.5, 16.0, vp.x - _caption.size.x - 16.0)
	var below := hole.end.y + GAP
	var above := hole.position.y - GAP - _caption.size.y
	_caption.position = Vector2(x, below if below + _caption.size.y <= vp.y - 16.0 else maxf(above, 16.0))
