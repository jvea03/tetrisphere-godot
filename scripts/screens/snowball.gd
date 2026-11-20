extends TSScreen

## The Snowball Fight (TSSnowball). On top, the battle: two snow forts, a
## squad of gingerbread people behind one and of snowmen behind the other,
## lobbing snowballs at each other under falling snow. Then the score --
## both teams' totals on a tug-of-war bar, which team the player is on and
## whether it's ahead -- the time left, the player's own throws with a prize
## at each milestone (claimed here), the team prize, and PLAY. A finished weekend's result is shown first, once.

const FROST := Color(0.88, 0.94, 1.0)

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
	content.add_child(TSUI.scroll(list))
	var res := TSSnowball.take_result()
	if not res.is_empty():
		list.add_child(_result_card(res))
	list.add_child(_battle_card())
	if TSSnowball.is_live():
		list.add_child(_score_card())
		_toast = TSUI.card(TSUI.BUTTER, 20, 12, 3)
		_toast_text = TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		_toast.add_child(_toast_text)
		_toast.visible = false
		list.add_child(_toast)
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
	_tick += delta
	if _tick >= 1.0 and TSSnowball.is_live():
		_tick = 0.0
		_refresh_score()


## The battle: an animated scene, with which team the player's on over it.
func _battle_card() -> Control:
	var card := TSUI.card(FROST, 28, 0, 4)
	var field := SnowBattle.new()
	field.custom_minimum_size = Vector2(0, 320)
	field.mine = TSSnowball.team
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
## the right, a squad of three behind each. Every squad member pops up on its
## own clock, winds back and throws at someone in the other squad; snowballs
## arc both ways and burst in a puff; snow falls.
class SnowBattle extends Control:
	const SQUAD := 3
	const THROW_TIME := 0.7       # pop up, wind back, release, duck
	const RELEASE := 0.34         # the moment in it the ball leaves the hand
	const GINGER := Color(0.8, 0.5, 0.26)
	const ICING := Color(1.0, 1.0, 0.98)
	const SNOW := Color(0.98, 0.99, 1.0)
	const CARROT := Color(1.0, 0.56, 0.16)
	const COAL := Color(0.16, 0.13, 0.16)
	const STICK := Color(0.45, 0.3, 0.2)

	var mine := ""
	var _t := 0.0
	var _balls: Array = []    # {from, to, t, dur}
	var _puffs: Array = []    # {at, t}
	var _squads := {}         # left (bool) -> [{slot, wait, throw, thrown, aim, bob}]
	var _rng := RandomNumberGenerator.new()

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
		for p: Dictionary in _puffs:
			p["t"] = float(p["t"]) + delta
		_puffs = _puffs.filter(func(x: Dictionary) -> bool: return float(x["t"]) < 0.45)
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
		var u := float(m["throw"])
		if u < 0.0:
			return 0.3 + 0.08 * sin(_t * 2.2 + float(m["bob"]))
		if u < 0.15:
			return lerpf(0.3, 1.0, u / 0.15)
		if u > THROW_TIME - 0.2:
			return lerpf(1.0, 0.3, (u - (THROW_TIME - 0.2)) / 0.2)
		return 1.0

	func _head(left: bool, slot: int, rise: float) -> Vector2:
		return Vector2(_slot_x(left, slot), _wall_top() - 14.0 - rise * 58.0)

	func _hand(left: bool, m: Dictionary) -> Vector2:
		return _head(left, int(m["slot"]), _rise(m)) + Vector2((26.0 if left else -26.0), -26.0)

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
		for ball: Dictionary in _balls:
			var u := float(ball["t"]) / float(ball["dur"])
			var a: Vector2 = ball["from"]
			var b: Vector2 = ball["to"]
			var p := a.lerp(b, u) + Vector2(0, -80.0 * sin(u * PI))
			draw_circle(p + Vector2(0, 3), 9.0, Color(0.55, 0.68, 0.9, 0.5), true, -1.0, true)
			draw_circle(p, 9.0, Color.WHITE, true, -1.0, true)
			draw_circle(p, 9.0, TSUI.INK, false, 2.0, true)
		for puff: Dictionary in _puffs:
			var k := float(puff["t"]) / 0.45
			var at: Vector2 = puff["at"]
			for j in 7:
				var d := Vector2.from_angle(TAU * float(j) / 7.0) * (8.0 + 26.0 * k)
				draw_circle(at + d, 6.0 * (1.0 - k) + 1.0, Color(1, 1, 1, 1.0 - k), true, -1.0, true)
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
			var head := _head(left, int(m["slot"]), _rise(m))
			if left:
				_gingerbread(head, col, m)
			else:
				_snowman(head, col, m)
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

	## The throwing arm: back over the shoulder while winding up, then flung
	## forward, the snowball in hand until it's let go.
	func _arm(shoulder: Vector2, dir: float, m: Dictionary, col: Color, width: float) -> void:
		var u := float(m["throw"])
		var ang := 0.6   # resting, down by the side
		if u >= 0.0:
			if u < RELEASE:
				ang = lerpf(0.6, -2.4, minf(u / (RELEASE * 0.7), 1.0))
			else:
				ang = lerpf(-2.4, 0.1, minf((u - RELEASE) / 0.12, 1.0))
		var hand := shoulder + Vector2(cos(ang) * dir, sin(ang)) * 28.0
		draw_line(shoulder, hand, TSUI.INK, width + 5.0, true)
		draw_line(shoulder, hand, col, width, true)
		if u >= 0.0 and not bool(m["thrown"]):
			draw_circle(hand, 8.0, Color.WHITE, true, -1.0, true)
			draw_circle(hand, 8.0, TSUI.INK, false, 2.0, true)

	## A gingerbread person: a cookie head and body, icing eyes, smile and
	## brow squiggle, gumdrop buttons and a bow tie in the team's colour.
	func _gingerbread(head: Vector2, col: Color, m: Dictionary) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = GINGER
		sb.set_corner_radius_all(18)
		sb.border_color = TSUI.INK
		sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(head + Vector2(-22, 16), Vector2(44, 70)))
		var back := head + Vector2(-18, 30)   # the other arm, out to the side
		draw_line(back, back + Vector2(-14, 14), TSUI.INK, 15.0, true)
		draw_line(back, back + Vector2(-14, 14), GINGER, 10.0, true)
		draw_circle(head, 24.0, GINGER, true, -1.0, true)
		draw_circle(head, 24.0, TSUI.INK, false, 3.0, true)
		for s in [-1.0, 1.0]:
			draw_circle(head + Vector2(4.0 + s * 8.0, -3.0), 3.6, ICING, true, -1.0, true)
			draw_circle(head + Vector2(4.0 + s * 8.0, -3.0), 3.6, TSUI.INK, false, 1.5, true)
			draw_circle(head + Vector2(4.0 + s * 15.0, 7.0), 4.0, Color(1.0, 0.5, 0.5, 0.6), true, -1.0, true)
		draw_arc(head + Vector2(4.0, 6.0), 8.0, 0.35, PI - 0.35, 10, ICING, 3.0, true)
		var squig := PackedVector2Array()
		for i in 7:
			squig.append(head + Vector2(-14.0 + float(i) * 5.0, -14.0 + (2.0 if i % 2 == 0 else -2.0)))
		draw_polyline(squig, ICING, 2.5, true)
		var bow := head + Vector2(0, 24)
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-11, -6), bow + Vector2(-11, 6)]), col)
		draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(11, -6), bow + Vector2(11, 6)]), col)
		draw_circle(bow, 3.5, col.darkened(0.2), true, -1.0, true)
		for k in 2:
			draw_circle(head + Vector2(0, 38.0 + float(k) * 13.0), 4.5, col, true, -1.0, true)
			draw_circle(head + Vector2(0, 38.0 + float(k) * 13.0), 4.5, TSUI.INK, false, 1.5, true)
		_arm(head + Vector2(18, 30), 1.0, m, GINGER, 10.0)

	## A snowman: two snowballs stacked, coal eyes and smile, a carrot nose
	## pointing at the enemy, a scarf in the team's colour, stick arms and a
	## top hat.
	func _snowman(head: Vector2, col: Color, m: Dictionary) -> void:
		var belly := head + Vector2(0, 42)
		draw_circle(belly, 30.0, SNOW, true, -1.0, true)
		draw_circle(belly, 30.0, TSUI.INK, false, 3.0, true)
		for k in 2:
			draw_circle(belly + Vector2(0, -8.0 + float(k) * 14.0), 3.5, COAL, true, -1.0, true)
		var back := head + Vector2(22, 34)   # the other arm, a twig out to the side
		draw_line(back, back + Vector2(18, 10), STICK, 4.0, true)
		draw_line(back + Vector2(12, 7), back + Vector2(16, -2), STICK, 3.0, true)
		draw_circle(head, 24.0, SNOW, true, -1.0, true)
		draw_circle(head, 24.0, TSUI.INK, false, 3.0, true)
		for s in [-1.0, 1.0]:
			draw_circle(head + Vector2(-4.0 + s * 8.0, -4.0), 3.6, COAL, true, -1.0, true)
			draw_circle(head + Vector2(-4.0 + s * 15.0, 7.0), 4.0, Color(1.0, 0.6, 0.66, 0.55), true, -1.0, true)
		for i in 5:
			var a := 0.45 + (PI - 0.9) * float(i) / 4.0
			draw_circle(head + Vector2(-4.0, 4.0) + Vector2.from_angle(a) * 9.0, 1.8, COAL, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -1), head + Vector2(-4, 5), head + Vector2(-24, 3)]), CARROT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(5)
		sb.border_color = TSUI.INK
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(head + Vector2(-22, 17), Vector2(44, 10)))
		var tail := head + Vector2(10, 24)
		var flap := sin(_t * 5.0 + float(m["bob"])) * 4.0
		draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(8, 0), tail + Vector2(12 + flap, 22), tail + Vector2(2 + flap, 22)]), col)
		draw_rect(Rect2(head + Vector2(-20, -24), Vector2(40, 6)), COAL)
		draw_rect(Rect2(head + Vector2(-13, -48), Vector2(26, 25)), COAL)
		draw_rect(Rect2(head + Vector2(-13, -32), Vector2(26, 6)), col)
		_arm(head + Vector2(-20, 34), -1.0, m, STICK, 4.0)
