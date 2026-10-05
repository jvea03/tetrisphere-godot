class_name TSScreen
extends Control

## Base for every menu screen: the paper background, a content column inside
## the safe area, an optional header (back arrow, title, info button), the
## bottom nav bar for the five tab screens, and the wallet. Subclasses build
## their content in build() into `content`.

## The five tabs, left to right; a tab slides in from the side it sits on.
const TABS := [
	{"id": "collection", "icon": "collection", "label": "Collection", "scene": "res://scenes/collection.tscn"},
	{"id": "shop", "icon": "shop", "label": "Shop", "scene": "res://scenes/shop.tscn"},
	{"id": "home", "icon": "home", "label": "Home", "scene": "res://scenes/home.tscn"},
	{"id": "leaderboard", "icon": "trophy", "label": "Ranks", "scene": "res://scenes/leaderboard.tscn"},
	{"id": "clubs", "icon": "clubs", "label": "Clubs", "scene": "res://scenes/clubs.tscn"},
]
const NAV_HEIGHT := 128.0

var content: VBoxContainer # the column screens fill
var header_row: HBoxContainer
var wallet: TSCoinPill
var nav: Control


func _ready() -> void:
	TSProfile.ensure_loaded()
	TSSfx.ensure_buses()
	add_child(TSUI.paper_rect())
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20 + int(TSUI.safe_top()))
	margin.add_theme_constant_override("margin_bottom", 20 + int(TSUI.safe_bottom()) + (int(NAV_HEIGHT) if tab_id() != "" else 0))
	add_child(margin)
	content = TSUI.vbox(16)
	margin.add_child(content)
	if tab_id() != "":
		_build_nav()
	build()
	TSUI.juice(self)


## Which nav tab this screen is ("" for a screen without the nav bar).
func tab_id() -> String:
	return ""


func build() -> void:
	pass


## A header: back arrow (or nothing), the title, then the wallet and/or an
## info button on the right.
func add_header(title_text: String, back: bool, with_wallet := true, info: Callable = Callable()) -> HBoxContainer:
	header_row = TSUI.hbox(12)
	content.add_child(header_row)
	if back:
		var b := TSUI.icon_button("back", 76, TSUI.SKY)
		b.pressed.connect(go_home)
		header_row.add_child(b)
	var t := TSUI.title(title_text, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if back else HORIZONTAL_ALIGNMENT_LEFT
	TSUI.expand(t)
	# A long title ("7-Day Eggsperience") shrinks to fit beside the buttons
	# rather than pushing the screen wider than the phone.
	t.clip_text = true
	t.resized.connect(_fit_title.bind(t))
	header_row.add_child(t)
	if with_wallet:
		wallet = TSCoinPill.new()
		header_row.add_child(wallet)
	if info.is_valid():
		var i := TSUI.icon_button("info", 68, TSUI.CARD)
		i.pressed.connect(info)
		header_row.add_child(i)
	return header_row


## The biggest title size, up to 44, whose text fits the label's width.
func _fit_title(t: Label) -> void:
	var font := t.get_theme_font("font")
	var outline := t.get_theme_constant("outline_size")
	var fs := 44
	while fs > 26 and font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + outline > t.size.x:
		fs -= 2
	if t.get_theme_font_size("font_size") != fs:
		t.add_theme_font_size_override("font_size", fs)


func go_home() -> void:
	SceneFlow.go(SceneFlow.HOME)


func _build_nav() -> void:
	nav = PanelContainer.new()
	nav.name = "NavBar"
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_left = 12
	nav.offset_right = -12
	nav.offset_top = -NAV_HEIGHT - 8 - TSUI.safe_bottom()
	nav.offset_bottom = -8 - TSUI.safe_bottom()
	nav.add_theme_stylebox_override("panel", TSUI.sb(TSUI.CARD, 34, 3, 5, 8))
	add_child(nav)
	var row := TSUI.hbox(4)
	nav.add_child(row)
	var mine := _tab_index(tab_id())
	for i in TABS.size():
		var tab: Dictionary = TABS[i]
		var active := i == mine
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, NAV_HEIGHT - 26)
		var face := TSUI.sb(TSUI.PINK if active else Color(0, 0, 0, 0), 26, 3 if active else 0, 3 if active else 0, 2)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, face)
		var v := TSUI.vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := TSIcon.make(tab["icon"], 58 if active else 50)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(TSUI.label(tab["label"], 19 if active else 17, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(b)
		if active:
			continue
		var dir := signi(i - mine)
		var go := func(): SceneFlow.slide(tab["scene"], dir)
		match tab["id"]:
			"collection":
				TSNav.gate(b, TSNav.collection_unlocked(), TSNav.COLLECTION_UNLOCK_LEVEL, self, go)
			"leaderboard":
				TSNav.gate_social(b, true, 0, self, go)
			"clubs":
				TSNav.gate_social(b, TSNav.clubs_unlocked(), TSNav.CLUBS_UNLOCK_LEVEL, self, go)
			_:
				b.pressed.connect(go)


static func _tab_index(id: String) -> int:
	for i in TABS.size():
		if TABS[i]["id"] == id:
			return i
	return -1
