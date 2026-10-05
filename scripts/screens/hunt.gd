extends TSScreen

## The 7-Day Eggsperience (Duckdoku's VoyageScreen). A banner with what it is
## and how long is left; a strip of seven day cards, each with what it pays --
## done (mint, ticked), today (butter, flagged), open, or locked -- and Day 7
## in gold as the grand prize; the selected day's three quests, each ticked
## off as it's done, with a full-width PLAY; and the grand prize, with a pip
## for every day claimed so far.

const DONE := Color(0.86, 0.97, 0.88)
const TODAY := Color(1.0, 0.95, 0.76)
const LOCKED := Color(0.9, 0.88, 0.9)
const GRAND := Color(1.0, 0.86, 0.5)
const QUEST_ICONS := {"level": "trophy", "clear": "star", "booster": "bomb", "flawless": "heart", "chest": "chest", "collection": "collection", "daily_puzzle": "calendar"}

var _days: HBoxContainer
var _day_title: Label
var _day_status: PanelContainer
var _day_reward: Label
var _quests: VBoxContainer
var _ends: Label
var _prize_sub: Label
var _prize_pips: HBoxContainer
var _selected := 1


func build() -> void:
	TSProfile.ensure_loaded()
	TSHunt.roll()
	TSHunt.mark_seen()
	add_header("7-Day Eggsperience", true)
	var list := TSUI.vbox(14)
	content.add_child(TSUI.scroll(list))
	list.add_child(_banner())
	if TSHunt.reward_message != "":
		var toast := TSUI.card(TSUI.BUTTER, 20, 12, 3)
		var row := TSUI.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		toast.add_child(row)
		row.add_child(TSIcon.make("coin", 34))
		row.add_child(TSUI.label(TSHunt.reward_message, 24, TSUI.INK))
		list.add_child(toast)
		TSHunt.reward_message = ""
	_days = TSUI.hbox(6)
	list.add_child(_days)
	list.add_child(_day_panel())
	list.add_child(_prize_card())
	list.add_child(TSUI.spacer(10))
	_selected = _default_day()
	_refresh()


func _default_day() -> int:
	for day in range(1, TSHunt.DAYS + 1):
		if TSHunt.day_unlocked(day) and not TSHunt.day_claimed(day):
			return day
	return TSHunt.today_day()


## The top: the basket, what to do, and the time left on a pill.
func _banner() -> Control:
	var card := TSUI.card(Color(0.94, 0.88, 1.0), 28, 14, 4)
	var row := TSUI.hbox(12)
	card.add_child(row)
	row.add_child(TSIcon.make("hunt", 120))
	var v := TSUI.vbox(8)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	v.add_child(TSUI.wrap(TSUI.label("A new day of quests unlocks every day. Finish a day's three quests for coins, and all seven days for the grand prize!", 21)))
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", TSUI.sb(Color.WHITE, 99, 2, 0, 12))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pr := TSUI.hbox(6)
	pill.add_child(pr)
	pr.add_child(TSIcon.make("clock", 26))
	_ends = TSUI.label("", 19, TSUI.INK)
	pr.add_child(_ends)
	v.add_child(pill)
	return card


## The selected day: its title and what it pays (or "Claimed"), its quests,
## and PLAY.
func _day_panel() -> Control:
	var panel := TSUI.card(TSUI.CARD, 28, 16, 4)
	var pv := TSUI.vbox(10)
	panel.add_child(pv)
	var head := TSUI.hbox(8)
	_day_title = TSUI.label("", 30)
	TSUI.expand(_day_title)
	head.add_child(_day_title)
	_day_status = PanelContainer.new()
	var sr := TSUI.hbox(6)
	_day_status.add_child(sr)
	_day_status.set_meta("row", sr)
	head.add_child(_day_status)
	pv.add_child(head)
	_quests = TSUI.vbox(8)
	pv.add_child(_quests)
	var play := TSUI.button("PLAY", TSUI.PINK, 34, Vector2(0, 80))
	play.pressed.connect(func(): SceneFlow.go(SceneFlow.GAME))
	pv.add_child(play)
	return panel


func _refresh() -> void:
	for c in _days.get_children():
		c.queue_free()
	for day in range(1, TSHunt.DAYS + 1):
		_days.add_child(_day_card(day))
	var left := TSHunt.days_left()
	_ends.text = "Ends in %d day%s" % [left, "" if left == 1 else "s"]
	# The selected day's head: its reward still to earn, or claimed.
	_day_title.text = "Day %d" % _selected + (" -- Grand Prize" if _selected == TSHunt.DAYS else "")
	var claimed := TSHunt.day_claimed(_selected)
	_day_status.add_theme_stylebox_override("panel", TSUI.sb(TSUI.MINT if claimed else TSUI.BUTTER, 99, 2, 0, 12))
	var sr: HBoxContainer = _day_status.get_meta("row")
	for c in sr.get_children():
		c.queue_free()
	sr.add_child(TSIcon.make("check" if claimed else "coin", 28))
	sr.add_child(TSUI.label("Claimed" if claimed else TSProfile.fmt_coins(int(TSHunt.DAY_REWARDS[_selected - 1])), 22, TSUI.INK))
	for c in _quests.get_children():
		c.queue_free()
	for i in TSHunt.QUESTS[_selected - 1].size():
		_quests.add_child(_quest_row(_selected, i))
	# The grand prize: one pip a day claimed.
	var done := 0
	for day in range(1, TSHunt.DAYS + 1):
		done += int(TSHunt.day_claimed(day))
	for c in _prize_pips.get_children():
		c.queue_free()
	for day in range(1, TSHunt.DAYS + 1):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(0, 18)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.add_theme_stylebox_override("panel", TSUI.sb(TSUI.GOLD if TSHunt.day_claimed(day) else Color(1, 1, 1, 0.7), 99, 2, 0, 0))
		_prize_pips.add_child(pip)
	_prize_sub.text = "Every day claimed -- well done!" if done >= TSHunt.DAYS else "%d of %d days claimed" % [done, TSHunt.DAYS]
	TSUI.juice(self)


