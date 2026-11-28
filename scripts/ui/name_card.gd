class_name TSNameCard
extends RefCounted

## "Choose your name", for the leaderboards. Forced as they unlock (Save only:
## TSProfile.must_name -- Home and Ranks show it until a name is saved); for a
## player already past the unlock and still under the default name, offered the
## first time they open Ranks, with "Later". The card sits high on the screen,
## clear of the phone keyboard.

const META := "name_card"


## True while `screen` has the card up.
static func is_open(screen: Control) -> bool:
	return screen.has_meta(META) and is_instance_valid(screen.get_meta(META))


## Closes an offered card (Android back). False if there is none, or it is forced.
static func close_offered(screen: Control) -> bool:
	if not is_open(screen):
		return false
	var root: Control = screen.get_meta(META)
	if bool(root.get_meta("forced")):
		return false
	(root.get_meta("finish") as Callable).call()
	return true


## Shows the card on `screen`; done() once it closes (a name saved, or Later).
## Returns its parts (root, edit, save, later -- null when forced, error).
static func open(screen: Control, forced: bool, done := Callable()) -> Dictionary:
	var card := TSUI.dialog(screen, 580)
	var root: Control = card["root"]
	screen.set_meta(META, root)
	root.set_meta("forced", forced)
	(root.get_child(1) as Control).anchor_bottom = 0.62   # the keyboard covers the foot of the screen
	var box: VBoxContainer = card["box"]
	box.add_child(TSUI.title("Choose your name", 40))
	box.add_child(TSUI.halo(TSIcon.make("critter", 110, TSProfile.avatar()), 160.0, TSUI.BUTTER, false))
	box.add_child(TSUI.wrap(TSUI.label("This is how other players see you on the leaderboards.", 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER), 500))
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
	root.set_meta("finish", finish)
	var save := TSUI.button("Save", TSUI.GREEN, 30)
	var submit := func() -> void:
		var problem := TSProfile.choose_name(edit.text)
		if problem == "":
			TSSfx.play("ding")
			finish.call()
			return
		error.text = problem
		error.visible = true
	save.pressed.connect(submit)
	edit.text_submitted.connect(func(_text: String) -> void: submit.call())
	box.add_child(save)
	var later: Button = null
	if not forced:
		later = TSUI.button("Later", TSUI.SKY, 24, Vector2(0, 60))
		later.pressed.connect(finish)
		box.add_child(later)
	TSUI.juice(root)
	TSUI.reveal(root, card["panel"])
	return {"root": root, "edit": edit, "save": save, "later": later, "error": error}
