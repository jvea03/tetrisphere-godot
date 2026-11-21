class_name TSSitesNewYear
extends RefCounted

## The New Year planet's work sites (TSSites): a twilight party village of
## sparklers, a clock tower counting down to midnight, fireworks, lanterns
## and a dance floor. Drawn round each spot's foot at (0, 0).

const SILVER := Color(0.88, 0.9, 0.98)
const PARTY := [Color(1.0, 0.62, 0.74), Color(1.0, 0.84, 0.36), Color(0.62, 0.8, 1.0), Color(0.76, 0.66, 1.0), Color(0.6, 0.9, 0.66)]


static func draw(s: TSShipScene, ci: CanvasItem, part: int, lv: int) -> void:
	match part:
		TSProfile.CAMP_FIRE: _sparkler_fire(s, ci, lv)
		TSProfile.CAMP_TENT: _party_tent(s, ci, lv)
		TSProfile.CAMP_BENCH: _firework_bench(s, ci, lv)
		TSProfile.CAMP_GARDEN: _star_garden(s, ci, lv)
		TSProfile.CAMP_WELL: _wishing_well(s, ci, lv)
		TSProfile.CAMP_LOOKOUT: _clock_tower(s, ci, lv)
		TSProfile.CAMP_HAMMOCK: _star_chairs(s, ci, lv)
		TSProfile.CAMP_PICNIC: _party_table(s, ci, lv)
		TSProfile.CAMP_CLOTHESLINE: _banner_line(s, ci, lv)
		TSProfile.CAMP_MAILBOX: _wish_box(s, ci, lv)
		TSProfile.CAMP_WINDMILL: _pinwheel(s, ci, lv)
		TSProfile.CAMP_DOCK: _lantern_dock(s, ci, lv)
		TSProfile.CAMP_PLAYGROUND: _dance_floor(s, ci, lv)
		TSProfile.CAMP_TREEHOUSE: _firework_tower(s, ci, lv)
		TSProfile.CAMP_STALL: _party_shop(s, ci, lv)
		TSProfile.CAMP_GREENHOUSE: _lantern_house(s, ci, lv)
		TSProfile.CAMP_SPRING: _bubbly_fountain(s, ci, lv)
		TSProfile.CAMP_OBSERVATORY: _countdown_stage(s, ci, lv)
		TSProfile.CAMP_OVEN: _cake_bakery(s, ci, lv)
		TSProfile.CAMP_STATUE: _hourglass(s, ci, lv)


static func _confetti(s: TSShipScene, ci: CanvasItem, c: Vector2, r: float, n := 8) -> void:
	for j in n:
		var age := fposmod(s._t * 0.4 + float(j) / float(n), 1.0)
		var at := c + Vector2(sin(j * 2.7) * r, -r * 0.6 + age * r * 1.4)
		var turn := s._t * 3.0 + j
		var d := Vector2(5, 0).rotated(turn)
		ci.draw_line(at - d, at + d, Color(PARTY[j % PARTY.size()], 1.0 - age * 0.6), 4.0, true)


## A firework bursting at `c`, on its own beat.
static func _burst(s: TSShipScene, ci: CanvasItem, c: Vector2, r: float, phase: float, col: Color) -> void:
	var age := fposmod(s._t * 0.5 + phase, 1.0)
	if age > 0.7:
		return
	var u := age / 0.7
	for j in 10:
		var d := Vector2.from_angle(TAU * float(j) / 10.0)
		ci.draw_line(c + d * r * u * 0.5, c + d * r * u, Color(col, 1.0 - u), 4.0, true)
		ci.draw_circle(c + d * r * u, 3.0, Color(Color.WHITE, 1.0 - u), true, -1.0, true)


# Sparkler Fire: Cold Ashes, Sparkler Fire, Stone Ring, Fondue Pot, Spark Fountain.
static func _sparkler_fire(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 52.0)
	for turn in [0.35, -0.35]:
		ci.draw_line(Vector2(-26, 6).rotated(turn), Vector2(26, 6).rotated(turn), TSSites.WOOD.darkened(0.45) if lv == 0 else TSSites.WOOD, 10.0, true)
	if lv == 0:
		TSSites.puffs(s, ci, Vector2(0, -6), Color(0.66, 0.64, 0.7), 60.0, 2)
		return
	if lv >= 2:
		for j in 9:
			var a := TAU * float(j) / 9.0
			s._ellipse(ci, Vector2(cos(a) * 46.0, sin(a) * 12.0 + 6.0), 11.0, 7.0, TSSites.LILAC.lightened(0.3))
	var flick := 1.0 + 0.1 * sin(s._t * 11.0)
	s._blob(ci, [Vector2(-20, 0), Vector2(0, -50.0 * flick), Vector2(20, 0)], Color(0.86, 0.5, 1.0))
	s._blob(ci, [Vector2(-10, 0), Vector2(0, -26.0 * flick), Vector2(10, 0)], TSSites.BUTTER, false)
	if lv >= 3:
		for leg in [-1.0, 1.0]:
			ci.draw_line(Vector2(leg * 48.0, 8.0), Vector2(0, -140.0), TSSites.INK, 4.0, true)
		s._blob(ci, [Vector2(-20, -128), Vector2(20, -128), Vector2(16, -104), Vector2(-16, -104)], SILVER)
		TSSites.puffs(s, ci, Vector2(0, -116), Color(1.0, 0.92, 0.7), 40.0, 2)
	var sparks := 10 if lv >= 4 else 5
	for n in sparks:
		var age := fposmod(s._t * 0.9 + float(n) / float(sparks), 1.0)
		var d := Vector2.from_angle(-PI * 0.5 + sin(n * 1.9) * 0.9)
		s._sparkle(ci, Vector2(0, -30) + d * age * (110.0 if lv >= 4 else 60.0), 6.0 * (1.0 - age), [TSSites.GOLD, Color.WHITE, Color(0.86, 0.6, 1.0)][n % 3])


