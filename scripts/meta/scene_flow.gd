extends CanvasLayer

## Autoload "SceneFlow" (Duckdoku's SceneTransition): every scene change
## fades out to paper and back, and the bottom tabs slide between screens
## instead. Call SceneFlow.go(path) / go_packed(packed) / slide(path, dir)
## instead of changing scenes directly.

const FADE_SECONDS := 0.16
const SLIDE_SECONDS := 0.25

const HOME := "res://scenes/home.tscn"
const GAME := "res://main.tscn"

var fade_rect: ColorRect
var in_flight := false
var _music_scene: Node   # the screen the music was last set for
const QUIET_SCREENS := ["res://scenes/opening.tscn", "res://scenes/loading.tscn"]


## The menu song plays on every menu screen and the level songs in a level
## (the game screen is the only 3D one), and over the crash cutscene. The
## screens on the way in -- the studio splash and the loading screen -- are
## quiet, so the menu song starts as the main menu (or the cutscene) appears.
func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _music_scene:
		_music_scene = scene
		if scene == null:
			return
		if scene is Node3D:
			TSSfx.music("level")
		elif QUIET_SCREENS.has(scene.scene_file_path):
			TSSfx.music("")
		else:
			TSSfx.music("menu")


## Android back button: the current screen gets first refusal through an
## optional on_back_requested() -> bool (close a pop-up, park the ball...);
## otherwise any screen goes back to Home, and Home itself quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()


func _handle_back() -> void:
	if in_flight:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("on_back_requested") and scene.call("on_back_requested"):
		return
	if scene.scene_file_path == HOME:
		get_tree().quit()
		return
	if scene.scene_file_path.ends_with("loading.tscn") or scene.scene_file_path.ends_with("opening.tscn"):
		return
	go(HOME)


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect = ColorRect.new()
	fade_rect.color = TSToon.PAPER
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)


func go(path: String) -> void:
	if in_flight:
		return
	in_flight = true
	await _fade(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade(0.0)
	in_flight = false


func go_packed(packed: PackedScene) -> void:
	if in_flight:
		return
	in_flight = true
	await _fade(1.0)
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await _fade(0.0)
	in_flight = false


## Blocks input while the screen is covered, so a tap cannot land mid-swap.
func _fade(target_alpha: float) -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", target_alpha, FADE_SECONDS)
	await tween.finished
	if target_alpha <= 0.0:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Slides to a tab's screen: direction > 0 brings it in from the right (a tab
## further right), < 0 from the left. The nav bar (the node named "NavBar")
## stays still -- a frozen crop of it sits over the moving screens.
func slide(path: String, direction: int) -> void:
	if in_flight:
		return
	var root := get_tree().root
	var screen := root.get_visible_rect().size
	var dir := float(signi(direction)) if direction != 0 else 1.0
	in_flight = true
	await RenderingServer.frame_post_draw
	var snapshot := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var old_scene := get_tree().current_scene
	var nav: Control = old_scene.find_child("NavBar", true, false) as Control if old_scene else null
	var nav_y: float = nav.get_global_rect().position.y if nav else -1.0
	var tex_scale := Vector2(snapshot.get_width(), snapshot.get_height()) / screen

	var overlay := CanvasLayer.new()
	overlay.layer = 129
	root.add_child(overlay)
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(blocker)
	var old_rect := TextureRect.new()
	old_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.add_child(old_rect)
	if nav_y >= 0.0:
		var content := AtlasTexture.new()
		content.atlas = snapshot
		content.region = Rect2(Vector2.ZERO, Vector2(screen.x, nav_y) * tex_scale)
		old_rect.texture = content
		old_rect.position = Vector2.ZERO
		old_rect.size = Vector2(screen.x, nav_y)
		var bar := AtlasTexture.new()
		bar.atlas = snapshot
		bar.region = Rect2(Vector2(0.0, nav_y) * tex_scale, Vector2(screen.x, screen.y - nav_y) * tex_scale)
		var bar_rect := TextureRect.new()
		bar_rect.texture = bar
		bar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar_rect.position = Vector2(0.0, nav_y)
		bar_rect.size = Vector2(screen.x, screen.y - nav_y)
		bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar_rect)
	else:
		old_rect.texture = snapshot
		old_rect.size = screen

	var new_scene: Node = (load(path) as PackedScene).instantiate()
	var new_ctrl := new_scene as Control
	if new_ctrl:
		new_ctrl.position.x = screen.x * dir
	root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if old_scene:
		old_scene.queue_free()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old_rect, "position:x", -screen.x * dir, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if new_ctrl:
		tween.tween_property(new_ctrl, "position:x", 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	overlay.queue_free()
	in_flight = false
