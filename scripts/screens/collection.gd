extends TSScreen

## The Collection (Duckdoku's CollectionScreen, with ducks as critters and
## ships as shells). A feature card shows the selected critter or shell, big,
## with its title, rarity, level stars and one button: Buy while locked,
## Upgrade while there is a level to gain, Max Level at the top. Tapping an
## owned critter makes it your avatar -- the one sealed in the egg -- and an
## owned shell becomes the egg's colours. Every level counts toward the
## collection level, and each collection level adds 1% to the coins a win pays.

const TILE := 120.0
const TUTORIAL_CRITTER := 5 # Blueberry: the Common one the walkthrough's gift buys

var _level_label: Label
var _bonus_label: Label
var _level_bar: ProgressBar
var _feature: VBoxContainer
var _feature_tile: Control
var _feature_btn: Button
var _tabs: PanelContainer
var _critter_grid: GridContainer
var _shell_grid: GridContainer
var _critter_scroll: ScrollContainer
var _shell_scroll: ScrollContainer
var _level_card: PanelContainer
var _info: Dictionary
var _tutorial: TSTutorial
var _shells := false
var _sel_critter := -1
var _sel_shell := -1
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

	_tabs = TSUI.tabs(["Critters", "Shells"], func(i: int):
		_shells = i == 1
		TSUI.style_tabs(_tabs, i)
		_refresh())
	content.add_child(_tabs)
	_critter_grid = _grid()
	_critter_scroll = TSUI.scroll(_critter_grid)
	content.add_child(_critter_scroll)
	_shell_grid = _grid()
	_shell_scroll = TSUI.scroll(_shell_grid)
	content.add_child(_shell_scroll)

	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("Your Collection", 40))
	ibox.add_child(TSUI.wrap(TSUI.label("Buy and upgrade critters and shells with coins. Every level you own counts toward your Collection level, and each Collection level adds +1% to the coins every win pays.\n\nTap a critter to make it yours: it's the one sealed in the egg. Tap a shell to paint the egg in its colours.", 22), 520))
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
	_bonus_label.text = "+%d%% coins" % TSProfile.collection_coin_bonus_percent()
	_level_bar.max_value = TSProfile.collection_points_for_level(lvl)
	_level_bar.value = TSProfile.collection_level_progress()
	if _sel_critter < 0:
		_sel_critter = TSProfile.avatar()
	if _sel_shell < 0:
		_sel_shell = TSProfile.equipped_shell
	_build_feature()
	_build_critters()
	_build_shells()
	_critter_scroll.visible = not _shells
	_shell_scroll.visible = _shells
	TSUI.juice(self)


# -- the feature card -------------------------------------------------------------------

func _build_feature() -> void:
	if _feature_btn.get_parent():
		_feature_btn.get_parent().remove_child(_feature_btn)
	for c in _feature.get_children():
		c.queue_free()
	var i := _sel_shell if _shells else _sel_critter
	var owned := TSProfile.is_shell_unlocked(i) if _shells else TSProfile.is_critter_unlocked(i)
	var rarity := TSProfile.shell_rarity(i) if _shells else TSProfile.critter_rarity(i)
	var row := TSUI.hbox(16)
	_feature.add_child(row)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(200, 200)
	var bg: Color = TSUI.CARD
	if owned:
		bg = (TSProfile.SHELLS[i]["cap"] if _shells else TSProfile.critter_color(i)).lerp(Color.WHITE, 0.55)
	var face := TSUI.sb(bg, 34, 6, 4, 8)
	face.border_color = TSUI.RARITY_COLORS[rarity]
	if not _shells and i == TSProfile.avatar() or _shells and i == TSProfile.equipped_shell:
		face.shadow_color = Color(TSUI.GOLD, 0.9)
		face.shadow_size = 8
	tile.add_theme_stylebox_override("panel", face)
	var art := TSIcon.make("egg" if _shells else "critter", 170, i)
	art.silhouette = not owned
	tile.add_child(art)
	row.add_child(tile)
	_feature_tile = tile
	var info := TSUI.vbox(8)
	TSUI.expand(info)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var name := TSProfile.shell_name(i) if _shells else TSProfile.critter_name(i)
	var level := TSProfile.shell_level_of(i) if _shells else TSProfile.critter_level_of(i)
	var max_level := TSProfile.SHELL_MAX_LEVEL if _shells else TSProfile.CRITTER_MAX_LEVEL
	if owned:
		name = TSProfile.progress_title(level, max_level, name)
	info.add_child(TSUI.wrap(TSUI.label(name, 32, TSUI.INK if owned else TSUI.MUTED)))
	var tags := TSUI.hbox(8)
	var pill := TSUI.pill(TSProfile.RARITY_NAMES[rarity].to_upper(), TSUI.RARITY_COLORS[rarity], 18)
	tags.add_child(pill)
	tags.add_child(TSUI.label("Lv %d/%d" % [level, max_level] if owned else "Locked", 22, TSFX.COL_GAIN if owned else TSUI.MUTED))
	info.add_child(tags)
	if owned:
		info.add_child(_stars(level, max_level, 26.0))
		var using := (_shells and i == TSProfile.equipped_shell) or (not _shells and i == TSProfile.avatar())
		info.add_child(TSUI.label("In your egg" if using else "Tap its tile to use it", 20, TSUI.MUTED))
	_refresh_feature_button(i, owned)
	_feature.add_child(_feature_btn)


