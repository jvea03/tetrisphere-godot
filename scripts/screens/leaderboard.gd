extends TSScreen

## The leaderboards (Duckdoku's LeaderboardScreen): Daily, Weekly and Season,
## scored in stars. Top 3 win coins, paid once a board resets (the prize waits
## on Home). The rivals are simulated locally -- there is no backend -- the
## same for everyone on a given day. The player's own row stays pinned at the
## bottom while it is scrolled out of view.

const TAB_INFO := {
	"daily": {"title": "Daily Leaderboard", "sub": "Win levels to earn stars -- one for every heart you had left. Top 3 each day win coins."},
	"weekly": {"title": "Weekly Leaderboard", "sub": "Stars add up across the week. Top 3 each week win coins."},
	"season": {"title": "Season Leaderboard", "sub": "Stars add up across the month. Top 3 each season win coins."},
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
	_refresh_countdown()
	_scroll_to_player()


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
	var dt := Time.get_datetime_dict_from_system()
	var day_secs := int(dt["hour"]) * 3600 + int(dt["minute"]) * 60 + int(dt["second"])
	var secs := 0
	match _tab:
		"daily":
			secs = 86400 - day_secs
		"weekly":
			secs = TSProfile.seconds_until_weekly_reset()
		_:
			var next := {"year": dt["year"], "month": int(dt["month"]) + 1, "day": 1, "hour": 0, "minute": 0, "second": 0}
			if next["month"] > 12:
				next["month"] = 1
				next["year"] = int(dt["year"]) + 1
			secs = int(Time.get_unix_time_from_datetime_dict(next)) - int(Time.get_unix_time_from_system()) - int(Time.get_time_zone_from_system().get("bias", 0)) * 60
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
