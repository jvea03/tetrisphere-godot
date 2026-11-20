extends TSScreen

## The Snowball Fight (TSSnowball). On top, the battle: two snow forts, a
## squad of gingerbread people behind one and of snowmen behind the other,
## lobbing snowballs at each other under falling snow. Then the score --
## both teams' totals on a tug-of-war bar, which team the player is on and
## whether it's ahead -- the time left, the player's own throws with a prize
## at each milestone (claimed here), the team prize, and PLAY. Under the
## battle, the Giant Snowball (mash it every six hours) and how snowballs
## are earned. A finished weekend's result is shown first, once.

const FROST := Color(0.88, 0.94, 1.0)

var _field: SnowBattle
var _blast_btn: Button
var _blast_bar: ProgressBar
var _blast_note: Label
var _mash_left := -1.0   # seconds of mashing left; -1 not mashing
var _taps := 0
var _flying := false     # the Giant Snowball is in the air
var _blast_gain := 0     # what it threw, shown when it lands
var _top_team := ""      # the team the Top Throwers tab is showing
var _main_tabs: PanelContainer
var _top_tabs: PanelContainer
var _top_list: VBoxContainer
var _top_status: Label

var _red_total: Label
var _green_total: Label
var _tug: Control
var _status: Label
var _ends: Label
var _mine: Label
var _miles: VBoxContainer
var _toast: PanelContainer
var _toast_text: Label
var _tick := 0.0


