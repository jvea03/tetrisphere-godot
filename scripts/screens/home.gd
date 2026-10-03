extends TSScreen

## Home (Duckdoku's StartMenu): the avatar card (critter, collection level,
## Profile), the wallet (a shortcut to the Shop) and Settings along the top;
## the side tiles -- login streak, Daily Egg, Battle Pass, Egg Hunt and any
## running sale -- down the left; behind it all, a crash site to drag around:
## a spaceship crash-landed on a planet, crewed by the critters you own; the
## chest tray; the level plate and PLAY. Pop-ups for Settings, Profile, a
## sale, a chest opening, skipping a chest timer, and leaderboard results,
## plus the first-time walkthroughs.

var play_btn: Button
var level_label: Label
var avatar_btn: Button
var avatar_icon: TSIcon
var collection_star: Label
var collection_bar: ProgressBar
var coin_pill: TSCoinPill
var side: VBoxContainer
var streak_btn: Button
var streak_badge: PanelContainer
var daily_btn: Button
var daily_dot: Panel
var pass_btn: Button
var pass_dot: Panel
var hunt_btn: Button
var hunt_dot: Panel
var sale_btn: Button
var sale_timer: Label
var tray: PanelContainer
var tutorial: TSTutorial
var _world: TSShipScene      # the crash site behind everything
var _launch_btn: Button      # shown at a season's end when the ship is ready

var _chest_slots: Array = [] # per slot: {btn, plate, art, pill, pill_label, band}
var _settings: Dictionary
const PRIVACY_URL := "https://jvea03.github.io/duckdoku-privacy/egg-escape.html"
var _profile: Dictionary
var _sale: Dictionary
var _skip: Dictionary
var _chest: Dictionary
var _results: Dictionary
var _ad_wait: Dictionary
var _skip_slot := -1
var _chest_opening := false
var _chest_tweens: Array[Tween] = []
var _chest_rarity := ""
var _chest_coins := 0
var _chest_coins_before := -1
var _sale_coins_before := 0
var _board_day := ""
var _name_edit: LineEdit
var _avatar_choice := 0


func tab_id() -> String:
	return "home"


func build() -> void:
	TSProfile.record_login()
	_build_top_bar()
	content.add_child(TSUI.spacer(0, true))
	_build_showcase()
	_build_chest_tray()
	_build_play()
	_build_side_tiles()
	_build_dialogs()
	tutorial = TSTutorial.new()
	add_child(tutorial)

	var features := TSNav.features_unlocked()
	tray.visible = features
	pass_btn.visible = features
	hunt_btn.visible = features
	if features:
		TSHunt.roll()
	_refresh_side()
	var walkthrough := false
	if features and not TSProfile.home_tutorial_seen:
		_start_home_tutorial()
		walkthrough = true
	elif daily_btn.visible and not TSProfile.daily_callout_seen:
		_start_daily_callout()
		walkthrough = true
	TSProfile.settle_boards()
	TSProfile.save()
	var results := not walkthrough and not TSProfile.pending_board_prizes.is_empty()
	_setup_sale(walkthrough or results)
	if results:
		_open_board_results.call_deferred()
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_tick)
	add_child(tick)


func _tick() -> void:
	_refresh_chest_tray()
	_refresh_sale_icon()
	_tick_boards()
	if _sale["root"].visible and TSSales.current().is_empty():
		TSUI.conceal(_sale["root"])
	elif _sale["root"].visible and _sale.has("timer"):
		(_sale["timer"] as Label).text = "Ends in %s" % TSSales.format_left(TSSales.seconds_left())


# -- top bar ---------------------------------------------------------------------

func _build_top_bar() -> void:
	var row := TSUI.hbox(14)
	content.add_child(row)
	avatar_btn = Button.new()
	avatar_btn.focus_mode = Control.FOCUS_NONE
	avatar_btn.custom_minimum_size = Vector2(150, 150)
	var face := TSUI.sb(TSProfile.avatar_color(), 36, 3, 5, 6)
	for st in ["normal", "hover", "pressed", "focus"]:
		avatar_btn.add_theme_stylebox_override(st, face)
	avatar_btn.pressed.connect(_open_profile)
	row.add_child(avatar_btn)
	avatar_icon = TSIcon.make("critter", 110, TSProfile.avatar())
	avatar_icon.position = Vector2(20, 6)
	avatar_icon.size = Vector2(110, 110)
	avatar_btn.add_child(avatar_icon)
	var star := TSIcon.make("star", 48)
	star.position = Vector2(-6, 100)
	star.size = Vector2(48, 48)
	avatar_btn.add_child(star)
	collection_star = TSUI.label("1", 20, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	collection_star.position = Vector2(-6, 104)
	collection_star.size = Vector2(48, 44)
	avatar_btn.add_child(collection_star)
	collection_bar = TSUI.bar(TSUI.GOLD, 18)
	collection_bar.position = Vector2(46, 118)
	collection_bar.size = Vector2(92, 18)
	avatar_btn.add_child(collection_bar)
	_refresh_avatar()

	row.add_child(TSUI.spacer(0, true))
	coin_pill = TSCoinPill.new(true)
	coin_pill.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			SceneFlow.slide("res://scenes/shop.tscn", -1))
	row.add_child(coin_pill)
	var cog := TSUI.icon_button("cog", 84)
	cog.pressed.connect(_open_settings)
	cog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cog)


