extends TSScreen

## The Collection (Duckdoku's CollectionScreen, with ducks as critters and
## ships as the crash site: a camp to build and the crashed spaceship to fix).
## A feature card shows the selected critter, camp spot or ship part, big,
## with its title, level stars and one button. Critters: Buy while locked,
## Upgrade while there is a level to gain, Max Level at the top; tapping an
## owned critter makes it your avatar -- the one sealed in the egg. Camp spots
## and ship parts start broken: Build or Fix, then Upgrade up to Max Level,
## and every step shows at the crash site on Home. The camp comes first: the
## ship waits until every camp spot is done. Every level counts toward the
## collection level, and each collection level adds 1% to the coins a win
## pays.

const TILE := 120.0
const TUTORIAL_CRITTER := 5 # Blueberry: the Common one the walkthrough's gift buys
const BROKEN_TINT := Color(0.86, 0.84, 0.86)   # a broken part's tile
const SHIP_PINK := Color(1.0, 0.74, 0.82)       # a fixed part's tile

var _level_label: Label
var _bonus_label: Label
var _level_bar: ProgressBar
var _feature: VBoxContainer
var _feature_tile: Control
var _feature_btn: Button
var _tabs: PanelContainer
var _critter_grid: GridContainer
var _part_grid: GridContainer
var _critter_scroll: ScrollContainer
var _part_scroll: ScrollContainer
var _level_card: PanelContainer
var _info: Dictionary
var _tutorial: TSTutorial
var _tab := 0             # 0 critters, 1 the camp, 2 the ship
var _sel_critter := -1
var _sel_part := {"camp": -1, "ship": -1}   # the selected spot on each tab
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

	_tabs = TSUI.tabs(["Critters", "Camp", "Ship"], func(i: int):
		_tab = i
		TSUI.style_tabs(_tabs, i)
		_refresh())
	content.add_child(_tabs)
	_critter_grid = _grid()
	_critter_scroll = TSUI.scroll(_critter_grid)
	content.add_child(_critter_scroll)
	_part_grid = _grid()
	_part_scroll = TSUI.scroll(_part_grid)
	content.add_child(_part_scroll)

	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("Your Collection", 40))
	ibox.add_child(TSUI.wrap(TSUI.label("Buy and upgrade critters with coins, build up your camp, then fix and upgrade your crashed ship. Every level counts toward your Collection level, and each Collection level adds +1% to the coins every win pays.\n\nTap a critter to make it yours: it's the one sealed in the egg. Everything you build, fix or upgrade shows at the crash site on Home. Finish the camp first -- the ship opens once every camp spot is fully upgraded.", 22), 520))
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
	for group in ["camp", "ship"]:
		if int(_sel_part[group]) < 0:
			_sel_part[group] = _first_unfinished(group)
	_build_feature()
	_build_critters()
	_build_parts()
	_critter_scroll.visible = _tab == 0
	_part_scroll.visible = _tab != 0
	TSUI.juice(self)


## The tab's group of parts: "camp" or "ship".
func _group() -> String:
	return "ship" if _tab == 2 else "camp"


## The first spot in a group still to be built or fixed, else the first one.
static func _first_unfinished(group: String) -> int:
	var first := -1
	for i in TSProfile.PART_COUNT:
		if str(TSProfile.PARTS[i]["group"]) != group:
			continue
		if first < 0:
			first = i
		if not TSProfile.is_part_fixed(i):
			return i
	return first


# -- the feature card -------------------------------------------------------------------

func _build_feature() -> void:
	if _feature_btn.get_parent():
		_feature_btn.get_parent().remove_child(_feature_btn)
	for c in _feature.get_children():
		c.queue_free()
	if _tab != 0:
		_build_part_feature(int(_sel_part[_group()]))
	else:
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


