extends TSScreen

## The Collection (Duckdoku's CollectionScreen, with ducks as critters). A
## feature card shows the selected critter, big, with its title, level stars
## and one button: Buy while locked, Upgrade while there is a level to gain,
## Max Level at the top; tapping an owned critter makes it your avatar -- the
## one sealed in the egg. Every critter level counts toward the collection
## level, and each collection level adds 1% to the materials a win pays. (The camp
## and the ship are built from their nodes on Home, and don't count.)

const TILE := 118.0
const COLUMNS := 5
const TUTORIAL_CRITTER := 5 # Grad: the Common one the walkthrough's gift buys

var _level_label: Label
var _bonus_label: Label
var _level_bar: ProgressBar
var _feature: VBoxContainer
var _feature_tile: Control
var _feature_btn: Button
var _owned_grid: GridContainer   # the critters you have
var _locked_grid: GridContainer  # and the ones still to collect
var _owned_head: Label
var _locked_head: Label
var _count_label: Label
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
	_count_label = TSUI.label("", 18, TSUI.MUTED)
	lv.add_child(_count_label)
	content.add_child(_level_card)

	# The selected critter on its stage, its button underneath, in one card.
	var feature_card := TSUI.card(TSUI.CARD, 30, 14, 4)
	content.add_child(feature_card)
	_feature = TSUI.vbox(12)
	feature_card.add_child(_feature)
	_feature_btn = TSUI.button("", TSUI.GREEN, 28, Vector2(0, 72))
	_feature_btn.pressed.connect(_on_feature_pressed)

	# Every critter: yours first, then the ones still to collect.
	var lists := TSUI.vbox(10)
	_owned_head = _section(lists, TSUI.MINT)
	_owned_grid = _grid()
	lists.add_child(_owned_grid)
	lists.add_child(TSUI.spacer(6))
	_locked_head = _section(lists, TSUI.GREY)
	_locked_grid = _grid()
	lists.add_child(_locked_grid)
	lists.add_child(TSUI.spacer(10))
	_critter_scroll = TSUI.scroll(lists)
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
	g.columns = COLUMNS
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	return g


