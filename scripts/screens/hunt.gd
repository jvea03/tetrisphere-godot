extends TSScreen

## The 7-Day Egg Hunt (Duckdoku's VoyageScreen): a row of seven day cards --
## locked, open, today, or done -- the selected day's three quests with
## progress bars, what finishing them pays, PLAY, and the Day 7 grand prize.

var _days: HBoxContainer
var _day_title: Label
var _reward_amount: Label
var _reward_caption: Label
var _quests: VBoxContainer
var _footer: Label
var _prize_sub: Label
var _prize_bar: ProgressBar
var _prize_count: Label
var _selected := 1


func build() -> void:
	TSProfile.ensure_loaded()
	TSHunt.roll()
	TSHunt.mark_seen()
	add_header("Egg Hunt", true)
	var hero := TSUI.hbox(10)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(TSIcon.make("hunt", 150))
	hero.add_child(TSUI.wrap(TSUI.label("Finish each day's quests for coins -- and hunt all week for the grand prize!", 24), 420))
	content.add_child(hero)
	if TSHunt.reward_message != "":
		var toast := TSUI.card(TSUI.BUTTER, 20, 12, 2)
		toast.add_child(TSUI.label(TSHunt.reward_message, 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		content.add_child(toast)
		TSHunt.reward_message = ""
	_days = TSUI.hbox(6)
	content.add_child(_days)
	var panel := TSUI.card(TSUI.CARD, 28, 16, 4)
	var pv := TSUI.vbox(12)
	panel.add_child(pv)
	var head := TSUI.hbox(8)
	_day_title = TSUI.label("", 30)
	TSUI.expand(_day_title)
	head.add_child(_day_title)
	_reward_caption = TSUI.label("", 18, TSUI.MUTED)
	head.add_child(_reward_caption)
	head.add_child(TSIcon.make("coin", 34))
	_reward_amount = TSUI.label("", 26)
	head.add_child(_reward_amount)
	pv.add_child(head)
	_quests = TSUI.vbox(10)
	pv.add_child(_quests)
	var play := TSUI.button("PLAY", TSUI.PINK, 34, Vector2(260, 80))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): SceneFlow.go(SceneFlow.GAME))
	pv.add_child(play)
	content.add_child(panel)
	content.add_child(_prize_card())
	content.add_child(TSUI.spacer(0, true))
	_footer = TSUI.label("", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_footer)
	_selected = _default_day()
	_refresh()


func _default_day() -> int:
	for day in range(1, TSHunt.DAYS + 1):
		if TSHunt.day_unlocked(day) and not TSHunt.day_claimed(day):
			return day
	return TSHunt.today_day()


func _refresh() -> void:
	for c in _days.get_children():
		c.queue_free()
	for day in range(1, TSHunt.DAYS + 1):
		_days.add_child(_day_card(day))
	_day_title.text = "Day %d Quests" % _selected
	_reward_amount.text = TSProfile.fmt_coins(int(TSHunt.DAY_REWARDS[_selected - 1]))
	_reward_caption.text = "Earned:" if TSHunt.day_claimed(_selected) else "Finish all:"
	for c in _quests.get_children():
		c.queue_free()
	for i in TSHunt.QUESTS[_selected - 1].size():
		_quests.add_child(_quest_row(_selected, i))
	var left := TSHunt.days_left()
	_footer.text = "The hunt ends in %d day%s" % [left, "" if left == 1 else "s"]
	var done := 0
	var total := 0
	for day in range(1, TSHunt.DAYS + 1):
		total += int(TSHunt.DAY_REWARDS[day - 1])
		if TSHunt.day_claimed(day):
			done += 1
	_prize_sub.text = "Hunt complete -- every day claimed!" if done >= TSHunt.DAYS else "%s coins  ·  %s for the whole hunt" % [TSProfile.fmt_coins(int(TSHunt.DAY_REWARDS[TSHunt.DAYS - 1])), TSProfile.fmt_coins(total)]
	_prize_bar.value = done
	_prize_count.text = "%d/%d days" % [done, TSHunt.DAYS]
	TSUI.juice(self)


func _day_card(day: int) -> Control:
	var unlocked := TSHunt.day_unlocked(day)
	var done := TSHunt.day_claimed(day)
	var today := day == TSHunt.today_day()
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(90, 108)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := TSUI.sb(TSUI.CARD if unlocked else Color(0.9, 0.88, 0.9), 20, 5 if day == _selected else 3, 3, 4)
	face.border_color = TSUI.GOLD_DARK if day == _selected else TSUI.INK
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, face)
	b.disabled = not unlocked
	if unlocked:
		b.pressed.connect(func():
			_selected = day
			_refresh())
	var v := TSUI.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(TSUI.label("Day %d" % day, 18, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var icon := "lock" if not unlocked else ("check" if done else ("egg" if today else "star"))
	var ic := TSIcon.make(icon, 46, (day - 1) % TSProfile.EGG_PAINT_COUNT)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	if today and not done:
		v.add_child(TSUI.label("TODAY", 14, TSUI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	return b


func _quest_row(day: int, i: int) -> Control:
	var q: Dictionary = TSHunt.QUESTS[day - 1][i]
	var have := TSHunt.quest_progress(day, i)
	var target := int(q["target"])
	var done := have >= target
	var card := TSUI.card(Color(1.0, 0.96, 0.9), 20, 12, 2)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var icons := {"level": "trophy", "clear": "star", "booster": "bomb", "flawless": "heart", "chest": "chest", "collection": "collection", "daily_puzzle": "calendar"}
	h.add_child(TSIcon.make(icons.get(str(q["stat"]), "star"), 50))
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	h.add_child(v)
	v.add_child(TSUI.label(TSHunt.quest_name(day, i), 22))
	var bar_row := TSUI.hbox(8)
	var bar := TSUI.bar(TSUI.MINT if done else TSUI.SKY, 20)
	TSUI.expand(bar)
	bar.max_value = target
	bar.value = have
	bar_row.add_child(bar)
	var count := "%d/%d" % [TSHunt.start_level + have, TSHunt.goal_level(day, i)] if str(q["stat"]) == "level" else "%d/%d" % [have, target]
	bar_row.add_child(TSUI.label(count, 18, TSUI.MUTED))
	v.add_child(bar_row)
	var check := TSIcon.make("check" if done else "clock", 44)
	if not done:
		check.modulate.a = 0.35
	h.add_child(check)
	return card


func _prize_card() -> Control:
	var card := TSUI.card(Color(1.0, 0.92, 0.78), 26, 14, 4)
	var row := TSUI.hbox(12)
	card.add_child(row)
	row.add_child(TSIcon.make("chest", 100, 0, "legendary"))
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	row.add_child(v)
	v.add_child(TSUI.label("Day %d Grand Prize" % TSHunt.DAYS, 28))
	_prize_sub = TSUI.label("", 20, TSUI.MUTED)
	v.add_child(_prize_sub)
	var bar_row := TSUI.hbox(8)
	_prize_bar = TSUI.bar(TSUI.GOLD, 20)
	_prize_bar.max_value = TSHunt.DAYS
	TSUI.expand(_prize_bar)
	bar_row.add_child(_prize_bar)
	_prize_count = TSUI.label("", 18)
	bar_row.add_child(_prize_count)
	v.add_child(bar_row)
	return card