# Party Tent: Torn Tarp, Party Tent, Pennants, Disco Ball, Big Top.
static func _party_tent(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	var w := 100.0 if lv >= 4 else 80.0
	var h := 140.0 if lv >= 4 else 110.0
	s._ellipse(ci, Vector2(0, 6), w * 1.15, 16.0, TSSites.SHADOW, false)
	if lv == 0:
		ci.draw_line(Vector2(-50, 0), Vector2(-40, -44), TSSites.WOOD, 5.0, true)
		s._blob(ci, [Vector2(-90, 4), Vector2(-40, -40), Vector2(30, -14), Vector2(90, 6)], Color(0.78, 0.74, 0.86))
		return
	# Striped canvas: alternating gores from the peak.
	for j in 6:
		var a := Vector2(-w + w * 2.0 * j / 6.0, 0)
		var b := Vector2(-w + w * 2.0 * (j + 1) / 6.0, 0)
		s._blob(ci, [a, b, Vector2(0, -h)], TSSites.LILAC if j % 2 == 0 else Color(0.98, 0.96, 1.0))
	s._blob(ci, [Vector2(-22, 0), Vector2(0, -h * 0.5), Vector2(22, 0)], Color(0.36, 0.26, 0.46) if lv < 4 else TSSites.BUTTER)
	if lv >= 2:
		for side in [-1.0, 1.0]:
			for n in 5:
				var u := (float(n) + 0.5) / 5.0
				var at := Vector2(side * w * (1.0 - u), -h * u)
				s._blob(ci, [at + Vector2(-7, 0), at + Vector2(7, 0), at + Vector2(0, 14)], PARTY[n % PARTY.size()], false)
	if lv >= 3:
		var top := Vector2(0, -h)
		ci.draw_line(top, top + Vector2(0, -20), TSSites.INK, 3.0, true)
		ci.draw_circle(top + Vector2(0, -36), 16.0, TSSites.INK, true, -1.0, true)
		ci.draw_circle(top + Vector2(0, -36), 13.5, SILVER, true, -1.0, true)
		for j in 3:
			ci.draw_line(top + Vector2(-13, -42 + j * 6), top + Vector2(13, -42 + j * 6), Color(0.6, 0.62, 0.8), 2.0, true)
		s._sparkle(ci, top + Vector2(10 * sin(s._t * 2.0), -44), 6.0, Color.WHITE)
	if lv >= 4:
		TSSites.flag(s, ci, Vector2(0, -h - 100.0), TSSites.GOLD, 48.0)


# Firework Bench: Loose Planks, Bench, Rocket Rack, Fuse Spools, Star Awning.
static func _firework_bench(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0, 6.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4, Color(0.7, 0.58, 0.6))
		return
	if lv >= 4:
		for x in [-80.0, 80.0]:
			s._post(ci, Vector2(x, 0), Vector2(x, -140), 6.0)
		s._blob(ci, [Vector2(-96, -150), Vector2(96, -150), Vector2(86, -122), Vector2(-86, -122)], TSSites.NIGHT)
		for j in 5:
			TSSites.star(ci, Vector2(-64 + j * 32, -136), 8.0, TSSites.GOLD)
	if lv >= 2:
		s._box(ci, Rect2(Vector2(-60, -112), Vector2(120, 50)), TSSites.WOOD.darkened(0.2))
		for j in 4:
			var x := -44.0 + j * 28.0
			s._blob(ci, [Vector2(x - 7, -64), Vector2(x + 7, -64), Vector2(x + 7, -100), Vector2(x, -112), Vector2(x - 7, -100)], PARTY[j])
	for x in [-56.0, 56.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -48), 5.0)
	s._box(ci, Rect2(Vector2(-74, -62), Vector2(148, 16)), Color(0.82, 0.66, 0.56))
	if lv >= 3:
		for j in 2:
			var c := Vector2(-34 + j * 60, -72)
			s._ellipse(ci, c, 16.0, 10.0, TSSites.RED if j == 0 else TSSites.GOLD)
			ci.draw_line(c + Vector2(14, 0), c + Vector2(30, 8), TSSites.INK, 2.0, true)
			s._sparkle(ci, c + Vector2(30, 8), 5.0 * (0.6 + 0.4 * sin(s._t * 9.0 + j)), TSSites.BUTTER)


# Starflower Garden: Bare Dirt, Sprouts, Moonflowers, Starflowers, Glowing Bulbs.
static func _star_garden(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	s._ellipse(ci, Vector2(0, -6), 110.0, 28.0, Color(0.5, 0.4, 0.46))
	if lv == 0:
		return
	for n in 7:
		var at := Vector2(-84 + n * 28, -6 + (n % 2) * 10)
		var h := 22.0 if lv == 1 else 44.0
		ci.draw_line(at, at + Vector2(0, -h), Color(0.36, 0.62, 0.5), 4.0, true)
		if lv >= 2:
			var head := at + Vector2(0, -h)
			if lv >= 3 and n % 2 == 0:
				TSSites.star(ci, head, 11.0, TSSites.BUTTER, sin(s._t + n) * 0.2)
			else:
				for p in 5:
					ci.draw_circle(head + Vector2.from_angle(TAU * p / 5.0) * 7.0, 5.0, SILVER, true, -1.0, true)
				ci.draw_circle(head, 4.0, TSSites.LILAC, true, -1.0, true)
	if lv >= 4:
		for x in [-120.0, 120.0]:
			s._post(ci, Vector2(x, 0), Vector2(x, -60), 4.0, TSSites.INK)
			ci.draw_circle(Vector2(x, -70), 18.0, Color(TSSites.BUTTER, 0.25 + 0.1 * sin(s._t * 3.0 + x)), true, -1.0, true)
			ci.draw_circle(Vector2(x, -70), 9.0, TSSites.BUTTER, true, -1.0, true)
		TSSites.twinkle(s, ci, Vector2(0, -40), 70.0, TSSites.BUTTER, 4)


# Wishing Well: Pile of Stones, Stone Well, Starry Roof, Coin Sparkles, Wish Ribbons.
static func _wishing_well(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-34, -6), Vector2(10, -10), Vector2(40, -2), Vector2(-6, -26), Vector2(26, -24)], TSSites.STONE)
		return
	s._box(ci, Rect2(Vector2(-56, -60), Vector2(112, 60)), TSSites.STONE)
	for row in 2:
		ci.draw_line(Vector2(-54, -40 + row * 20), Vector2(54, -40 + row * 20), Color(TSSites.INK, 0.25), 2.0, true)
	s._ellipse(ci, Vector2(0, -60), 56.0, 13.0, Color(0.22, 0.24, 0.44))
	if lv >= 2:
		for x in [-48.0, 48.0]:
			s._post(ci, Vector2(x, -60), Vector2(x, -140), 7.0)
		TSSites.roof(s, ci, Vector2(-70, -138), Vector2(70, -138), 48.0, TSSites.NIGHT)
		for j in 3:
			TSSites.star(ci, Vector2(-30 + j * 30, -156 + (j % 2) * 10), 6.0, TSSites.GOLD)
	if lv >= 3:
		for j in 3:
			var age := fposmod(s._t * 0.5 + float(j) / 3.0, 1.0)
			s._sparkle(ci, Vector2(-24 + j * 24, -62 - age * 30.0), 7.0 * (1.0 - age), TSSites.GOLD)
	if lv >= 4:
		for side in [-1.0, 1.0]:
			for j in 3:
				var at := Vector2(side * 48.0, -120 + j * 18)
				var sway := sin(s._t * 3.0 + j + side) * 5.0
				ci.draw_line(at, at + Vector2(side * 14.0 + sway, 14), PARTY[j + (1 if side > 0 else 0)], 5.0, true)


