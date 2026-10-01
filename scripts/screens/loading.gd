class_name Loading
extends Control

## A loading screen: whoever comes here sets target_scene_path first. Loads it
## on a background thread with a progress bar, never for less than
## MIN_SECONDS so it does not just flash by. The screen is the game's key art
## -- the title over the pink ship of critters in space -- with the bar along
## the bottom, over its clouds.

static var target_scene_path: String = ""

const MIN_SECONDS := 1.0
const ART := "res://icons/loading_screen.webp"
const BAR_FROM_BOTTOM := 70.0   # px above the phone's safe area

var _elapsed := 0.0
var _advanced := false
var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	# The art fills the screen whatever its shape (it is 9:16, as the game is);
	# a taller phone trims a little off its sides.
	var art := TextureRect.new()
	art.texture = load(ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var bottom := TSUI.vbox(10)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.offset_bottom = -(TSUI.safe_bottom() + BAR_FROM_BOTTOM)
	add_child(bottom)
	_bar = TSUI.bar(TSUI.PINK, 34)
	_bar.custom_minimum_size.x = 440
	_bar.max_value = 1.0
	_bar.step = 0.0
	bottom.add_child(_bar)
	_label = TSUI.outlined(TSUI.label("Loading", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, 10)
	bottom.add_child(_label)
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
