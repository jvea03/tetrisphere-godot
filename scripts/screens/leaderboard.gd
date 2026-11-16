extends TSScreen

## The leaderboards (Duckdoku's LeaderboardScreen): Daily, Weekly and Season,
## scored in stars, against real players (Online: Firebase). Top 3 win coins,
## paid once a board resets and its place is known (the prize waits on Home).
## Tapping another player opens their card: send a sticker, block, report.
## The player's own row stays pinned at the bottom while it is scrolled out of
## view.

const TAB_INFO := {
	"daily": {"title": "Daily Leaderboard", "sub": "Win levels to earn stars -- one for every heart you had left. Top 3 each day win coins."},
	"weekly": {"title": "Weekly Leaderboard", "sub": "Stars add up across the week. Top 3 each week win coins."},
	"season": {"title": "Season Leaderboard", "sub": "Stars add up all season -- it ends with the Battle Pass season. Top 3 win coins."},
}
const PERIODS := ["daily", "weekly", "season"]

var _tab := "daily"
var _tabs: PanelContainer
var _title: Label
var _sub: Label
var _countdown: Label
var _banner: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _pinned: MarginContainer
var _player_row: Control
var _info: Dictionary
var _status: Label            # connecting, offline, or only you so far
## What each board looked like when last shown this run: board -> {player key
## -> [rank, stars]} (the player's own also lasts across runs, in
## TSProfile.board_seen), so a refresh can show what changed since.
static var _seen := {}
const MOVE_SECONDS := 0.42


func tab_id() -> String:
	return "leaderboard"


