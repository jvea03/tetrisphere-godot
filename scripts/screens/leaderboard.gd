extends TSScreen

## The leaderboards (Duckdoku's LeaderboardScreen): Daily, Weekly and Season,
## scored in stars. Top 3 win coins, paid once a board resets (the prize waits
## on Home). The rivals are simulated locally -- there is no backend -- the
## same for everyone on a given day. The player's own row stays pinned at the
## bottom while it is scrolled out of view.

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
		_refresh())
	content.add_child(_tabs)
	_countdown = TSUI.label("", 22, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_countdown)
	_banner = TSUI.card(TSUI.BUTTER, 20, 12, 2)
	_banner.add_child(TSUI.wrap(TSUI.label("", 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
	content.add_child(_banner)
	_list = TSUI.vbox(10)
	_scroll = TSUI.scroll(_list)
	content.add_child(_scroll)
	_pinned = MarginContainer.new()
	content.add_child(_pinned)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _refresh_pinned.call_deferred())
	_info = TSUI.dialog(self, 580)
	var ibox: VBoxContainer = _info["box"]
	ibox.add_child(TSUI.title("Climb the Leaderboards", 38))
	for line in ["Win levels to earn stars.", "Climb the daily, weekly and season boards.", "Finish top 3 to win coins -- collect them on Home when the board resets."]:
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
	_refresh()


func _refresh() -> void:
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
	for i in entries.size():
		var row := _row(i + 1, entries[i])
		_list.add_child(row)
		if entries[i].get("is_player", false):
			_player_row = row
			_pinned.add_child(_row(i + 1, entries[i]))
	if entries.size() >= 3:
		_list.add_child(_podium(entries))
	_refresh_countdown()
	_scroll_to_player()


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
		var who := TSIcon.make("critter", steps[rank][2], TSProfile.avatar() if me else TSProfile.npc_critter(hash(str(entry["name"]))))
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
	box.add_child(TSUI.spacer(12))
	box.add_child(row)
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
	var dt := TSClock.datetime_dict()
	var day_secs := int(dt["hour"]) * 3600 + int(dt["minute"]) * 60 + int(dt["second"])
	var secs := 0
	match _tab:
		"daily":
			secs = 86400 - day_secs
		"weekly":
			secs = TSProfile.seconds_until_weekly_reset()
		_:   # the season: as the Battle Pass season
			secs = TSProfile.seconds_until_season_reset()
	_countdown.text = "%s in %s" % ["Resets" if _tab == "daily" else "Ends", TSUI.fmt_duration(maxi(secs, 0))]


func _row(rank: int, entry: Dictionary) -> Control:
	var me: bool = entry.get("is_player", false)
	var card := TSUI.card(Color(0.86, 0.96, 0.8) if me else TSUI.CARD, 22, 12, 3)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var rank_lbl := TSUI.label(str(rank), 30, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	rank_lbl.custom_minimum_size = Vector2(56, 56)
	h.add_child(TSFX.medal_plate(rank, rank_lbl))
	h.add_child(TSIcon.make("critter", 52, TSProfile.avatar() if me else TSProfile.npc_critter(hash(str(entry["name"])))))
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
	ch.add_child(TSUI.label(str(entry["stars"]), 26))
	h.add_child(chip)
	return card