## A camp spot or ship part: broken, or built / fixed at some stage, what the
## next step adds, and the Build / Fix / Upgrade button. Ship parts wait for
## the camp to be finished.
func _build_part_feature(i: int) -> void:
	var level := TSProfile.part_level_of(i)
	var fixed := level >= 1
	var camp := TSProfile.is_camp(i)
	var art := TSIcon.make("part", 170, i, "" if fixed else "broken")
	var info := _feature_row(SHIP_PINK.lerp(Color.WHITE, 0.55) if fixed else BROKEN_TINT, TSUI.INK if fixed else TSUI.RED_DOT, false, art, false)
	info.add_child(TSUI.wrap(TSUI.label(TSProfile.part_name(i), 32)))
	var tags := TSUI.hbox(8)
	if fixed:
		tags.add_child(TSUI.pill(TSProfile.part_stage(i, level).to_upper(), TSUI.SKY, 18))
	else:
		tags.add_child(TSUI.pill("UNBUILT" if camp else "BROKEN", TSUI.RED_DOT, 18, Color.WHITE))
	info.add_child(tags)
	if not camp and TSProfile.is_ship_ready():
		var when := "Launch it now from Home!" if TSProfile.can_launch() else ("Launched this season." if TSProfile.has_launched_this_season() else "It can launch at the season's end, in %d days." % TSProfile.days_to_launch_window())
		info.add_child(TSUI.wrap(TSUI.label("Ship ready! " + when, 20, TSFX.COL_GAIN)))
	if fixed:
		info.add_child(TSUI.label("Lv %d/%d" % [level, TSProfile.PART_MAX_LEVEL], 22, TSFX.COL_GAIN))
		info.add_child(_stars(level, TSProfile.PART_MAX_LEVEL, 26.0))
	else:
		var why := "build it to make camp more homely" if camp else "fix it to get your ship flying again"
		info.add_child(TSUI.wrap(TSUI.label("%s -- %s." % [TSProfile.part_stage(i, 0), why], 20, TSUI.MUTED)))
	if TSProfile.is_part_max_level(i):
		info.add_child(TSUI.label("Fully upgraded!", 20, TSUI.MUTED))
		_feature_btn.text = "Max Level"
		_feature_btn.disabled = true
		return
	if not TSProfile.is_part_available(i):
		info.add_child(TSUI.wrap(TSUI.label("Finish the camp first: every camp spot to Lv %d." % TSProfile.CAMP_LEVEL_FOR_SHIP, 20, TSUI.MUTED)))
		_feature_btn.text = "Camp first  ·  %d/%d done" % [TSProfile.camp_spots_done(), TSProfile.camp_spot_count()]
		_feature_btn.disabled = true
		return
	if fixed:
		info.add_child(TSUI.wrap(TSUI.label("Next: " + TSProfile.part_stage(i, level + 1), 20, TSUI.MUTED)))
	var cost := TSProfile.part_next_cost(i)
	var verb := "Upgrade" if fixed else ("Build" if camp else "Fix")
	_feature_btn.text = "%s  ·  %s coins" % [verb, TSProfile.fmt_coins(cost)]
	_feature_btn.disabled = TSProfile.coin_count < cost


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
	var ok := false
	var before := TSProfile.collection_level()
	if _tab != 0:
		ok = TSProfile.improve_part(int(_sel_part[_group()]))
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
	if ok and _tab == 0 and _sel_critter == TUTORIAL_CRITTER:
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
		_critter_grid.add_child(_tile(i))


## The tab's camp spots or ship parts, in a fixed order.
func _build_parts() -> void:
	for c in _part_grid.get_children():
		c.queue_free()
	for i in TSProfile.PART_COUNT:
		if str(TSProfile.PARTS[i]["group"]) == _group():
			_part_grid.add_child(_part_tile(i))


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


func _part_tile(i: int) -> Control:
	var level := TSProfile.part_level_of(i)
	var fixed := level >= 1
	var selected := i == int(_sel_part[_group()])
	var open := TSProfile.is_part_available(i)
	var art := TSIcon.make("part", TILE * 0.8, i, "" if fixed else "broken")
	var b := _tile_button(SHIP_PINK.lerp(Color.WHITE, 0.55) if fixed else BROKEN_TINT, TSUI.INK if selected else (TSUI.GREY if fixed or not open else TSUI.RED_DOT), selected, art, false)
	if fixed:
		_badge(b, "Lv %d" % level, TSUI.INK, Vector2(TILE - 60, 4))
	elif not open:
		var lock := TSIcon.make("lock", 34)
		lock.position = Vector2(4, 4)
		lock.size = Vector2(34, 34)
		b.add_child(lock)
	else:
		_badge(b, "BUILD" if TSProfile.is_camp(i) else "FIX", TSUI.RED_DOT, Vector2(4, 4))
	b.pressed.connect(func():
		_sel_part[_group()] = i
		_refresh())
	return _tile_column(b, i, TSProfile.part_name(i), true)


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
	var steps := [{"rect": _feature.get_global_rect(), "text": "This is your Collection: critters, your camp and your ship. They boost the coins you earn."}]
	if gift > 0:
		steps.append({"rect": wallet.get_global_rect(), "text": "Here's %s coins -- enough for your first critter." % TSProfile.fmt_coins(gift)})
	var buying := not TSProfile.is_critter_unlocked(TUTORIAL_CRITTER) and TSProfile.coin_count >= TSProfile.critter_unlock_cost(TUTORIAL_CRITTER)
	if buying:
		steps.append({"rect": func() -> Rect2: return _tile_rect(TUTORIAL_CRITTER), "text": "Tap Blueberry.", "gate": true})
		steps.append({"rect": func() -> Rect2: return _feature_btn.get_global_rect(), "text": "Tap Buy to adopt it.", "gate": true})
	steps.append({"rect": func() -> Rect2: return _feature.get_global_rect(), "text": "It's yours! Tap an owned critter to seal it in the egg, and upgrade it here." if buying else "Tap an owned critter to seal it in the egg, and upgrade it here."})
	steps.append({"rect": func() -> Rect2: return _level_card.get_global_rect(), "text": "Each Collection level adds +1% coins on every win."})
	steps.append({"rect": func() -> Rect2: return _tabs.get_global_rect(), "text": "Build up your camp on the next tab, then fix your crashed ship on the one after. Everything shows at Home, and counts toward your level too."})
	_tutorial.start(steps)


func _tile_rect(i: int) -> Rect2:
	for t in _critter_grid.get_children():
		if t.get_meta("index", -1) == i:
			return (t as Control).get_global_rect()
	return _critter_grid.get_global_rect()