## A section's heading: a pill with its name and count, a rule running on.
func _section(parent: Control, colour: Color) -> Label:
	var row := TSUI.hbox(10)
	parent.add_child(row)
	var pill := TSUI.pill("", colour, 20)
	row.add_child(pill)
	var rule := ColorRect.new()
	rule.color = Color(TSUI.INK, 0.15)
	rule.custom_minimum_size = Vector2(0, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(TSUI.expand(rule))
	return pill.get_meta("label")


func _refresh() -> void:
	if _last_coins >= 0 and TSProfile.coin_count != _last_coins:
		wallet.spend(_last_coins, TSProfile.coin_count)
	_last_coins = TSProfile.coin_count
	var lvl := TSProfile.collection_level()
	_level_label.text = "Collection Level %d" % lvl
	_bonus_label.text = "+%d%% materials" % TSProfile.collection_material_bonus_percent()
	_level_bar.max_value = TSProfile.collection_points_for_level(lvl)
	_level_bar.value = TSProfile.collection_level_progress()
	_count_label.text = "%d of %d critters collected" % [_owned_count(), _listed_count()]
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
	var info := _feature_row(i, owned, rarity)
	var level := TSProfile.critter_level_of(i)
	var name := TSProfile.critter_name(i)
	if owned:
		name = TSProfile.progress_title(level, TSProfile.CRITTER_MAX_LEVEL, name)
	var name_label := TSUI.wrap(TSUI.outlined(TSUI.label(name, 36, TSUI.INK if owned else TSUI.MUTED), Color.WHITE, 8))
	info.add_child(name_label)
	var tags := TSUI.hbox(8)
	tags.add_child(TSUI.pill(TSProfile.RARITY_NAMES[rarity].to_upper(), TSUI.RARITY_COLORS[rarity], 18))
	tags.add_child(TSUI.label("Lv %d/%d" % [level, TSProfile.CRITTER_MAX_LEVEL] if owned else "Not yet yours", 22, TSFX.COL_GAIN if owned else TSUI.MUTED))
	info.add_child(tags)
	if owned:
		info.add_child(_stars(level, TSProfile.CRITTER_MAX_LEVEL, 28.0))
		if i == TSProfile.avatar():
			var here := TSUI.hbox(6)
			here.add_child(TSIcon.make("egg", 30))
			here.add_child(TSUI.label("In your egg", 20, TSUI.INK))
			info.add_child(here)
		else:
			info.add_child(TSUI.label("Tap its tile to put it in your egg", 18, TSUI.MUTED))
	elif TSProfile.is_critter_pass_exclusive(i):
		var pass_row := TSUI.hbox(6)
		pass_row.add_child(TSIcon.make("pass", 30))
		pass_row.add_child(TSUI.label("Only in the Battle Pass", 20, TSUI.INK))
		info.add_child(pass_row)
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


## The feature card's stage -- the critter over a slowly turning sunburst in
## its rarity's colour (sparkling for Epic and Legendary), a gold glow round
## it while it's the one in the egg -- and, beside it, the column the caller
## fills.
func _feature_row(i: int, owned: bool, rarity: int) -> VBoxContainer:
	var row := TSUI.hbox(16)
	_feature.add_child(row)
	var tint: Color = TSUI.RARITY_COLORS[rarity]
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(210, 210)
	var face := TSUI.sb(TSProfile.critter_color(i).lerp(tint, 0.3).lerp(Color.WHITE, 0.2) if owned else Color(0.9, 0.88, 0.88), 36, 5, 5, 0)
	face.border_color = tint.darkened(0.15) if owned else TSUI.GREY.darkened(0.2)
	if owned and i == TSProfile.avatar():
		face.shadow_color = Color(TSUI.GOLD, 0.9)
		face.shadow_size = 10
	stage.add_theme_stylebox_override("panel", face)
	var burst := Burst.new()
	burst.colour = Color(Color.WHITE, 0.5) if owned else Color(Color.WHITE, 0.4)
	burst.sparkles = [0, 0, 5, 9][rarity] if owned else 0
	stage.add_child(burst)
	var art := TSIcon.make("critter", 176, i)
	art.silhouette = not owned
	stage.add_child(art)
	row.add_child(stage)
	_feature_tile = stage
	var info := TSUI.vbox(8)
	TSUI.expand(info)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	return info


## A sunburst behind the featured critter: soft rays turning slowly inside a
## circle, and twinkling sparkles round it.
class Burst extends Control:
	var colour := Color(1, 1, 1, 0.5)
	var sparkles := 0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 8.0
		for k in 12:
			var a := _t * 0.25 + TAU * float(k) / 12.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.12) * r, c + Vector2.from_angle(a + 0.12) * r]), colour)
		for k in sparkles:
			# Each in its own spot round the edge, pulsing in its own time.
			var at := c + Vector2.from_angle(TAU * float(k) / float(sparkles) + 0.4) * r * (0.72 + 0.16 * float(k % 2))
			var s := 9.0 * maxf(0.0, sin(_t * 2.4 + float(k) * 1.7))
			if s > 0.5:
				var star := PackedVector2Array()
				for p in 8:
					star.append(at + Vector2.from_angle(TAU * float(p) / 8.0) * (s if p % 2 == 0 else s * 0.3))
				draw_colored_polygon(star, Color(1.0, 0.95, 0.6))


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
	for g in [_owned_grid, _locked_grid]:
		for c in g.get_children():
			c.queue_free()
	var order: Array = range(TSProfile.CRITTER_COUNT)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _key(TSProfile.is_critter_unlocked(a), TSProfile.critter_rarity(a), TSProfile.critter_name(a)) < _key(TSProfile.is_critter_unlocked(b), TSProfile.critter_rarity(b), TSProfile.critter_name(b)))
	for i in order:
		if TSProfile.is_critter_listed(i):
			(_owned_grid if TSProfile.is_critter_unlocked(i) else _locked_grid).add_child(_tile(i))
	var owned := _owned_count()
	_owned_head.text = "Your critters  %d" % owned
	_locked_head.text = "Still to collect  %d" % (_listed_count() - owned)
	_locked_head.get_parent().get_parent().visible = owned < _listed_count()


func _owned_count() -> int:
	var n := 0
	for i in TSProfile.CRITTER_COUNT:
		n += int(TSProfile.is_critter_unlocked(i))
	return n


## The critters in the Collection: all but those held back for a later release.
func _listed_count() -> int:
	var n := 0
	for i in TSProfile.CRITTER_COUNT:
		n += int(TSProfile.is_critter_listed(i))
	return n


## A critter's tile: owned, in a wash of its own colour with its level; still
## to collect, its shadow on grey with its price (or the pass it comes from)
## under its name. The bottom lip is its rarity's colour either way.
func _tile(i: int) -> Control:
	var owned := TSProfile.is_critter_unlocked(i)
	var rarity: Color = TSUI.RARITY_COLORS[TSProfile.critter_rarity(i)]
	var bg: Color = TSProfile.critter_color(i).lerp(Color.WHITE, 0.45) if owned else Color(0.93, 0.91, 0.9)
	var selected := i == _sel_critter
	var b := _tile_button(bg, rarity, selected, TSIcon.make("critter", TILE * 0.84, i), not owned)
	if owned:
		_badge(b, "Lv %d" % TSProfile.critter_level_of(i), TSUI.INK, Vector2(TILE - 56, 4))
		if TSProfile.is_critter_new(i):
			_badge(b, "NEW", TSUI.RED_DOT, Vector2(4, 4))
		if i == TSProfile.avatar():
			var egg := TSIcon.make("egg", 30)
			egg.position = Vector2(4, TILE - 40)
			egg.size = Vector2(30, 30)
			b.add_child(egg)
	b.pressed.connect(func():
		_sel_critter = i
		TSProfile.clear_new_critters([i])
		if owned:
			TSProfile.set_avatar_critter(i)
		_refresh()
		if i == TUTORIAL_CRITTER:
			_tutorial.gate_passed())
	return _tile_column(b, i, owned)