## A day's card: its number, a picture of where it stands (a tick, today's
## egg, a lock, or for Day 7 the grand chest) and what it pays.
func _day_card(day: int) -> Control:
	var unlocked := TSHunt.day_unlocked(day)
	var done := TSHunt.day_claimed(day)
	var today := day == TSHunt.today_day()
	var grand := day == TSHunt.DAYS
	var selected := day == _selected
	var bg := DONE if done else (TODAY if today and unlocked else (TSUI.CARD if unlocked else LOCKED))
	if grand and not done:
		bg = GRAND if unlocked else GRAND.lerp(LOCKED, 0.55)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 138)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := TSUI.sb(bg, 18, 4 if selected else 2, 4, 2)
	face.border_color = TSUI.GOLD_DARK if selected else TSUI.INK
	if selected:
		face.shadow_color = Color(TSUI.GOLD, 0.7)
		face.shadow_size = 6
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, face)
	b.disabled = not unlocked
	if unlocked:
		b.pressed.connect(func():
			TSSfx.play("tap")
			_selected = day
			_refresh())
	var v := TSUI.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(TSUI.label("TODAY" if today and unlocked and not done else "Day %d" % day, 15, TSUI.CORAL if today and unlocked and not done else TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var icon := "check"
	var variant := ""
	if not done:
		if grand:
			icon = "chest"
			variant = "legendary" if unlocked else "locked"
		elif not unlocked:
			icon = "lock"
		else:
			icon = "egg"
	var ic := TSIcon.make(icon, 54, (day - 1) % TSProfile.EGG_PAINT_COUNT, variant)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked and not grand:
		ic.modulate.a = 0.6
	v.add_child(ic)
	var reward := int(TSHunt.DAY_REWARDS[day - 1])
	v.add_child(TSUI.label("%dk" % (reward / 1000) if reward % 1000 == 0 else TSProfile.fmt_coins(reward), 16, TSUI.INK if unlocked else TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return b


## A quest: its icon on a soft disc, what to do, a bar with the count, and a
## tick once done (the row turns mint).
func _quest_row(day: int, i: int) -> Control:
	var q: Dictionary = TSHunt.QUESTS[day - 1][i]
	var have := TSHunt.quest_progress(day, i)
	var target := int(q["target"])
	var done := have >= target
	var card := TSUI.card(DONE if done else Color(1.0, 0.96, 0.9), 20, 14, 2)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", TSUI.sb(Color.WHITE, 99, 2, 0, 4))
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_child(TSIcon.make(QUEST_ICONS.get(str(q["stat"]), "star"), 48))
	h.add_child(disc)
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(TSUI.label(TSHunt.quest_name(day, i), 22))
	var bar_row := TSUI.hbox(8)
	var bar := TSUI.bar(TSUI.MINT if done else TSUI.SKY, 18)
	TSUI.expand(bar)
	bar.max_value = target
	bar.value = have
	bar_row.add_child(bar)
	var count := "%d/%d" % [TSHunt.start_level + have, TSHunt.goal_level(day, i)] if str(q["stat"]) == "level" else "%d/%d" % [have, target]
	bar_row.add_child(TSUI.label(count, 18, TSUI.MUTED))
	v.add_child(bar_row)
	if done:
		h.add_child(TSIcon.make("check", 40))
	return card


## The grand prize: the big chest, what it pays, and a pip per day claimed.
func _prize_card() -> Control:
	var card := TSUI.card(GRAND.lerp(Color.WHITE, 0.45), 28, 16, 4)
	var row := TSUI.hbox(14)
	card.add_child(row)
	row.add_child(TSIcon.make("chest", 110, 0, "legendary"))
	var v := TSUI.vbox(6)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	v.add_child(TSUI.label("Grand Prize", 30))
	var pay := TSUI.hbox(6)
	pay.add_child(TSIcon.make("coin", 30))
	var total := 0
	for r in TSHunt.DAY_REWARDS:
		total += int(r)
	pay.add_child(TSUI.label("%s on Day %d  ·  %s all week" % [TSProfile.fmt_coins(int(TSHunt.DAY_REWARDS[TSHunt.DAYS - 1])), TSHunt.DAYS, TSProfile.fmt_coins(total)], 19, TSUI.INK))
	v.add_child(pay)
	_prize_pips = TSUI.hbox(5)
	v.add_child(_prize_pips)
	_prize_sub = TSUI.label("", 18, TSUI.MUTED)
	v.add_child(_prize_sub)
	return card