# Clock Tower: Pile of Bricks, Base, Tower, Clock Face, Midnight Bell.
static func _clock_tower(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var brick := Color(0.66, 0.58, 0.8)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-34, -6), Vector2(10, -10), Vector2(40, -2), Vector2(-6, -24)], brick, 22.0, 13.0)
		return
	var h := 70.0 if lv == 1 else 220.0
	s._box(ci, Rect2(Vector2(-50, -h), Vector2(100, h)), brick)
	s._box(ci, Rect2(Vector2(-16, -44), Vector2(32, 44)), Color(0.36, 0.26, 0.46))
	if lv >= 2:
		for y in [-80.0, -130.0]:
			s._box(ci, Rect2(Vector2(-12, y - 20), Vector2(24, 26)), TSSites.BUTTER)
		TSSites.roof(s, ci, Vector2(-62, -h), Vector2(62, -h), 70.0, TSSites.NIGHT)
	if lv >= 3:
		var c := Vector2(0, -h + 40)
		ci.draw_circle(c, 34.0, TSSites.INK, true, -1.0, true)
		ci.draw_circle(c, 30.0, Color(1.0, 0.98, 0.9), true, -1.0, true)
		for j in 12:
			ci.draw_circle(c + Vector2.from_angle(TAU * j / 12.0) * 24.0, 2.0, TSSites.INK, true, -1.0, true)
		ci.draw_line(c, c + Vector2(0, -22), TSSites.INK, 4.0, true)
		ci.draw_line(c, c + Vector2(0, -16).rotated(s._t * 0.5), TSSites.INK, 3.0, true)
	if lv >= 4:
		var swing := sin(s._t * 3.0) * 0.3 if fposmod(s._t, 6.0) < 1.5 else 0.0
		var hang := Vector2(0, -h - 30)
		var pts: Array = []
		for v in [Vector2(-14, 0), Vector2(14, 0), Vector2(10, -20), Vector2(-10, -20)]:
			pts.append(hang + (v as Vector2).rotated(swing))
		s._blob(ci, pts, TSSites.GOLD)
		TSSites.star(ci, Vector2(0, -h - 82), 12.0, TSSites.GOLD)


# Stargazing Chairs: Fallen Log, Deck Chair, Two Chairs, Blankets, Star Lamp.
static func _star_chairs(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 4.0)
	if lv == 0:
		s._blob(ci, [Vector2(-70, 0), Vector2(60, 0), Vector2(60, -22), Vector2(-70, -22)], TSSites.WOOD.darkened(0.1))
		return
	var chairs := [-50.0] if lv == 1 else [-60.0, 50.0]
	for n in chairs.size():
		var x: float = chairs[n]
		s._post(ci, Vector2(x - 30, 0), Vector2(x + 30, -30), 5.0)
		s._post(ci, Vector2(x + 30, 0), Vector2(x - 6, -50), 5.0)
		var cloth := TSSites.LILAC if n == 0 else Color(0.62, 0.8, 1.0)
		s._blob(ci, [Vector2(x - 34, -24), Vector2(x + 10, -24), Vector2(x - 2, -66), Vector2(x - 20, -70)], cloth)
		if lv >= 3:
			s._blob(ci, [Vector2(x - 30, -22), Vector2(x + 14, -22), Vector2(x + 10, -32), Vector2(x - 26, -34)], PARTY[n + 1])
	if lv >= 4:
		s._post(ci, Vector2(0, 0), Vector2(0, -110), 4.0, TSSites.INK)
		ci.draw_circle(Vector2(0, -120), 22.0, Color(TSSites.BUTTER, 0.25 + 0.1 * sin(s._t * 2.0)), true, -1.0, true)
		TSSites.star(ci, Vector2(0, -120), 14.0, TSSites.BUTTER, s._t * 0.3)


# Party Table: Fallen Log, Table, Party Cloth, Party Hats, Confetti Feast.
static func _party_table(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	if lv == 0:
		s._blob(ci, [Vector2(-70, 0), Vector2(60, 0), Vector2(60, -26), Vector2(-70, -26)], TSSites.WOOD.darkened(0.1))
		return
	for x in [-56.0, 56.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -52), 5.0)
	s._box(ci, Rect2(Vector2(-74, -66), Vector2(148, 16)), TSSites.LILAC if lv >= 2 else Color(0.86, 0.66, 0.46))
	if lv >= 2:
		for j in 7:
			var x := -70.0 + j * 20.0
			s._blob(ci, [Vector2(x, -52), Vector2(x + 20, -52), Vector2(x + 10, -40)], PARTY[j % PARTY.size()], false)
	if lv >= 3:
		for j in 3:
			var at := Vector2(-50 + j * 40, -66)
			s._blob(ci, [at + Vector2(-10, 0), at + Vector2(10, 0), at + Vector2(0, -30)], PARTY[j + 1])
			ci.draw_circle(at + Vector2(0, -30), 4.0, TSSites.BUTTER, true, -1.0, true)
	if lv >= 4:
		s._box(ci, Rect2(Vector2(30, -96), Vector2(36, 30)), Color(1.0, 0.94, 0.86))
		ci.draw_line(Vector2(48, -96), Vector2(48, -110), TSSites.INK, 2.0, true)
		ci.draw_circle(Vector2(48, -114), 4.0 + sin(s._t * 9.0), Color(1.0, 0.7, 0.3), true, -1.0, true)
		_confetti(s, ci, Vector2(0, -100), 90.0, 10)


