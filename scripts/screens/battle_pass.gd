extends TSScreen

## The Battle Pass (Duckdoku's BattlePassScreen): 30 tiers, a free reward and
## a premium reward on each, climbed with stars (the hearts left on a win,
## plus quests). Tap a reached, unclaimed reward to collect it. A second tab
## holds the Daily and Weekly quests. The premium track is a real-money
## product through Billing (simulated here); a tier can be bought for coins.

const COL_PREMIUM := Color(1.0, 0.94, 0.8)
const COL_PREMIUM_RIM := Color(0.74, 0.56, 1.0)

var _timer: Label
var _progress_label: Label
var _progress: ProgressBar
var _tier_buy: Button
var _tabs: PanelContainer
var _quest_tabs: PanelContainer
var _pass_content: VBoxContainer
var _quest_content: VBoxContainer
var _tier_list: VBoxContainer
var _quest_list: VBoxContainer
var _buy_btn: Button
var _purchased: Label
var _buy: Dictionary
var _info: Dictionary
var _weekly := false
var _dots: Array = []
var _acc := 0.0


func build() -> void:
	add_header("Battle Pass", true, true, func(): TSUI.reveal(_info["root"], _info["panel"]))
	var timer_pill := TSUI.pill("", TSUI.CARD, 22)
	timer_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer = timer_pill.get_meta("label")
	content.add_child(timer_pill)
	# hero: the season's premium critter and ship-part upgrade
	var season := TSProfile.season_rewards()
	var hero := TSUI.card(Color(0.84, 0.76, 1.0), 30, 12, 4)
	var hero_row := TSUI.hbox(10)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hero_row)
	for t in season["paid_critters"]:
		hero_row.add_child(TSIcon.make("critter", 150, int(season["paid_critters"][t])))
	var hero_text := TSUI.vbox(2)
	hero_text.add_child(TSUI.outlined(TSUI.label("Season %d" % TSProfile.battle_pass_season_number(), 40, Color.WHITE), TSUI.INK, 10))
	hero_text.add_child(TSUI.label("Exclusive critter + ship upgrade", 22, TSUI.INK))
	hero_row.add_child(hero_text)
	for t in season["paid_parts"]:
		hero_row.add_child(TSIcon.make("part", 110, int(season["paid_parts"][t])))
	content.add_child(hero)
	_progress_label = TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_progress_label)
	_progress = TSUI.bar(TSUI.GOLD, 30)
	content.add_child(_progress)
	_tabs = TSUI.tabs(["Battle Pass", "Quests"], _on_main_tab)
	content.add_child(_tabs)
	for b in _tabs.get_meta("buttons"):
		_dots.append(TSUI.dot(b))

	_pass_content = TSUI.vbox(10)
	_pass_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_pass_content)
	var heads := TSUI.hbox(8)
	heads.add_child(TSUI.spacer(70))
	heads.add_child(TSUI.expand(TSUI.label("FREE", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
	heads.add_child(TSUI.expand(TSUI.label("PREMIUM", 24, COL_PREMIUM_RIM.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER)))
	_pass_content.add_child(heads)
	_tier_list = TSUI.vbox(10)
	_pass_content.add_child(TSUI.scroll(_tier_list))

	_quest_content = TSUI.vbox(10)
	_quest_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_content.visible = false
	content.add_child(_quest_content)
	_quest_tabs = TSUI.tabs(["Daily", "Weekly"], _on_quest_tab, 22)
	_quest_content.add_child(_quest_tabs)
	for b in _quest_tabs.get_meta("buttons"):
		_dots.append(TSUI.dot(b))
	_quest_list = TSUI.vbox(10)
	_quest_content.add_child(TSUI.scroll(_quest_list))

	_tier_buy = TSUI.button("Buy next tier", TSUI.BUTTER, 24, Vector2(0, 64))
	_tier_buy.pressed.connect(_on_tier_buy)
	content.add_child(_tier_buy)
	_buy_btn = TSUI.button("Unlock Premium  ·  %s" % _price(), COL_PREMIUM_RIM, 30, Vector2(0, 84))
	_buy_btn.pressed.connect(_open_buy)
	content.add_child(_buy_btn)
	_purchased = TSUI.label("Premium unlocked for this season", 24, COL_PREMIUM_RIM.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_purchased)
	_build_dialogs()
	_refresh()
	_build_quests()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh_timer()


func _price() -> String:
	var live := Billing.price_of("battle_pass")
	return live if live != "" else TSProfile.BATTLE_PASS_PRICE_LABEL


func _refresh() -> void:
	_refresh_timer()
	var tier := TSProfile.battle_pass_tier()
	var count := TSProfile.BATTLE_PASS_TIER_COUNT
	var per_tier := TSProfile.battle_pass_tier_cost(mini(tier + 1, count))
	_progress.max_value = maxi(per_tier, 1)
	if tier >= count:
		_progress.value = _progress.max_value
		_progress_label.text = "Pass complete!"
	else:
		_progress.value = TSProfile.battle_pass_tier_progress()
		_progress_label.text = "%d / %d stars to Tier %d" % [TSProfile.battle_pass_tier_progress(), per_tier, tier + 1]
	if tier >= count or not TSProfile.battle_pass_open():
		_tier_buy.visible = false
	else:
		var cost := TSProfile.battle_pass_tier_buy_cost()
		_tier_buy.visible = true
		_tier_buy.text = "Buy Tier %d  ·  %s coins" % [tier + 1, TSProfile.fmt_coins(cost)]
		_tier_buy.disabled = TSProfile.coin_count < cost
	_buy_btn.visible = not TSProfile.battle_pass_purchased
	_purchased.visible = TSProfile.battle_pass_purchased
	_build_tiers()
	_refresh_dots()


func _refresh_timer() -> void:
	_timer.text = "%s left" % TSUI.fmt_duration(TSProfile.battle_pass_seconds_remaining())


func _refresh_dots() -> void:
	var daily := TSProfile.has_unclaimed_daily_quests()
	var weekly := TSProfile.has_unclaimed_weekly_quests()
	(_dots[0] as Control).visible = TSProfile.has_claimable_battle_pass_reward()
	(_dots[1] as Control).visible = daily or weekly
	(_dots[2] as Control).visible = daily
	(_dots[3] as Control).visible = weekly


func _on_main_tab(i: int) -> void:
	TSUI.style_tabs(_tabs, i)
	_pass_content.visible = i == 0
	_quest_content.visible = i == 1


func _on_quest_tab(i: int) -> void:
	TSUI.style_tabs(_quest_tabs, i)
	_weekly = i == 1
	_build_quests()


# -- tiers --------------------------------------------------------------------------

func _build_tiers() -> void:
	for c in _tier_list.get_children():
		c.queue_free()
	var current := TSProfile.battle_pass_tier()
	for tier in range(1, TSProfile.BATTLE_PASS_TIER_COUNT + 1):
		var row := TSUI.hbox(8)
		var badge := TSUI.card(TSUI.GOLD if tier <= current else TSUI.CARD, 18, 4, 2)
		badge.custom_minimum_size = Vector2(62, 96)
		badge.add_child(TSUI.label(str(tier), 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(badge)
		row.add_child(_reward_card(tier, current, TSProfile.battle_pass_free_reward(tier), false))
		row.add_child(_reward_card(tier, current, TSProfile.battle_pass_paid_reward(tier), true))
		_tier_list.add_child(row)
	TSUI.juice(_tier_list)


func _reward_card(tier: int, current: int, reward: Dictionary, premium: bool) -> Control:
	var reached := tier <= current
	var claimed: bool = bool((TSProfile.battle_pass_paid_claimed if premium else TSProfile.battle_pass_free_claimed)[tier - 1])
	var claimable := TSProfile.can_claim_battle_pass_paid(tier) if premium else TSProfile.can_claim_battle_pass_free(tier)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := TSUI.sb(COL_PREMIUM if premium else TSUI.CARD, 22, 5 if claimable else 3, 2, 8)
	face.border_color = TSUI.GOLD_DARK if claimable else (COL_PREMIUM_RIM if premium else TSUI.INK)
	card.add_theme_stylebox_override("panel", face)
	if claimed:
		card.modulate = Color(1, 1, 1, 0.5)
	var stack := MarginContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	var h := TSUI.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(h)
	if reward.has("critter"):
		h.add_child(_item("critter", int(reward["critter"]), TSProfile.critter_name(int(reward["critter"]))))
	if reward.has("part"):
		h.add_child(_item("part", int(reward["part"]), TSProfile.part_name(int(reward["part"]))))
	if int(reward.get("coins", 0)) > 0:
		h.add_child(_item("coin", 0, "x%s" % TSProfile.fmt_coins(int(reward["coins"]))))
	if int(reward.get("materials", 0)) > 0:
		h.add_child(_item("materials", 0, "x%d" % int(reward["materials"])))
	if int(reward.get("bomb", 0)) > 0:
		h.add_child(_item("bomb", 0, "x%d" % int(reward["bomb"])))
	if (not premium and not reached) or (premium and not TSProfile.battle_pass_purchased):
		var lock := TSIcon.make("lock", 34)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_END
		lock.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		stack.add_child(lock)
	if claimed:
		var tick := TSIcon.make("check", 34)
		tick.size_flags_horizontal = Control.SIZE_SHRINK_END
		tick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		stack.add_child(tick)
	if claimable:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				_claim(tier, premium, h))
	return card


func _item(icon: String, idx: int, caption: String) -> Control:
	var v := TSUI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TSIcon.make(icon, 52, idx)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := TSUI.label(caption, 17, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 70
	v.add_child(l)
	return v


func _claim(tier: int, premium: bool, anchor: Control) -> void:
	var before := TSProfile.coin_count
	var from := anchor.get_global_rect()
	var reward := TSProfile.claim_battle_pass_paid(tier) if premium else TSProfile.claim_battle_pass_free(tier)
	if reward.is_empty():
		return
	TSSfx.play("upgrade")
	if TSProfile.coin_count > before:
		wallet.receive(from, before, TSProfile.coin_count)
	else:
		TSFX.sparkle_burst_at(self, from)
	_refresh()


func _on_tier_buy() -> void:
	var before := TSProfile.coin_count
	if not TSProfile.purchase_battle_pass_tier():
		return
	wallet.spend(before, TSProfile.coin_count)
	TSSfx.play("upgrade")
	TSFX.sparkle_burst(self, _tier_buy)
	_refresh()


# -- quests ------------------------------------------------------------------------

func _build_quests() -> void:
	for c in _quest_list.get_children():
		c.queue_free()
	if not _weekly:
		for q in TSProfile.daily_quest_rows():
			_quest_list.add_child(_quest_row(q))
	else:
		for group in TSProfile.weekly_quest_groups():
			var ago: int = group["weeks_ago"]
			_quest_list.add_child(TSUI.label("This week" if ago == 0 else ("Last week" if ago == 1 else "%d weeks ago" % ago), 22, COL_PREMIUM_RIM.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER))
			for q in group["rows"]:
				_quest_list.add_child(_quest_row(q))
	TSUI.juice(_quest_list)
	_refresh_dots()


func _quest_row(q: Dictionary) -> Control:
	var card := TSUI.card(TSUI.CARD, 22, 14, 2)
	var row := TSUI.hbox(10)
	card.add_child(row)
	var done: bool = q["done"]
	var claimed: bool = q["claimed"]
	var name_lbl := TSUI.wrap(TSUI.label(q["name"], 24, TSUI.MUTED if claimed else TSUI.INK))
	TSUI.expand(name_lbl)
	row.add_child(name_lbl)
	var pts := TSUI.hbox(4)
	pts.add_child(TSIcon.make("star", 30))
	pts.add_child(TSUI.label("+%d" % int(q["points"]), 22))
	pts.add_child(TSIcon.make("materials", 30))
	pts.add_child(TSUI.label("+%d" % TSProfile.quest_materials(int(q["points"])), 22))
	row.add_child(pts)
	if done and not claimed:
		var b := TSUI.button("Collect", TSUI.GREEN, 22, Vector2(130, 56), 4)
		b.pressed.connect(func():
			if TSProfile.claim_quest(q["week_key"], q["index"]) < 0:
				return
			TSSfx.play("upgrade")
			TSFX.sparkle_burst(self, b)
			_refresh()
			_build_quests())
		row.add_child(b)
	else:
		row.add_child(TSUI.label("Collected" if claimed else "%d/%d" % [int(q["progress"]), int(q["target"])], 22, TSUI.MUTED))
	if claimed:
		card.modulate = Color(1, 1, 1, 0.6)
	return card


# -- buying the pass --------------------------------------------------------------------

func _build_dialogs() -> void:
	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("How the Battle Pass Works", 34))
	ibox.add_child(TSUI.wrap(TSUI.label("1. Win levels to earn stars -- one for every heart you have left, and 2 more for a first try. Quests give more.\n2. Stars climb the tiers.\n3. Tap a reached tier's reward to collect it. Premium adds a bigger reward on every tier.", 22), 520))
	var ok := TSUI.button("Got it", TSUI.PINK, 26)
	ok.pressed.connect(func(): TSUI.conceal(_info["root"]))
	ibox.add_child(ok)
	_buy = TSUI.dialog(self, 600)


func _open_buy() -> void:
	var box: VBoxContainer = _buy["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Premium Pass", 44))
	var season := TSProfile.season_rewards()
	var lines := PackedStringArray()
	lines.append("A bigger reward on every tier: more coins, bombs and building materials.")
	for t in season["paid_critters"]:
		var c := int(season["paid_critters"][t])
		lines.append("%s at tier %d%s." % [TSProfile.critter_name(c), t, " -- only here" if TSProfile.is_critter_pass_exclusive(c) else ""])
	for t in season["paid_parts"]:
		lines.append("A free %s fix or upgrade at tier %d." % [TSProfile.part_name(int(season["paid_parts"][t])).to_lower(), t])
	lines.append("A 4th chest slot, with two chests unlocking at once.")
	lines.append("Chests unlock %d%% faster." % TSChests.TIMER_DISCOUNT_PERCENT)
	lines.append("+%d%% on every coin you earn, all season." % TSProfile.BATTLE_PASS_COIN_BONUS_PERCENT)
	var body := ""
	for l in lines:
		body += "•  " + l + "\n"
	box.add_child(TSUI.wrap(TSUI.label(body.strip_edges(), 22), 540))
	var tier := TSProfile.battle_pass_tier()
	if tier > 0:
		var coins := 0
		var bombs := 0
		var mats := 0
		for t in range(1, tier + 1):
			var r := TSProfile.battle_pass_paid_reward(t)
			coins += int(r.get("coins", 0))
			bombs += int(r.get("bomb", 0))
			mats += int(r.get("materials", 0))
		box.add_child(TSUI.wrap(TSUI.label("You are on tier %d, so buying now unlocks right away: %s coins, %d bombs and %d building materials." % [tier, TSProfile.fmt_coins(coins), bombs, mats], 22, TSFX.COL_GAIN, HORIZONTAL_ALIGNMENT_CENTER), 540))
	var confirm := TSUI.button("Buy Pass  ·  %s" % _price(), COL_PREMIUM_RIM, 30, Vector2(0, 84))
	confirm.pressed.connect(func():
		TSUI.conceal(_buy["root"])
		Billing.purchase_result.connect(func(id: String, _ok: bool):
			if id == "battle_pass" and is_inside_tree():
				_refresh(), CONNECT_ONE_SHOT)
		Billing.purchase("battle_pass"))
	box.add_child(confirm)
	var later := TSUI.button("Not now", TSUI.GREY, 24, Vector2(0, 60))
	later.pressed.connect(func(): TSUI.conceal(_buy["root"]))
	box.add_child(later)
	TSUI.juice(box)
	TSUI.reveal(_buy["root"], _buy["panel"])


func on_back_requested() -> bool:
	for d in [_buy, _info]:
		if d["root"].visible:
			TSUI.conceal(d["root"])
			return true
	return false
