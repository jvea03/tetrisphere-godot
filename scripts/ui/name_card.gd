class_name TSNameCard
extends RefCounted

## "Choose your name", for the leaderboards: anyone on them without a name of
## their own gets it, on Home and on Ranks, until one is saved
## (TSProfile.must_name). Names are unique, checked with the server
## (choose_name); offline there is "Not now" until the next run. The card sits
## high on the screen, clear of the phone keyboard.

const META := "name_card"


## True while `screen` has the card up.
static func is_open(screen: Control) -> bool:
	return screen.has_meta(META) and is_instance_valid(screen.get_meta(META))


## Shows the card on `screen`; done() once it closes. Returns its parts (root,
## edit, save, skip, error).
static func open(screen: Control, done := Callable()) -> Dictionary:
	var card := TSUI.dialog(screen, 580)
	var root: Control = card["root"]
	screen.set_meta(META, root)
	(root.get_child(1) as Control).anchor_bottom = 0.62   # the keyboard covers the foot of the screen
	var box: VBoxContainer = card["box"]
	box.add_child(TSUI.title("Choose your name", 40))
	box.add_child(TSUI.halo(TSIcon.make("critter", 110, TSProfile.avatar()), 160.0, TSUI.BUTTER, false))
	var why := "This is how other players see you on the leaderboards. No two players share a name."
	if TSProfile.name_taken:
		why = "Somebody else already has \"%s\". Choose another name for the leaderboards." % TSProfile.player_name
		if TSProfile.name_blocked(TSProfile.player_name):
			why = "\"%s\" can't be used on the leaderboards. Choose another name." % TSProfile.player_name
	box.add_child(TSUI.wrap(TSUI.label(why, 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER), 500))
	var edit := LineEdit.new()
	edit.max_length = TSProfile.NAME_MAX_LENGTH
	edit.placeholder_text = "Your name"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 68)
	edit.add_theme_font_override("font", TSToon.hand_font())
	edit.add_theme_font_size_override("font_size", 30)
	edit.add_theme_color_override("font_color", TSUI.INK)
	edit.add_theme_color_override("font_placeholder_color", TSUI.MUTED)
	edit.add_theme_stylebox_override("normal", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	edit.add_theme_stylebox_override("focus", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	box.add_child(edit)
	var error := TSUI.wrap(TSUI.label("", 20, Color(0.8, 0.2, 0.25), HORIZONTAL_ALIGNMENT_CENTER), 500)
	error.visible = false
	box.add_child(error)
	var finish := func() -> void:
		if root.get_meta("closed", false):
			return
		root.set_meta("closed", true)
		screen.remove_meta(META)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		TSUI.conceal(root)
		root.get_tree().create_timer(TSUI.REVEAL_SECONDS + 0.05).timeout.connect(root.queue_free)
		if done.is_valid():
			done.call()
	var save := TSUI.button("Save", TSUI.GREEN, 30)
	var skip := TSUI.button("Not now", TSUI.SKY, 24, Vector2(0, 60))
	skip.visible = false   # only once a name couldn't be checked: nobody is locked out offline
	skip.pressed.connect(func() -> void:
		TSProfile.name_later = true
		finish.call())
	var submit := func() -> void:
		if save.disabled:
			return
		save.disabled = true
		error.add_theme_color_override("font_color", TSUI.MUTED)
		error.text = "Checking..."
		error.visible = true
		TSProfile.choose_name(edit.text, func(problem: String) -> void:
			if not is_instance_valid(root):
				return
			save.disabled = false
			if problem == "":
				TSSfx.play("ding")
				finish.call()
				return
			error.add_theme_color_override("font_color", Color(0.8, 0.2, 0.25))
			error.text = problem
			error.visible = true
			if problem == TSProfile.NAME_OFFLINE:
				skip.visible = true)
	save.pressed.connect(submit)
	edit.text_submitted.connect(func(_text: String) -> void: submit.call())
	box.add_child(save)
	box.add_child(skip)
	TSUI.juice(root)
	TSUI.reveal(root, card["panel"])
	return {"root": root, "edit": edit, "save": save, "skip": skip, "error": error}