# Banner Line: Loose Line, Line, Pennants, Lanterns, Happy New Year.
static func _banner_line(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0, 4.0)
	if lv == 0:
		var rope := PackedVector2Array()
		for j in 10:
			rope.append(Vector2(-70 + j * 14, -4 + sin(j * 1.6) * 6))
		ci.draw_polyline(rope, Color(0.9, 0.84, 0.7), 4.0, true)
		return
	for x in [-120.0, 120.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -140), 7.0)
	var line := PackedVector2Array()
	for j in 13:
		var u := float(j) / 12.0
		line.append(Vector2(-120.0 + u * 240.0, -136.0 + sin(u * PI) * 20.0))
	ci.draw_polyline(line, TSSites.INK, 2.5, true)
	if lv >= 2:
		for j in 12:
			var a := line[j]
			var b := line[j + 1]
			s._blob(ci, [a, b, (a + b) * 0.5 + Vector2(0, 20)], PARTY[j % PARTY.size()], false)
	if lv >= 3:
		for j in [3, 9]:
			var at := line[j] + Vector2(0, 30)
			ci.draw_line(line[j], at, TSSites.INK, 1.5, true)
			s._ellipse(ci, at + Vector2(0, 12), 12.0, 14.0, Color(1.0, 0.56, 0.42))
			ci.draw_circle(at + Vector2(0, 12), 16.0, Color(TSSites.BUTTER, 0.2 + 0.1 * sin(s._t * 3.0 + j)), true, -1.0, true)
	if lv >= 4:
		s._box(ci, Rect2(Vector2(-90, -100), Vector2(180, 36)), TSSites.NIGHT)
		s._text(ci, Vector2(-86, -74), "HAPPY NEW YEAR", 20.0, TSSites.GOLD)


# Wish Box: Dented Can, Box, Painted, Wish Slip, Overflowing Wishes.
static func _wish_box(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 40.0)
	if lv == 0:
		s._blob(ci, [Vector2(-20, 0), Vector2(24, -4), Vector2(20, -30), Vector2(-24, -26)], Color(0.7, 0.7, 0.76))
		return
	s._post(ci, Vector2(0, 0), Vector2(0, -60), 8.0)
	var col := TSSites.NIGHT if lv >= 2 else Color(0.8, 0.78, 0.86)
	s._box(ci, Rect2(Vector2(-34, -116), Vector2(68, 56)), col)
	ci.draw_rect(Rect2(Vector2(-16, -110), Vector2(32, 5)), TSSites.INK)
	if lv >= 2:
		for j in 4:
			TSSites.star(ci, Vector2(-22 + j * 15, -80 + (j % 2) * 10), 5.0, TSSites.GOLD)
	if lv >= 3:
		var bob := sin(s._t * 2.0) * 3.0
		s._box(ci, Rect2(Vector2(-10, -134 + bob), Vector2(20, 24)), Color(1.0, 0.98, 0.9))
	if lv >= 4:
		for j in 5:
			var age := fposmod(s._t * 0.4 + float(j) / 5.0, 1.0)
			var at := Vector2(sin(j * 2.3) * 40.0 * age, -120.0 - age * 70.0)
			s._box(ci, Rect2(at - Vector2(7, 5), Vector2(14, 10)), Color(Color(1.0, 0.98, 0.9), 1.0 - age))


# Pinwheel Tower: Broken Pinwheel, Spinning, Glitter Sails, Little Door, Sparkle Lights.
static func _pinwheel(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var h := 90.0 if lv == 0 else 210.0
	s._blob(ci, [Vector2(-40, 0), Vector2(40, 0), Vector2(20, -h), Vector2(-20, -h)], Color(0.94, 0.92, 1.0))
	if lv == 0:
		TSSites.planks(s, ci, Vector2(60, 0), 2, Color(0.84, 0.8, 0.86))
		return
	if lv >= 3:
		s._blob(ci, [Vector2(-14, 0), Vector2(14, 0), Vector2(14, -36), Vector2(0, -46), Vector2(-14, -36)], TSSites.NIGHT)
	if lv >= 4:
		TSSites.bulbs(s, ci, Vector2(-40, 0), Vector2(-20, -h), 0.0, 6)
		TSSites.bulbs(s, ci, Vector2(40, 0), Vector2(20, -h), 0.0, 6)
	var hub := Vector2(0, -h)
	var spin := s._t * (2.4 if lv >= 2 else 1.0)
	for j in 4:
		var d := Vector2.from_angle(spin + j * PI * 0.5)
		var across := Vector2(-d.y, d.x)
		var fill: Color = PARTY[j] if lv >= 2 else Color(0.84, 0.8, 0.86)
		s._blob(ci, [hub, hub + d * 90.0, hub + d * 50.0 + across * 50.0], fill)
		if lv >= 2:
			s._sparkle(ci, hub + d * 60.0 + across * 20.0, 4.0, Color.WHITE)
	ci.draw_circle(hub, 10.0, TSSites.INK, true, -1.0, true)
	ci.draw_circle(hub, 6.0, TSSites.GOLD, true, -1.0, true)


# Lantern Dock: Driftwood, Little Dock, Paper Boat, Lantern Post, Floating Lanterns.
static func _lantern_dock(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		TSSites.planks(s, ci, Vector2(0, 0), 3, Color(0.8, 0.7, 0.6))
		return
	for x in [-26.0, 26.0]:
		s._post(ci, Vector2(x, 10), Vector2(x, -66), 7.0, TSSites.WOOD.darkened(0.2))
	for j in 6:
		s._box(ci, Rect2(Vector2(-34, -10.0 - j * 11.0), Vector2(68, 9)), TSSites.WOOD)
	if lv >= 2:
		var bob := sin(s._t * 1.4) * 3.0
		var boat := Vector2(-110, -10 + bob)
		s._blob(ci, [boat + Vector2(-40, -10), boat + Vector2(40, -10), boat + Vector2(26, 8), boat + Vector2(-26, 8)], Color(1.0, 0.98, 0.94))
		s._blob(ci, [boat + Vector2(-6, -10), boat + Vector2(6, -10), boat + Vector2(0, -40)], Color(1.0, 0.98, 0.94))
	if lv >= 3:
		s._post(ci, Vector2(30, -70), Vector2(30, -140), 5.0, TSSites.INK)
		TSSites.lantern(s, ci, Vector2(30, -150), Color(1.0, 0.6, 0.44))
	if lv >= 4:
		for j in 4:
			var age := fposmod(s._t * 0.08 + float(j) / 4.0, 1.0)
			var at := Vector2(-150 + j * 70 + sin(age * 6.0 + j) * 10.0, -40.0 - age * 260.0)
			ci.draw_circle(at, 18.0, Color(1.0, 0.7, 0.4, 0.25 * (1.0 - age)), true, -1.0, true)
			s._box(ci, Rect2(at - Vector2(9, 11), Vector2(18, 22)), Color(Color(1.0, 0.6, 0.4), 1.0 - age * 0.7))


# Dance Floor: Loose Tiles, Floor, Light Tiles, DJ Booth, Disco Ball.
static func _dance_floor(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 150.0)
	if lv == 0:
		for j in 5:
			var at := Vector2(-80 + j * 40, -4 + (j % 2) * 8)
			s._blob(ci, [at + Vector2(-16, 0), at + Vector2(16, 0), at + Vector2(20, -10), at + Vector2(-12, -12)], Color(0.74, 0.7, 0.84))
		return
	# The floor, a grid of tiles seen from the side.
	var rows := 4
	var cols := 8
	for r in rows:
		for c in cols:
			var y0 := -10.0 - r * 14.0
			var w0 := 150.0 - r * 12.0
			var w1 := 150.0 - (r + 1) * 12.0
			var x0 := -w0 + w0 * 2.0 * c / cols
			var x1 := -w0 + w0 * 2.0 * (c + 1) / cols
			var x2 := -w1 + w1 * 2.0 * (c + 1) / cols
			var x3 := -w1 + w1 * 2.0 * c / cols
			var lit := lv >= 2 and (c + r + int(s._t * 3.0)) % 3 == 0
			var col: Color = PARTY[(c + r) % PARTY.size()] if lit else Color(0.36, 0.32, 0.5)
			s._blob(ci, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x2, y0 - 14), Vector2(x3, y0 - 14)], col)
	if lv >= 3:
		s._box(ci, Rect2(Vector2(110, -110), Vector2(70, 60)), TSSites.NIGHT)
		ci.draw_circle(Vector2(130, -112), 12.0, TSSites.INK, true, -1.0, true)
		ci.draw_circle(Vector2(162, -112), 12.0, TSSites.INK, true, -1.0, true)
		for j in 3:
			ci.draw_circle(Vector2(124 + j * 18, -80), 4.0, PARTY[(j + int(s._t * 4.0)) % PARTY.size()], true, -1.0, true)
	if lv >= 4:
		ci.draw_line(Vector2(0, -200), Vector2(0, -160), TSSites.INK, 3.0, true)
		ci.draw_circle(Vector2(0, -140), 24.0, TSSites.INK, true, -1.0, true)
		ci.draw_circle(Vector2(0, -140), 21.0, SILVER, true, -1.0, true)
		for j in 4:
			var y := -154.0 + j * 9.0
			ci.draw_line(Vector2(-18, y), Vector2(18, y), Color(0.6, 0.62, 0.8), 2.0, true)
		for j in 5:
			var d := Vector2.from_angle(s._t * 1.5 + j * TAU / 5.0)
			ci.draw_line(Vector2(0, -140), Vector2(0, -140) + Vector2(d.x * 120.0, 100.0 + d.y * 20.0), Color(PARTY[j], 0.35), 6.0, true)


