class_name TSScroll
extends ScrollContainer

## A scroll list a finger can drag from anywhere. Godot hands a touch to the
## control under it, and a control that stops mouse input (every card, every
## button, by default) never passes it up to the list -- so on a phone a list
## made of cards and buttons, like the Shop or the Battle Pass, hardly
## scrolled at all. Everything inside is set to pass the touch on instead,
## buttons included: a button still takes a tap, but once the finger has moved
## DEAD_ZONE pixels it is a scroll, and the button under it lets go without
## being pressed -- so scrolling never buys or claims anything by accident.
## Sliders, text fields and scroll bars keep their own drags.

const DEAD_ZONE := 14   # pixels a finger must move before a drag starts scrolling

var _press_at := Vector2.ZERO
var _press_button: BaseButton   # the button the finger came down on, until it moves off as a scroll
var _touching := false


func _ready() -> void:
	scroll_deadzone = DEAD_ZONE
	for n in find_children("*", "Control", true, false):
		_release(n as Control)
	# Rows and cards are built later, as screens refresh.
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Control and is_ancestor_of(n):
		_release(n as Control)


static func _release(c: Control) -> void:
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if _keeps_touches(c):
		return
	c.mouse_filter = Control.MOUSE_FILTER_PASS


## Touches reach the list from the button or card under them (they pass them
## on). A press notes the button it landed on; a drag past the dead zone
## makes that button let go, unpressed.
func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		_touching = press.pressed
		_press_at = press.global_position
		_press_button = _button_at(press.global_position) if press.pressed else null
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _touching and _press_button != null \
			and motion.global_position.distance_to(_press_at) > DEAD_ZONE:
		_let_go(_press_button)
		_press_button = null


## The button under a touch (a phone has no hover to ask): the last drawn,
## so the topmost, of those whose box holds it.
func _button_at(at: Vector2) -> BaseButton:
	var hit: BaseButton = null
	for n in find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and b.get_global_rect().has_point(at):
			hit = b
	return hit


## Cancels a button's press without pressing it: disabling a button drops
## the press it was holding.
static func _let_go(b: BaseButton) -> void:
	if not is_instance_valid(b) or b.disabled:
		return
	b.disabled = true
	b.disabled = false


## Whether anything inside would still swallow a touch before the list sees it.
func swallowing_controls() -> Array[Control]:
	var out: Array[Control] = []
	for n in find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not _keeps_touches(c):
			out.append(c)
	return out


## Controls that need the drag for themselves.
static func _keeps_touches(c: Control) -> bool:
	return c is Range or c is LineEdit or c is TextEdit or c is ScrollBar or c is ScrollContainer