func _refresh_avatar() -> void:
	avatar_icon.set_icon("critter", TSProfile.avatar())
	var face := TSUI.sb(TSProfile.avatar_color(), 36, 3, 5, 6)
	for st in ["normal", "hover", "pressed", "focus"]:
		avatar_btn.add_theme_stylebox_override(st, face)
	collection_star.text = str(TSProfile.collection_level())
	collection_bar.max_value = TSProfile.collection_points_for_level(TSProfile.collection_level())
	collection_bar.value = TSProfile.collection_level_progress()


# -- side tiles ------------------------------------------------------------------

func _build_side_tiles() -> void:
	side = TSUI.vbox(18)
	side.position = Vector2(24, 196 + TSUI.safe_top())
	side.z_index = 2
	add_child(side)
	streak_btn = _side_tile("flame", _open_streaks)
	streak_badge = TSUI.pill("0", TSUI.BUTTER, 18)
	streak_badge.position = Vector2(56, -12)
	streak_btn.add_child(streak_badge)
	daily_btn = _side_tile("calendar", _on_daily_pressed)
	daily_dot = TSUI.dot(daily_btn)
	pass_btn = _side_tile("pass", func(): SceneFlow.go("res://scenes/battle_pass.tscn"))
	pass_dot = TSUI.dot(pass_btn)
	hunt_btn = _side_tile("hunt", func(): SceneFlow.go("res://scenes/hunt.tscn"))
	hunt_dot = TSUI.dot(hunt_btn)
	sale_btn = _side_tile("tag", _open_sale)
	var tag := TSUI.pill("SALE", TSUI.CORAL, 16)
	tag.position = Vector2(10, -16)
	sale_btn.add_child(tag)
	sale_timer = TSUI.outlined(TSUI.label("", 16, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER), TSUI.PAPER, 6)
	sale_timer.position = Vector2(-10, 88)
	sale_timer.size = Vector2(116, 24)
	sale_btn.add_child(sale_timer)


func _side_tile(icon: String, on_press: Callable) -> Button:
	var b := TSUI.icon_button(icon, 96, TSUI.CARD)
	b.pressed.connect(on_press)
	side.add_child(b)
	return b


func _refresh_side() -> void:
	streak_badge.get_meta("label").text = str(TSProfile.login_streak_count)
	streak_btn.visible = not TSProfile.has_claimed_all_streak_rewards_today()
	daily_btn.visible = TSNav.daily_unlocked() and not TSProfile.is_daily_completed_today()
	daily_dot.visible = daily_btn.visible and TSProfile.daily_streak_last_date != Time.get_date_string_from_system()
	pass_dot.visible = TSProfile.has_claimable_battle_pass_reward() or TSProfile.has_unclaimed_quests()
	hunt_dot.visible = TSHunt.has_alert()


func _open_streaks() -> void:
	SceneFlow.go("res://scenes/streak.tscn")


func _on_daily_pressed() -> void:
	TSSession.daily_requested = true
	SceneFlow.go(SceneFlow.GAME)


# -- showcase, chest tray, play ----------------------------------------------------------