# Firework Tower: Scaffold, Platform, Rocket Rack, Countdown Sign, Big Rocket.
static func _firework_tower(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4)
		return
	for x in [-60.0, 60.0]:
		s._post(ci, Vector2(x, 0), Vector2(x * 0.7, -200), 8.0)
	for y in [-60.0, -130.0]:
		s._post(ci, Vector2(-56, y), Vector2(56, y - 30), 5.0)
	if lv >= 2:
		s._box(ci, Rect2(Vector2(-60, -214), Vector2(120, 16)), TSSites.WOOD)
	if lv >= 3:
		for j in 3:
			var x := -36.0 + j * 36.0
			s._blob(ci, [Vector2(x - 8, -214), Vector2(x + 8, -214), Vector2(x + 8, -256), Vector2(x, -270), Vector2(x - 8, -256)], PARTY[j])
		_burst(s, ci, Vector2(-80, -330), 50.0, 0.0, PARTY[0])
		_burst(s, ci, Vector2(70, -360), 60.0, 0.45, PARTY[2])
	if lv >= 4:
		TSSites.sign(s, ci, Vector2(0, -100), "3 2 1!", 84.0, TSSites.NIGHT, TSSites.GOLD)
		s._blob(ci, [Vector2(-22, -214), Vector2(22, -214), Vector2(22, -300), Vector2(0, -340), Vector2(-22, -300)], TSSites.RED)
		s._blob(ci, [Vector2(-22, -230), Vector2(-40, -210), Vector2(-22, -260)], TSSites.GOLD)
		s._blob(ci, [Vector2(22, -230), Vector2(40, -210), Vector2(22, -260)], TSSites.GOLD)
		ci.draw_circle(Vector2(0, -280), 9.0, TSSites.ACCENT, true, -1.0, true)
		_burst(s, ci, Vector2(0, -420), 80.0, 0.2, TSSites.GOLD)


# Party Shop: Crates, Stall, Awning, Party Hats, Bell & Sign.
static func _party_shop(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 6.0)
	if lv == 0:
		s._box(ci, Rect2(Vector2(-60, -44), Vector2(50, 44)), TSSites.WOOD)
		s._box(ci, Rect2(Vector2(-4, -36), Vector2(44, 36)), TSSites.WOOD.darkened(0.1))
		return
	for x in [-80.0, 80.0]:
		s._post(ci, Vector2(x, -60), Vector2(x, -170), 7.0)
	s._box(ci, Rect2(Vector2(-90, -64), Vector2(180, 64)), TSSites.WOOD)
	if lv >= 2:
		for j in 6:
			var x0 := -100.0 + j * 33.4
			s._blob(ci, [Vector2(x0, -190), Vector2(x0 + 33.4, -190), Vector2(x0 + 33.4, -160), Vector2(x0 + 16.7, -150), Vector2(x0, -160)], TSSites.LILAC if j % 2 == 0 else TSSites.BUTTER)
	if lv >= 3:
		for j in 4:
			var at := Vector2(-60 + j * 40, -64)
			s._blob(ci, [at + Vector2(-12, 0), at + Vector2(12, 0), at + Vector2(0, -34)], PARTY[j])
			ci.draw_circle(at + Vector2(0, -34), 4.0, Color.WHITE, true, -1.0, true)
	if lv >= 4:
		TSSites.sign(s, ci, Vector2(0, -214), "PARTY", 110.0)
		for j in 3:
			var bob := sin(s._t * 2.0 + j) * 4.0
			var at := Vector2(80 + j * 16, -190 + bob)
			ci.draw_line(at, at + Vector2(0, 50), TSSites.INK, 1.5, true)
			s._ellipse(ci, at, 11.0, 13.0, PARTY[j + 2])