func build() -> void:
	add_header("Leaderboard", false, false, func(): TSUI.reveal(_info["root"], _info["panel"]))
	var hero := TSUI.hbox(10)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(TSIcon.make("trophy", 110))
	var hv := TSUI.vbox(2)
	_title = TSUI.label("", 34)
	hv.add_child(_title)
	_sub = TSUI.wrap(TSUI.label("", 20, TSUI.MUTED), 460)
	hv.add_child(_sub)
	hero.add_child(hv)
	content.add_child(hero)
	_tabs = TSUI.tabs(["Daily", "Weekly", "Season"], func(i: int):
		_tab = PERIODS[i]
		TSUI.style_tabs(_tabs, i)
		_refresh()
		_fetch())
	content.add_child(_tabs)
	_countdown = TSUI.label("", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_countdown)
	_banner = TSUI.card(TSUI.BUTTER, 20, 12, 2)
	_banner.add_child(TSUI.wrap(TSUI.label("", 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
	content.add_child(_banner)
	_status = TSUI.wrap(TSUI.label("", 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER), 600)
	content.add_child(_status)
	_list = TSUI.vbox(10)
	_scroll = TSUI.scroll(_list)
	content.add_child(_scroll)
	_pinned = MarginContainer.new()
	content.add_child(_pinned)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _refresh_pinned.call_deferred())
	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("Climb the Leaderboards", 38))
	for line in ["Win levels to earn stars.", "Climb the daily, weekly and season boards against players everywhere.", "Finish top 3 to win coins -- collect them on Home when the board resets.", "Tap a player to send them a sticker."]:
		var row := TSUI.hbox(10)
		row.add_child(TSIcon.make("star", 36))
		row.add_child(TSUI.wrap(TSUI.label(line, 22), 440))
		ibox.add_child(row)
	var ok := TSUI.button("Got it", TSUI.PINK, 26)
	ok.pressed.connect(func(): TSUI.conceal(_info["root"]))
	ibox.add_child(ok)
	var tick := Timer.new()
	tick.wait_time = 30.0
	tick.autostart = true
	tick.timeout.connect(_refresh_countdown)
	add_child(tick)
	Online.boards_changed.connect(_on_boards_changed)
	TSProfile.push_boards()
	TSProfile.resolve_board_results(_refresh)
	_refresh()
	_fetch()
	Online.check_stickers(true)
	Online.stickers_arrived.connect(_on_stickers)
	TSStickerCards.show_received(self)


## Asks Online for every board at once (a minute fresh at most), so switching
## tabs shows its rows straight away.
func _fetch() -> void:
	for p in PERIODS:
		Online.fetch(TSProfile.current_board(p))


var _drawn := ""   # what the list shows now (tab and rows), so a fetch that changes nothing redraws nothing


## A board arrived: redraw only if the open tab's rows are different.
func _on_boards_changed() -> void:
	if _signature() != _drawn:
		_refresh()


func _signature() -> String:
	return _tab + JSON.stringify(TSProfile.standings_for(_tab).map(func(e: Dictionary) -> Array: return [e.get("uid", ""), e["stars"], e["name"], e.get("avatar", 0)]))


func _refresh() -> void:
	_drawn = _signature()
	if TSProfile.leaderboard_reward_message != "":
		(_banner.get_child(0) as Label).text = TSProfile.leaderboard_reward_message
		_banner.visible = true
		TSProfile.leaderboard_reward_message = ""
	else:
		_banner.visible = false
	_title.text = TAB_INFO[_tab]["title"]
	_sub.text = TAB_INFO[_tab]["sub"]
	for c in _list.get_children():
		c.queue_free()
	for c in _pinned.get_children():
		c.queue_free()
	_player_row = null
	var entries: Array = TSProfile.standings_for(_tab)
	var fetched := not Online.entries(TSProfile.current_board(_tab)).is_empty()
	if entries.size() > 1:
		_status.text = ""
	elif fetched:
		_status.text = "Only you so far -- win levels to stay on top!"
	elif Online.last_error != "":
		_status.text = "Can't reach the leaderboard right now. Check your connection."
	else:
		_status.text = "Loading the leaderboard..."
	_status.visible = _status.text != ""
	# What changed since this board was last shown: only once its rows have
	# arrived (the first look, with only the player on it, says nothing).
	var board := TSProfile.current_board(_tab)
	var before: Dictionary = (_seen.get(board, {}) as Dictionary).duplicate()
	if TSProfile.board_seen.has(board) and not before.has("me"):
		before["me"] = TSProfile.board_seen[board]
	var compare := fetched and not before.is_empty()
	var now := {}
	var moves: Array = []   # [row card, places it rose (negative: fell)]
	# The top three on their podium, over the list.
	if entries.size() >= 3:
		_list.add_child(_podium(entries))
	for i in entries.size():
		var e: Dictionary = entries[i]
		var key := "me" if e.get("is_player", false) else str(e.get("uid", e["name"]))
		now[key] = [i + 1, int(e["stars"])]
		var was: Variant = before.get(key) if compare else null
		var holder := _row(i + 1, e, was if was != null else ([] if not compare else ["new"]))
		_list.add_child(holder)
		if was != null and int(was[0]) != i + 1:
			moves.append([holder.get_child(0), int(was[0]) - (i + 1), key == "me"])
		if e.get("is_player", false):
			_player_row = holder
			_pinned.add_child(_row(i + 1, e, []))
	if fetched:
		_seen[board] = now
		if now.has("me"):
			TSProfile.board_seen[board] = now["me"]
	_refresh_countdown()
	_scroll_to_player()
	if not moves.is_empty():
		_play_moves(moves)


## Each row that moved glides from where it was to where it is now (the
## player's own on top, with a bounce as it lands).
func _play_moves(moves: Array) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# One row's height (a row's holder, not the podium over the list).
	var holder: Control = (moves[0][0] as Control).get_parent()
	var step := holder.size.y + float(_list.get_theme_constant("separation"))
	if step <= 0.0:
		return
	var span := float(_list.get_child_count()) * step
	for m in moves:
		var card: Control = m[0]
		var from := clampf(float(m[1]) * step, -span, span)
		card.position.y = from
		card.z_index = 2 if m[2] else 1
		var tw := card.create_tween()
		tw.tween_property(card, "position:y", 0.0, MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if m[2]:
			card.pivot_offset = card.size * 0.5
			tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.08)
			tw.tween_property(card, "scale", Vector2.ONE, 0.12)
			tw.tween_callback(func() -> void: TSSfx.play("ding" if int(m[1]) > 0 else "tick"))


## Under the list, the board's top three on a podium: gold in the middle,
## silver and bronze either side, each critter standing on its step.
func _podium(entries: Array) -> Control:
	var row := TSUI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var steps := {1: [TSUI.GOLD, 132.0, 104.0], 2: [Color(0.84, 0.87, 0.93), 96.0, 88.0], 3: [Color(0.94, 0.73, 0.55), 72.0, 84.0]}
	for rank in [2, 1, 3]:
		var entry: Dictionary = entries[rank - 1]
		var me: bool = entry.get("is_player", false)
		var col := TSUI.vbox(0)
		col.size_flags_vertical = Control.SIZE_SHRINK_END
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var who := TSIcon.make("critter", steps[rank][2], TSProfile.avatar() if me else int(entry.get("avatar", 0)))
		who.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if rank == 1:   # the winner's crown, tipped on its head
			var crown := TSIcon.make("crown", 70)
			crown.size = Vector2(70, 70)
			crown.position = Vector2(steps[rank][2] * 0.5 - 35.0, -40.0)
			crown.rotation = -0.12
			who.add_child(crown)
			col.add_child(TSUI.spacer(34))
		col.add_child(who)
		var step := PanelContainer.new()
		step.add_theme_stylebox_override("panel", TSUI.sb(steps[rank][0], 14, 3, 4, 8))
		step.custom_minimum_size = Vector2(150, steps[rank][1])
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step.add_child(TSUI.label(str(rank), 40, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(step)
		row.add_child(col)
	var box := TSUI.vbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	box.add_child(TSUI.spacer(6))   # a little room before the list under it
	return box


func _refresh_pinned() -> void:
	if _player_row == null or not is_instance_valid(_player_row):
		_pinned.visible = false
		return
	var view := _scroll.get_global_rect()
	var r := _player_row.get_global_rect()
	_pinned.visible = r.end.y > view.end.y or r.position.y < view.position.y


func _scroll_to_player() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or _player_row == null or not is_instance_valid(_player_row):
		return
	_scroll.scroll_vertical = int(maxf(_player_row.position.y - (_scroll.size.y - _player_row.size.y) / 2.0, 0.0))
	await get_tree().process_frame
	if is_inside_tree():
		_refresh_pinned()


func _refresh_countdown() -> void:
	var secs := 0
	match _tab:   # the boards reset at UTC midnight, the same moment for everyone
		"daily":
			secs = TSProfile.seconds_until_board_day()
		"weekly":
			secs = TSProfile.seconds_until_board_week()
		_:   # the season: as the Battle Pass season
			secs = TSProfile.seconds_until_season_reset()
	_countdown.text = "%s in %s" % ["Resets" if _tab == "daily" else "Ends", TSUI.fmt_duration(maxi(secs, 0))]


## A row, in a holder of its own height so the card can glide inside it
## (_play_moves). `was` is [rank, stars] when it was last shown, ["new"] for
## someone who wasn't there then, or [] for nothing to show.
func _row(rank: int, entry: Dictionary, was: Array = []) -> Control:
	var me: bool = entry.get("is_player", false)
	var card := TSUI.card(Color(0.86, 0.96, 0.8) if me else TSUI.CARD, 22, 12, 3)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var rank_lbl := TSUI.label(str(rank), 30, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.custom_minimum_size = Vector2(56, 56)
	h.add_child(TSFX.medal_plate(rank, rank_lbl))
	h.add_child(TSIcon.make("critter", 52, TSProfile.avatar() if me else int(entry.get("avatar", 0))))
	var name_lbl := TSUI.label("%s (You)" % entry["name"] if me else str(entry["name"]), 24)
	name_lbl.clip_text = true
	TSUI.expand(name_lbl)
	h.add_child(name_lbl)
	if rank <= 3:
		var table: Array = TSProfile.LEADERBOARD_DAILY_COIN_REWARDS
		if _tab == "weekly":
			table = TSProfile.LEADERBOARD_WEEKLY_COIN_REWARDS
		elif _tab == "season":
			table = TSProfile.LEADERBOARD_SEASON_COIN_REWARDS
		h.add_child(TSIcon.make("coin", 26))
		h.add_child(TSUI.label("+%s" % TSProfile.fmt_coins(table[rank - 1]), 18, TSUI.MUTED))
	var chip := TSUI.card(TSUI.BUTTER if not me else TSUI.MINT, 99, 8, 0)
	var ch := TSUI.hbox(4)
	chip.add_child(ch)
	ch.add_child(TSIcon.make("star", 32))
	var stars_lbl := TSUI.label(str(entry["stars"]), 26)
	ch.add_child(stars_lbl)
	# What changed since last time: places up or down, or new here; stars
	# gained count up.
	if was.size() == 1:
		h.add_child(TSUI.pill("NEW", TSUI.SKY, 14))
	elif was.size() == 2:
		var moved := int(was[0]) - rank
		if moved != 0:
			h.add_child(_move_chip(moved))
		var old_stars := int(was[1])
		var new_stars := int(entry["stars"])
		if new_stars > old_stars:
			stars_lbl.text = str(old_stars)
			var tw := stars_lbl.create_tween()
			tw.tween_interval(0.1)
			tw.tween_method(func(v: float) -> void: stars_lbl.text = str(roundi(v)), float(old_stars), float(new_stars), 0.45)
	h.add_child(chip)
	if not me:
		# Another player: tap for their card (a sticker, block, report).
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent) -> void:
			var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
			if not down:
				return
			card.pivot_offset = card.size * 0.5
			card.create_tween().tween_property(card, "scale", Vector2(0.97, 0.97) if e.pressed else Vector2.ONE, 0.06)
			if not e.pressed and not _scroll_moved():
				_open_sticker_picker(card, entry))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.custom_minimum_size = Vector2(0, card.get_combined_minimum_size().y)
	holder.add_child(card)
	holder.resized.connect(func() -> void: card.size = Vector2(holder.size.x, holder.custom_minimum_size.y))
	return holder


## Places up (green, an arrow up) or down (red, an arrow down).
func _move_chip(moved: int) -> Control:
	var up := moved > 0
	var chip := TSUI.card(Color(0.78, 0.94, 0.76) if up else Color(1.0, 0.82, 0.82), 99, 6, 0)
	var row := TSUI.hbox(2)
	chip.add_child(row)
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(16, 16)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(8, 2), Vector2(15, 14), Vector2(1, 14)]) if up else PackedVector2Array([Vector2(1, 2), Vector2(15, 2), Vector2(8, 14)])
		arrow.draw_colored_polygon(pts, Color(0.2, 0.62, 0.3) if up else Color(0.86, 0.28, 0.32)))
	row.add_child(arrow)
	row.add_child(TSUI.label(str(absi(moved)), 18, TSUI.INK))
	return chip


