extends TSScreen

## Daily Streaks (Duckdoku's StreakScreen): two cards -- the login streak and
## the Daily Egg streak -- each a week-long track of seven days with bombs on
## day seven, and a coin claim for today that the whole card collects.

var _login_card: PanelContainer
var _daily_card: PanelContainer
var _login: Dictionary = {}
var _daily: Dictionary = {}
var _banner: PanelContainer


func build() -> void:
	add_header("Daily Streaks", true)
	content.add_child(TSUI.wrap(TSUI.label("Collect coins every day. Keep it up 7 days in a row for %d free bombs." % TSProfile.STREAK_REWARD_BOMBS, 24, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
	_banner = TSUI.card(TSUI.BUTTER, 22, 14, 2)
	_banner.add_child(TSUI.wrap(TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
	content.add_child(_banner)
	content.add_child(TSUI.spacer(0, true))
	_login_card = _make_card("LOGIN STREAK", TSUI.BUTTER, "flame", _login, _on_login_tap)
	content.add_child(_login_card)
	content.add_child(TSUI.spacer(10))
	_daily_card = _make_card("DAILY EGG STREAK", TSUI.SKY, "calendar", _daily, _on_daily_tap)
	content.add_child(_daily_card)
	content.add_child(TSUI.spacer(0, true))
	_refresh()


func _make_card(title_text: String, pill_color: Color, icon: String, parts: Dictionary, on_tap: Callable) -> PanelContainer:
	var card := TSUI.card(TSUI.CARD, 30, 22, 5)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			on_tap.call())
	var v := TSUI.vbox(12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var pill := TSUI.pill(title_text, pill_color, 24)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pill)
	var row := TSUI.hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var text := TSUI.vbox(2)
	TSUI.expand(text)
	row.add_child(text)
	parts["count"] = TSUI.label("", 40)
	text.add_child(parts["count"])
	parts["progress"] = TSUI.label("", 22, TSUI.MUTED)
	text.add_child(parts["progress"])
	var ic := TSIcon.make(icon, 100)
	row.add_child(ic)
	parts["icon"] = ic
	var track := TSUI.hbox(10)
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(track)
	parts["track"] = track
	var claim := TSUI.card(TSUI.GOLD, 99, 10, 0)
	claim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crow := TSUI.hbox(8)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	claim.add_child(crow)
	crow.add_child(TSIcon.make("coin", 36))
	parts["claim_label"] = TSUI.label("", 24)
	crow.add_child(parts["claim_label"])
	v.add_child(claim)
	parts["claim"] = claim
	parts["collected"] = TSUI.label("", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(parts["collected"])
	return card


func _refresh() -> void:
	_fill(_login, _login_card, TSProfile.login_streak_count, TSProfile.can_claim_login_reward(), TSProfile.login_reward_amount(), true)
	_fill(_daily, _daily_card, TSProfile.daily_streak_count, TSProfile.can_claim_daily_reward(), TSProfile.daily_reward_amount(), false)
	if TSProfile.streak_reward_message != "":
		(_banner.get_child(0) as Label).text = TSProfile.streak_reward_message
		_banner.visible = true
		TSProfile.streak_reward_message = ""
	else:
		_banner.visible = false


func _fill(parts: Dictionary, card: PanelContainer, count: int, claimable: bool, amount: int, login: bool) -> void:
	(parts["count"] as Label).text = "%d day%s" % [count, "" if count == 1 else "s"]
	var interval := TSProfile.STREAK_REWARD_INTERVAL
	var remaining := interval - (count % interval)
	(parts["progress"] as Label).text = "Reward day!" if count > 0 and count % interval == 0 else "%d day%s until the bombs" % [remaining, "" if remaining == 1 else "s"]
	(parts["claim_label"] as Label).text = "Tap to collect +%s coins!" % TSProfile.fmt_coins(amount)
	(parts["claim"] as Control).visible = claimable
	var collected: Label = parts["collected"]
	collected.visible = not claimable
	var today := Time.get_date_string_from_system()
	var claimed_today := (TSProfile.login_reward_claimed_date if login else TSProfile.daily_reward_claimed_date) == today
	collected.text = "Collected today" if claimed_today else ("Come back tomorrow" if login else "Crack today's Daily Egg to keep it going")
	card.add_theme_stylebox_override("panel", TSUI.sb(TSUI.CARD, 30, 5 if claimable else 3, 5, 22))
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = TSUI.GOLD_DARK if claimable else TSUI.INK
	# the seven-day track
	var track: HBoxContainer = parts["track"]
	for c in track.get_children():
		c.queue_free()
	var reached := count % interval
	if reached == 0 and count > 0:
		reached = interval
	for day in range(1, interval + 1):
		var done := day <= reached
		var last := day == interval
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := 72.0 if last else 56.0
		chip.custom_minimum_size = Vector2(s, s)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var face := TSUI.sb(TSUI.GOLD if done else Color(0.95, 0.92, 0.9), 99, 4 if day == reached else 2, 0, 0)
		chip.add_theme_stylebox_override("panel", face)
		if last:
			var bomb := TSIcon.make("bomb", s)
			chip.add_child(bomb)
		elif done:
			chip.add_child(TSIcon.make("check", s))
		else:
			chip.add_child(TSUI.label(str(day), 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		track.add_child(chip)


func _on_login_tap() -> void:
	var before := TSProfile.coin_count
	if TSProfile.claim_login_reward() <= 0:
		return
	_celebrate(_login_card, _login["icon"], before)


func _on_daily_tap() -> void:
	var before := TSProfile.coin_count
	if TSProfile.claim_daily_reward() <= 0:
		return
	_celebrate(_daily_card, _daily["icon"], before)


func _celebrate(card: Control, icon: Control, before: int) -> void:
	TSSfx.play("upgrade")
	TSHaptics.medium()
	card.pivot_offset = card.size / 2.0
	var b := card.create_tween()
	b.tween_property(card, "scale", Vector2(1.04, 1.04), 0.09)
	b.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wallet.receive(icon.get_global_rect(), before, TSProfile.coin_count)
	_refresh()
