extends TSScreen

## The Collection (Duckdoku's CollectionScreen, with ducks as critters). A
## feature card shows the selected critter, big, with its title, level stars
## and one button: Buy while locked, Upgrade while there is a level to gain,
## Max Level at the top; tapping an owned critter makes it your avatar -- the
## one sealed in the egg. Every critter level counts toward the collection
## level, and each collection level adds 1% to the materials a win pays. (The camp
## and the ship are built from their nodes on Home, and don't count.)

const TILE := 120.0
const TUTORIAL_CRITTER := 5 # Blueberry: the Common one the walkthrough's gift buys

var _level_label: Label
var _bonus_label: Label
var _level_bar: ProgressBar
var _feature: VBoxContainer
var _feature_tile: Control
var _feature_btn: Button
var _critter_grid: GridContainer
var _critter_scroll: ScrollContainer
var _level_card: PanelContainer
var _info: Dictionary
var _tutorial: TSTutorial
var _sel_critter := -1
var _last_coins := -1


func tab_id() -> String:
	return "collection"


func build() -> void:
	add_header("Collection", false, true, func(): TSUI.reveal(_info["root"], _info["panel"]))
	_level_card = TSUI.card(TSUI.CARD, 26, 14, 3)
	var lrow := TSUI.hbox(12)
	_level_card.add_child(lrow)
	lrow.add_child(TSIcon.make("star", 56))
	var lv := TSUI.vbox(4)
	TSUI.expand(lv)
	lrow.add_child(lv)
	var top := TSUI.hbox(8)
	_level_label = TSUI.label("", 28)
	TSUI.expand(_level_label)
	top.add_child(_level_label)
	_bonus_label = TSUI.label("", 24, TSFX.COL_GAIN)
	top.add_child(_bonus_label)
	lv.add_child(top)
	_level_bar = TSUI.bar(TSUI.GOLD, 22)
	lv.add_child(_level_bar)
	content.add_child(_level_card)

	_feature = TSUI.vbox(8)
	content.add_child(_feature)
	_feature_btn = TSUI.button("", TSUI.GREEN, 28, Vector2(0, 76))
	_feature_btn.pressed.connect(_on_feature_pressed)

	_critter_grid = _grid()
	_critter_scroll = TSUI.scroll(_critter_grid)
	content.add_child(_critter_scroll)

	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("Your Collection", 40))
	ibox.add_child(TSUI.wrap(TSUI.label("Buy and upgrade critters with coins. Every critter level counts toward your Collection level, and each Collection level adds +1% to the building materials every win pays (and fills the mine under the ship faster). Your Camp level adds +1% coins per level.\n\nTap a critter to make it yours: it's the one sealed in the egg. Your camp and ship are built on Home -- tap the plus signs at the crash site.", 22), 520))
	var ok := TSUI.button("Got it", TSUI.PINK, 26)
	ok.pressed.connect(func(): TSUI.conceal(_info["root"]))
	ibox.add_child(ok)
	_tutorial = TSTutorial.new()
	add_child(_tutorial)
	_refresh()
	_maybe_start_tutorial()


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 14)
	return g


func _refresh() -> void:
	if _last_coins >= 0 and TSProfile.coin_count != _last_coins:
		wallet.spend(_last_coins, TSProfile.coin_count)
	_last_coins = TSProfile.coin_count
	var lvl := TSProfile.collection_level()
	_level_label.text = "Collection Level %d" % lvl
	_bonus_label.text = "+%d%% materials" % TSProfile.collection_material_bonus_percent()
	_level_bar.max_value = TSProfile.collection_points_for_level(lvl)
	_level_bar.value = TSProfile.collection_level_progress()
	if _sel_critter < 0:
		_sel_critter = TSProfile.avatar()
	_build_feature()
	_build_critters()
	TSUI.juice(self)


# -- the feature card -------------------------------------------------------------------

func _build_feature() -> void:
	if _feature_btn.get_parent():
		_feature_btn.get_parent().remove_child(_feature_btn)
	for c in _feature.get_children():
		c.queue_free()
	_build_critter_feature(_sel_critter)
	_feature.add_child(_feature_btn)