func _refresh_feature_button(i: int, owned: bool) -> void:
	var cost := 0
	var maxed := false
	if not owned and not _shells and TSProfile.is_critter_pass_exclusive(i):
		_feature_btn.text = "Battle Pass reward"
	elif not owned:
		cost = TSProfile.shell_cost(i) if _shells else TSProfile.critter_unlock_cost(i)
		_feature_btn.text = "Buy  ·  %s coins" % TSProfile.fmt_coins(cost)
	elif TSProfile.is_shell_max_level(i) if _shells else TSProfile.is_critter_max_level(i):
		maxed = true
		_feature_btn.text = "Max Level"
	else:
		cost = TSProfile.shell_level_up_cost(i) if _shells else TSProfile.critter_level_up_cost(i)
		_feature_btn.text = "Upgrade  ·  %s coins" % TSProfile.fmt_coins(cost)
	_feature_btn.disabled = maxed or TSProfile.coin_count < cost


func _on_feature_pressed() -> void:
	var ok := false
	var before := TSProfile.collection_level()
	if _shells:
		ok = TSProfile.level_up_shell(_sel_shell) if TSProfile.is_shell_unlocked(_sel_shell) else TSProfile.unlock_shell(_sel_shell)
	else:
		if not TSProfile.is_critter_unlocked(_sel_critter) and TSProfile.is_critter_pass_exclusive(_sel_critter):
			SceneFlow.go("res://scenes/battle_pass.tscn")
			return
		ok = TSProfile.level_up_critter(_sel_critter) if TSProfile.is_critter_unlocked(_sel_critter) else TSProfile.unlock_critter(_sel_critter)
	if ok:
		TSSfx.play("upgrade")
		TSFX.sparkle_burst(self, _feature_tile)
	_refresh()
	if ok and TSProfile.collection_level() > before:
		_level_up_banner()
	if ok and not _shells and _sel_critter == TUTORIAL_CRITTER:
		_tutorial.gate_passed()