# The crash site (TSShipScene): a world bigger than the screen behind all of
# Home, crewed by the critters the player owns. The column keeps an open gap
# where the ship first shows. Home's own layers let touches through, so a
# drag on any empty part of the screen pans the world; buttons and cards
# still take their own.
func _build_showcase() -> void:
	var gap := TSUI.vbox(0)
	gap.custom_minimum_size = Vector2(0, 340)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(gap)
	_world = TSShipScene.new()
	add_child(_world)
	move_child(_world, 1)   # just over the paper, under everything else
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(content.get_parent() as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# At the end of a season, a readied ship can launch (TSProfile.can_launch).
	if TSProfile.can_launch():
		gap.add_child(TSUI.spacer(0, true))
		_launch_btn = TSUI.button("LAUNCH!  +%s" % TSProfile.fmt_coins(TSProfile.launch_reward()), TSUI.GOLD, 30, Vector2(320, 80))   # narrow enough to clear the side tiles
		_launch_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_launch_btn.pressed.connect(_on_launch_pressed)
		gap.add_child(_launch_btn)
		_launch_btn.pivot_offset = _launch_btn.custom_minimum_size * 0.5
		var beat := _launch_btn.create_tween().set_loops()
		beat.tween_property(_launch_btn, "scale", Vector2.ONE * 1.06, 0.5).set_trans(Tween.TRANS_SINE)
		beat.tween_property(_launch_btn, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## Lift-off: the ship roars away with its crew aboard; then the reward and the
## news -- a new planet, a new camp to build -- and Home reopens there.
func _on_launch_pressed() -> void:
	_launch_btn.disabled = true
	_launch_btn.visible = false
	TSSfx.play("win")
	TSHaptics.heavy()
	_world.launched.connect(_on_launched, CONNECT_ONE_SHOT)
	_world.launch()


func _on_launched() -> void:
	var before := TSProfile.coin_count
	var coins := TSProfile.launch_ship()
	var card := TSUI.dialog(self, 600)
	var box: VBoxContainer = card["box"]
	box.add_child(TSUI.title("Lift-off!", 48))
	box.add_child(TSUI.wrap(TSUI.label("Your critters flew to Planet %d! A new crash site means a new camp to build and a new ship to fix -- everything you levelled up still counts toward your Collection." % TSProfile.planet_number, 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER), 540))
	box.add_child(TSUI.label("+%s coins" % TSProfile.fmt_coins(coins), 36, TSFX.COL_GAIN, HORIZONTAL_ALIGNMENT_CENTER))
	var go := TSUI.button("Explore Planet %d" % TSProfile.planet_number, TSUI.GREEN, 28, Vector2(0, 76))
	go.pressed.connect(func(): SceneFlow.go(SceneFlow.HOME))
	box.add_child(go)
	TSUI.reveal(card["root"], card["panel"])
	coin_pill.receive(card["panel"].get_global_rect(), before, TSProfile.coin_count)
	TSFX.confetti(self)


func _build_chest_tray() -> void:
	tray = TSUI.card(Color(1.0, 0.9, 0.78), 28, 12, 5)
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(tray)
	var row := TSUI.hbox(10)
	tray.add_child(row)
	for i in TSChests.SLOT_COUNT:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(106, 122)   # a touch smaller, so the camp shows more
		btn.flat = true
		btn.pressed.connect(_on_chest_slot_pressed.bind(i))
		var plate := Panel.new()
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(plate)
		var art := TSIcon.make("chest", 78)
		art.position = Vector2(14, 3)
		art.size = Vector2(78, 78)
		btn.add_child(art)
		var pill := TSUI.pill("", Color(0.4, 0.36, 0.56), 15, Color.WHITE)
		pill.position = Vector2(12, 60)
		pill.custom_minimum_size = Vector2(82, 0)
		btn.add_child(pill)
		var band := TSUI.label("", 15, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		band.position = Vector2(0, 92)
		band.size = Vector2(106, 28)
		btn.add_child(band)
		row.add_child(btn)
		_chest_slots.append({"btn": btn, "plate": plate, "art": art, "pill": pill, "band": band})
	_refresh_chest_tray()


func _refresh_chest_tray() -> void:
	if _skip.has("root") and _skip["root"].visible and _skip_slot >= 0:
		_refresh_skip()
	for i in TSChests.SLOT_COUNT:
		var s: Dictionary = _chest_slots[i]
		var art: TSIcon = s["art"]
		var gold := false
		var variant := "common"
		var pill_text := ""
		var band := ""
		art.modulate = Color.WHITE
		if not TSChests.slot_open(i) and TSChests.is_empty(i):
			variant = "locked"
			band = "PASS SLOT"
		elif TSChests.is_empty(i):
			art.modulate = Color(1, 1, 1, 0.22 if i == TSChests.free_slot() else 0.12)
			band = ("%d/%d WINS" % [TSChests.WINS_PER_CHEST - TSChests.wins_to_next(), TSChests.WINS_PER_CHEST]) if i == TSChests.free_slot() else "EMPTY"
		else:
			variant = TSChests.rarity_of(i)
			if TSChests.is_ready(i):
				gold = true
				variant = "open"
				band = "OPEN!"
			elif TSChests.is_unlocking(i):
				gold = true
				pill_text = TSChests.format_countdown_short(TSChests.seconds_left(i))
				band = "OPENING"
			else:
				pill_text = TSChests.format_unlock_time(variant)
				band = "UNLOCK"   # tap to start its timer
		art.set_icon("chest", 0, variant)
		(s["plate"] as Panel).add_theme_stylebox_override("panel", TSUI.sb(TSUI.GOLD if gold else TSUI.CARD, 22, 3, 3, 0))
		(s["pill"] as Control).visible = pill_text != ""
		(s["pill"] as PanelContainer).get_meta("label").text = pill_text
		(s["band"] as Label).text = band


func _build_play() -> void:
	var group := TSUI.vbox(0)
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(group)
	var plate := TSUI.card(TSUI.BUTTER, 22, 10, 2)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	level_label = TSUI.label("", 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	plate.add_child(level_label)
	group.add_child(plate)
	play_btn = TSUI.button("PLAY", TSUI.PINK, 60, Vector2(460, 124), 10)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	play_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	play_btn.add_theme_color_override("font_outline_color", TSUI.INK)
	play_btn.add_theme_constant_override("outline_size", 14)
	play_btn.pressed.connect(_on_play_pressed)
	group.add_child(play_btn)
	var level := TSProfile.last_level
	var diff := TSLevels.difficulty_for_level(level)
	level_label.text = "Level %d" % level if diff < TSLevels.DIFF_EXTREME else "Level %d  ·  EXTREME" % level
	if diff >= TSLevels.DIFF_EXTREME:
		level_label.add_theme_color_override("font_color", Color(0.86, 0.22, 0.3))
	if TSSession.has_saved_game and not bool(TSSession.state.get("daily", false)):
		play_btn.text = "CONTINUE"
	TSUI.breathe(play_btn)
	content.add_child(TSUI.spacer(8))


## A win card closed past the interstitial gate owes an ad before the next level.
func _on_play_pressed() -> void:
	if TSProfile.interstitial_owed and not TSProfile.no_ads and not Ads.is_busy():
		play_btn.disabled = true
		TSUI.reveal(_ad_wait["root"], _ad_wait["panel"])
		Ads.interstitial_closed.connect(func():
			TSProfile.interstitial_owed = false
			TSProfile.save()
			if is_inside_tree():
				SceneFlow.go(SceneFlow.GAME), CONNECT_ONE_SHOT)
		Ads.show_interstitial()
		return
	if TSProfile.interstitial_owed:
		TSProfile.interstitial_owed = false
		TSProfile.save()
	SceneFlow.go(SceneFlow.GAME)


# -- chests ------------------------------------------------------------------------

func _on_chest_slot_pressed(i: int) -> void:
	var btn: Button = _chest_slots[i]["btn"]
	if not TSChests.slot_open(i) and TSChests.is_empty(i):
		TSUI.note(self, btn, "Battle Pass: a 4th slot + 2 unlocks at once")
		return
	if TSChests.is_empty(i):
		var n := TSChests.wins_to_next()
		TSUI.note(self, btn, "Win %d more level%s for a chest" % [n, "" if n == 1 else "s"])
		return
	if TSChests.is_ready(i):
		_open_chest(i)
		return
	if TSChests.is_unlocking(i):
		_open_skip(i)
		return
	if TSChests.start_unlock(i):
		TSUI.note(self, btn, "Unlocking -- %s" % TSChests.format_unlock_time(TSChests.rarity_of(i)))
		_refresh_chest_tray()
	else:
		var limit := TSChests.max_concurrent_unlocks()
		TSUI.note(self, btn, "One chest at a time" if limit == 1 else "Only %d chests at a time" % limit)


func _open_skip(i: int) -> void:
	_skip_slot = i
	(_skip["title"] as Label).text = "%s Chest" % TSChests.DISPLAY_NAMES[TSChests.rarity_of(i)]
	_refresh_skip()
	TSUI.reveal(_skip["root"], _skip["panel"])


func _refresh_skip() -> void:
	if not TSChests.is_unlocking(_skip_slot):
		TSUI.conceal(_skip["root"])
		return
	var cost := TSChests.skip_cost(_skip_slot)
	(_skip["body"] as Label).text = "Opens in %s. Open it now?" % TSChests.format_countdown(TSChests.seconds_left(_skip_slot))
	var b: Button = _skip["confirm"]
	b.text = "Open for %s coins" % TSProfile.fmt_coins(cost)
	b.disabled = TSProfile.coin_count < cost


func _on_skip_confirmed() -> void:
	var before := TSProfile.coin_count
	if not TSChests.skip_unlock(_skip_slot):
		return
	TSUI.conceal(_skip["root"])
	coin_pill.spend(before, TSProfile.coin_count)
	_refresh_chest_tray()


func _open_chest(i: int) -> void:
	var before := TSProfile.coin_count
	var reward := TSChests.open(i)
	if reward.is_empty():
		return
	_refresh_chest_tray()
	_chest_coins_before = before
	coin_pill.label.text = TSProfile.fmt_coins(before)
	(_chest["title"] as Label).text = "%s Chest" % TSChests.DISPLAY_NAMES[reward["rarity"]]
	TSUI.reveal(_chest["root"], _chest["panel"])
	_play_chest_open(str(reward["rarity"]), int(reward["coins"]))


## The chest wobbles harder and harder, bursts open in a flash with a spray of
## coins, the amount counts up, and Collect appears. A tap skips to the end.
func _play_chest_open(rarity: String, coins: int) -> void:
	_chest_opening = true
	_chest_rarity = rarity
	_chest_coins = coins
	_chest_tweens.clear()
	var face: TSIcon = _chest["art"]
	var amount: Label = _chest["amount"]
	var done: Button = _chest["done"]
	face.set_icon("chest", 0, rarity)
	face.rotation = 0.0
	face.pivot_offset = face.size / 2.0
	amount.text = "+0 coins"
	amount.modulate.a = 0.0
	done.modulate.a = 0.0
	done.disabled = true
	var wob := face.create_tween()
	_chest_tweens.append(wob)
	wob.tween_interval(0.2)
	for k in 8:
		var amp := lerpf(0.05, 0.17, float(k) / 7.0)
		wob.tween_property(face, "rotation", amp * (1.0 if k % 2 == 0 else -1.0), 0.1).set_trans(Tween.TRANS_SINE)
	wob.tween_property(face, "rotation", 0.0, 0.05)
	await wob.finished
	if not _chest_opening:
		return
	TSSfx.play("upgrade")
	TSHaptics.medium()
	face.set_icon("chest", 0, "open")
	face.scale = Vector2(0.72, 0.72)
	var pop := face.create_tween()
	_chest_tweens.append(pop)
	pop.tween_property(face, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TSFX.sparkle_burst(self, face)
	amount.modulate.a = 1.0
	var count := amount.create_tween()
	_chest_tweens.append(count)
	count.tween_method(func(v: float): amount.text = "+%s coins" % TSProfile.fmt_coins(int(round(v))), 0.0, float(coins), 0.6)
	count.tween_callback(_finish_chest_open)


func _finish_chest_open() -> void:
	if not _chest_opening:
		return
	_chest_opening = false
	for t in _chest_tweens:
		if t.is_valid():
			t.kill()
	_chest_tweens.clear()
	var face: TSIcon = _chest["art"]
	face.set_icon("chest", 0, "open")
	face.rotation = 0.0
	face.scale = Vector2.ONE
	(_chest["amount"] as Label).modulate.a = 1.0
	(_chest["amount"] as Label).text = "+%s coins" % TSProfile.fmt_coins(_chest_coins)
	var done: Button = _chest["done"]
	done.disabled = false
	done.create_tween().tween_property(done, "modulate:a", 1.0, 0.2)


func _close_chest() -> void:
	_finish_chest_open()
	var from := (_chest["art"] as Control).get_global_rect()
	TSUI.conceal(_chest["root"])
	if _chest_coins_before >= 0:
		coin_pill.receive(from, _chest_coins_before, TSProfile.coin_count)
		_chest_coins_before = -1


# -- sales ----------------------------------------------------------------------------

func _setup_sale(walkthrough: bool) -> void:
	Billing.purchase_result.connect(_on_purchase_result)
	TSSales.roll()
	_refresh_sale_icon()
	if not TSSales.current().is_empty() and not TSSales.popup_shown and not walkthrough:
		_open_sale.call_deferred()


func _refresh_sale_icon() -> void:
	var running := not TSSales.current().is_empty()
	sale_btn.visible = running
	if running:
		sale_timer.text = TSSales.format_left(TSSales.seconds_left())


func _open_sale() -> void:
	var o := TSSales.current()
	if o.is_empty():
		_refresh_sale_icon()
		return
	var box: VBoxContainer = _sale["box"]
	for c in box.get_children():
		c.queue_free()
	var top := TSUI.hbox(8)
	box.add_child(top)
	top.add_child(TSUI.spacer(60))
	top.add_child(TSUI.expand(TSUI.title(str(o["name"]), 40)))
	var close := TSUI.close_button()
	close.pressed.connect(func(): TSUI.conceal(_sale["root"]))
	top.add_child(close)
	var timer := TSUI.label("Ends in %s" % TSSales.format_left(TSSales.seconds_left()), 22, TSUI.CORAL, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(timer)
	_sale["timer"] = timer
	var hero := TSUI.hbox(-30)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(TSIcon.make("chest", 160, 0, "legendary"))
	hero.add_child(TSIcon.make("egg", 150, 10))
	box.add_child(hero)
	var got := TSSales.contents(o)
	var strip := TSUI.card(TSUI.SKY, 22, 12, 2)
	var row := TSUI.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_child(row)
	row.add_child(_stack("coin", TSProfile.fmt_coins(int(got.get("coins", 0)))))
	if int(got.get("bomb", 0)) > 0:
		row.add_child(_stack("bomb", "x%d" % int(got["bomb"])))
	box.add_child(strip)
	var buy_row := TSUI.hbox(16)
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buy_row)
	var was := RichTextLabel.new()
	was.bbcode_enabled = true
	was.fit_content = true
	was.autowrap_mode = TextServer.AUTOWRAP_OFF
	was.custom_minimum_size = Vector2(90, 0)
	was.add_theme_font_override("normal_font", TSToon.hand_font())
	was.add_theme_font_size_override("normal_font_size", 24)
	was.add_theme_color_override("default_color", TSUI.MUTED)
	was.text = "[s]%s[/s]" % o["orig_price"]
	was.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(was)
	var live := Billing.price_of(str(o["product_id"]))
	var buy := TSUI.button(live if live != "" else str(o["price"]), TSUI.GREEN, 32, Vector2(240, 80))
	buy.pressed.connect(func():
		_sale_coins_before = TSProfile.coin_count
		Billing.purchase(str(o["product_id"])))
	buy_row.add_child(buy)
	TSUI.juice(box)
	TSSales.mark_popup_shown()
	TSUI.reveal(_sale["root"], _sale["panel"])


func _stack(icon: String, caption: String) -> Control:
	var v := TSUI.vbox(2)
	var ic := TSIcon.make(icon, 64)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(TSUI.label(caption, 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _on_purchase_result(product_id: String, success: bool) -> void:
	if not is_inside_tree() or not success or not product_id.begins_with("popup_"):
		return
	var from := (_sale["panel"] as Control).get_global_rect()
	TSUI.conceal(_sale["root"])
	_refresh_sale_icon()
	coin_pill.receive(from, _sale_coins_before, TSProfile.coin_count)


# -- leaderboard results -------------------------------------------------------------

func _tick_boards() -> void:
	var today := Time.get_date_string_from_system()
	if _board_day == today:
		return
	var first := _board_day == ""
	_board_day = today
	if first:
		return
	TSProfile.settle_boards()
	TSProfile.save()
	if not TSProfile.pending_board_prizes.is_empty() and not _results["root"].visible:
		_open_board_results()


func _open_board_results() -> void:
	var prizes: Array = TSProfile.pending_board_prizes
	if prizes.is_empty():
		return
	var box: VBoxContainer = _results["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Leaderboard Results", 38))
	box.add_child(TSUI.wrap(TSUI.label("The board has reset. Here is where you finished:", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
	var total := 0
	for p in prizes:
		total += int(p["coins"])
		var row := TSUI.card(TSUI.CARD, 20, 12, 2)
		var h := TSUI.hbox(12)
		row.add_child(h)
		var place := TSUI.label(str(int(p["place"])), 30, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		place.custom_minimum_size = Vector2(56, 56)
		h.add_child(TSFX.medal_plate(int(p["place"]), place))
		var info := TSUI.vbox(0)
		TSUI.expand(info)
		info.add_child(TSUI.label(str(p["board"]), 24))
		info.add_child(TSUI.label("Finished #%d · %s" % [int(p["place"]), str(p["score"])], 18, TSUI.MUTED))
		h.add_child(info)
		h.add_child(TSIcon.make("coin", 34))
		h.add_child(TSUI.label("+%s" % TSProfile.fmt_coins(int(p["coins"])), 24, TSFX.COL_GAIN))
		box.add_child(row)
	var collect := TSUI.button("Collect %s coins" % TSProfile.fmt_coins(total), TSUI.GREEN, 30, Vector2(0, 84))
	collect.pressed.connect(func():
		collect.disabled = true
		var from := collect.get_global_rect()
		var before := TSProfile.coin_count
		TSProfile.claim_board_prizes()
		TSUI.conceal(_results["root"])
		coin_pill.receive(from, before, TSProfile.coin_count))
	box.add_child(collect)
	TSUI.juice(box)
	TSUI.reveal(_results["root"], _results["panel"])


# -- dialogs ------------------------------------------------------------------------

func _build_dialogs() -> void:
	_settings = TSUI.dialog(self, 560)
	_profile = TSUI.dialog(self, 560)
	_sale = TSUI.dialog(self, 600)
	_skip = TSUI.dialog(self, 520)
	_chest = TSUI.dialog(self, 520)
	_results = TSUI.dialog(self, 600)
	_ad_wait = TSUI.dialog(self, 480)

	# skip a chest timer
	var sbox: VBoxContainer = _skip["box"]
	var stitle := TSUI.title("Chest", 40)
	sbox.add_child(stitle)
	_skip["title"] = stitle
	var sbody := TSUI.wrap(TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	sbox.add_child(sbody)
	_skip["body"] = sbody
	var confirm := TSUI.button("Open", TSUI.GREEN, 28)
	confirm.pressed.connect(_on_skip_confirmed)
	sbox.add_child(confirm)
	_skip["confirm"] = confirm
	var wait := TSUI.button("Wait", TSUI.GREY, 26)
	wait.pressed.connect(func(): TSUI.conceal(_skip["root"]))
	sbox.add_child(wait)

	# chest opening
	var cbox: VBoxContainer = _chest["box"]
	var ctitle := TSUI.title("Chest", 40)
	cbox.add_child(ctitle)
	_chest["title"] = ctitle
	var art := TSIcon.make("chest", 220)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cbox.add_child(art)
	_chest["art"] = art
	var amount := TSUI.outlined(TSUI.label("+0 coins", 40, TSUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, 10)
	cbox.add_child(amount)
	_chest["amount"] = amount
	var done := TSUI.button("Collect", TSUI.GREEN, 30)
	done.pressed.connect(_close_chest)
	cbox.add_child(done)
	_chest["done"] = done
	(_chest["panel"] as Control).gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _chest_opening:
			_finish_chest_open())

	# waiting on an interstitial
	var abox: VBoxContainer = _ad_wait["box"]
	abox.add_child(TSUI.title("Ad break", 38))
	var ad_icon := TSIcon.make("ad", 120)
	ad_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	abox.add_child(ad_icon)
	abox.add_child(TSUI.label("Your level starts in a moment...", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	_build_settings()
	_build_profile()
	TSUI.juice(self)


func _build_settings() -> void:
	var box: VBoxContainer = _settings["box"]
	box.add_child(TSUI.title("Settings", 44))
	var help := TSUI.card(Color(1.0, 0.95, 0.86), 20, 14, 0)
	help.visible = false
	help.add_child(TSUI.wrap(TSUI.label(TSUI.HOW_TO_PLAY, 20), 480))
	var help_btn := TSUI.button("How to Play", TSUI.SKY, 26, Vector2(0, 64))
	help_btn.pressed.connect(func(): help.visible = not help.visible)
	box.add_child(help_btn)
	box.add_child(help)
	for row in [["music", "Music", "music_enabled"], ["sound", "Sound Effects", "sfx_enabled"], ["vibrate", "Haptics", "haptics_enabled"]]:
		box.add_child(_toggle_row(row[0], row[1], row[2]))
	var restore := TSUI.expand(TSUI.button("Restore Purchases", TSUI.LILAC, 22, Vector2(0, 64))) as Button
	restore.pressed.connect(func():
		restore.disabled = true
		restore.text = "Restoring..."
		Billing.restore_finished.connect(func(restored: Array):
			if not is_instance_valid(restore):
				return
			restore.disabled = false
			restore.text = "Restored: No Ads Pass" if Billing.NO_ADS in restored else ("No Ads Pass already active" if TSProfile.no_ads else "Nothing to restore"), CONNECT_ONE_SHOT)
		Billing.restore_purchases())
	# The privacy policy, opened in the phone's browser (Play wants it
	# reachable from inside the app as well as from the store listing).
	var privacy := TSUI.expand(TSUI.button("Privacy Policy", TSUI.CARD, 22, Vector2(0, 64))) as Button
	privacy.pressed.connect(func(): OS.shell_open(PRIVACY_URL))
	var links := TSUI.hbox(12)
	links.add_child(restore)
	links.add_child(privacy)
	box.add_child(links)
	var close := TSUI.button("Close", TSUI.PINK, 28)
	close.pressed.connect(func(): TSUI.conceal(_settings["root"]))
	box.add_child(close)
	var version := "Version %s" % str(ProjectSettings.get_setting("application/config/version", "0.1"))
	box.add_child(TSUI.label(version, 18, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))




func _toggle_row(icon: String, text: String, prop: String) -> Control:
	var row := TSUI.hbox(12)
	row.add_child(TSIcon.make(icon, 48))
	row.add_child(TSUI.expand(TSUI.label(text, 26)))
	var on: bool = TSProfile.get_toggle(prop)
	var b := TSUI.button("On" if on else "Off", TSUI.MINT if on else TSUI.GREY, 24, Vector2(120, 60), 4)
	b.pressed.connect(func():
		var now: bool = not TSProfile.get_toggle(prop)
		TSProfile.set_toggle(prop, now)
		TSProfile.save()
		TSSfx.apply_settings()
		b.text = "On" if now else "Off"
		TSUI.restyle(b, TSUI.MINT if now else TSUI.GREY, 4)
		if prop == "haptics_enabled" and now:
			TSHaptics.light())
	row.add_child(b)
	return row


func _open_settings() -> void:
	TSUI.reveal(_settings["root"], _settings["panel"])


func _build_profile() -> void:
	var box: VBoxContainer = _profile["box"]
	box.add_child(TSUI.title("Profile", 44))
	var preview := TSIcon.make("critter", 150, TSProfile.avatar())
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(preview)
	_profile["preview"] = preview
	if TSNav.collection_unlocked():
		var go := TSUI.button("Pick a critter in the Collection", TSUI.SKY, 22, Vector2(0, 60))
		go.pressed.connect(func(): SceneFlow.slide("res://scenes/collection.tscn", -1))
		box.add_child(go)
	else:
		box.add_child(TSUI.wrap(TSUI.label("Reach level %d to pick your critter in the Collection" % TSNav.COLLECTION_UNLOCK_LEVEL, 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
	box.add_child(TSUI.label("NAME", 20, TSUI.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size = Vector2(0, 64)
	_name_edit.add_theme_font_override("font", TSToon.hand_font())
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_color_override("font_color", TSUI.INK)
	_name_edit.add_theme_stylebox_override("normal", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	_name_edit.add_theme_stylebox_override("focus", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	box.add_child(_name_edit)
	box.add_child(TSUI.label("RING COLOUR", 20, TSUI.MUTED))
	var swatches := TSUI.hbox(10)
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(swatches)
	_profile["swatches"] = swatches
	var save := TSUI.button("Save", TSUI.GREEN, 28)
	save.pressed.connect(_on_profile_save)
	box.add_child(save)
	var cancel := TSUI.button("Cancel", TSUI.GREY, 24, Vector2(0, 60))
	cancel.pressed.connect(func(): TSUI.conceal(_profile["root"]))
	box.add_child(cancel)


func _refresh_swatches() -> void:
	var row: HBoxContainer = _profile["swatches"]
	for c in row.get_children():
		c.queue_free()
	for i in TSProfile.AVATAR_COLORS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 64)
		var face := TSUI.sb(TSProfile.AVATAR_COLORS[i], 99, 5 if i == _avatar_choice else 2, 0, 0)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, face)
		b.pressed.connect(func():
			_avatar_choice = i
			_refresh_swatches())
		row.add_child(b)


func _open_profile() -> void:
	_name_edit.text = TSProfile.player_name
	_avatar_choice = TSProfile.avatar_index
	(_profile["preview"] as TSIcon).set_icon("critter", TSProfile.avatar())
	_refresh_swatches()
	TSUI.reveal(_profile["root"], _profile["panel"])


func _on_profile_save() -> void:
	var new_name := _name_edit.text.strip_edges()
	if not TSFilter.is_clean(new_name):
		TSUI.note(self, _name_edit, "That name isn't allowed -- please choose another")
		return
	TSProfile.player_name = new_name if new_name != "" else TSProfile.DEFAULT_NAME
	TSProfile.avatar_index = _avatar_choice
	TSProfile.save()
	_refresh_avatar()
	TSUI.conceal(_profile["root"])


# -- walkthroughs -----------------------------------------------------------------------

func _start_home_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	tutorial.finished.connect(func():
		TSProfile.home_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	tutorial.start([
		{"rect": tray.get_global_rect(), "text": "Win 3 levels to earn a chest."},
		{"rect": tray.get_global_rect(), "text": "Tap a chest to start unlocking it, then tap again when it's ready to collect coins. One chest unlocks at a time."},
		{"rect": pass_btn.get_global_rect(), "text": "The Battle Pass is open! Hearts left on a win become stars, and stars climb the tiers for coins."},
		{"rect": hunt_btn.get_global_rect(), "text": "And the Egg Hunt: three quests a day for a week, with coins for every day you finish."},
	])


func _start_daily_callout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	tutorial.finished.connect(func():
		TSProfile.daily_callout_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	tutorial.start([{"rect": daily_btn.get_global_rect(), "text": "The Daily Egg is here! A new egg every day -- crack it for coins and a streak."}])


## Android back: close whatever is open; with nothing open, Home quits.
func on_back_requested() -> bool:
	if _chest["root"].visible:
		_close_chest()
		return true
	for d in [_sale, _skip, _settings, _profile, _results]:
		if d["root"].visible:
			TSUI.conceal(d["root"])
			return true
	return false
