class_name TSScroll
extends ScrollContainer

## A scroll list a finger can drag from anywhere. Godot hands a touch to the
## control under it, and a control that stops mouse input (every card, every
## button, by default) never passes it up to the list -- so on a phone a list
## made of cards and buttons, like the Shop, hardly scrolled at all. Cards,
## rows and other plain controls are set to pass the touch on instead. Buttons
## are deliberately left alone: a drag that begins on one never presses it, so
## scrolling can't buy something by accident (a drag from a card, a label or a
## gap scrolls; only the button itself takes taps). Sliders, text fields and
## scroll bars keep their own drags.

const DEAD_ZONE := 14   # pixels a finger must move before a drag starts scrolling


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


## Whether anything inside would still swallow a touch before the list sees it.
func swallowing_controls() -> Array[Control]:
	var out: Array[Control] = []
	for n in find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not _keeps_touches(c):
			out.append(c)
	return out


## Controls that need the touch for themselves.
static func _keeps_touches(c: Control) -> bool:
	return c is BaseButton or c is Range or c is LineEdit or c is TextEdit or c is ScrollBar or c is ScrollContainer
