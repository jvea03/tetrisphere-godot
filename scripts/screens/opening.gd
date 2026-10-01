extends Control

## The first screen: the studio's splash, The Little Guy Games' logo, as in
## Duckdoku -- the same logo on the same pale blue, at the same share of the
## screen -- for a moment, then on. A brand-new player sees the crash cutscene
## next (the intro scene), which goes straight into level 1; everyone else
## goes through the loading screen (with the game's own logo) to Home. A tap
## skips the splash.

const SPLASH_SECONDS := 1.5
const INTRO := "res://scenes/intro.tscn"
const STUDIO_LOGO := "res://icons/company_logo.png"
const STUDIO_BG := Color(0.858824, 0.933333, 0.980392)   # Duckdoku's splash blue
const STUDIO_LOGO_PX := 390.0   # Duckdoku's 260 on its 480-wide screen, on our 720

var _advanced := false


func _ready() -> void:
	TSProfile.ensure_loaded()
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	var bg := ColorRect.new()
	bg.color = STUDIO_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var logo := TextureRect.new()
	logo.texture = load(STUDIO_LOGO)
	logo.custom_minimum_size = Vector2.ONE * STUDIO_LOGO_PX
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(logo)
	get_tree().create_timer(SPLASH_SECONDS).timeout.connect(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_advance()


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	if _wants_intro():
		SceneFlow.go(INTRO)
		return
	var first_launch := not TSProfile.tutorial_seen and TSProfile.last_level <= 1
	Loading.target_scene_path = SceneFlow.GAME if first_launch else SceneFlow.HOME
	SceneFlow.go("res://scenes/loading.tscn")


## A brand-new player, before level 1, who has not seen the crash cutscene.
func _wants_intro() -> bool:
	return not TSProfile.intro_seen and not TSProfile.tutorial_seen and TSProfile.last_level <= 1


## The game's name, Egg Escape: Puzzle Break: "Egg Escape" hand-lettered, each
## letter in its own pastel with a thick ink outline and tipped a little so it
## reads as drawn, not typeset; "Puzzle Break" under it, smaller.
class Logo extends VBoxContainer:
	const WORD := "Egg Escape"
	const TAGLINE := "Puzzle Break"

	static func make(px: int) -> Logo:
		var logo := Logo.new()
		logo.alignment = BoxContainer.ALIGNMENT_CENTER
		logo.add_theme_constant_override("separation", int(px * 0.05))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", -2)
		logo.add_child(row)
		var colors := [TSUI.PINK, TSUI.BUTTER, TSUI.MINT, TSUI.SKY, TSUI.LILAC, TSUI.PEACH]
		for i in WORD.length():
			if WORD[i] == " ":   # the gap between the words, not an outlined blank
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(px * 0.28, 0)
				row.add_child(gap)
				continue
			var l := TSUI.outlined(TSUI.label(WORD[i], px, colors[i % colors.size()], HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, int(px * 0.16))
			l.rotation = deg_to_rad(-6.0 if i % 2 == 0 else 5.0)
			l.pivot_offset = Vector2(px * 0.3, px * 0.6)
			row.add_child(l)
		var tagline := TSUI.outlined(TSUI.label(TAGLINE, int(px * 0.42), TSUI.INK.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER), Color.WHITE, int(px * 0.08))
		logo.add_child(tagline)
		return logo