var _press_scroll := 0


## A drag through the list (scrolling it) isn't a tap on a row.
func _scroll_moved() -> bool:
	return absi(_scroll.scroll_vertical - _press_scroll) > 12


func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_press_scroll = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0


## Stickers show only here, while the leaderboard is open; any that arrive
## after the player has left wait in Online.received for their next visit.
func _on_stickers() -> void:
	if is_inside_tree() and is_visible_in_tree():
		TSStickerCards.show_received(self)


# -- stickers ----------------------------------------------------------------------
# As in Duckdoku: tap a rival's row and a speech bubble opens over it with the
# stickers this player has; tap one and it arcs onto the row, slaps down,
# wobbles and peels off, with a toast. One sticker per player every
# STICKER_COOLDOWN seconds (the bubble says how long is left). Block and
# Report sit at the bubble's foot.

const STICKER_COOLDOWN := 600
const STICKER_STATE := "user://stickers.cfg"
static var _sent_at := {}   # player uid -> when this player last sent them one (also in STICKER_STATE)
var _picker: Control = null


static func _sticker_wait(uid: String) -> int:
	if _sent_at.is_empty() and TSProfile.persist:
		var cfg := ConfigFile.new()
		if cfg.load(STICKER_STATE) == OK:
			for k in cfg.get_section_keys("sent") if cfg.has_section("sent") else []:
				_sent_at[k] = int(cfg.get_value("sent", k, 0))
	return maxi(int(_sent_at.get(uid, 0)) + STICKER_COOLDOWN - int(Time.get_unix_time_from_system()), 0)