func build() -> void:
	TSProfile.ensure_loaded()
	TSSnowball.roll()
	add_header("Snowball Fight", true)
	var list := TSUI.vbox(14)
	var battle_scroll := TSUI.scroll(list)
	if TSSnowball.is_live():
		var top_scroll := _top_view()
		top_scroll.visible = false
		_main_tabs = TSUI.tabs(["Battle", "Top Throwers"], func(i: int):
			TSUI.style_tabs(_main_tabs, i)
			battle_scroll.visible = i == 0
			top_scroll.visible = i == 1
			if i == 1:
				_show_top())
		content.add_child(_main_tabs)
		content.add_child(battle_scroll)
		content.add_child(top_scroll)
		TSSnowball.push_board(true)
		Online.boards_changed.connect(_on_boards_changed)
	else:
		content.add_child(battle_scroll)
	var res := TSSnowball.take_result()
	if not res.is_empty():
		list.add_child(_result_card(res))
	list.add_child(_battle_card())
	if TSSnowball.is_live():
		_toast = TSUI.card(TSUI.BUTTER, 20, 12, 3)
		_toast_text = TSUI.wrap(TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		_toast.add_child(_toast_text)
		_toast.visible = false
		list.add_child(_toast)
		list.add_child(_blast_card())
		list.add_child(_how_card())
		list.add_child(_score_card())
		list.add_child(_throws_card())
		list.add_child(_prize_card())
		list.add_child(_play_button())
	else:
		var card := TSUI.card(TSUI.CARD, 26, 18, 4)
		card.add_child(TSUI.wrap(TSUI.label("The next Snowball Fight starts on Friday. Pop pieces all weekend to throw snowballs for your team!", 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)))
		list.add_child(card)
	list.add_child(TSUI.spacer(10))
	_refresh()


func _process(delta: float) -> void:
	if _mash_left >= 0.0:
		_mash_left -= delta
		_blast_btn.text = "MASH!  %.1f" % maxf(_mash_left, 0.0)
		if _mash_left <= 0.0:
			_throw_giant()
	_tick += delta
	if _tick >= 1.0 and TSSnowball.is_live():
		_tick = 0.0
		_refresh_score()
		_refresh_blast()


## The battle: an animated scene, with which team the player's on over it.
func _battle_card() -> Control:
	var card := TSUI.card(FROST, 28, 0, 4)
	var field := SnowBattle.new()
	field.custom_minimum_size = Vector2(0, 320)
	field.mine = TSSnowball.team
	field.giant_landed.connect(_on_giant_landed)
	_field = field
	card.add_child(field)
	if TSSnowball.is_live():
		var pill := TSUI.pill("You're on %s!" % TSSnowball.TEAM_NAMES[TSSnowball.team], TSSnowball.TEAM_COLORS[TSSnowball.team], 22, Color.WHITE)
		(pill.get_meta("label") as Label).add_theme_color_override("font_outline_color", TSUI.INK)
		(pill.get_meta("label") as Label).add_theme_constant_override("outline_size", 6)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var over := TSUI.vbox(0)
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.add_child(TSUI.spacer(12))
		over.add_child(pill)
		card.add_child(over)
	return card



## How snowballs are earned, said plainly.
func _how_card() -> Control:
	var card := TSUI.card(TSUI.CARD, 28, 16, 4)
	var v := TSUI.vbox(10)
	card.add_child(v)
	v.add_child(TSUI.label("How to earn snowballs", 28))
	for row: Array in [
		["egg", "Play any level: every piece you pop throws 1 snowball for your team."],
		["snowball", "Giant Snowball: mash the button above for %d-%d snowballs, once every %d hours." % [TSSnowball.BLAST_MIN, TSSnowball.BLAST_MAX, TSSnowball.BLAST_COOLDOWN / 3600]],
		["chest", "Throw enough for the prizes below, and %d by Sunday night to share the team prize." % TSSnowball.MIN_TO_PLACE],
	]:
		var h := TSUI.hbox(12)
		var icon := TSIcon.make(str(row[0]), 48)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(icon)
		var l := TSUI.wrap(TSUI.label(str(row[1]), 20, TSUI.INK))
		TSUI.expand(l)
		h.add_child(l)
		v.add_child(h)
	return card


## The Giant Snowball: tap to start, mash for a few seconds, and it flies.
func _blast_card() -> Control:
	var card := TSUI.card(Color(0.9, 0.96, 1.0), 28, 16, 4)
	var v := TSUI.vbox(10)
	card.add_child(v)
	var head := TSUI.hbox(10)
	head.add_child(TSIcon.make("snowball", 64))
	var hv := TSUI.vbox(0)
	TSUI.expand(hv)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(TSUI.label("Giant Snowball", 28))
	_blast_note = TSUI.wrap(TSUI.label("", 18, TSUI.MUTED))
	hv.add_child(_blast_note)
	head.add_child(hv)
	v.add_child(head)
	_blast_bar = TSUI.bar(TSUI.SKY, 18)
	_blast_bar.max_value = TSSnowball.BLAST_TAPS
	_blast_bar.visible = false
	v.add_child(_blast_bar)
	_blast_btn = TSUI.button("", TSUI.SKY, 30, Vector2(0, 84))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_blast_btn.add_theme_color_override(k, Color.WHITE)
	_blast_btn.add_theme_color_override("font_outline_color", TSUI.INK)
	_blast_btn.add_theme_constant_override("outline_size", 8)
	_blast_btn.button_down.connect(_mash)
	v.add_child(_blast_btn)
	_refresh_blast()
	return card


## A tap on the Giant Snowball button: the first starts the mashing, every
## one after grows the ball.
func _mash() -> void:
	if _mash_left < 0.0:
		if not TSSnowball.blast_ready() or _flying:
			return
		_mash_left = TSSnowball.BLAST_SECONDS
		_taps = 0
		_blast_bar.visible = true
	_taps = mini(_taps + 1, TSSnowball.BLAST_TAPS)
	_blast_bar.value = _taps
	_field.charge = float(_taps) / float(TSSnowball.BLAST_TAPS)
	TSSfx.play("tick", 0.8 + 0.6 * _field.charge)
	TSHaptics.light()
	_blast_btn.scale = Vector2(0.94, 0.94)
	_blast_btn.pivot_offset = _blast_btn.size * 0.5
	create_tween().tween_property(_blast_btn, "scale", Vector2.ONE, 0.12)


## Mashing's over: the snowballs are thrown, and the Giant Snowball flies.
func _throw_giant() -> void:
	_mash_left = -1.0
	_blast_bar.visible = false
	_blast_gain = TSSnowball.blast(_taps)
	_flying = true
	_field.launch()
	TSSfx.play("whoosh")
	_refresh_blast()


func _on_giant_landed() -> void:
	_flying = false
	TSSfx.play("puff")
	TSHaptics.medium()
	if _blast_gain > 0:
		_toast_text.text = "Giant Snowball! +%d snowballs for %s" % [_blast_gain, TSSnowball.TEAM_NAMES[TSSnowball.team]]
		_toast.visible = true
		_blast_gain = 0
	_refresh()


func _refresh_blast() -> void:
	if _blast_btn == null or _mash_left >= 0.0:
		return
	var ready := TSSnowball.blast_ready() and not _flying
	_blast_btn.disabled = not ready
	if ready:
		_blast_btn.text = "THROW IT!"
		_blast_note.text = "Tap, then mash as fast as you can for %d seconds: %d-%d snowballs." % [int(TSSnowball.BLAST_SECONDS), TSSnowball.BLAST_MIN, TSSnowball.BLAST_MAX]
	else:
		_blast_btn.text = "Ready in " + TSUI.fmt_duration(TSSnowball.blast_wait())
		_blast_note.text = "Rolling a new one. You can throw a Giant Snowball every %d hours." % (TSSnowball.BLAST_COOLDOWN / 3600)



# -- top throwers ------------------------------------------------------------------

## The Top Throwers tab: each team's best this weekend, from the online
## boards (TSSnowball.standings), the player's own team first.
func _top_view() -> ScrollContainer:
	var v := TSUI.vbox(12)
	var hero := TSUI.hbox(10)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(TSIcon.make("trophy", 90))
	var hv := TSUI.vbox(2)
	hv.add_child(TSUI.label("Top Throwers", 32))
	hv.add_child(TSUI.wrap(TSUI.label("Who's thrown the most snowballs for each team this weekend.", 19, TSUI.MUTED), 440))
	hero.add_child(hv)
	v.add_child(hero)
	_top_team = TSSnowball.team
	var names: Array = []
	for t: String in [TSSnowball.team, TSSnowball.rival()]:
		names.append(TSSnowball.TEAM_NAMES[t].trim_prefix("Team "))
	_top_tabs = TSUI.tabs(names, func(i: int):
		TSUI.style_tabs(_top_tabs, i)
		_top_team = TSSnowball.team if i == 0 else TSSnowball.rival()
		_show_top())
	v.add_child(_top_tabs)
	_top_status = TSUI.wrap(TSUI.label("", 21, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_top_status)
	_top_list = TSUI.vbox(8)
	v.add_child(_top_list)
	v.add_child(TSUI.spacer(10))
	return TSUI.scroll(v)


func _show_top() -> void:
	Online.fetch(TSSnowball.board(_top_team))
	_refresh_top()


func _on_boards_changed() -> void:
	if _top_list != null and _top_list.is_visible_in_tree():
		_refresh_top()


func _refresh_top() -> void:
	for c in _top_list.get_children():
		c.queue_free()
	var rows := TSSnowball.standings(_top_team)
	var fetched := not Online.entries(TSSnowball.board(_top_team)).is_empty()
	var mine := _top_team == TSSnowball.team
	if not Online.enabled():
		_top_status.text = "The Top Throwers board isn't available right now."
	elif rows.is_empty() or (rows.size() == 1 and mine and fetched):
		_top_status.text = ("Only you so far -- pop pieces to stay on top!" if mine else "Nobody on %s has thrown yet." % TSSnowball.TEAM_NAMES[_top_team]) if fetched else "Loading the top throwers..."
	elif not fetched and Online.last_error != "":
		_top_status.text = "Can't reach the leaderboard right now. Check your connection."
	else:
		_top_status.text = ""
	_top_status.visible = _top_status.text != ""
	for i in mini(rows.size(), Online.TOP_N):
		_top_list.add_child(_top_row(i + 1, rows[i]))


func _top_row(rank: int, entry: Dictionary) -> Control:
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
	var chip := TSUI.card(FROST if not me else TSUI.MINT, 99, 8, 0)
	var ch := TSUI.hbox(4)
	chip.add_child(ch)
	ch.add_child(TSIcon.make("snowball", 32))
	ch.add_child(TSUI.label(TSProfile.fmt_coins(int(entry["stars"])), 26))
	h.add_child(chip)
	return card


## Both teams' totals, the tug-of-war between them, who's ahead, time left.
func _score_card() -> Control:
	var card := TSUI.card(TSUI.CARD, 28, 16, 4)
	var v := TSUI.vbox(10)
	card.add_child(v)
	var row := TSUI.hbox(8)
	v.add_child(row)
	var left := TSUI.vbox(0)
	TSUI.expand(left)
	left.add_child(TSUI.label(TSSnowball.TEAM_NAMES["red"], 20, TSUI.MUTED))
	_red_total = TSUI.label("", 32, TSSnowball.TEAM_COLORS["red"].darkened(0.25))
	left.add_child(_red_total)
	row.add_child(left)
	var vs := TSUI.label("VS", 26, TSUI.INK)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	var right := TSUI.vbox(0)
	TSUI.expand(right)
	right.add_child(TSUI.label(TSSnowball.TEAM_NAMES["green"], 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	_green_total = TSUI.label("", 32, TSSnowball.TEAM_COLORS["green"].darkened(0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_green_total)
	row.add_child(right)
	_tug = TugBar.new()
	_tug.custom_minimum_size = Vector2(0, 44)
	v.add_child(_tug)
	_status = TSUI.wrap(TSUI.label("", 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_status)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", TSUI.sb(FROST, 99, 2, 0, 12))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pr := TSUI.hbox(6)
	pill.add_child(pr)
	pr.add_child(TSIcon.make("clock", 26))
	_ends = TSUI.label("", 19, TSUI.INK)
	pr.add_child(_ends)
	v.add_child(pill)
	return card


## The player's throws, and a prize at each milestone.
func _throws_card() -> Control:
	var card := TSUI.card(TSUI.CARD, 28, 16, 4)
	var v := TSUI.vbox(10)
	card.add_child(v)
	var head := TSUI.hbox(10)
	head.add_child(TSIcon.make("snowball", 64))
	var hv := TSUI.vbox(0)
	TSUI.expand(hv)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(TSUI.label("Your snowballs", 28))
	hv.add_child(TSUI.wrap(TSUI.label("Every piece you pop throws one for your team.", 18, TSUI.MUTED)))
	head.add_child(hv)
	_mine = TSUI.label("", 40, TSUI.INK)
	_mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_mine)
	v.add_child(head)
	_miles = TSUI.vbox(8)
	v.add_child(_miles)
	return card


func _milestone_row(i: int) -> Control:
	var m: Dictionary = TSSnowball.MILESTONES[i]
	var at := int(m["at"])
	var reached := TSSnowball.milestone_reached(i)
	var done := TSSnowball.milestone_claimed(i)
	var card := TSUI.card(Color(0.86, 0.97, 0.88) if done else (Color(1.0, 0.95, 0.76) if reached else FROST.lerp(Color.WHITE, 0.4)), 20, 12, 2)
	var h := TSUI.hbox(10)
	card.add_child(h)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", TSUI.sb(Color.WHITE, 99, 2, 0, 4))
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_child(TSIcon.make("bomb" if m.has("bombs") else "coin", 44))
	h.add_child(disc)
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var what := ("%d bomb%s" % [int(m["bombs"]), "" if int(m["bombs"]) == 1 else "s"]) if m.has("bombs") else "%s coins" % TSProfile.fmt_coins(int(m["coins"]))
	v.add_child(TSUI.label("Throw %s  ·  %s" % [TSProfile.fmt_coins(at), what], 21))
	var bar_row := TSUI.hbox(8)
	var bar := TSUI.bar(TSUI.MINT if reached else TSUI.SKY, 16)
	TSUI.expand(bar)
	bar.max_value = at
	bar.value = mini(TSSnowball.thrown, at)
	bar_row.add_child(bar)
	bar_row.add_child(TSUI.label("%d/%d" % [mini(TSSnowball.thrown, at), at], 17, TSUI.MUTED))
	v.add_child(bar_row)
	if done:
		h.add_child(TSIcon.make("check", 40))
	elif reached:
		var b := TSUI.button("Claim", TSUI.GREEN, 22, Vector2(110, 56), 4)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			var got := TSSnowball.claim(i)
			if got != "":
				TSSfx.play("coin")
				_toast_text.text = got
				_toast.visible = true
				_refresh())
		h.add_child(b)
	return card


## The team prize when the weekend's over.
func _prize_card() -> Control:
	var card := TSUI.card(Color(1.0, 0.93, 0.72), 28, 16, 4)
	var row := TSUI.hbox(14)
	card.add_child(row)
	row.add_child(TSIcon.make("chest", 100, 0, "legendary"))
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	v.add_child(TSUI.label("Team Prize", 30))
	v.add_child(TSUI.wrap(TSUI.label("Winning team: %s coins  ·  The other team: %s coins" % [TSProfile.fmt_coins(TSSnowball.WIN_COINS), TSProfile.fmt_coins(TSSnowball.LOSE_COINS)], 19, TSUI.INK)))
	v.add_child(TSUI.wrap(TSUI.label("Throw %d snowballs by Sunday night to join in." % TSSnowball.MIN_TO_PLACE, 18, TSUI.MUTED)))
	return card


func _play_button() -> Control:
	var play := TSUI.button("PLAY", TSUI.PINK, 34, Vector2(0, 80))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		play.add_theme_color_override(k, Color.WHITE)
	play.add_theme_color_override("font_outline_color", TSUI.INK)
	play.add_theme_constant_override("outline_size", 10)
	play.pressed.connect(func(): SceneFlow.go(SceneFlow.GAME))
	TSUI.breathe(play)
	return play


## Last weekend's result: who won, and what came the player's way.
func _result_card(r: Dictionary) -> Control:
	var won := bool(r["won"])
	var card := TSUI.card(Color(1.0, 0.95, 0.76) if won else FROST, 28, 16, 4)
	var v := TSUI.vbox(6)
	card.add_child(v)
	var t := str(r["team"])
	v.add_child(TSUI.label(("%s won the Snowball Fight!" % TSSnowball.TEAM_NAMES[t]) if won else ("%s won this time..." % TSSnowball.TEAM_NAMES["green" if t == "red" else "red"]), 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(TSUI.label("%s to %s  ·  you threw %s" % [TSProfile.fmt_coins(int(r["mine"])), TSProfile.fmt_coins(int(r["theirs"])), TSProfile.fmt_coins(int(r["thrown"]))], 19, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var got: Array = []
	if int(r["coins"]) > 0:
		got.append("+%s coins" % TSProfile.fmt_coins(int(r["coins"])))
	if int(r["bombs"]) > 0:
		got.append("+%d bomb%s" % [int(r["bombs"]), "" if int(r["bombs"]) == 1 else "s"])
	v.add_child(TSUI.label("  ".join(got) if not got.is_empty() else "Throw %d next time to share the prize!" % TSSnowball.MIN_TO_PLACE, 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	return card


func _refresh() -> void:
	if not TSSnowball.is_live():
		return
	_refresh_score()
	_mine.text = TSProfile.fmt_coins(TSSnowball.thrown)
	for c in _miles.get_children():
		c.queue_free()
	for i in TSSnowball.MILESTONES.size():
		_miles.add_child(_milestone_row(i))
	TSUI.juice(self)


func _refresh_score() -> void:
	_red_total.text = TSProfile.fmt_coins(TSSnowball.team_total("red"))
	_green_total.text = TSProfile.fmt_coins(TSSnowball.team_total("green"))
	(_tug as TugBar).red_share = TSSnowball.share("red")
	_tug.queue_redraw()
	_status.text = "Your team is winning -- keep it up!" if TSSnowball.winning() else "Your team is behind -- throw more snowballs!"
	_ends.text = "Ends in " + TSUI.fmt_duration(TSSnowball.seconds_left())


## Red from the left, green from the right, meeting at the share line, with a
## snowball riding on it.
class TugBar extends Control:
	var red_share := 0.5

	func _draw() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(size.x, size.y - 12))
		var split := r.size.x * red_share
		var red: Color = TSSnowball.TEAM_COLORS["red"]
		var green: Color = TSSnowball.TEAM_COLORS["green"]
		var back := StyleBoxFlat.new()
		back.set_corner_radius_all(int(r.size.y * 0.5))
		back.bg_color = green
		back.border_color = TSUI.INK
		back.set_border_width_all(3)
		draw_style_box(back, r)
		var fore := StyleBoxFlat.new()
		fore.bg_color = red
		fore.corner_radius_top_left = int(r.size.y * 0.5)
		fore.corner_radius_bottom_left = int(r.size.y * 0.5)
		draw_style_box(fore, Rect2(r.position + Vector2(3, 3), Vector2(maxf(split - 3.0, 0.0), r.size.y - 6)))
		var c := Vector2(split, size.y * 0.5)
		draw_circle(c, size.y * 0.5, Color(0.97, 0.99, 1.0), true, -1.0, true)
		draw_circle(c, size.y * 0.5, TSUI.INK, false, 3.0, true)
		draw_arc(c, size.y * 0.32, 0.3, PI - 0.3, 12, Color(0.66, 0.8, 0.98), 3.0, true)


## The battle scene: Team Gingerbread's fort on the left, Team Snowman's on
## the right, a squad of three behind each: the game's own Ginger and
## Snowman critters. Every squad member pops up on its own clock, winds back
## and throws at someone in the other squad; snowballs arc both ways and
## burst in a puff; snow falls. The Giant Snowball (charge, then launch)
## grows over the player's fort while they mash, then flies across and
## knocks the other squad tumbling out of their fort; they pop back in a
## couple of seconds later.
class SnowBattle extends Control:
	const SQUAD := 3
	const THROW_TIME := 0.7       # pop up, wind back, release, duck
	const RELEASE := 0.34         # the moment in it the ball leaves the hand
	const GINGER := 3            # the Ginger critter (TSProfile.CRITTERS)
	const SNOWMAN := 70          # and the Snowman
	const SIZE := 116.0          # a squad member's sticker, across
	const SNOW := Color(0.98, 0.99, 1.0)
	const GIANT_FLIGHT := 1.0     # the Giant Snowball's flight, in seconds
	const KNOCKED := 2.4          # how long a knocked-out squad is gone
	const SPAWN := 0.4            # popping back in
	const FALL := 1400.0          # gravity on a knocked-out critter, px/s²

	signal giant_landed

	var mine := ""
	## The Giant Snowball while it's being mashed: 0..1, how charged; -1 none.
	var charge := -1.0
	var _t := 0.0
	var _balls: Array = []    # {from, to, t, dur}
	var _puffs: Array = []    # {at, t, big}
	var _squads := {}         # left (bool) -> [{slot, wait, throw, thrown, aim, bob, (out, vx, vy, spin), (spawn)}]
	var _giant := {}          # the Giant Snowball in flight: {t, from, to, left}
	var _rng := RandomNumberGenerator.new()

	## The player's side: Team Gingerbread's ("red") is on the left.
	func _mine_left() -> bool:
		return mine != "green"

	## Throws the charged Giant Snowball at the other team.
	func launch() -> void:
		var left := _mine_left()
		_giant = {"t": 0.0, "from": _charge_at(), "to": Vector2(_fort_x(not left), _wall_top() - 30.0), "left": left}
		charge = -1.0

	## Where the Giant Snowball grows while charging: over the player's fort.
	func _charge_at() -> Vector2:
		return Vector2(_fort_x(_mine_left()), _wall_top() - 112.0)

	func _giant_radius() -> float:
		return 22.0 + 30.0 * clampf(charge, 0.0, 1.0)

	## A squad knocked out of its fort: each critter flies up and away,
	## spinning, and is back after KNOCKED seconds.
	func _knock(left: bool) -> void:
		var away := -1.0 if left else 1.0
		for m: Dictionary in _squads[left]:
			m["out"] = 0.0
			m["vx"] = away * _rng.randf_range(120.0, 300.0)
			m["vy"] = -_rng.randf_range(420.0, 600.0)
			m["spin"] = away * _rng.randf_range(5.0, 10.0)
			m["throw"] = -1.0
			m.erase("spawn")
		var at := Vector2(_fort_x(left), _wall_top() - 20.0)
		for k in 6:
			_puffs.append({"at": at + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-40, 30)), "t": -0.04 * float(k), "big": true})

	func _ready() -> void:
		_rng.randomize()
		clip_contents = true
		for left in [true, false]:
			var members: Array = []
			for i in SQUAD:
				members.append({"slot": i, "wait": _rng.randf_range(0.2, 2.0), "throw": -1.0, "thrown": false, "aim": 0, "bob": _rng.randf() * TAU})
			_squads[left] = members

	func _process(delta: float) -> void:
		_t += delta
		for left: bool in _squads:
			for m: Dictionary in _squads[left]:
				if m.has("out"):
					m["out"] = float(m["out"]) + delta
					if float(m["out"]) >= KNOCKED:
						m.erase("out")
						m["spawn"] = 0.0
						m["wait"] = _rng.randf_range(0.6, 1.6)
					continue
				if m.has("spawn"):
					m["spawn"] = float(m["spawn"]) + delta
					if float(m["spawn"]) >= SPAWN:
						m.erase("spawn")
					continue
				if float(m["throw"]) < 0.0:
					m["wait"] = float(m["wait"]) - delta
					if float(m["wait"]) <= 0.0:
						m["throw"] = 0.0
						m["thrown"] = false
						m["aim"] = _rng.randi() % SQUAD
					continue
				m["throw"] = float(m["throw"]) + delta
				if not bool(m["thrown"]) and float(m["throw"]) >= RELEASE:
					m["thrown"] = true
					var to := _head(not left, int(m["aim"]), 0.3) + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-6, 20))
					_balls.append({"from": _hand(left, m), "to": to, "t": 0.0, "dur": _rng.randf_range(0.8, 1.05)})
				if float(m["throw"]) >= THROW_TIME:
					m["throw"] = -1.0
					m["wait"] = _rng.randf_range(0.9, 2.6)
		for ball: Dictionary in _balls:
			ball["t"] = float(ball["t"]) + delta
		for ball: Dictionary in _balls.filter(func(x: Dictionary) -> bool: return float(x["t"]) >= float(x["dur"])):
			_puffs.append({"at": ball["to"], "t": 0.0})
		_balls = _balls.filter(func(x: Dictionary) -> bool: return float(x["t"]) < float(x["dur"]))
		if not _giant.is_empty():
			_giant["t"] = float(_giant["t"]) + delta
			if float(_giant["t"]) >= GIANT_FLIGHT:
				_knock(not bool(_giant["left"]))
				_giant = {}
				giant_landed.emit()
		for p: Dictionary in _puffs:
			p["t"] = float(p["t"]) + delta
		_puffs = _puffs.filter(func(x: Dictionary) -> bool: return float(x["t"]) < (0.8 if x.get("big", false) else 0.45))
		queue_redraw()

	func _ground() -> float:
		return size.y * 0.88

	func _fort_x(left: bool) -> float:
		return size.x * (0.25 if left else 0.75)

	func _fort_w() -> float:
		return minf(size.x * 0.38, 270.0)

	func _wall_top() -> float:
		return _ground() - 66.0

	## Where a squad member stands along its wall.
	func _slot_x(left: bool, slot: int) -> float:
		return _fort_x(left) + (float(slot) - 1.0) * _fort_w() * 0.32

	## How far up a member has popped: about 0 ducked, 1 fully up to throw.
	func _rise(m: Dictionary) -> float:
		if m.has("spawn"):   # popping back up from behind the wall
			var k := clampf(float(m["spawn"]) / SPAWN, 0.0, 1.0)
			return lerpf(-1.4, 0.3, 1.0 - pow(1.0 - k, 3.0)) + 0.25 * sin(k * PI)
		var u := float(m["throw"])
		if u < 0.0:
			return 0.3 + 0.08 * sin(_t * 2.2 + float(m["bob"]))
		if u < 0.15:
			return lerpf(0.3, 1.0, u / 0.15)
		if u > THROW_TIME - 0.2:
			return lerpf(1.0, 0.3, (u - (THROW_TIME - 0.2)) / 0.2)
		return 1.0

	## The middle of a member's sticker: its face over the wall when
	## ducked, most of it showing when it pops up.
	func _head(left: bool, slot: int, rise: float) -> Vector2:
		return Vector2(_slot_x(left, slot), _wall_top() - 12.0 - rise * 62.0)

	func _hand(left: bool, m: Dictionary) -> Vector2:
		return _head(left, int(m["slot"]), _rise(m)) + Vector2((-26.0 if left else 26.0), -60.0)

	func _draw() -> void:
		# The sky, the hills, the snowy ground.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.84, 1.0))
		draw_rect(Rect2(Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.55)), Color(0.78, 0.88, 1.0))
		var hill := PackedVector2Array()
		for i in 25:
			var x := size.x * float(i) / 24.0
			hill.append(Vector2(x, _ground() - 40.0 - 18.0 * sin(float(i) * 0.7)))
		hill.append(Vector2(size.x, size.y))
		hill.append(Vector2(0, size.y))
		draw_colored_polygon(hill, Color(0.9, 0.95, 1.0))
		draw_rect(Rect2(Vector2(0, _ground()), Vector2(size.x, size.y)), SNOW)
		for left in [true, false]:
			_draw_side(left)
		# Knocked-out critters, tumbling up and away in front of everything.
		for left: bool in _squads:
			for m: Dictionary in _squads[left]:
				if m.has("out"):
					var s := float(m["out"])
					var at := _head(left, int(m["slot"]), 0.3) + Vector2(float(m["vx"]) * s, float(m["vy"]) * s + 0.5 * FALL * s * s)
					_critter(at, left, m, float(m["spin"]) * s)
		for ball: Dictionary in _balls:
			var u := float(ball["t"]) / float(ball["dur"])
			var a: Vector2 = ball["from"]
			var b: Vector2 = ball["to"]
			var p := a.lerp(b, u) + Vector2(0, -80.0 * sin(u * PI))
			draw_circle(p + Vector2(0, 3), 9.0, Color(0.55, 0.68, 0.9, 0.5), true, -1.0, true)
			draw_circle(p, 9.0, Color.WHITE, true, -1.0, true)
			draw_circle(p, 9.0, TSUI.INK, false, 2.0, true)
		for puff: Dictionary in _puffs:
			if float(puff["t"]) < 0.0:
				continue
			var big: bool = puff.get("big", false)
			var k := float(puff["t"]) / (0.8 if big else 0.45)
			var at: Vector2 = puff["at"]
			var reach := 60.0 if big else 26.0
			var blob := 16.0 if big else 6.0
			for j in 7:
				var d := Vector2.from_angle(TAU * float(j) / 7.0 + (0.4 if big else 0.0)) * (8.0 + reach * k)
				draw_circle(at + d, blob * (1.0 - k) + 1.0, Color(1, 1, 1, 1.0 - k), true, -1.0, true)
		# The Giant Snowball: growing over the player's fort while it's mashed,
		# then flying across, spinning.
		if charge >= 0.0:
			var r := _giant_radius() + 2.0 * sin(_t * 30.0)
			_giant_ball(_charge_at() + Vector2(0, -r * 0.3), r, _t * 2.0)
		if not _giant.is_empty():
			var u := float(_giant["t"]) / GIANT_FLIGHT
			var a: Vector2 = _giant["from"]
			var b: Vector2 = _giant["to"]
			var p := a.lerp(b, u) + Vector2(0, -130.0 * sin(u * PI))
			_giant_ball(p, 52.0, u * TAU * (1.5 if bool(_giant["left"]) else -1.5))
		# Falling snow.
		for i in 40:
			var sx := fmod(float(i) * 97.3 + sin(_t * 0.8 + float(i)) * 14.0, size.x)
			var sy := fmod(float(i) * 53.1 + _t * (30.0 + float(i % 5) * 8.0), size.y)
			draw_circle(Vector2(sx, sy), 2.0 + float(i % 3), Color(1, 1, 1, 0.85), true, -1.0, true)

	## A team's side: its squad (each popping up to throw), its fort in
	## front, and its flag on a tall pole at the outer end.
	func _draw_side(left: bool) -> void:
		var col: Color = TSSnowball.TEAM_COLORS["red" if left else "green"]
		for m: Dictionary in _squads.get(left, []):
			if not m.has("out"):
				_critter(_head(left, int(m["slot"]), _rise(m)), left, m)
		_fort(left)
		var w := _fort_w()
		var pole := Vector2(_fort_x(left) + (-w * 0.5 - 4.0 if left else w * 0.5 + 4.0), _wall_top())
		draw_line(pole, pole + Vector2(0, -150), TSUI.INK, 4.0, true)
		var dir := 1.0 if left else -1.0   # the flag flies inward, high over the squad
		var flag := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			flag.append(pole + Vector2(0, -150) + Vector2(dir * u * 50.0, sin(_t * 4.0 + u * 3.0) * 4.0 * u))
		for i in range(6, -1, -1):
			var u := float(i) / 6.0
			flag.append(pole + Vector2(0, -124) + Vector2(dir * u * 50.0, sin(_t * 4.0 + u * 3.0) * 4.0 * u))
		draw_colored_polygon(flag, col)
		draw_polyline(flag, TSUI.INK, 2.5, true)
		if mine == ("red" if left else "green"):
			var star_c := pole + Vector2(dir * 25.0, -137.0)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(star_c + Vector2.from_angle(a) * (9.0 if i % 2 == 0 else 4.0))
			draw_colored_polygon(pts, Color.WHITE)

	## Three rows of snow blocks, with a block standing up at each end and
	## between each pair of throwers.
	func _fort(left: bool) -> void:
		var x := _fort_x(left)
		var w := _fort_w()
		var g := _ground()
		var bw := w / 6.0
		var bh := 22.0
		for r in 3:
			var shift := bw * 0.5 if r % 2 == 1 else 0.0
			for c in 8:
				var bx := x - w * 0.5 + float(c) * bw - shift
				if bx + bw <= x - w * 0.5 + 1.0 or bx >= x + w * 0.5 - 1.0:
					continue
				var rx := maxf(bx, x - w * 0.5)
				_block(Rect2(Vector2(rx, g - bh * float(r + 1)), Vector2(minf(bx + bw, x + w * 0.5) - rx, bh)))
		for s in [-0.5, -0.16, 0.16, 0.5]:
			var cx := clampf(x + w * s - bw * 0.5, x - w * 0.5, x + w * 0.5 - bw)
			_block(Rect2(Vector2(cx, g - bh * 4.0), Vector2(bw, bh)))

	func _block(r: Rect2) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.98, 1.0)
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0.6, 0.72, 0.92)
		sb.set_border_width_all(2)
		draw_style_box(sb, r)

	## A squad member: the critter's own sticker (the snowmen flipped to face
	## the gingerbread), tipping back as it winds up and forward as it throws,
	## a snowball held up in its hand until it lets go.
	func _critter(at: Vector2, left: bool, m: Dictionary, spin := 0.0) -> void:
		var dir := 1.0 if left else -1.0
		var u := float(m["throw"])
		var tilt := 0.04 * sin(_t * 1.7 + float(m["bob"]))
		if u >= 0.0:
			tilt = lerpf(0.0, -0.3, minf(u / RELEASE, 1.0)) if u < RELEASE else lerpf(0.22, 0.0, minf((u - RELEASE) / (THROW_TIME - RELEASE), 1.0))
		var tex: Texture2D = TSProfile.critter_art(GINGER if left else SNOWMAN)
		draw_set_transform(at, tilt * dir + spin, Vector2(1.0 if left else -1.0, 1.0))
		draw_texture_rect(tex, Rect2(Vector2(-SIZE, -SIZE) * 0.5, Vector2(SIZE, SIZE)), false)
		draw_set_transform(Vector2.ZERO)
		if u >= 0.0 and not bool(m["thrown"]):
			var hand := _hand(left, m)
			draw_circle(hand, 10.0, Color.WHITE, true, -1.0, true)
			draw_circle(hand, 10.0, TSUI.INK, false, 2.5, true)

	## A big snowball: a soft shadow, the ball, an outline, and a couple of
	## curved shading lines that turn with it.
	func _giant_ball(at: Vector2, r: float, turn: float) -> void:
		draw_circle(at + Vector2(0, r * 0.12), r, Color(0.55, 0.68, 0.9, 0.45), true, -1.0, true)
		draw_circle(at, r, Color.WHITE, true, -1.0, true)
		draw_circle(at, r, TSUI.INK, false, 3.5, true)
		for k in 2:
			var a := turn + PI * float(k)
			draw_arc(at, r * 0.62, a, a + 1.1, 12, Color(0.7, 0.82, 0.98), 4.0, true)
		draw_circle(at + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.9), true, -1.0, true)