# Lantern House: Glass Shards, Frame, Glass Panes, Paper Lanterns, Glow.
static func _lantern_house(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0)
	if lv == 0:
		for at in [Vector2(-40, -4), Vector2(0, -10), Vector2(40, -2)]:
			s._blob(ci, [at, at + Vector2(20, -10), at + Vector2(10, 10)], Color(0.82, 0.86, 1.0))
		return
	var shape := [Vector2(-90, 0), Vector2(90, 0), Vector2(90, -90), Vector2(0, -150), Vector2(-90, -90)]
	if lv >= 2:
		s._blob(ci, shape, Color(0.78, 0.82, 1.0, 0.6))
	for v in [[Vector2(-90, 0), Vector2(-90, -90)], [Vector2(90, 0), Vector2(90, -90)], [Vector2(-90, -90), Vector2(0, -150)], [Vector2(90, -90), Vector2(0, -150)], [Vector2(0, 0), Vector2(0, -150)], [Vector2(-90, -50), Vector2(90, -50)]]:
		s._post(ci, v[0], v[1], 4.0, SILVER)
	if lv >= 3:
		for j in 4:
			var at := Vector2(-60 + j * 40, -70 - (j % 2) * 30)
			var sway := sin(s._t * 1.6 + j) * 3.0
			s._ellipse(ci, at + Vector2(sway, 0), 13.0, 16.0, [Color(1.0, 0.56, 0.42), TSSites.BUTTER, Color(1.0, 0.62, 0.74), TSSites.BUTTER][j])
	if lv >= 4:
		ci.draw_circle(Vector2(0, -70), 90.0, Color(1.0, 0.8, 0.5, 0.15 + 0.05 * sin(s._t * 2.0)), true, -1.0, true)
		TSSites.twinkle(s, ci, Vector2(0, -150), 30.0, TSSites.BUTTER, 3)


# Bubbly Fountain: Puddle, Stone Pool, Bubbles, Sparkling Jets, Gold Rim.
static func _bubbly_fountain(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		s._ellipse(ci, Vector2.ZERO, 40.0, 10.0, TSShipScene.WATER, false)
		return
	s._ellipse(ci, Vector2.ZERO, 100.0, 28.0, Color(0.94, 0.86, 0.6))
	for j in 12:
		var a := TAU * float(j) / 12.0
		s._ellipse(ci, Vector2(cos(a) * 104.0, sin(a) * 30.0), 16.0, 10.0, TSSites.GOLD if lv >= 4 else TSSites.STONE)
	if lv >= 2:
		for j in 6:
			var age := fposmod(s._t * 0.5 + float(j) / 6.0, 1.0)
			ci.draw_arc(Vector2(-60 + j * 24, -age * 80.0), 6.0 + age * 4.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8 * (1.0 - age)), 2.5, true)
	if lv >= 3:
		for side in [-1.0, 0.0, 1.0]:
			var pts := PackedVector2Array()
			var hgt := 120.0 if side == 0.0 else 80.0
			for j in 9:
				var u := float(j) / 8.0
				pts.append(Vector2(side * 30.0 + side * u * 40.0, -hgt * 4.0 * u * (1.0 - u)))
			ci.draw_polyline(pts, Color(0.8, 0.94, 1.0, 0.9), 6.0, true)
		TSSites.twinkle(s, ci, Vector2(0, -90), 40.0, Color.WHITE, 3)


# Countdown Stage: Rubble, Stage, Curtains, Spotlights, Countdown Clock.
static func _countdown_stage(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 120.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-40, 0), Vector2(10, -6), Vector2(50, 2), Vector2(-10, -26)], TSSites.STONE, 26.0, 16.0)
		return
	s._box(ci, Rect2(Vector2(-120, -40), Vector2(240, 40)), Color(0.5, 0.36, 0.56))
	for j in 3:
		s._box(ci, Rect2(Vector2(-110 + j * 80, -40), Vector2(60, 10)), Color(0.6, 0.46, 0.66))
	if lv >= 2:
		for x in [-110.0, 110.0]:
			s._post(ci, Vector2(x, -40), Vector2(x, -200), 6.0, TSSites.INK)
		s._box(ci, Rect2(Vector2(-120, -210), Vector2(240, 20)), TSSites.NIGHT)
		for side in [-1.0, 1.0]:
			var sway := sin(s._t * 1.2) * 4.0
			s._blob(ci, [Vector2(side * 108, -190), Vector2(side * 60 + sway, -190), Vector2(side * 76, -40), Vector2(side * 108, -40)], TSSites.RED)
	if lv >= 3:
		for side in [-1.0, 1.0]:
			var lamp := Vector2(side * 100, -200)
			var aim := Vector2(side * -30 + sin(s._t + side) * 30.0, -40)
			ci.draw_colored_polygon(PackedVector2Array([lamp, aim + Vector2(-30, 0), aim + Vector2(30, 0)]), Color(1.0, 0.96, 0.8, 0.25))
			ci.draw_circle(lamp, 9.0, TSSites.BUTTER, true, -1.0, true)
	if lv >= 4:
		s._box(ci, Rect2(Vector2(-60, -280), Vector2(120, 56)), TSSites.INK)
		var count := 10 - int(fposmod(s._t, 11.0))
		s._text(ci, Vector2(-30, -238), "0:%02d" % maxi(count, 0), 34.0, TSSites.GOLD)
		if count <= 0:
			_burst(s, ci, Vector2(0, -330), 70.0, 0.0, TSSites.GOLD)


# Cake Bakery: Clay Lump, Oven, Chimney, Cupcakes, Tiered Cake.
static func _cake_bakery(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	var clay := Color(0.82, 0.62, 0.7)
	if lv == 0:
		s._ellipse(ci, Vector2(0, -14), 50.0, 26.0, clay.darkened(0.15))
		return
	if lv >= 2:
		s._box(ci, Rect2(Vector2(20, -150), Vector2(24, 70)), clay.darkened(0.1))
		TSSites.puffs(s, ci, Vector2(32, -160), Color(1.0, 0.92, 0.96))
	TSSites.dome(s, ci, Vector2.ZERO, 80.0, clay)
	TSSites.dome(s, ci, Vector2.ZERO, 34.0, Color(0.32, 0.22, 0.3))
	ci.draw_circle(Vector2(0, -12), 12.0, Color(1.0, 0.6, 0.4, 0.6 + 0.3 * sin(s._t * 9.0)), true, -1.0, true)
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-136, -30), Vector2(64, 30)), TSSites.WOOD)
		for j in 3:
			var at := Vector2(-124 + j * 20, -30)
			s._blob(ci, [at + Vector2(-8, 0), at + Vector2(8, 0), at + Vector2(9, -12), at + Vector2(-9, -12)], Color(0.9, 0.7, 0.5))
			TSSites.dome(s, ci, at + Vector2(0, -12), 9.0, PARTY[j])
	if lv >= 4:
		for t in 3:
			var w := 34.0 - t * 9.0
			s._box(ci, Rect2(Vector2(125 - w, -24.0 - t * 22.0), Vector2(w * 2.0, 22)), [Color(1.0, 0.94, 0.86), Color(1.0, 0.78, 0.86), TSSites.LILAC.lightened(0.3)][t])
		ci.draw_line(Vector2(125, -90), Vector2(125, -104), TSSites.INK, 2.0, true)
		ci.draw_circle(Vector2(125, -108), 4.0 + sin(s._t * 9.0), Color(1.0, 0.7, 0.3), true, -1.0, true)