func _build_critter_feature(i: int) -> void:
	var owned := TSProfile.is_critter_unlocked(i)
	var rarity := TSProfile.critter_rarity(i)
	var bg: Color = TSProfile.critter_color(i).lerp(Color.WHITE, 0.55) if owned else TSUI.CARD
	var info := _feature_row(bg, TSUI.RARITY_COLORS[rarity], i == TSProfile.avatar(), TSIcon.make("critter", 170, i), not owned)
	var level := TSProfile.critter_level_of(i)
	var name := TSProfile.critter_name(i)
	if owned:
		name = TSProfile.progress_title(level, TSProfile.CRITTER_MAX_LEVEL, name)
	info.add_child(TSUI.wrap(TSUI.label(name, 32, TSUI.INK if owned else TSUI.MUTED)))
	var tags := TSUI.hbox(8)
	tags.add_child(TSUI.pill(TSProfile.RARITY_NAMES[rarity].to_upper(), TSUI.RARITY_COLORS[rarity], 18))
	tags.add_child(TSUI.label("Lv %d/%d" % [level, TSProfile.CRITTER_MAX_LEVEL] if owned else "Locked", 22, TSFX.COL_GAIN if owned else TSUI.MUTED))
	info.add_child(tags)
	if owned:
		info.add_child(_stars(level, TSProfile.CRITTER_MAX_LEVEL, 26.0))
		info.add_child(TSUI.label("In your egg" if i == TSProfile.avatar() else "Tap its tile to use it", 20, TSUI.MUTED))
	var cost := 0
	var maxed := false
	if not owned and TSProfile.is_critter_pass_exclusive(i):
		_feature_btn.text = "Battle Pass reward"
	elif not owned:
		cost = TSProfile.critter_unlock_cost(i)
		_feature_btn.text = "Buy  ·  %s coins" % TSProfile.fmt_coins(cost)
	elif TSProfile.is_critter_max_level(i):
		maxed = true
		_feature_btn.text = "Max Level"
	else:
		cost = TSProfile.critter_level_up_cost(i)
		_feature_btn.text = "Upgrade  ·  %s coins" % TSProfile.fmt_coins(cost)
	_feature_btn.disabled = maxed or TSProfile.coin_count < cost


## The feature card's big tile and, beside it, the column the caller fills.
func _feature_row(bg: Color, border: Color, glow: bool, art: TSIcon, silhouette: bool) -> VBoxContainer:
	var row := TSUI.hbox(16)
	_feature.add_child(row)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(200, 200)
	var face := TSUI.sb(bg, 34, 6, 4, 8)
	face.border_color = border
	if glow:
		face.shadow_color = Color(TSUI.GOLD, 0.9)
		face.shadow_size = 8
	tile.add_theme_stylebox_override("panel", face)
	art.silhouette = silhouette
	tile.add_child(art)
	row.add_child(tile)
	_feature_tile = tile
	var info := TSUI.vbox(8)
	TSUI.expand(info)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	return info


func _on_feature_pressed() -> void:
	var before := TSProfile.collection_level()
	if not TSProfile.is_critter_unlocked(_sel_critter) and TSProfile.is_critter_pass_exclusive(_sel_critter):
		SceneFlow.go("res://scenes/battle_pass.tscn")
		return
	var ok := TSProfile.level_up_critter(_sel_critter) if TSProfile.is_critter_unlocked(_sel_critter) else TSProfile.unlock_critter(_sel_critter)
	if ok:
		TSSfx.play("upgrade")
		TSFX.sparkle_burst(self, _feature_tile)
	_refresh()
	if ok and TSProfile.collection_level() > before:
		_level_up_banner()
	if ok and _sel_critter == TUTORIAL_CRITTER:
		_tutorial.gate_passed()


