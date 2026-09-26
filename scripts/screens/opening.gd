extends Control

## The branding splash: the hand-drawn logo and an egg, for a moment, then
## the loading screen. A brand-new player goes straight onto the ball (the
## Level 1 walkthrough); everyone else lands on Home. A tap skips it.

const SPLASH_SECONDS := 1.5

var _advanced := false


func _ready() -> void:
	TSProfile.ensure_loaded()
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	add_child(TSUI.paper_rect())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := TSUI.vbox(24)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	v.add_child(Logo.make(96))
	v.add_child(TSUI.spacer(24.0))   # room for the critter's ears under the tagline
	var egg := TSIcon.make("egg", 300, 0)
	egg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(egg)
	var critter := TSIcon.make("critter", 150, TSProfile.avatar())
	critter.position = Vector2(75, -40)
	egg.add_child(critter)
	egg.move_child(critter, 0)
	get_tree().create_timer(SPLASH_SECONDS).timeout.connect(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_advance()


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	var first_launch := not TSProfile.tutorial_seen and TSProfile.last_level <= 1
	Loading.target_scene_path = SceneFlow.GAME if first_launch else SceneFlow.HOME
	SceneFlow.go("res://scenes/loading.tscn")


## The game's name, EggBlok - Puzzle Break: "EggBlok" hand-lettered, each
## letter in its own pastel with a thick ink outline and tipped a little so it
## reads as drawn, not typeset; "Puzzle Break" under it, smaller.
class Logo extends VBoxContainer:
	const WORD := "EggBlok"
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
			var l := TSUI.outlined(TSUI.label(WORD[i], px, colors[i % colors.size()], HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, int(px * 0.16))
			l.rotation = deg_to_rad(-6.0 if i % 2 == 0 else 5.0)
			l.pivot_offset = Vector2(px * 0.3, px * 0.6)
			row.add_child(l)
		var tagline := TSUI.outlined(TSUI.label(TAGLINE, int(px * 0.42), TSUI.INK.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER), Color.WHITE, int(px * 0.08))
		logo.add_child(tagline)
		return logo