# Golden Hourglass: Big Rock, Base, Hourglass, Pedestal, Golden Hourglass.
static func _hourglass(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	if lv == 0:
		s._blob(ci, [Vector2(-50, 0), Vector2(50, 0), Vector2(40, -60), Vector2(0, -80), Vector2(-40, -56)], TSSites.STONE)
		return
	var base := Vector2.ZERO
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-56, -40), Vector2(112, 40)), Color(0.9, 0.88, 0.98))
		base = Vector2(0, -40)
	var frame := TSSites.GOLD if lv >= 4 else TSSites.WOOD
	s._box(ci, Rect2(base + Vector2(-44, -14), Vector2(88, 14)), frame)
	if lv >= 2:
		var glass := Color(0.86, 0.92, 1.0, 0.8)
		s._blob(ci, [base + Vector2(-34, -14), base + Vector2(34, -14), base + Vector2(4, -60), base + Vector2(34, -106), base + Vector2(-34, -106), base + Vector2(-4, -60)], glass)
		var flow := fposmod(s._t * 0.1, 1.0)
		s._blob(ci, [base + Vector2(-26.0 * (1.0 - flow), -96.0 + 30.0 * flow), base + Vector2(26.0 * (1.0 - flow), -96.0 + 30.0 * flow), base + Vector2(0, -64)], TSSites.BUTTER, false)
		s._blob(ci, [base + Vector2(-30, -16), base + Vector2(30, -16), base + Vector2(0, -16 - 40.0 * flow)], TSSites.BUTTER, false)
		ci.draw_line(base + Vector2(0, -62), base + Vector2(0, -18), TSSites.BUTTER, 2.0, true)
		s._box(ci, Rect2(base + Vector2(-44, -120), Vector2(88, 14)), frame)
		for x in [-40.0, 40.0]:
			s._post(ci, base + Vector2(x, -14), base + Vector2(x, -106), 5.0, frame)
	else:
		s._blob(ci, [base + Vector2(-30, -14), base + Vector2(30, -14), base + Vector2(20, -80), base + Vector2(-20, -80)], TSSites.STONE)
	if lv >= 4:
		TSSites.twinkle(s, ci, base + Vector2(0, -70), 60.0, TSSites.BUTTER, 4)


# -- the card's icons --------------------------------------------------------------

