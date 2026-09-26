extends TSScreen

## Clubs (Duckdoku's Teams/Crews). Before joining: Join (a list of clubs),
## Search, and Create (name your own, with a badge, for coins). Once in a
## club: its page -- badge, name, the Leader's note, chat with the simulated
## members, and the member list -- and a weekly club leaderboard. Everything
## is simulated locally; there is no backend (see TSProfile's clubs section).

var _join_view: VBoxContainer
var _club_view: VBoxContainer
var _outer_tabs: PanelContainer
var _inner_tabs: PanelContainer
var _join_list: VBoxContainer
var _search_list: VBoxContainer
var _search_input: LineEdit
var _create_box: VBoxContainer
var _create_name: LineEdit
var _create_btn: Button
var _create_hint: Label
var _create_icons: HBoxContainer
var _create_icon := 0
var _mode := 0 # join / search / create
var _club_mode := 0 # club / leaderboard
var _chat_list: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _detail: Dictionary
var _leave: Dictionary
var _message: Dictionary
var _badge_pick: Dictionary
var _intro: Dictionary
var _detail_club := ""


func tab_id() -> String:
	return "clubs"


func build() -> void:
	add_header("Clubs", false, true, _open_intro)
	_join_view = TSUI.vbox(12)
	_join_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_join_view)
	_club_view = TSUI.vbox(12)
	_club_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_club_view)
	_build_dialogs()
	_refresh()
	if not TSProfile.club_intro_seen:
		TSProfile.club_intro_seen = true
		TSProfile.save()
		_open_intro.call_deferred()


func _refresh() -> void:
	_join_view.visible = not TSProfile.has_club
	_club_view.visible = TSProfile.has_club
	for c in _join_view.get_children():
		c.queue_free()
	for c in _club_view.get_children():
		c.queue_free()
	if TSProfile.has_club:
		_build_club_view()
	else:
		_build_join_view()
	TSUI.juice(self)


# -- not in a club ------------------------------------------------------------------------

func _build_join_view() -> void:
	_outer_tabs = TSUI.tabs(["Join", "Search", "Create"], func(i: int):
		_mode = i
		_refresh())
	TSUI.style_tabs(_outer_tabs, _mode)
	_join_view.add_child(_outer_tabs)
	match _mode:
		0:
			_join_list = TSUI.vbox(10)
			_join_view.add_child(TSUI.scroll(_join_list))
			_fill_club_list(_join_list, TSProfile.CLUB_LIST)
		1:
			_search_input = _line_edit("Search clubs by name")
			_search_input.text_changed.connect(func(_t): _refresh_search())
			_join_view.add_child(_search_input)
			_search_list = TSUI.vbox(10)
			_join_view.add_child(TSUI.scroll(_search_list))
			_refresh_search()
		2:
			_build_create()


func _line_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 68)
	e.add_theme_font_override("font", TSToon.hand_font())
	e.add_theme_font_size_override("font_size", 26)
	e.add_theme_color_override("font_color", TSUI.INK)
	e.add_theme_color_override("font_placeholder_color", TSUI.MUTED)
	e.add_theme_stylebox_override("normal", TSUI.sb(Color.WHITE, 20, 3, 0, 16))
	e.add_theme_stylebox_override("focus", TSUI.sb(Color.WHITE, 20, 3, 0, 16))
	return e


func _refresh_search() -> void:
	var q := _search_input.text.strip_edges().to_lower()
	var found: Array = []
	if q != "":
		for club in TSProfile.CLUB_LIST:
			if str(club["name"]).to_lower().contains(q):
				found.append(club)
	_fill_club_list(_search_list, found, "Type a club name to search." if q == "" else "No clubs match \"%s\"." % _search_input.text.strip_edges())