func _tile_button(bg: Color, rarity: Color, selected: bool, art: TSIcon, silhouette: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TILE, TILE)
	var face := TSUI.sb(bg, 24, 4 if selected else 3, 5, 4)
	face.border_color = TSUI.INK if selected else rarity.darkened(0.1)
	face.border_width_bottom = 8
	if selected:
		face.shadow_color = Color(TSUI.GOLD, 0.85)
		face.shadow_size = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, face)
	if selected:
		# The selected tile keeps its rarity's lip under the ink rim.
		var lip := Panel.new()
		var lip_style := TSUI.sb(rarity, 0, 0, 0, 0)
		lip_style.set_corner_radius_all(0)
		lip_style.corner_radius_bottom_left = 20
		lip_style.corner_radius_bottom_right = 20
		lip.add_theme_stylebox_override("panel", lip_style)
		lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lip.position = Vector2(4, TILE - 12)
		lip.size = Vector2(TILE - 8, 8)
		b.add_child(lip)
	art.silhouette = silhouette
	art.position = Vector2(TILE * 0.08, TILE * 0.04)
	art.size = Vector2(TILE * 0.84, TILE * 0.84)
	b.add_child(art)
	return b


func _badge(b: Button, text: String, colour: Color, at: Vector2) -> void:
	var pill := TSUI.pill(text, colour, 14, Color.WHITE)
	pill.position = at
	b.add_child(pill)


func _tile_column(b: Button, i: int, owned: bool) -> Control:
	var v := TSUI.vbox(0)
	v.set_meta("index", i)
	v.add_child(b)
	var name := TSUI.label(TSProfile.critter_name(i), 18, TSUI.INK if owned else TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = TILE
	v.add_child(name)
	if not owned:
		var price := TSUI.hbox(3)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if TSProfile.is_critter_pass_exclusive(i):
			price.add_child(TSIcon.make("pass", 20))
			price.add_child(TSUI.label("Pass", 16, TSUI.MUTED))
		else:
			var cost := TSProfile.critter_unlock_cost(i)
			price.add_child(TSIcon.make("coin", 18))
			price.add_child(TSUI.label(_short_coins(cost), 16, TSUI.INK if TSProfile.coin_count >= cost else TSUI.MUTED))
		v.add_child(price)
	return v


## "5k", "15k", "100k": a price short enough for a tile.
static func _short_coins(n: int) -> String:
	return "%dk" % (n / 1000) if n >= 1000 and n % 1000 == 0 else TSProfile.fmt_coins(n)


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
	var steps := [{"rect": _feature.get_global_rect(), "text": "This is your Collection: your critters. Every level they gain raises your Collection level."}]
	if gift > 0:
		steps.append({"rect": wallet.get_global_rect(), "text": "Here's %s coins -- enough for your first critter." % TSProfile.fmt_coins(gift)})
	var buying := not TSProfile.is_critter_unlocked(TUTORIAL_CRITTER) and TSProfile.coin_count >= TSProfile.critter_unlock_cost(TUTORIAL_CRITTER)
	if buying:
		# The critter to tap sits far down the alphabetical list. The walkthrough
		# blocks scrolling (everything outside its spotlight is dark and dead), so
		# bring the tile on screen now, while the first two steps look elsewhere.
		_scroll_tile_into_view(TUTORIAL_CRITTER)
		steps.append({"rect": func() -> Rect2: return _tile_rect(TUTORIAL_CRITTER), "text": "Tap %s." % TSProfile.critter_name(TUTORIAL_CRITTER), "gate": true})
		steps.append({"rect": func() -> Rect2: return _feature_btn.get_global_rect(), "text": "Tap Buy to adopt it.", "gate": true})
	steps.append({"rect": func() -> Rect2: return _feature.get_global_rect(), "text": "It's yours! Tap an owned critter to seal it in the egg, and upgrade it here." if buying else "Tap an owned critter to seal it in the egg, and upgrade it here."})
	steps.append({"rect": func() -> Rect2: return _level_card.get_global_rect(), "text": "Each Collection level adds +1% building materials on every win."})
	_tutorial.start(steps)


## Scrolls the critter list so critter i's tile sits comfortably in view.
func _scroll_tile_into_view(i: int) -> void:
	for g in [_owned_grid, _locked_grid]:
		for t in g.get_children():
			if t.get_meta("index", -1) == i:
				var tile := t as Control
				var top := tile.global_position.y - _critter_scroll.global_position.y + float(_critter_scroll.scroll_vertical)
				_critter_scroll.scroll_vertical = maxi(0, int(top - (_critter_scroll.size.y - tile.size.y) * 0.4))
				return


func _tile_rect(i: int) -> Rect2:
	for g in [_owned_grid, _locked_grid]:
		for t in g.get_children():
			if t.get_meta("index", -1) == i:
				return (t as Control).get_global_rect()
	return _locked_grid.get_global_rect()