static func icon(ic: TSIcon, part: int, broken: bool) -> void:
	var lilac := Color(0.72, 0.7, 0.78) if broken else TSSites.LILAC
	var gold := Color(0.8, 0.76, 0.66) if broken else TSSites.GOLD
	var night := Color(0.5, 0.5, 0.58) if broken else TSSites.NIGHT
	var wood := Color(0.62, 0.5, 0.44) if broken else Color(0.78, 0.56, 0.38)
	var silver := SILVER
	if broken:
		ic._ellipse(Vector2(0.5, 0.72), 0.34, 0.12, Color(0.74, 0.7, 0.84))
	match part:
		TSProfile.CAMP_FIRE:
			ic._rrect(Rect2(0.22, 0.62, 0.56, 0.1), 0.04, wood)
			if not broken:
				ic._poly([Vector2(0.38, 0.64), Vector2(0.5, 0.26), Vector2(0.62, 0.64)], Color(0.86, 0.5, 1.0))
				_star(ic, Vector2(0.7, 0.24), 0.08, gold)
		TSProfile.CAMP_TENT:
			ic._poly([Vector2(0.12, 0.8), Vector2(0.5, 0.18), Vector2(0.88, 0.8)], lilac)
			ic._poly([Vector2(0.38, 0.8), Vector2(0.5, 0.18), Vector2(0.62, 0.8)], Color(0.98, 0.96, 1.0))
		TSProfile.CAMP_BENCH:
			ic._rrect(Rect2(0.14, 0.56, 0.72, 0.1), 0.02, wood)
			if not broken:
				for j in 3:
					ic._poly([Vector2(0.28 + j * 0.16, 0.56), Vector2(0.36 + j * 0.16, 0.56), Vector2(0.32 + j * 0.16, 0.24)], [TSSites.RED, gold, TSSites.ACCENT][j])
		TSProfile.CAMP_GARDEN:
			ic._ellipse(Vector2(0.5, 0.7), 0.38, 0.14, Color(0.5, 0.4, 0.46))
			if not broken:
				for x in [0.3, 0.5, 0.7]:
					ic._line([Vector2(x, 0.7), Vector2(x, 0.42)], Color(0.36, 0.62, 0.5), 1.0)
					_star(ic, Vector2(x, 0.38), 0.08, gold)
		TSProfile.CAMP_WELL:
			ic._rrect(Rect2(0.26, 0.54, 0.48, 0.28), 0.04, TSSites.STONE)
			if not broken:
				ic._poly([Vector2(0.18, 0.3), Vector2(0.82, 0.3), Vector2(0.5, 0.1)], night)
				_star(ic, Vector2(0.5, 0.44), 0.07, gold)
		TSProfile.CAMP_LOOKOUT:
			ic._rrect(Rect2(0.34, 0.3, 0.32, 0.56), 0.02, Color(0.66, 0.58, 0.8))
			if not broken:
				ic._poly([Vector2(0.28, 0.32), Vector2(0.72, 0.32), Vector2(0.5, 0.08)], night)
				ic._circle(Vector2(0.5, 0.46), 0.1, Color(1.0, 0.98, 0.9))
				ic._line([Vector2(0.5, 0.46), Vector2(0.5, 0.39)], TSIcon.INK, 0.6)
		TSProfile.CAMP_HAMMOCK:
			ic._line([Vector2(0.2, 0.82), Vector2(0.7, 0.5)], wood, 1.2)
			ic._poly([Vector2(0.22, 0.66), Vector2(0.56, 0.66), Vector2(0.5, 0.3), Vector2(0.34, 0.28)], lilac)
		TSProfile.CAMP_PICNIC:
			ic._rrect(Rect2(0.14, 0.46, 0.72, 0.1), 0.02, lilac)
			if not broken:
				ic._poly([Vector2(0.4, 0.46), Vector2(0.6, 0.46), Vector2(0.5, 0.18)], Color(1.0, 0.62, 0.74))
		TSProfile.CAMP_CLOTHESLINE:
			ic._line([Vector2(0.1, 0.26), Vector2(0.9, 0.26)], TSIcon.INK, 0.8)
			if not broken:
				for j in 4:
					ic._poly([Vector2(0.12 + j * 0.2, 0.26), Vector2(0.28 + j * 0.2, 0.26), Vector2(0.2 + j * 0.2, 0.46)], [lilac, gold, TSSites.ACCENT, TSSites.PINK][j])
		TSProfile.CAMP_MAILBOX:
			ic._line([Vector2(0.5, 0.86), Vector2(0.5, 0.56)], wood, 1.4)
			ic._rrect(Rect2(0.28, 0.24, 0.44, 0.34), 0.04, night)
			if not broken:
				_star(ic, Vector2(0.5, 0.42), 0.08, gold)
		TSProfile.CAMP_WINDMILL:
			ic._line([Vector2(0.5, 0.88), Vector2(0.5, 0.44)], silver, 1.6)
			if not broken:
				for j in 4:
					var d := Vector2.from_angle(j * PI * 0.5)
					ic._poly([Vector2(0.5, 0.44), Vector2(0.5, 0.44) + d * 0.3, Vector2(0.5, 0.44) + d * 0.16 + Vector2(-d.y, d.x) * 0.16], PARTY[j])
		TSProfile.CAMP_DOCK:
			ic._rrect(Rect2(0.3, 0.56, 0.4, 0.24), 0.02, wood)
			if not broken:
				ic._rrect(Rect2(0.42, 0.22, 0.16, 0.2), 0.04, Color(1.0, 0.6, 0.44))
		TSProfile.CAMP_PLAYGROUND:
			ic._poly([Vector2(0.1, 0.84), Vector2(0.9, 0.84), Vector2(0.8, 0.6), Vector2(0.2, 0.6)], Color(0.36, 0.32, 0.5))
			if not broken:
				ic._circle(Vector2(0.5, 0.3), 0.14, silver)
		TSProfile.CAMP_TREEHOUSE:
			ic._line([Vector2(0.3, 0.86), Vector2(0.38, 0.4)], wood, 1.4)
			ic._line([Vector2(0.7, 0.86), Vector2(0.62, 0.4)], wood, 1.4)
			if not broken:
				ic._poly([Vector2(0.42, 0.4), Vector2(0.58, 0.4), Vector2(0.58, 0.2), Vector2(0.5, 0.1), Vector2(0.42, 0.2)], TSSites.RED)
				_star(ic, Vector2(0.78, 0.18), 0.08, gold)
		TSProfile.CAMP_STALL:
			ic._rrect(Rect2(0.16, 0.54, 0.68, 0.3), 0.03, wood)
			if not broken:
				for k in 4:
					ic._poly([Vector2(0.12 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.34), Vector2(0.12 + k * 0.19, 0.34)], lilac if k % 2 == 0 else TSSites.BUTTER)
		TSProfile.CAMP_GREENHOUSE:
			ic._poly([Vector2(0.14, 0.84), Vector2(0.86, 0.84), Vector2(0.86, 0.44), Vector2(0.5, 0.18), Vector2(0.14, 0.44)], Color(0.78, 0.82, 1.0))
			if not broken:
				ic._ellipse(Vector2(0.4, 0.6), 0.07, 0.09, Color(1.0, 0.56, 0.42))
				ic._ellipse(Vector2(0.62, 0.56), 0.07, 0.09, TSSites.BUTTER)
		TSProfile.CAMP_SPRING:
			ic._ellipse(Vector2(0.5, 0.66), 0.38, 0.14, Color(0.62, 0.88, 0.94))
			if not broken:
				for x in [0.36, 0.5, 0.64]:
					ic._circle(Vector2(x, 0.4 - (0.06 if x == 0.5 else 0.0)), 0.05, Color.WHITE)
		TSProfile.CAMP_OBSERVATORY:
			ic._rrect(Rect2(0.12, 0.66, 0.76, 0.16), 0.02, Color(0.5, 0.36, 0.56))
			if not broken:
				ic._rrect(Rect2(0.3, 0.2, 0.4, 0.22), 0.02, TSIcon.INK)
				ic._line([Vector2(0.4, 0.31), Vector2(0.6, 0.31)], gold, 1.2)
		TSProfile.CAMP_OVEN:
			ic._poly(TSSitesChristmas._dome(Vector2(0.5, 0.82), 0.38 if not broken else 0.24), Color(0.82, 0.62, 0.7))
			if not broken:
				ic._rrect(Rect2(0.38, 0.62, 0.24, 0.2), 0.1, Color(0.32, 0.22, 0.3))
		TSProfile.CAMP_STATUE:
			if broken:
				ic._poly([Vector2(0.2, 0.84), Vector2(0.8, 0.84), Vector2(0.7, 0.4), Vector2(0.5, 0.3), Vector2(0.28, 0.44)], TSSites.STONE)
			else:
				ic._rrect(Rect2(0.28, 0.14, 0.44, 0.08), 0.02, gold)
				ic._rrect(Rect2(0.28, 0.78, 0.44, 0.08), 0.02, gold)
				ic._poly([Vector2(0.34, 0.22), Vector2(0.66, 0.22), Vector2(0.52, 0.5), Vector2(0.66, 0.78), Vector2(0.34, 0.78), Vector2(0.48, 0.5)], Color(0.86, 0.92, 1.0))
				ic._poly([Vector2(0.38, 0.78), Vector2(0.62, 0.78), Vector2(0.5, 0.64)], TSSites.BUTTER, false)


static func _star(ic: TSIcon, c: Vector2, r: float, fill: Color) -> void:
	var pts: Array = []
	for j in 10:
		var a := -PI * 0.5 + TAU * float(j) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.45))
	ic._poly(pts, fill)
