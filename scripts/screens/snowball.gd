extends TSScreen

## The Snowball Fight (TSSnowball). On top, the battle: two snow forts, Team
## Red's and Team Green's, lobbing snowballs at each other under falling
## snow. Then the score -- both teams' totals on a tug-of-war bar, which team
## the player is on and whether it's ahead -- the time left, the player's own
## throws with a prize at each milestone (claimed here), the team prize, and
## PLAY. A finished weekend's result is shown first, once.

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
	field.custom_minimum_size = Vector2(0, 270)
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
	left.add_child(TSUI.label("Team Red", 20, TSUI.MUTED))
	_red_total = TSUI.label("", 32, TSSnowball.TEAM_COLORS["red"].darkened(0.25))
	left.add_child(_red_total)
	row.add_child(left)
	var vs := TSUI.label("VS", 26, TSUI.INK)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	var right := TSUI.vbox(0)
	TSUI.expand(right)
	right.add_child(TSUI.label("Team Green", 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
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


## The battle scene: a red fort on the left, a green one on the right, a
## round egg-critter in a team bobble hat behind each, ducking and popping up
## to throw; snowballs arc both ways and burst in a puff; snow falls.
class SnowBattle extends Control:
	var mine := ""
	var _t := 0.0
	var _balls: Array = []    # {from, to, t, dur}
	var _puffs: Array = []    # {at, t}
	var _next := 0.4
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()
		clip_contents = true

	func _process(delta: float) -> void:
		_t += delta
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(0.35, 0.8)
			var left := _rng.randf() < 0.5
			var a := _thrower(left)
			var b := _thrower(not left) + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-10, 30))
			_balls.append({"from": a, "to": b, "t": 0.0, "dur": _rng.randf_range(0.8, 1.1)})
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
		return size.y * 0.78

	func _fort_x(left: bool) -> float:
		return size.x * (0.2 if left else 0.8)

	func _thrower(left: bool) -> Vector2:
		return Vector2(_fort_x(left) + (30.0 if left else -30.0), _ground() - 120.0)

	func _draw() -> void:
		# The sky, the hills, the snowy ground.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.84, 1.0))
		draw_rect(Rect2(Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.55)), Color(0.78, 0.88, 1.0))
		var hill := PackedVector2Array()
		for i in 25:
			var x := size.x * float(i) / 24.0
			hill.append(Vector2(x, _ground() - 28.0 - 18.0 * sin(float(i) * 0.7)))
		hill.append(Vector2(size.x, size.y))
		hill.append(Vector2(0, size.y))
		draw_colored_polygon(hill, Color(0.9, 0.95, 1.0))
		draw_rect(Rect2(Vector2(0, _ground()), Vector2(size.x, size.y)), Color(0.97, 0.99, 1.0))
		for left in [true, false]:
			_draw_side(left)
		for ball: Dictionary in _balls:
			var u := float(ball["t"]) / float(ball["dur"])
			var a: Vector2 = ball["from"]
			var b: Vector2 = ball["to"]
			var p := a.lerp(b, u) + Vector2(0, -90.0 * sin(u * PI))
			draw_circle(p + Vector2(0, 3), 11.0, Color(0.55, 0.68, 0.9, 0.5), true, -1.0, true)
			draw_circle(p, 11.0, Color.WHITE, true, -1.0, true)
			draw_circle(p, 11.0, TSUI.INK, false, 2.0, true)
		for puff: Dictionary in _puffs:
			var k := float(puff["t"]) / 0.45
			var at: Vector2 = puff["at"]
			for j in 7:
				var d := Vector2.from_angle(TAU * float(j) / 7.0) * (8.0 + 30.0 * k)
				draw_circle(at + d, 7.0 * (1.0 - k) + 1.0, Color(1, 1, 1, 1.0 - k), true, -1.0, true)
		# Falling snow.
		for i in 40:
			var sx := fmod(float(i) * 97.3 + sin(_t * 0.8 + float(i)) * 14.0, size.x)
			var sy := fmod(float(i) * 53.1 + _t * (30.0 + float(i % 5) * 8.0), size.y)
			draw_circle(Vector2(sx, sy), 2.0 + float(i % 3), Color(1, 1, 1, 0.85), true, -1.0, true)

	## A team's side: its critter (bobbing up to throw), then its fort in front,
	## and its flag.
	func _draw_side(left: bool) -> void:
		var col: Color = TSSnowball.TEAM_COLORS["red" if left else "green"]
		var x := _fort_x(left)
		var g := _ground()
		var pop := maxf(sin(_t * 2.4 + (0.0 if left else 1.7)), 0.0) * 26.0
		var head := Vector2(x + (14.0 if left else -14.0), g - 86.0 - pop)
		# The critter: an egg-white body, eyes, rosy cheeks, a bobble hat.
		draw_circle(head, 34.0, Color(1.0, 0.97, 0.9), true, -1.0, true)
		draw_circle(head, 34.0, TSUI.INK, false, 3.0, true)
		var look := 6.0 if left else -6.0
		for s in [-1.0, 1.0]:
			draw_circle(head + Vector2(look + s * 11.0, 2.0), 4.5, TSUI.INK, true, -1.0, true)
			draw_circle(head + Vector2(look + s * 19.0, 12.0), 5.0, Color(1.0, 0.62, 0.66, 0.7), true, -1.0, true)
		draw_arc(head + Vector2(look, 12.0), 6.0, 0.3, PI - 0.3, 10, TSUI.INK, 2.5, true)
		var hat := PackedVector2Array()
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			hat.append(head + Vector2(cos(a) * 34.0, sin(a) * 30.0 - 8.0))
		draw_colored_polygon(hat, col)
		draw_polyline(hat, TSUI.INK, 3.0, true)
		draw_rect(Rect2(head + Vector2(-35, -14), Vector2(70, 12)), Color.WHITE)
		draw_rect(Rect2(head + Vector2(-35, -14), Vector2(70, 12)), TSUI.INK, false, 2.5)
		draw_circle(head + Vector2(0, -44), 9.0, Color.WHITE, true, -1.0, true)
		draw_circle(head + Vector2(0, -44), 9.0, TSUI.INK, false, 2.5, true)
		# The fort: three rows of snow blocks, crenellated on top.
		var w := 150.0
		var bw := w / 4.0
		var bh := 22.0
		for r in 3:
			var shift := bw * 0.5 if r % 2 == 1 else 0.0
			for c in 5:
				var bx := x - w * 0.5 + float(c) * bw - shift
				if bx + bw <= x - w * 0.5 + 1.0 or bx >= x + w * 0.5 - 1.0:
					continue
				var rx := maxf(bx, x - w * 0.5)
				var rr := Rect2(Vector2(rx, g - bh * float(r + 1)), Vector2(minf(bx + bw, x + w * 0.5) - rx, bh))
				var sbx := StyleBoxFlat.new()
				sbx.bg_color = Color(0.96, 0.98, 1.0)
				sbx.set_corner_radius_all(6)
				sbx.border_color = Color(0.6, 0.72, 0.92)
				sbx.set_border_width_all(2)
				draw_style_box(sbx, rr)
		for c in 2:
			var cx := x - w * 0.5 + (0.0 if c == 0 else w - bw)
			var sbt := StyleBoxFlat.new()
			sbt.bg_color = Color(0.96, 0.98, 1.0)
			sbt.set_corner_radius_all(6)
			sbt.border_color = Color(0.6, 0.72, 0.92)
			sbt.set_border_width_all(2)
			draw_style_box(sbt, Rect2(Vector2(cx, g - bh * 4.0), Vector2(bw, bh)))
		# The flag, waving, on the outer side.
		var pole := Vector2(x + (-w * 0.5 + 6.0 if left else w * 0.5 - 6.0), g - bh * 4.0)
		draw_line(pole, pole + Vector2(0, -80), TSUI.INK, 4.0, true)
		var dir := 1.0 if left else -1.0
		var flag := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			flag.append(pole + Vector2(0, -80) + Vector2(dir * u * 54.0, sin(_t * 4.0 + u * 3.0) * 4.0 * u))
		for i in range(6, -1, -1):
			var u := float(i) / 6.0
			flag.append(pole + Vector2(0, -50) + Vector2(dir * u * 54.0, sin(_t * 4.0 + u * 3.0) * 4.0 * u))
		draw_colored_polygon(flag, col)
		draw_polyline(flag, TSUI.INK, 2.5, true)
		if mine == ("red" if left else "green"):
			var star_c := pole + Vector2(dir * 27.0, -65.0)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(star_c + Vector2.from_angle(a) * (9.0 if i % 2 == 0 else 4.0))
			draw_colored_polygon(pts, Color.WHITE)
