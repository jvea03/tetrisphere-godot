class_name Loading
extends Control

## A loading screen: whoever comes here sets target_scene_path first. Loads it
## on a background thread with a progress bar, never for less than
## MIN_SECONDS so it does not just flash by. The screen is the game's key art
## -- the title over the pink ship of critters in space -- with the bar along
## the bottom, over its clouds. The art is fitted whole to the screen (see
## _layout_art), never cropped.

static var target_scene_path: String = ""

const MIN_SECONDS := 1.0
const ART := "res://icons/loading_screen.webp"
const BAR_FROM_BOTTOM := 70.0   # px above the phone's safe area

var _elapsed := 0.0
var _advanced := false
var _bar: ProgressBar
var _label: Label


var _art: TextureRect
var _fill: Array[TextureRect] = []   # the art's edge pixels, stretched over what it leaves bare


func _ready() -> void:
	# The whole key art always shows, title and all: it is fitted to the screen
	# (9:16 art), and a taller or wider screen gets the art's own edge pixels
	# stretched into the leftover space, so there is no seam.
	_art = TextureRect.new()
	_art.texture = load(ART)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:   # top, bottom, left, right
		var f := TextureRect.new()
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_SCALE
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(f)
		_fill.append(f)
	add_child(_art)
	_layout_art()
	get_viewport().size_changed.connect(_layout_art)
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


func _layout_art() -> void:
	var tex: Texture2D = _art.texture
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var vp := get_viewport_rect().size
	var s := minf(vp.x / tw, vp.y / th)
	var size := Vector2(tw, th) * s
	var at := ((vp - size) * 0.5).round()
	_art.position = at
	_art.size = size
	var rects := [
		[Rect2(0, 0, tw, 1), Rect2(at.x, 0, size.x, at.y)],                                     # top
		[Rect2(0, th - 1, tw, 1), Rect2(at.x, at.y + size.y, size.x, vp.y - at.y - size.y)],    # bottom
		[Rect2(0, 0, 1, th), Rect2(0, at.y, at.x, size.y)],                                     # left
		[Rect2(tw - 1, 0, 1, th), Rect2(at.x + size.x, at.y, vp.x - at.x - size.x, size.y)],    # right
	]
	for i in 4:
		var src: Rect2 = rects[i][0]
		var dst: Rect2 = rects[i][1]
		var f := _fill[i]
		f.visible = dst.size.x > 0.5 and dst.size.y > 0.5
		if f.visible:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = src
			f.texture = atlas
			f.position = dst.position
			f.size = dst.size


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