func _fill_club_list(list: VBoxContainer, clubs: Array, empty := "No clubs found.") -> void:
	for c in list.get_children():
		c.queue_free()
	if clubs.is_empty():
		list.add_child(TSUI.label(empty, 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for club in clubs:
		var card := TSUI.card(TSUI.CARD, 24, 14, 3)
		var row := TSUI.hbox(12)
		card.add_child(row)
		row.add_child(TSIcon.make("badge", 70, TSProfile.club_icon_for(str(club["name"]))))
		var v := TSUI.vbox(2)
		TSUI.expand(v)
		v.add_child(TSUI.label(str(club["name"]), 28))
		v.add_child(TSUI.label("%d/%d members" % [int(club["members"]), int(club["capacity"])], 20, TSUI.MUTED))
		row.add_child(v)
		var view := TSUI.button("View", TSUI.GREEN, 24, Vector2(110, 60), 4)
		view.pressed.connect(_open_detail.bind(club))
		row.add_child(view)
		list.add_child(card)
	TSUI.juice(list)


func _build_create() -> void:
	_create_box = TSUI.vbox(14)
	_join_view.add_child(_create_box)
	_create_box.add_child(TSUI.label("Club name", 24))
	_create_name = _line_edit("Name your club")
	_create_name.max_length = TSProfile.CLUB_NAME_MAX
	_create_name.text_changed.connect(func(_t): _refresh_create())
	_create_box.add_child(_create_name)
	_create_box.add_child(TSUI.label("Badge", 24))
	_create_icons = TSUI.hbox(6)
	_create_box.add_child(_create_icons)
	_fill_badges(_create_icons, _create_icon, func(i: int):
		_create_icon = i
		_fill_badges(_create_icons, _create_icon, Callable()))
	_create_hint = TSUI.wrap(TSUI.label("", 20, TSUI.MUTED))
	_create_box.add_child(_create_hint)
	_create_btn = TSUI.button("", TSUI.GREEN, 28, Vector2(0, 80))
	_create_btn.pressed.connect(func():
		var before := TSProfile.coin_count
		if TSProfile.create_club(_create_name.text, _create_icon):
			wallet.spend(before, TSProfile.coin_count)
			_refresh())
	_create_box.add_child(_create_btn)
	_refresh_create()


func _fill_badges(row: Container, selected: int, on_pick: Callable) -> void:
	for c in row.get_children():
		c.queue_free()
	for i in TSProfile.CLUB_ICON_COUNT:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2(62, 62)
		var ic := TSIcon.make("badge", 60, i)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(ic)
		b.modulate = Color.WHITE if i == selected else Color(1, 1, 1, 0.5)
		if i == selected:
			var ring := TSUI.sb(Color(0, 0, 0, 0), 99, 4, 0, 0)
			ring.border_color = TSUI.GOLD_DARK
			b.add_theme_stylebox_override("normal", ring)
		if on_pick.is_valid():
			b.pressed.connect(func(): on_pick.call(i))
		elif _create_icons == row:
			b.pressed.connect(func():
				_create_icon = i
				_fill_badges(row, i, Callable()))
		row.add_child(b)


func _refresh_create() -> void:
	var cost := TSProfile.CLUB_CREATE_COST
	_create_btn.text = "Create Club  ·  %s coins" % TSProfile.fmt_coins(cost)
	var name := _create_name.text.strip_edges()
	_create_btn.disabled = TSProfile.coin_count < cost or not TSProfile.is_valid_club_name(name)
	if name != "" and not TSFilter.is_clean(name):
		_create_hint.text = "That name isn't allowed -- please choose another."
	elif name != "" and not TSProfile.is_valid_club_name(name):
		_create_hint.text = "Club names are %d-%d letters, numbers or spaces." % [TSProfile.CLUB_NAME_MIN, TSProfile.CLUB_NAME_MAX]
	else:
		_create_hint.text = "You'll lead your own club -- others can find and join it."


# -- in a club --------------------------------------------------------------------------------

func _build_club_view() -> void:
	var head := TSUI.card(TSUI.CARD, 26, 14, 3)
	var row := TSUI.hbox(14)
	head.add_child(row)
	var badge := Button.new()
	badge.flat = true
	badge.focus_mode = Control.FOCUS_NONE
	badge.custom_minimum_size = Vector2(100, 100)
	var ic := TSIcon.make("badge", 100, TSProfile.club_icon_for(TSProfile.club_name))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(ic)
	badge.disabled = not TSProfile.club_is_owner
	badge.pressed.connect(_open_badge_pick)
	row.add_child(badge)
	var v := TSUI.vbox(2)
	TSUI.expand(v)
	v.add_child(TSUI.label(TSProfile.club_name, 32))
	v.add_child(TSUI.label(_club_subtitle(), 20, TSUI.MUTED))
	var note := TSProfile.club_message_for(TSProfile.club_name)
	v.add_child(TSUI.wrap(TSUI.label(note if note != "" else ("Tap Edit to leave a note for your club." if TSProfile.club_is_owner else "No note yet."), 20)))
	row.add_child(v)
	if TSProfile.club_is_owner:
		var edit := TSUI.button("Edit", TSUI.BUTTER, 20, Vector2(96, 56), 4)
		edit.pressed.connect(_open_message)
		row.add_child(edit)
	_club_view.add_child(head)
	_inner_tabs = TSUI.tabs(["Club", "Leaderboard"], func(i: int):
		_club_mode = i
		_refresh())
	TSUI.style_tabs(_inner_tabs, _club_mode)
	_club_view.add_child(_inner_tabs)
	if _club_mode == 0:
		_build_chat()
		var members := TSUI.vbox(8)
		for m in TSProfile.club_roster():
			members.add_child(_member_row(m))
		var ms := TSUI.scroll(members)
		ms.custom_minimum_size.y = 240
		ms.size_flags_vertical = Control.SIZE_FILL
		_club_view.add_child(ms)
		var leave := TSUI.button("Leave Club", TSUI.GREY, 22, Vector2(0, 58), 4)
		leave.pressed.connect(func():
			(_leave["title"] as Label).text = "Leave %s?" % TSProfile.club_name
			TSUI.reveal(_leave["root"], _leave["panel"]))
		_club_view.add_child(leave)
	else:
		_club_view.add_child(TSUI.label("Resets in %s" % TSUI.fmt_duration(TSProfile.seconds_until_weekly_reset()), 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		if TSProfile.club_leaderboard_reward_message != "":
			var banner := TSUI.card(TSUI.BUTTER, 20, 12, 2)
			banner.add_child(TSUI.wrap(TSUI.label(TSProfile.club_leaderboard_reward_message, 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
			_club_view.add_child(banner)
			TSProfile.club_leaderboard_reward_message = ""
		var list := TSUI.vbox(10)
		var entries := TSProfile.club_standings()
		for i in entries.size():
			list.add_child(_standing_row(i + 1, entries[i]))
		_club_view.add_child(TSUI.scroll(list))


func _club_subtitle() -> String:
	var members := 1
	var capacity := TSProfile.CLUB_DEFAULT_CAPACITY
	if not TSProfile.club_is_owner:
		for club in TSProfile.CLUB_LIST:
			if club["name"] == TSProfile.club_name:
				members = int(club["members"])
				capacity = int(club["capacity"])
	return "%d/%d members  ·  %s %s ago" % [members, capacity, "Founded" if TSProfile.club_is_owner else "Joined", _dur(TSProfile.club_tenure_seconds())]


static func _dur(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%dh" % maxi(seconds / 3600, 0) if seconds < 86400 else "%dd" % (seconds / 86400)


func _build_chat() -> void:
	var box := TSUI.card(Color(1.0, 0.95, 0.9), 24, 10, 2)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(8)
	box.add_child(v)
	_chat_list = TSUI.vbox(8)
	_chat_scroll = TSUI.scroll(_chat_list)
	v.add_child(_chat_scroll)
	var input_row := TSUI.hbox(8)
	_chat_input = _line_edit("Say something nice")
	_chat_input.max_length = TSProfile.CLUB_CHAT_LINE_MAX
	TSUI.expand(_chat_input)
	_chat_input.text_submitted.connect(func(_t): _send_chat())
	input_row.add_child(_chat_input)
	var send := TSUI.button("Send", TSUI.GREEN, 22, Vector2(100, 64), 4)
	send.pressed.connect(_send_chat)
	input_row.add_child(send)
	v.add_child(input_row)
	_club_view.add_child(box)
	_fill_chat()


func _fill_chat() -> void:
	for c in _chat_list.get_children():
		c.queue_free()
	if TSProfile.club_chat.is_empty():
		_chat_list.add_child(TSUI.label("No messages yet -- say hello!", 20, TSUI.MUTED))
	for line in TSProfile.club_chat:
		_chat_list.add_child(_chat_line(line))
	_scroll_chat_end()


func _chat_line(line: Dictionary) -> Control:
	var own: bool = line["is_player"]
	var row := TSUI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END if own else BoxContainer.ALIGNMENT_BEGIN
	if not own:
		row.add_child(TSIcon.make("critter", 44, TSProfile.npc_critter(hash(str(line["name"])))))
	var bubble := PanelContainer.new()
	var face := TSUI.sb(Color(1.0, 0.92, 0.72) if own else Color.WHITE, 20, 2, 0, 12)
	if own:
		face.corner_radius_bottom_right = 4
	else:
		face.corner_radius_bottom_left = 4
	bubble.add_theme_stylebox_override("panel", face)
	var v := TSUI.vbox(0)
	bubble.add_child(v)
	var ago := maxi(int(Time.get_unix_time_from_system()) - int(line["unix"]), 0)
	v.add_child(TSUI.label("%s  ·  %s" % [line["name"], "just now" if ago < 60 else ("%dm ago" % (ago / 60) if ago < 3600 else "%s ago" % _dur(ago))], 16, TSUI.MUTED))
	var text := TSUI.label(str(line["text"]), 22)
	if TSToon.hand_font().get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > 400:
		TSUI.wrap(text, 400)
	v.add_child(text)
	row.add_child(bubble)
	return row


func _scroll_chat_end() -> void:
	await get_tree().process_frame
	if is_inside_tree() and is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _send_chat() -> void:
	if not TSProfile.post_club_chat(_chat_input.text):
		return
	_chat_input.text = ""
	_fill_chat()
	await get_tree().create_timer(randf_range(1.5, 4.0)).timeout
	if is_inside_tree() and TSProfile.has_club and not TSProfile.club_chat_reply().is_empty() and is_instance_valid(_chat_list):
		_fill_chat()


func _member_row(m: Dictionary) -> Control:
	var me: bool = m["is_player"]
	var card := TSUI.card(Color(0.86, 0.96, 0.8) if me else TSUI.CARD, 20, 10, 2)
	var row := TSUI.hbox(10)
	card.add_child(row)
	row.add_child(TSIcon.make("critter", 52, int(m["critter"])))
	var v := TSUI.vbox(0)
	TSUI.expand(v)
	v.add_child(TSUI.label("%s (You)" % m["name"] if me else str(m["name"]), 22))
	v.add_child(TSUI.label("%s  ·  %s in club" % [m["rank"], _dur(int(m["tenure_seconds"]))], 18, TSUI.MUTED))
	row.add_child(v)
	row.add_child(TSIcon.make("star", 30))
	row.add_child(TSUI.label(str(m["stars"]), 22))
	return card


func _standing_row(rank: int, e: Dictionary) -> Control:
	var me: bool = e.get("is_player", false)
	var card := TSUI.card(Color(0.86, 0.96, 0.8) if me else TSUI.CARD, 22, 12, 3)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var rl := TSUI.label(str(rank), 30, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	rl.custom_minimum_size = Vector2(56, 56)
	h.add_child(TSFX.medal_plate(rank, rl))
	h.add_child(TSIcon.make("badge", 52, TSProfile.club_icon_for(str(e["name"]))))
	var n := TSUI.label("%s (Your Club)" % e["name"] if me else str(e["name"]), 22)
	n.clip_text = true
	TSUI.expand(n)
	h.add_child(n)
	if rank <= TSProfile.CLUB_LEADERBOARD_REWARDS.size():
		h.add_child(TSIcon.make("coin", 26))
		h.add_child(TSUI.label("+%s" % TSProfile.fmt_coins(TSProfile.CLUB_LEADERBOARD_REWARDS[rank - 1]), 18, TSUI.MUTED))
	h.add_child(TSIcon.make("star", 30))
	h.add_child(TSUI.label(str(e["score"]), 26))
	return card


# -- dialogs ------------------------------------------------------------------------------

func _build_dialogs() -> void:
	_detail = TSUI.dialog(self, 560)
	_leave = TSUI.dialog(self, 520)
	_message = TSUI.dialog(self, 580)
	_badge_pick = TSUI.dialog(self, 600)
	_intro = TSUI.dialog(self, 580)

	var lbox: VBoxContainer = _leave["box"]
	var lt := TSUI.title("Leave?", 40)
	lbox.add_child(lt)
	_leave["title"] = lt
	lbox.add_child(TSUI.wrap(TSUI.label("You can join another club, or come back, any time.", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
	var yes := TSUI.button("Leave Club", TSUI.CORAL, 26)
	yes.pressed.connect(func():
		TSUI.conceal(_leave["root"])
		TSProfile.leave_club()
		_refresh())
	lbox.add_child(yes)
	var no := TSUI.button("Stay", TSUI.GREEN, 26)
	no.pressed.connect(func(): TSUI.conceal(_leave["root"]))
	lbox.add_child(no)

	var ibox: VBoxContainer = _intro["box"]
	ibox.add_child(TSUI.title("Join a Club!", 44))
	ibox.add_child(TSUI.centered(TSIcon.make("clubs", 150)))
	for line in ["Team up with other hatchers.", "Every star you earn counts for your club.", "Top clubs each week win coins -- and you can chat!"]:
		var row := TSUI.hbox(10)
		row.add_child(TSIcon.make("heart", 34))
		row.add_child(TSUI.wrap(TSUI.label(line, 22), 440))
		ibox.add_child(row)
	var ok := TSUI.button("Let's go!", TSUI.PINK, 28)
	ok.pressed.connect(func(): TSUI.conceal(_intro["root"]))
	ibox.add_child(ok)
	TSUI.juice(self)


func _open_intro() -> void:
	TSUI.reveal(_intro["root"], _intro["panel"])


func _open_detail(club: Dictionary) -> void:
	_detail_club = str(club["name"])
	var box: VBoxContainer = _detail["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.centered(TSIcon.make("badge", 130, TSProfile.club_icon_for(_detail_club))))
	box.add_child(TSUI.title(_detail_club, 40))
	box.add_child(TSUI.label("%d/%d members" % [int(club["members"]), int(club["capacity"])], 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(TSUI.wrap(TSUI.label(TSProfile.club_message_for(_detail_club), 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
	var full: bool = int(club["members"]) >= int(club["capacity"])
	var join := TSUI.button("Club is full" if full else "Join Club", TSUI.GREEN, 28)
	join.disabled = full
	join.pressed.connect(func():
		if TSProfile.join_club(_detail_club):
			TSUI.conceal(_detail["root"])
			_refresh())
	box.add_child(join)
	var close := TSUI.button("Close", TSUI.GREY, 24, Vector2(0, 60))
	close.pressed.connect(func(): TSUI.conceal(_detail["root"]))
	box.add_child(close)
	TSUI.juice(box)
	TSUI.reveal(_detail["root"], _detail["panel"])


func _open_message() -> void:
	var box: VBoxContainer = _message["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Club Note", 40))
	var edit := TextEdit.new()
	edit.text = TSProfile.club_message
	edit.custom_minimum_size = Vector2(0, 180)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_font_override("font", TSToon.hand_font())
	edit.add_theme_font_size_override("font_size", 24)
	edit.add_theme_color_override("font_color", TSUI.INK)
	edit.add_theme_stylebox_override("normal", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	edit.add_theme_stylebox_override("focus", TSUI.sb(Color.WHITE, 18, 3, 0, 14))
	box.add_child(edit)
	var count := TSUI.label("", 18, TSUI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(count)
	var on_change := func():
		if edit.text.length() > TSProfile.CLUB_MESSAGE_MAX:
			edit.text = edit.text.left(TSProfile.CLUB_MESSAGE_MAX)
			edit.set_caret_column(edit.text.length())
		count.text = "%d/%d" % [edit.text.length(), TSProfile.CLUB_MESSAGE_MAX]
	edit.text_changed.connect(on_change)
	on_change.call()
	var save := TSUI.button("Save", TSUI.GREEN, 26)
	save.pressed.connect(func():
		TSProfile.set_club_message(edit.text)
		TSUI.conceal(_message["root"])
		_refresh())
	box.add_child(save)
	var cancel := TSUI.button("Cancel", TSUI.GREY, 24, Vector2(0, 60))
	cancel.pressed.connect(func(): TSUI.conceal(_message["root"]))
	box.add_child(cancel)
	TSUI.juice(box)
	TSUI.reveal(_message["root"], _message["panel"])


func _open_badge_pick() -> void:
	if not TSProfile.club_is_owner:
		return
	var box: VBoxContainer = _badge_pick["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Club Badge", 40))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(TSUI.centered(grid))
	_fill_badges(grid, TSProfile.club_icon, func(i: int):
		TSProfile.set_club_icon(i)
		TSUI.conceal(_badge_pick["root"])
		_refresh())
	var cancel := TSUI.button("Cancel", TSUI.GREY, 24, Vector2(0, 60))
	cancel.pressed.connect(func(): TSUI.conceal(_badge_pick["root"]))
	box.add_child(cancel)
	TSUI.juice(box)
	TSUI.reveal(_badge_pick["root"], _badge_pick["panel"])


func on_back_requested() -> bool:
	for d in [_detail, _leave, _message, _badge_pick, _intro]:
		if d["root"].visible:
			TSUI.conceal(d["root"])
			return true
	return false