static func _note_sent(uid: String, at: int) -> void:
	if at > 0:
		_sent_at[uid] = at
	else:
		_sent_at.erase(uid)
	if TSProfile.persist:
		var cfg := ConfigFile.new()
		for k in _sent_at:
			cfg.set_value("sent", k, _sent_at[k])
		cfg.save(STICKER_STATE)


func _close_sticker_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		var p := _picker
		_picker = null
		var t := p.create_tween()
		t.tween_property(p, "modulate:a", 0.0, 0.1)
		t.tween_callback(p.queue_free)


## A speech bubble over the row: who it's for, the stickers (popping in one
## by one), and Block / Report. A tap outside it closes it.
func _open_sticker_picker(row: Control, entry: Dictionary) -> void:
	_close_sticker_picker()
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 40
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_sticker_picker())
	add_child(shade)
	_picker = shade
	var bubble := PanelContainer.new()
	var face := TSUI.sb(Color.WHITE, 24, 3, 3, 12)
	face.shadow_color = Color(TSUI.INK, 0.25)
	face.shadow_size = 10
	face.shadow_offset = Vector2(0, 4)
	bubble.add_theme_stylebox_override("panel", face)
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(bubble)
	var v := TSUI.vbox(6)
	bubble.add_child(v)
	v.add_child(TSUI.label("Send %s a sticker" % str(entry["name"]), 20, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var uid := str(entry.get("uid", ""))
	var wait := _sticker_wait(uid)
	var owned: Array = TSStickers.owned()
	var cell := 96.0 if owned.size() <= 3 else 86.0
	var grid := GridContainer.new()
	grid.columns = mini(owned.size(), 4)   # four to a row, so each is big enough to tap
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	var faces: Array = []
	for id: String in owned:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(cell, cell + 22.0)
		var art := TSIcon.make("sticker", cell - 8.0, 0, id)
		art.position = Vector2(4, 0)
		art.size = Vector2(cell - 8.0, cell - 8.0)
		art.pivot_offset = art.size * 0.5
		b.add_child(art)
		var cap := TSUI.label(TSStickers.sticker_name(id), 15, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		cap.position = Vector2(-8, cell - 6.0)
		cap.size = Vector2(cell + 16.0, 22)
		b.add_child(cap)
		b.disabled = wait > 0
		if wait > 0:
			art.modulate.a = 0.4
		b.button_down.connect(func() -> void: art.create_tween().tween_property(art, "scale", Vector2(0.85, 0.85), 0.05))
		b.pressed.connect(func() -> void: _send_sticker(id, art, row, entry))
		grid.add_child(b)
		faces.append(art)
	var center := CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	if wait > 0:
		@warning_ignore("integer_division")
		v.add_child(TSUI.label("You can send another in %dm %02ds" % [wait / 60, wait % 60], 16, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var links := TSUI.hbox(18)
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["Block", func() -> void:
			TSStickerCards._block(uid)
			_close_sticker_picker()
			_refresh()], ["Report Name", func() -> void:
			Online.report(uid, str(entry["name"]))
			_close_sticker_picker()
			_sticker_toast("Thanks -- we'll take a look.")]]:
		var link := Button.new()
		link.flat = true
		link.focus_mode = Control.FOCUS_NONE
		link.text = pair[0]
		link.add_theme_font_size_override("font_size", 15)
		link.add_theme_color_override("font_color", TSUI.MUTED)
		link.pressed.connect(pair[1])
		links.add_child(link)
	v.add_child(links)
	# Over the row, or under it near the top of the screen.
	bubble.reset_size()
	var rr := row.get_global_rect()
	var y := rr.position.y - bubble.size.y - 6.0
	if y < 120.0:
		y = rr.end.y + 6.0
	bubble.global_position = Vector2((get_viewport_rect().size.x - bubble.size.x) * 0.5, y)
	bubble.pivot_offset = Vector2(bubble.size.x * 0.5, bubble.size.y if y < rr.position.y else 0.0)
	bubble.scale = Vector2(0.6, 0.6)
	bubble.modulate.a = 0.0
	var t := bubble.create_tween().set_parallel(true)
	t.tween_property(bubble, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(bubble, "modulate:a", 1.0, 0.08)
	TSSfx.play("pop1")
	for k in faces.size():
		var f: Control = faces[k]
		f.scale = Vector2(0.3, 0.3)
		var ft := f.create_tween()
		ft.tween_interval(0.04 + 0.035 * k)
		ft.tween_property(f, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The sticker arcs from the bubble onto the rival's row with a spin, slaps
## down (the row jolts, a sparkle, a buzz), wobbles, then peels off. It is
## sent at once; a failed send lifts the cooldown and says so.
func _send_sticker(id: String, from_face: Control, row: Control, entry: Dictionary) -> void:
	var start := from_face.get_global_rect()
	_close_sticker_picker()
	var uid := str(entry.get("uid", ""))
	var now := int(Time.get_unix_time_from_system())
	_note_sent(uid, now)
	var who := str(entry["name"])
	Online.send_sticker(uid, id, func(ok: bool) -> void:
		if ok:
			TSProfile.record_quest_event("sticker")   # the sticker quests; the cooldown stops farming
		else:
			_note_sent(uid, 0)
			if is_inside_tree():
				_sticker_toast("Couldn't send that to %s. Try again in a bit." % who))
	if not is_instance_valid(row):
		return
	var s := TSIcon.make("sticker", 76, 0, id)
	s.size = Vector2(76, 76)
	s.pivot_offset = s.size * 0.5
	s.top_level = true
	s.z_index = 60
	add_child(s)
	var rr := row.get_global_rect()
	var land := Vector2(rr.position.x + rr.size.x * 0.6, rr.get_center().y)
	var from := start.get_center()
	var mid := (from + land) * 0.5 + Vector2(0, -90)
	var path := func(p: float) -> void:
		s.global_position = from.lerp(mid, p).lerp(mid.lerp(land, p), p) - s.size * 0.5
		s.rotation = (1.0 - p) * -TAU * 0.75
		s.scale = Vector2.ONE * lerpf(1.0, 1.4, sin(p * PI) * 0.6 + p * 0.4)
	path.call(0.0)
	TSSfx.play("whoosh")
	var t := s.create_tween()
	t.tween_method(path, 0.0, 1.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		if is_instance_valid(row):
			row.pivot_offset = row.size * 0.5
			var jolt := row.create_tween()
			jolt.tween_property(row, "scale", Vector2(1.03, 0.94), 0.05)
			jolt.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		TSSfx.play("snap")
		TSFX.sparkle_burst_at(self, Rect2(land - Vector2(40, 40), Vector2(80, 80)))
		TSHaptics.light())
	t.tween_property(s, "scale", Vector2(1.6, 1.1), 0.05)
	t.tween_property(s, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "rotation", 0.18, 0.16)
	t.tween_property(s, "rotation", -0.1, 0.1)
	t.tween_property(s, "rotation", 0.12, 0.1)
	t.tween_interval(0.45)
	t.tween_property(s, "global_position:y", land.y - s.size.y * 0.5 - 30.0, 0.25)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.25)
	t.tween_callback(s.queue_free)
	_sticker_toast("%s sent to %s!" % [TSStickers.sticker_name(id), who])


var _toast: Control = null


func _sticker_toast(text: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()   # one toast at a time
	var lbl := TSUI.outlined(TSUI.label(text, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), TSUI.INK, 8)
	lbl.top_level = true
	lbl.z_index = 70
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(get_viewport_rect().size.x, 36)
	lbl.global_position = Vector2(0, _scroll.get_global_rect().end.y - 80.0)
	lbl.modulate.a = 0.0
	add_child(lbl)
	_toast = lbl
	var t := lbl.create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(lbl, "global_position:y", lbl.global_position.y - 16.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.3)
	t.tween_property(lbl, "modulate:a", 0.0, 0.25)
	t.tween_callback(lbl.queue_free)