func _level_up_banner() -> void:
	var banner := TSUI.card(TSUI.CARD, 30, 24, 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.top_level = true
	banner.z_index = 80
	var v := TSUI.vbox(4)
	banner.add_child(v)
	v.add_child(TSUI.title("Collection Level %d!" % TSProfile.collection_level(), 42))
	v.add_child(TSUI.label("+%d%% materials on every win" % TSProfile.collection_material_bonus_percent(), 26, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(banner)
	banner.reset_size()
	var area := get_viewport_rect().size
	banner.global_position = Vector2((area.x - banner.size.x) / 2.0, area.y * 0.36)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.5, 0.5)
	var t := banner.create_tween().set_parallel(true)
	t.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.8)
	t.chain().tween_property(banner, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(banner.queue_free)
	TSFX.confetti(self)
	TSHaptics.medium()


# -- grids -------------------------------------------------------------------------------

## Owned first, then by rarity, then A-Z.
static func _key(owned: bool, rarity: int, name: String) -> Array:
	return [0 if owned else 1, rarity, name.to_lower()]


func _build_critters() -> void:
	for c in _critter_grid.get_children():
		c.queue_free()
	var order: Array = range(TSProfile.CRITTER_COUNT)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _key(TSProfile.is_critter_unlocked(a), TSProfile.critter_rarity(a), TSProfile.critter_name(a)) < _key(TSProfile.is_critter_unlocked(b), TSProfile.critter_rarity(b), TSProfile.critter_name(b)))
	for i in order:
		_critter_grid.add_child(_tile(i))


func _tile(i: int) -> Control:
	var owned := TSProfile.is_critter_unlocked(i)
	var bg: Color = TSProfile.critter_color(i).lerp(Color.WHITE, 0.55) if owned else TSUI.CARD
	var selected := i == _sel_critter
	var b := _tile_button(bg, TSUI.INK if selected else TSUI.RARITY_COLORS[TSProfile.critter_rarity(i)], selected, TSIcon.make("critter", TILE * 0.8, i), not owned)
	if owned:
		_badge(b, "Lv %d" % TSProfile.critter_level_of(i), TSUI.INK, Vector2(TILE - 60, 4))
		if TSProfile.is_critter_new(i):
			_badge(b, "NEW", TSUI.RED_DOT, Vector2(4, 4))
	b.pressed.connect(func():
		_sel_critter = i
		TSProfile.clear_new_critters([i])
		if owned:
			TSProfile.set_avatar_critter(i)
		_refresh()
		if i == TUTORIAL_CRITTER:
			_tutorial.gate_passed())
	return _tile_column(b, i, TSProfile.critter_name(i), owned)


func _tile_button(bg: Color, border: Color, selected: bool, art: TSIcon, silhouette: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TILE, TILE)
	var face := TSUI.sb(bg, 26, 5 if selected else 4, 3, 4)
	face.border_color = border
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, face)
	art.silhouette = silhouette
	art.position = Vector2(TILE * 0.1, TILE * 0.1)
	art.size = Vector2(TILE * 0.8, TILE * 0.8)
	b.add_child(art)
	return b


func _badge(b: Button, text: String, colour: Color, at: Vector2) -> void:
	var pill := TSUI.pill(text, colour, 14, Color.WHITE)
	pill.position = at
	b.add_child(pill)


func _tile_column(b: Button, i: int, caption: String, bright: bool) -> Control:
	var v := TSUI.vbox(2)
	v.set_meta("index", i)
	v.add_child(b)
	var name := TSUI.label(caption, 18, TSUI.INK if bright else TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = TILE
	v.add_child(name)
	return v


## Five stars, one filled per fifth of the climb (all gold at max).
func _stars(level: int, max_level: int, size: float) -> Control:
	var row := TSUI.hbox(2)
	var filled := ceili(5.0 * level / max_level)
	for k in 5:
		var s := TSIcon.make("star", size)
		if k >= filled:
			s.tint = Color(0.86, 0.84, 0.84)
		row.add_child(s)
	return row


func _exit_tree() -> void:
	TSProfile.clear_new_critters()


# -- the walkthrough -----------------------------------------------------------------------

func _maybe_start_tutorial() -> void:
	if TSProfile.collection_tutorial_seen:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var before := TSProfile.coin_count
	var gift := TSProfile.claim_collection_gift()
	if gift > 0:
		wallet.receive(_feature.get_global_rect(), before, TSProfile.coin_count)
		_last_coins = TSProfile.coin_count
	_tutorial.finished.connect(func():
		TSProfile.collection_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	var steps := [{"rect": _feature.get_global_rect(), "text": "This is your Collection: your critters. Their levels boost the coins you earn."}]
	if gift > 0:
		steps.append({"rect": wallet.get_global_rect(), "text": "Here's %s coins -- enough for your first critter." % TSProfile.fmt_coins(gift)})
	var buying := not TSProfile.is_critter_unlocked(TUTORIAL_CRITTER) and TSProfile.coin_count >= TSProfile.critter_unlock_cost(TUTORIAL_CRITTER)
	if buying:
		steps.append({"rect": func() -> Rect2: return _tile_rect(TUTORIAL_CRITTER), "text": "Tap Blueberry.", "gate": true})
		steps.append({"rect": func() -> Rect2: return _feature_btn.get_global_rect(), "text": "Tap Buy to adopt it.", "gate": true})
	steps.append({"rect": func() -> Rect2: return _feature.get_global_rect(), "text": "It's yours! Tap an owned critter to seal it in the egg, and upgrade it here." if buying else "Tap an owned critter to seal it in the egg, and upgrade it here."})
	steps.append({"rect": func() -> Rect2: return _level_card.get_global_rect(), "text": "Each Collection level adds +1% building materials on every win."})
	_tutorial.start(steps)


func _tile_rect(i: int) -> Rect2:
	for t in _critter_grid.get_children():
		if t.get_meta("index", -1) == i:
			return (t as Control).get_global_rect()
	return _critter_grid.get_global_rect()