func _level_up_banner() -> void:
	var banner := TSUI.card(TSUI.CARD, 30, 24, 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.top_level = true
	banner.z_index = 80
	var v := TSUI.vbox(4)
	banner.add_child(v)
	v.add_child(TSUI.title("Collection Level %d!" % TSProfile.collection_level(), 42))
	v.add_child(TSUI.label("+%d%% coins on every win" % TSProfile.collection_coin_bonus_percent(), 26, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
		_critter_grid.add_child(_tile(i, false))


func _build_shells() -> void:
	for c in _shell_grid.get_children():
		c.queue_free()
	var order: Array = range(TSProfile.SHELL_COUNT)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _key(TSProfile.is_shell_unlocked(a), TSProfile.shell_rarity(a), TSProfile.shell_name(a)) < _key(TSProfile.is_shell_unlocked(b), TSProfile.shell_rarity(b), TSProfile.shell_name(b)))
	for i in order:
		_shell_grid.add_child(_tile(i, true))


func _tile(i: int, shell: bool) -> Control:
	var owned := TSProfile.is_shell_unlocked(i) if shell else TSProfile.is_critter_unlocked(i)
	var rarity := TSProfile.shell_rarity(i) if shell else TSProfile.critter_rarity(i)
	var v := TSUI.vbox(2)
	v.set_meta("index", i)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TILE, TILE)
	var bg: Color = TSUI.CARD
	if owned:
		bg = (TSProfile.SHELLS[i]["cap"] if shell else TSProfile.critter_color(i)).lerp(Color.WHITE, 0.55)
	var selected := i == (_sel_shell if shell else _sel_critter)
	var face := TSUI.sb(bg, 26, 5 if selected else 4, 3, 4)
	face.border_color = TSUI.INK if selected else TSUI.RARITY_COLORS[rarity]
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, face)
	var art := TSIcon.make("egg" if shell else "critter", TILE * 0.8, i)
	art.silhouette = not owned
	art.position = Vector2(TILE * 0.1, TILE * 0.1)
	art.size = Vector2(TILE * 0.8, TILE * 0.8)
	b.add_child(art)
	if owned:
		var lv := TSUI.pill("Lv %d" % (TSProfile.shell_level_of(i) if shell else TSProfile.critter_level_of(i)), TSUI.INK, 14, Color.WHITE)
		lv.position = Vector2(TILE - 60, 4)
		b.add_child(lv)
		if not shell and TSProfile.is_critter_new(i):
			var new_tag := TSUI.pill("NEW", TSUI.RED_DOT, 14, Color.WHITE)
			new_tag.position = Vector2(4, 4)
			b.add_child(new_tag)
	b.pressed.connect(func():
		if shell:
			_sel_shell = i
			if owned:
				TSProfile.equip_shell(i)
		else:
			_sel_critter = i
			TSProfile.clear_new_critters([i])
			if owned:
				TSProfile.set_avatar_critter(i)
		_refresh()
		if not shell and i == TUTORIAL_CRITTER:
			_tutorial.gate_passed())
	v.add_child(b)
	var name := TSUI.label(TSProfile.shell_name(i) if shell else TSProfile.critter_name(i), 18, TSUI.INK if owned else TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
	var steps := [{"rect": _feature.get_global_rect(), "text": "This is your Collection: critters and shells. They boost the coins you earn."}]
	if gift > 0:
		steps.append({"rect": wallet.get_global_rect(), "text": "Here's %s coins -- enough for your first critter." % TSProfile.fmt_coins(gift)})
	var buying := not TSProfile.is_critter_unlocked(TUTORIAL_CRITTER) and TSProfile.coin_count >= TSProfile.critter_unlock_cost(TUTORIAL_CRITTER)
	if buying:
		steps.append({"rect": func() -> Rect2: return _tile_rect(TUTORIAL_CRITTER), "text": "Tap Blueberry.", "gate": true})
		steps.append({"rect": func() -> Rect2: return _feature_btn.get_global_rect(), "text": "Tap Buy to adopt it.", "gate": true})
	steps.append({"rect": func() -> Rect2: return _feature.get_global_rect(), "text": "It's yours! Tap an owned critter to seal it in the egg, and upgrade it here." if buying else "Tap an owned critter to seal it in the egg, and upgrade it here."})
	steps.append({"rect": func() -> Rect2: return _level_card.get_global_rect(), "text": "Each Collection level adds +1% coins on every win."})
	steps.append({"rect": func() -> Rect2: return _tabs.get_global_rect(), "text": "Shells are on the next tab. They paint your egg, and count toward your level too."})
	_tutorial.start(steps)


func _tile_rect(i: int) -> Rect2:
	for t in _critter_grid.get_children():
		if t.get_meta("index", -1) == i:
			return (t as Control).get_global_rect()
	return _critter_grid.get_global_rect()
