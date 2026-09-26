class_name Loading
extends Control

## A loading screen: whoever comes here sets target_scene_path first. Loads it
## on a background thread with a progress bar, never for less than
## MIN_SECONDS so it does not just flash by.

static var target_scene_path: String = ""

const MIN_SECONDS := 1.0

var _elapsed := 0.0
var _advanced := false
var _bar: ProgressBar
var _label: Label
var _egg: TSIcon


func _ready() -> void:
	add_child(TSUI.paper_rect())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := TSUI.vbox(28)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var logo := preload("res://scripts/screens/opening.gd").Logo.make(80)
	v.add_child(logo)
	v.add_child(TSUI.spacer(12.0))
	_egg = TSIcon.make("egg", 220, TSProfile.equipped_shell)
	_egg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_egg)
	_bar = TSUI.bar(TSUI.PINK, 34)
	_bar.custom_minimum_size.x = 440
	_bar.max_value = 1.0
	_bar.step = 0.0
	v.add_child(_bar)
	_label = TSUI.label("Loading", 30, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_label)
	# the egg wobbles while it waits
	_egg.pivot_offset = Vector2(110, 200)
	var t := _egg.create_tween().set_loops()
	t.tween_property(_egg, "rotation", 0.12, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_egg, "rotation", -0.12, 0.4).set_trans(Tween.TRANS_SINE)
	if target_scene_path == "":
		target_scene_path = SceneFlow.HOME
	ResourceLoader.load_threaded_request(target_scene_path)


func _process(delta: float) -> void:
	if _advanced:
		return
	_elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	var loaded: float = progress[0] if progress.size() > 0 else 0.0
	_bar.value = minf(loaded, clampf(_elapsed / MIN_SECONDS, 0.0, 1.0))
	_label.text = "Loading" + ".".repeat(int(_elapsed * 3.0) % 4)
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		_advanced = true
		SceneFlow.go(target_scene_path)
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_SECONDS:
		_advanced = true
		SceneFlow.go_packed(ResourceLoader.load_threaded_get(target_scene_path))
