class_name TSSitesChristmas
extends RefCounted

## The Christmas planet's work sites (TSSites): a snowy village of yule fires,
## igloos, a toy workshop, a tree farm and a cocoa stand. Drawn round each
## spot's foot at (0, 0).



static func draw(s: TSShipScene, ci: CanvasItem, part: int, lv: int) -> void:
	match part:
		TSProfile.CAMP_FIRE: _yule_fire(s, ci, lv)
		TSProfile.CAMP_TENT: _igloo(s, ci, lv)
		TSProfile.CAMP_BENCH: _toy_bench(s, ci, lv)
		TSProfile.CAMP_GARDEN: _tree_farm(s, ci, lv)
		TSProfile.CAMP_WELL: _cocoa_fountain(s, ci, lv)
		TSProfile.CAMP_LOOKOUT: _bell_tower(s, ci, lv)
		TSProfile.CAMP_HAMMOCK: _sled(s, ci, lv)
		TSProfile.CAMP_PICNIC: _cookie_table(s, ci, lv)
		TSProfile.CAMP_CLOTHESLINE: _stocking_line(s, ci, lv)
		TSProfile.CAMP_MAILBOX: _santa_mailbox(s, ci, lv)
		TSProfile.CAMP_WINDMILL: _snow_mill(s, ci, lv)
		TSProfile.CAMP_DOCK: _ice_hut(s, ci, lv)
		TSProfile.CAMP_PLAYGROUND: _sled_hill(s, ci, lv)
		TSProfile.CAMP_TREEHOUSE: _big_tree(s, ci, lv)
		TSProfile.CAMP_STALL: _cocoa_stand(s, ci, lv)
		TSProfile.CAMP_GREENHOUSE: _gingerbread_house(s, ci, lv)
		TSProfile.CAMP_SPRING: _ice_rink(s, ci, lv)
		TSProfile.CAMP_OBSERVATORY: _sleigh_pad(s, ci, lv)
		TSProfile.CAMP_OVEN: _cookie_oven(s, ci, lv)
		TSProfile.CAMP_STATUE: _ice_sculpture(s, ci, lv)


# Yule Log Fire: Cold Embers, Yule Log, Stone Ring, Cocoa Pot, Roaring Yule Fire.
static func _yule_fire(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 56.0)
	if lv >= 2:
		for j in 9:
			var a := TAU * float(j) / 9.0
			s._ellipse(ci, Vector2(cos(a) * 48.0, sin(a) * 13.0 + 6.0), 11.0, 7.0, TSSites.STONE)
	# The log: bark, a cut end, a sprig of holly.
	s._blob(ci, [Vector2(-40, -4), Vector2(36, -4), Vector2(36, -26), Vector2(-40, -26)], TSSites.WOOD.darkened(0.15 if lv == 0 else 0.0))
	s._ellipse(ci, Vector2(36, -15), 8.0, 11.0, Color(0.9, 0.74, 0.54))
	if lv == 0:
		TSSites.puffs(s, ci, Vector2(0, -26), Color(0.66, 0.64, 0.7), 60.0, 2)
		return
	ci.draw_circle(Vector2(-22, -30), 6.0, TSSites.GREEN, true, -1.0, true)
	ci.draw_circle(Vector2(-14, -32), 6.0, TSSites.GREEN, true, -1.0, true)
	ci.draw_circle(Vector2(-18, -36), 4.0, TSSites.RED, true, -1.0, true)
	var flick := 1.0 + 0.12 * sin(s._t * 11.0)
	var big := 1.4 if lv >= 4 else 1.0
	s._blob(ci, [Vector2(-22 * big, -24), Vector2(0, -24 - 52.0 * big * flick), Vector2(22 * big, -24)], Color(1.0, 0.55, 0.3))
	s._blob(ci, [Vector2(-11 * big, -24), Vector2(0, -24 - 28.0 * big * flick), Vector2(11 * big, -24)], TSSites.BUTTER, false)
	if lv >= 3:
		for leg in [-1.0, 1.0]:
			ci.draw_line(Vector2(leg * 50.0, 8.0), Vector2(0, -150.0), TSSites.INK, 4.0, true)
		ci.draw_line(Vector2(0, -150), Vector2(0, -136), TSSites.INK, 2.0, true)
		s._blob(ci, [Vector2(-18, -136), Vector2(18, -136), Vector2(14, -112), Vector2(-14, -112)], Color(0.52, 0.32, 0.26))
		TSSites.puffs(s, ci, Vector2(0, -140), Color(0.98, 0.94, 0.9), 50.0, 2)
	if lv >= 4:
		for n in 4:
			var age := fposmod(s._t * 0.7 + float(n) / 4.0, 1.0)
			s._sparkle(ci, Vector2(sin(age * 9.0 + n) * 22.0, -70.0 - age * 90.0), 5.0 * (1.0 - age), Color(1.0, 0.7, 0.3))


# Igloo: Snow Pile, Snow Dome, Ice Door, Icicle Lights, Snow Palace.
static func _igloo(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 6.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-40, -10), Vector2(20, -14), Vector2(-6, -30), Vector2(50, -4)], TSSites.SNOW, 34.0, 20.0)
		return
	var r := 100.0 if lv >= 4 else 82.0
	TSSites.dome(s, ci, Vector2.ZERO, r, TSSites.SNOW)
	for row in 3:
		var y := -r * (0.25 + row * 0.25)
		var half := sqrt(maxf(r * r - y * y, 0.0))
		ci.draw_line(Vector2(-half + 4, y), Vector2(half - 4, y), Color(TSSites.ICE.darkened(0.2), 0.8), 2.5, true)
		for j in 4:
			var x := -half + (half * 2.0) * (float(j) + 0.5 * (row % 2)) / 4.0
			ci.draw_line(Vector2(x, y), Vector2(x, y + r * 0.25), Color(TSSites.ICE.darkened(0.2), 0.6), 2.0, true)
	if lv >= 2:
		TSSites.dome(s, ci, Vector2(0, 0), 32.0, TSSites.ICE)
		TSSites.dome(s, ci, Vector2(0, 0), 22.0, Color(0.32, 0.36, 0.56))
	if lv >= 3:
		var cols: Array = TSShipScene.LIGHTS
		for j in 9:
			var a := PI + PI * (float(j) + 0.5) / 9.0
			var at := Vector2(cos(a), sin(a)) * (r + 2.0)
			var on := fposmod(s._t * 2.0 + j * 0.4, 2.0) < 1.4
			ci.draw_circle(at, 5.0, (cols[j % 4] as Color) if on else (cols[j % 4] as Color).darkened(0.4), true, -1.0, true)
	if lv >= 4:
		# Two little ice turrets either side, a star flag on top.
		for side in [-1.0, 1.0]:
			s._box(ci, Rect2(Vector2(side * (r + 6.0) - 16.0, -70), Vector2(32, 70)), TSSites.ICE)
			TSSites.roof(s, ci, Vector2(side * (r + 6.0) - 20.0, -70), Vector2(side * (r + 6.0) + 20.0, -70), 30.0, TSSites.SNOW)
		TSSites.flag(s, ci, Vector2(0, -r - 50.0), TSSites.RED, 50.0)


# Toy Bench: Loose Planks, Toy Bench, Toy Rack, Wrapping Station, Candy Awning.
static func _toy_bench(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0, 6.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4, Color(0.8, 0.6, 0.42))
		return
	if lv >= 4:
		for x in [-80.0, 80.0]:
			TSSites.cane(ci, Vector2(x, 0), Vector2(x, -140), 7.0)
		for j in 6:
			var x0 := -90.0 + j * 30.0
			s._blob(ci, [Vector2(x0, -150), Vector2(x0 + 30, -150), Vector2(x0 + 30, -126), Vector2(x0 + 15, -116), Vector2(x0, -126)], TSSites.RED if j % 2 == 0 else TSSites.SNOW)
	if lv >= 2:
		s._blob(ci, [Vector2(-60, -112), Vector2(60, -112), Vector2(60, -62), Vector2(-60, -62)], TSSites.WOOD.darkened(0.2))
		# Toys on the rack: a ball, a little boat, a teddy's head.
		ci.draw_circle(Vector2(-36, -94), 10.0, TSSites.ACCENT, true, -1.0, true)
		s._blob(ci, [Vector2(-10, -80), Vector2(16, -80), Vector2(12, -72), Vector2(-6, -72)], TSSites.RED)
		ci.draw_circle(Vector2(38, -92), 11.0, Color(0.8, 0.58, 0.4), true, -1.0, true)
		ci.draw_circle(Vector2(31, -101), 5.0, Color(0.8, 0.58, 0.4), true, -1.0, true)
		ci.draw_circle(Vector2(45, -101), 5.0, Color(0.8, 0.58, 0.4), true, -1.0, true)
	for x in [-56.0, 56.0]:
		ci.draw_line(Vector2(x, 0), Vector2(x, -48), TSSites.INK, 9.0, true)
		ci.draw_line(Vector2(x, 0), Vector2(x, -48), TSSites.WOOD, 5.0, true)
	s._box(ci, Rect2(Vector2(-74, -62), Vector2(148, 16)), Color(0.86, 0.66, 0.46))
	if lv >= 3:
		TSSites.present(s, ci, Vector2(-30, -62), 0.8)
		TSSites.present(s, ci, Vector2(10, -62), 0.65)
		# A roll of paper.
		s._blob(ci, [Vector2(30, -62), Vector2(68, -62), Vector2(68, -76), Vector2(30, -76)], TSSites.GREEN)
	if lv == 1:
		TSSites.snow_cap(s, ci, Vector2(0, -62), 70.0)


# Tree Farm: Frozen Dirt, Saplings, Little Pines, Baubles, Star-Topped Tree.
static func _tree_farm(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	s._ellipse(ci, Vector2(0, -6), 110.0, 28.0, Color(0.66, 0.6, 0.64) if lv == 0 else Color(0.9, 0.94, 1.0))
	if lv == 0:
		for j in 4:
			ci.draw_line(Vector2(-70 + j * 44, -10), Vector2(-50 + j * 44, -2), Color(TSSites.INK, 0.4), 3.0, true)
		return
	var spots := [Vector2(-66, -10), Vector2(-20, 2), Vector2(26, -12), Vector2(70, 0)]
	for n in spots.size():
		var at: Vector2 = spots[n]
		var h := 30.0 if lv == 1 else 70.0 + (n % 2) * 12.0
		if lv >= 4 and n == 1:
			h = 120.0
		s._post(ci, at, at + Vector2(0, -12), 5.0, TSSites.WOOD)
		for tier in 3:
			var w := h * (0.42 - tier * 0.09)
			var y := -10.0 - h * tier * 0.28
			s._blob(ci, [at + Vector2(-w, y), at + Vector2(w, y), at + Vector2(0, y - h * 0.5)], TSSites.GREEN.darkened(0.08 * tier))
		if lv >= 3:
			for b in 3:
				var bc: Color = TSShipScene.LIGHTS[(b + n) % 4]
				ci.draw_circle(at + Vector2(-h * 0.18 + b * h * 0.18, -16.0 - h * 0.2 - (b % 2) * h * 0.14), 5.0, bc, true, -1.0, true)
		if lv >= 4 and n == 1:
			TSSites.star(ci, at + Vector2(0, -10.0 - h * 1.06), 16.0 + sin(s._t * 3.0) * 1.5, TSSites.GOLD)


# Cocoa Fountain: Ice Chunks, Fountain, Cocoa Flowing, Marshmallows, Candy Cane Rim.
static func _cocoa_fountain(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 80.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-34, -6), Vector2(10, -10), Vector2(40, -2), Vector2(-6, -26)], TSSites.ICE)
		return
	s._box(ci, Rect2(Vector2(-70, -50), Vector2(140, 50)), Color(0.86, 0.82, 0.9))
	s._ellipse(ci, Vector2(0, -50), 70.0, 16.0, Color(0.5, 0.32, 0.24) if lv >= 2 else Color(0.62, 0.72, 0.9))
	s._post(ci, Vector2(0, -50), Vector2(0, -110), 12.0, Color(0.86, 0.82, 0.9))
	s._ellipse(ci, Vector2(0, -110), 34.0, 9.0, Color(0.86, 0.82, 0.9))
	if lv >= 2:
		s._ellipse(ci, Vector2(0, -112), 28.0, 6.0, Color(0.5, 0.32, 0.24), false)
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for j in 8:
				var u := float(j) / 7.0
				pts.append(Vector2(side * (28.0 + u * 22.0), -110.0 + u * u * 58.0))
			ci.draw_polyline(pts, Color(0.5, 0.32, 0.24), 7.0, true)
		TSSites.puffs(s, ci, Vector2(0, -118), Color.WHITE, 50.0, 2)
	if lv >= 3:
		for j in 4:
			var bob := sin(s._t * 2.0 + j) * 2.0
			s._box(ci, Rect2(Vector2(-46 + j * 26, -60 + bob), Vector2(16, 12)), TSSites.SNOW)
	if lv >= 4:
		for x in [-74.0, 74.0]:
			TSSites.cane(ci, Vector2(x, 0), Vector2(x, -80), 8.0)
			ci.draw_arc(Vector2(x - 12.0 * signf(x), -80), 12.0, PI, TAU if x > 0 else PI * 2.0, 10, TSSites.INK, 13.0, true)
			ci.draw_arc(Vector2(x - 12.0 * signf(x), -80), 12.0, PI, TAU, 10, TSSites.RED, 8.0, true)


# Bell Tower: Pile of Logs, Platform, Bell, Peaked Roof, Wreath.
static func _bell_tower(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4)
		return
	for x in [-44.0, 44.0]:
		s._post(ci, Vector2(x, 0), Vector2(x * 0.8, -150), 9.0)
	s._post(ci, Vector2(-44, -40), Vector2(40, -110), 5.0)
	s._post(ci, Vector2(44, -40), Vector2(-40, -110), 5.0)
	s._box(ci, Rect2(Vector2(-56, -160), Vector2(112, 14)), TSSites.WOOD)
	if lv >= 2:
		var swing := sin(s._t * 2.4) * 0.25 if fposmod(s._t, 5.0) < 1.5 else 0.0
		var hang := Vector2(0, -214)
		var bell := [Vector2(-22, 0), Vector2(22, 0), Vector2(16, -30), Vector2(-16, -30)]
		var pts: Array = []
		for v in bell:
			pts.append(hang + Vector2(0, 30) + (v as Vector2).rotated(swing))
		s._blob(ci, pts, TSSites.GOLD)
		ci.draw_circle(hang + Vector2(0, 34) + Vector2(0, 4).rotated(swing), 6.0, TSSites.INK, true, -1.0, true)
	for x in [-40.0, 40.0]:
		s._post(ci, Vector2(x, -160), Vector2(x, -222), 6.0)
	if lv >= 3:
		TSSites.roof(s, ci, Vector2(-62, -220), Vector2(62, -220), 50.0, TSSites.RED)
		TSSites.snow_cap(s, ci, Vector2(0, -262), 30.0)
	if lv >= 4:
		ci.draw_arc(Vector2(0, -120), 22.0, 0.0, TAU, 20, TSSites.INK, 15.0, true)
		ci.draw_arc(Vector2(0, -120), 22.0, 0.0, TAU, 20, TSSites.GREEN, 10.0, true)
		s._blob(ci, [Vector2(-8, -100), Vector2(8, -100), Vector2(12, -88), Vector2(-12, -88)], TSSites.RED)


# Sled: Broken Runners, Sled, Blanket, Scarf, Sleigh Bells.
static func _sled(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0, 4.0)
	if lv == 0:
		ci.draw_arc(Vector2(-30, -10), 24.0, PI * 0.5, PI * 1.3, 10, TSSites.INK, 7.0, true)
		TSSites.planks(s, ci, Vector2(10, 0), 3, TSSites.RED.darkened(0.2))
		return
	# The runners curling up at the front.
	ci.draw_line(Vector2(-80, -4), Vector2(60, -4), TSSites.INK, 8.0, true)
	ci.draw_arc(Vector2(60, -24), 20.0, -PI * 0.5, PI * 0.5, 10, TSSites.INK, 8.0, true)
	for x in [-50.0, 0.0, 40.0]:
		ci.draw_line(Vector2(x, -4), Vector2(x, -26), TSSites.INK, 5.0, true)
	s._blob(ci, [Vector2(-90, -26), Vector2(56, -26), Vector2(60, -40), Vector2(-90, -40)], TSSites.RED)
	s._blob(ci, [Vector2(-96, -40), Vector2(-74, -40), Vector2(-74, -96), Vector2(-96, -88)], TSSites.RED.darkened(0.1))
	if lv >= 2:
		var cloth := PackedVector2Array([Vector2(-70, -40), Vector2(40, -40), Vector2(36, -54), Vector2(-66, -58)])
		s._blob(ci, Array(cloth), TSSites.GREEN)
		for x in [-50.0, -20.0, 10.0]:
			ci.draw_line(Vector2(x, -42), Vector2(x + 4, -56), Color(TSSites.SNOW, 0.8), 3.0, true)
	if lv >= 3:
		var wave := sin(s._t * 3.0) * 5.0
		s._blob(ci, [Vector2(-96, -90), Vector2(-74, -86), Vector2(-60, -64 + wave), Vector2(-70, -60 + wave)], Color(1.0, 0.86, 0.4))
	if lv >= 4:
		for j in 4:
			var at := Vector2(-64 + j * 30, -40)
			var jingle := sin(s._t * 8.0 + j) * 2.0
			ci.draw_circle(at + Vector2(0, 6 + jingle), 7.0, TSSites.INK, true, -1.0, true)
			ci.draw_circle(at + Vector2(0, 6 + jingle), 5.0, TSSites.GOLD, true, -1.0, true)


# Cookie Table: Snowy Log, Log Seat, Cookie Table, Red Cloth, Cookie Feast.
static func _cookie_table(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	if lv == 0:
		s._blob(ci, [Vector2(-70, 0), Vector2(60, 0), Vector2(60, -26), Vector2(-70, -26)], TSSites.WOOD.darkened(0.1))
		TSSites.snow_cap(s, ci, Vector2(-4, -30), 60.0)
		return
	for x in [-90.0, 90.0]:
		s._box(ci, Rect2(Vector2(x - 20, -26), Vector2(40, 26)), TSSites.WOOD.darkened(0.05))
	if lv >= 2:
		for x in [-56.0, 56.0]:
			ci.draw_line(Vector2(x, 0), Vector2(x, -52), TSSites.INK, 9.0, true)
			ci.draw_line(Vector2(x, 0), Vector2(x, -52), TSSites.WOOD, 5.0, true)
		var top := TSSites.RED if lv >= 3 else Color(0.86, 0.66, 0.46)
		s._box(ci, Rect2(Vector2(-74, -66), Vector2(148, 16)), top)
		if lv >= 3:
			for x in [-60.0, -20.0, 20.0, 60.0]:
				ci.draw_rect(Rect2(Vector2(x - 8, -66), Vector2(16, 16)), Color(TSSites.SNOW, 0.85))
	if lv >= 4:
		# A plate of star cookies, a milk jug.
		s._ellipse(ci, Vector2(-24, -70), 30.0, 7.0, TSSites.SNOW)
		for j in 3:
			TSSites.star(ci, Vector2(-44 + j * 20, -78), 9.0, Color(0.9, 0.66, 0.4))
		s._box(ci, Rect2(Vector2(26, -98), Vector2(24, 32)), TSSites.SNOW)
		ci.draw_rect(Rect2(Vector2(28, -86), Vector2(20, 6)), TSSites.ACCENT)


# Stocking Line: Loose Line, Line, Stockings, Mittens, Garland.
static func _stocking_line(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0, 4.0)
	if lv == 0:
		var rope := PackedVector2Array()
		for j in 10:
			rope.append(Vector2(-70 + j * 14, -4 + sin(j * 1.6) * 6))
		ci.draw_polyline(rope, Color(0.9, 0.84, 0.7), 4.0, true)
		return
	for x in [-120.0, 120.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -130), 8.0)
	var line := PackedVector2Array()
	for j in 13:
		var u := float(j) / 12.0
		line.append(Vector2(-120.0 + u * 240.0, -126.0 + sin(u * PI) * 18.0))
	ci.draw_polyline(line, TSSites.INK, 2.5, true)
	if lv >= 2:
		for n in 4:
			var at := line[2 + n * 3]
			var sway := sin(s._t * 2.0 + n) * 3.0
			var c: Color = [TSSites.RED, TSSites.GREEN, TSSites.RED, Color(0.42, 0.62, 1.0)][n]
			s._blob(ci, [at + Vector2(-9, 0), at + Vector2(9, 0), at + Vector2(9 + sway, 34), at + Vector2(22 + sway, 40), at + Vector2(20 + sway, 52), at + Vector2(-6 + sway, 50), at + Vector2(-9 + sway, 34)], c)
			s._box(ci, Rect2(at + Vector2(-11, -2), Vector2(22, 10)), TSSites.SNOW)
	if lv >= 3:
		for n in 2:
			var at := line[1 + n * 9] + Vector2(6, 0)
			s._blob(ci, [at + Vector2(-10, 0), at + Vector2(10, 0), at + Vector2(12, 26), at + Vector2(-12, 26)], Color(0.42, 0.78, 1.0) if n == 0 else TSSites.BUTTER)
			ci.draw_circle(at + Vector2(-12, 16), 6.0, Color(0.42, 0.78, 1.0) if n == 0 else TSSites.BUTTER, true, -1.0, true)
	if lv >= 4:
		var g := PackedVector2Array()
		for j in 25:
			var u := float(j) / 24.0
			g.append(Vector2(-120.0 + u * 240.0, -136.0 + sin(u * PI) * 8.0))
		ci.draw_polyline(g, TSSites.INK, 14.0, true)
		ci.draw_polyline(g, TSSites.GREEN, 9.0, true)
		for j in range(2, 24, 4):
			ci.draw_circle(g[j], 4.0, TSSites.RED, true, -1.0, true)


# North Pole Mailbox: Dented Can, Mailbox, Candy Stripes, Flag Up, Letter Pile.
static func _santa_mailbox(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 40.0)
	if lv == 0:
		s._blob(ci, [Vector2(-20, 0), Vector2(24, -4), Vector2(20, -30), Vector2(-24, -26)], Color(0.7, 0.7, 0.76))
		return
	if lv >= 2:
		TSSites.cane(ci, Vector2(0, 0), Vector2(0, -70), 10.0)
	else:
		s._post(ci, Vector2(0, 0), Vector2(0, -70), 9.0)
	s._blob(ci, [Vector2(-30, -70), Vector2(30, -70), Vector2(30, -110), Vector2(0, -122), Vector2(-30, -110)], TSSites.RED)
	ci.draw_rect(Rect2(Vector2(-16, -96), Vector2(32, 5)), TSSites.INK)
	if lv >= 2:
		TSSites.snow_cap(s, ci, Vector2(0, -122), 32.0)
	if lv >= 3:
		var up := sin(s._t * 1.5) * 0.1
		s._post(ci, Vector2(32, -80), Vector2(32, -80) + Vector2(0, -40).rotated(up), 4.0, TSSites.INK)
		s._blob(ci, [Vector2(32, -120), Vector2(52, -114), Vector2(32, -106)], TSSites.GOLD)
	if lv >= 4:
		for j in 4:
			var at := Vector2(-50 + j * 20, -2 - (j % 2) * 6)
			s._box(ci, Rect2(at, Vector2(26, 18)), TSSites.SNOW)
			ci.draw_line(at, at + Vector2(13, 9), Color(TSSites.INK, 0.5), 2.0, true)
			ci.draw_line(at + Vector2(26, 0), at + Vector2(13, 9), Color(TSSites.INK, 0.5), 2.0, true)


# Snow Mill: Broken Blades, Spinning, Striped Sails, Little Door, Snow Puffs.
static func _snow_mill(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var h := 90.0 if lv == 0 else 210.0
	s._blob(ci, [Vector2(-46, 0), Vector2(46, 0), Vector2(26, -h), Vector2(-26, -h)], Color(0.92, 0.95, 1.0))
	if lv == 0:
		TSSites.planks(s, ci, Vector2(60, 0), 2, Color(0.84, 0.8, 0.78))
		return
	TSSites.roof(s, ci, Vector2(-34, -h), Vector2(34, -h), 40.0, TSSites.GREEN)
	TSSites.snow_cap(s, ci, Vector2(0, -h - 40.0), 22.0)
	if lv >= 3:
		s._blob(ci, [Vector2(-14, 0), Vector2(14, 0), Vector2(14, -36), Vector2(0, -46), Vector2(-14, -36)], TSSites.RED)
		TSSites.lantern(s, ci, Vector2(0, -120))
	if lv >= 4:
		for j in 6:
			var age := fposmod(s._t * 0.3 + float(j) / 6.0, 1.0)
			ci.draw_circle(Vector2(sin(j * 2.1) * 90.0 * age, -h + 10.0 + age * 140.0), 5.0, Color(TSSites.SNOW, 1.0 - age), true, -1.0, true)
	var hub := Vector2(0, -h + 10)
	var spin := s._t * (1.8 if lv >= 2 else 1.0)
	for j in 4:
		var d := Vector2.from_angle(spin + j * PI * 0.5)
		var across := Vector2(-d.y, d.x) * 14.0
		var fill := (TSSites.RED if j % 2 == 0 else TSSites.SNOW) if lv >= 2 else Color(0.86, 0.8, 0.72)
		s._blob(ci, [hub + d * 18.0, hub + d * 100.0, hub + d * 100.0 + across, hub + d * 18.0 + across], fill)
	ci.draw_circle(hub, 9.0, TSSites.INK, true, -1.0, true)


# Ice Fishing Hut: Driftwood, Ice Hole, Little Hut, Lantern, Fish Flag.
static func _ice_hut(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		TSSites.planks(s, ci, Vector2(0, 0), 3, Color(0.8, 0.7, 0.6))
		return
	s._ellipse(ci, Vector2(-60, 4), 26.0, 8.0, Color(0.32, 0.46, 0.66))
	s._ellipse(ci, Vector2(-60, 4), 18.0, 5.0, Color(0.5, 0.7, 0.9), false)
	if lv >= 2:
		s._box(ci, Rect2(Vector2(-10, -70), Vector2(80, 70)), TSSites.RED.darkened(0.1))
		for y in [-50.0, -30.0]:
			ci.draw_line(Vector2(-8, y), Vector2(68, y), Color(TSSites.INK, 0.35), 2.0, true)
		TSSites.roof(s, ci, Vector2(-18, -70), Vector2(78, -70), 36.0, TSSites.WOOD)
		TSSites.snow_cap(s, ci, Vector2(30, -106), 40.0)
		s._box(ci, Rect2(Vector2(18, -40), Vector2(24, 40)), Color(0.4, 0.28, 0.3))
	# A fishing rod over the hole, bobbing.
	var bob := sin(s._t * 1.6) * 3.0
	s._post(ci, Vector2(-20, -4), Vector2(-70, -60), 3.0, TSSites.WOOD)
	ci.draw_line(Vector2(-70, -60), Vector2(-62, 2 + bob), TSSites.INK, 1.5, true)
	ci.draw_circle(Vector2(-62, 2 + bob), 4.0, TSSites.RED, true, -1.0, true)
	if lv >= 3:
		TSSites.lantern(s, ci, Vector2(82, -50))
	if lv >= 4:
		s._post(ci, Vector2(70, -90), Vector2(70, -170), 4.0, TSSites.INK)
		var wave := sin(s._t * 3.0) * 4.0
		s._blob(ci, [Vector2(70, -170), Vector2(110, -160 + wave), Vector2(118, -150 + wave), Vector2(110, -142 + wave), Vector2(70, -146)], TSSites.ACCENT)
		ci.draw_circle(Vector2(84, -160 + wave * 0.5), 3.0, TSSites.INK, true, -1.0, true)


# Sledding Hill: Snow Heap, Sled Ramp, Two Sleds, Snowman, Flag Run.
static func _sled_hill(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 150.0)
	var h := 40.0 if lv == 0 else 140.0
	s._blob(ci, [Vector2(-160, 0), Vector2(160, 0), Vector2(60, -h * 0.7), Vector2(0, -h), Vector2(-50, -h * 0.85)], TSSites.SNOW)
	if lv == 0:
		return
	# The run down the hill, worn smooth.
	ci.draw_line(Vector2(-10, -h + 6), Vector2(150, -4), Color(TSSites.ICE, 0.9), 14.0, true)
	if lv >= 2:
		var u := fposmod(s._t * 0.25, 1.0)
		var at := Vector2(-10, -h + 6).lerp(Vector2(150, -4), u)
		s._blob(ci, [at + Vector2(-22, -6), at + Vector2(22, 4), at + Vector2(20, -6), at + Vector2(-20, -16)], TSSites.RED)
	if lv >= 3:
		var at2 := Vector2(-100, -16)
		s._blob(ci, [at2 + Vector2(-22, 0), at2 + Vector2(22, 0), at2 + Vector2(22, -10), at2 + Vector2(-22, -10)], TSSites.ACCENT)
	if lv >= 3:
		var m := Vector2(-60, -h * 0.55)
		s._ellipse(ci, m, 26.0, 24.0, TSSites.SNOW)
		s._ellipse(ci, m + Vector2(0, -36), 18.0, 17.0, TSSites.SNOW)
		ci.draw_circle(m + Vector2(-6, -40), 2.5, TSSites.INK, true, -1.0, true)
		ci.draw_circle(m + Vector2(6, -40), 2.5, TSSites.INK, true, -1.0, true)
		s._blob(ci, [m + Vector2(0, -34), m + Vector2(16, -31), m + Vector2(0, -30)], Color(1.0, 0.56, 0.24), false)
		s._box(ci, Rect2(m + Vector2(-14, -66), Vector2(28, 14)), TSSites.INK)
	if lv >= 4:
		for j in 4:
			var at3 := Vector2(-10, -h + 6).lerp(Vector2(150, -4), float(j + 1) / 5.0) + Vector2(0, -16)
			s._post(ci, at3, at3 + Vector2(0, -38), 3.0, TSSites.INK)
			s._blob(ci, [at3 + Vector2(0, -38), at3 + Vector2(20, -32 + sin(s._t * 4.0 + j) * 2.0), at3 + Vector2(0, -26)], TSSites.RED if j % 2 == 0 else TSSites.GREEN)


# Giant Christmas Tree: Bare Pine, Garland, Baubles, Lights, Golden Star.
static func _big_tree(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0)
	s._box(ci, Rect2(Vector2(-16, -40), Vector2(32, 40)), TSSites.WOOD.darkened(0.1))
	var tiers := 4
	for t in tiers:
		var w := 120.0 - t * 24.0
		var y := -30.0 - t * 66.0
		s._blob(ci, [Vector2(-w, y), Vector2(w, y), Vector2(0, y - 110.0)], TSSites.GREEN.darkened(0.04 * t) if lv >= 1 else Color(0.36, 0.5, 0.42))
		if lv == 0:
			TSSites.snow_cap(s, ci, Vector2(0, y - 110.0), 14.0)
	if lv == 0:
		return
	if lv >= 1:
		for t in 3:
			var y := -60.0 - t * 66.0
			var w := 96.0 - t * 22.0
			var g := PackedVector2Array()
			for j in 9:
				var u := float(j) / 8.0
				g.append(Vector2(-w + u * w * 2.0, y + sin(u * PI) * 14.0 - u * 20.0))
			ci.draw_polyline(g, TSSites.INK, 9.0, true)
			ci.draw_polyline(g, TSSites.GOLD, 5.0, true)
	if lv >= 2:
		var spots := [Vector2(-70, -50), Vector2(40, -64), Vector2(-20, -110), Vector2(56, -130), Vector2(-50, -160), Vector2(20, -190), Vector2(-10, -240)]
		for n in spots.size():
			ci.draw_circle(spots[n], 10.0, TSSites.INK, true, -1.0, true)
			ci.draw_circle(spots[n], 7.5, [TSSites.RED, TSSites.ACCENT, TSSites.GOLD][n % 3], true, -1.0, true)
	if lv >= 3:
		for n in 14:
			var a := float(n) * 2.3
			var y := -40.0 - fposmod(a * 37.0, 260.0)
			var half := 120.0 * (1.0 + y / 300.0) * 0.8
			var at := Vector2(sin(a * 1.7) * half, y)
			var on := fposmod(s._t * 1.5 + n * 0.37, 1.0) < 0.7
			ci.draw_circle(at, 4.0, (TSShipScene.LIGHTS[n % 4] as Color) if on else Color(0.5, 0.5, 0.55), true, -1.0, true)
	if lv >= 4:
		TSSites.star(ci, Vector2(0, -312), 26.0 + sin(s._t * 2.0) * 2.0, TSSites.GOLD, sin(s._t) * 0.1)
		TSSites.twinkle(s, ci, Vector2(0, -312), 40.0)
		for x in [-90.0, 70.0]:
			TSSites.present(s, ci, Vector2(x, 6), 1.0)


# Cocoa Stand: Crates, Stand, Striped Awning, Steaming Mugs, Bell & Sign.
static func _cocoa_stand(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 6.0)
	if lv == 0:
		s._box(ci, Rect2(Vector2(-60, -44), Vector2(50, 44)), TSSites.WOOD)
		s._box(ci, Rect2(Vector2(-4, -36), Vector2(44, 36)), TSSites.WOOD.darkened(0.1))
		TSSites.snow_cap(s, ci, Vector2(-35, -46), 26.0)
		return
	for x in [-80.0, 80.0]:
		s._post(ci, Vector2(x, -60), Vector2(x, -170), 7.0)
	s._box(ci, Rect2(Vector2(-90, -64), Vector2(180, 64)), Color(0.62, 0.4, 0.3))
	if lv >= 2:
		for j in 6:
			var x0 := -100.0 + j * 33.4
			s._blob(ci, [Vector2(x0, -190), Vector2(x0 + 33.4, -190), Vector2(x0 + 33.4, -160), Vector2(x0 + 16.7, -150), Vector2(x0, -160)], TSSites.RED if j % 2 == 0 else TSSites.SNOW)
		TSSites.snow_cap(s, ci, Vector2(0, -192), 100.0)
	if lv >= 3:
		for j in 3:
			var c := Vector2(-50 + j * 50, -64)
			s._blob(ci, [c + Vector2(-13, 0), c + Vector2(13, 0), c + Vector2(15, -28), c + Vector2(-15, -28)], [TSSites.RED, TSSites.SNOW, TSSites.GREEN][j])
			ci.draw_arc(c + Vector2(17, -14), 8.0, -PI * 0.5, PI * 0.5, 8, TSSites.INK, 4.0, true)
			TSSites.puffs(s, ci, c + Vector2(0, -32), Color.WHITE, 40.0, 2)
	if lv >= 4:
		TSSites.sign(s, ci, Vector2(0, -214), "COCOA", 110.0)
		var ring := sin(s._t * 6.0) * 0.3 if fposmod(s._t, 4.0) < 0.6 else 0.0
		var bell := Vector2(80, -150)
		s._blob(ci, [bell + Vector2(-10, 0).rotated(ring), bell + Vector2(10, 0).rotated(ring), bell + Vector2(14, 22).rotated(ring), bell + Vector2(-14, 22).rotated(ring)], TSSites.GOLD)


# Gingerbread House: Crumbs, Cookie Walls, Icing Roof, Gumdrops, Candy Cane Door.
static func _gingerbread_house(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0)
	var ginger := Color(0.78, 0.5, 0.3)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-40, -6), Vector2(0, -12), Vector2(40, -4)], ginger, 22.0, 12.0)
		return
	s._box(ci, Rect2(Vector2(-80, -100), Vector2(160, 100)), ginger)
	s._box(ci, Rect2(Vector2(-60, -76), Vector2(30, 28)), Color(1.0, 0.86, 0.5))
	s._box(ci, Rect2(Vector2(30, -76), Vector2(30, 28)), Color(1.0, 0.86, 0.5))
	if lv >= 2:
		TSSites.roof(s, ci, Vector2(-100, -96), Vector2(100, -96), 80.0, Color(0.66, 0.4, 0.26))
		# Icing dripping along the eaves.
		var drip := PackedVector2Array()
		for j in 17:
			var u := float(j) / 16.0
			var x := -96.0 + u * 192.0
			var y := -96.0 - (1.0 - absf(u - 0.5) * 2.0) * 76.0
			drip.append(Vector2(x, y + (8.0 if j % 2 == 1 else 0.0)))
		ci.draw_polyline(drip, TSSites.SNOW, 8.0, true)
		s._post(ci, Vector2(40, -150), Vector2(40, -190), 12.0, ginger.darkened(0.1))
		TSSites.puffs(s, ci, Vector2(40, -196), Color(0.94, 0.94, 0.98), 60.0, 2)
	if lv >= 3:
		var drops := [Vector2(-70, -108), Vector2(-40, -134), Vector2(0, -160), Vector2(40, -134), Vector2(70, -108), Vector2(-74, -10), Vector2(74, -10)]
		for n in drops.size():
			TSSites.dome(s, ci, drops[n], 9.0, [TSSites.RED, TSSites.GREEN, TSSites.BUTTER, TSSites.ACCENT, TSSites.PINK][n % 5])
	if lv >= 4:
		s._blob(ci, Array(s._half_circle(Vector2(0, 0), 22.0)) , Color(0.42, 0.26, 0.2))
		for x in [-28.0, 28.0]:
			TSSites.cane(ci, Vector2(x, 0), Vector2(x, -54), 7.0)
	else:
		s._box(ci, Rect2(Vector2(-14, -44), Vector2(28, 44)), Color(0.5, 0.3, 0.22))


# Skating Rink: Puddle, Ice Rink, Skates, Lanterns, Twirling Flag.
static func _ice_rink(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		s._ellipse(ci, Vector2.ZERO, 40.0, 10.0, TSSites.ICE, false)
		return
	s._ellipse(ci, Vector2.ZERO, 120.0, 32.0, TSSites.ICE)
	for j in 3:
		ci.draw_arc(Vector2(-30 + j * 30, 0), 30.0 + j * 10.0, PI * 1.1, PI * 1.7, 10, Color(1, 1, 1, 0.7), 3.0, true)
	for j in 14:
		var a := TAU * float(j) / 14.0
		s._ellipse(ci, Vector2(cos(a) * 124.0, sin(a) * 34.0), 14.0, 9.0, TSSites.SNOW)
	if lv >= 2:
		# A little critter-sized skater gliding round: a scarf and two skates.
		var a2 := s._t * 0.8
		var at := Vector2(cos(a2) * 70.0, sin(a2) * 14.0 - 4.0)
		for side in [-6.0, 6.0]:
			s._blob(ci, [at + Vector2(side - 6, 0), at + Vector2(side + 8, 0), at + Vector2(side + 6, -10), at + Vector2(side - 6, -10)], TSSites.SNOW)
			ci.draw_line(at + Vector2(side - 8, 2), at + Vector2(side + 10, 2), TSSites.INK, 2.0, true)
	if lv >= 3:
		for x in [-100.0, 100.0]:
			s._post(ci, Vector2(x, -20), Vector2(x, -90), 4.0, TSSites.INK)
			TSSites.lantern(s, ci, Vector2(x, -100))
	if lv >= 4:
		TSSites.flag(s, ci, Vector2(0, -110), TSSites.RED, 80.0)
		TSSites.bulbs(s, ci, Vector2(-100, -100), Vector2(100, -100), 18.0, 9)


# Sleigh Pad: Rubble, Runway, Sleigh, Sacks of Gifts, Reindeer Bells.
static func _sleigh_pad(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-40, 0), Vector2(10, -6), Vector2(50, 2), Vector2(-10, -26)], TSSites.STONE, 26.0, 16.0)
		return
	s._ellipse(ci, Vector2(0, 0), 120.0, 26.0, Color(0.86, 0.9, 1.0))
	for j in 6:
		var x := -100.0 + j * 40.0
		ci.draw_circle(Vector2(x, 0), 5.0, TSSites.BUTTER if fposmod(s._t * 2.0 - j * 0.3, 2.0) < 1.0 else Color(0.6, 0.6, 0.66), true, -1.0, true)
	if lv >= 2:
		ci.draw_line(Vector2(-80, -10), Vector2(70, -10), TSSites.INK, 8.0, true)
		ci.draw_arc(Vector2(70, -32), 22.0, -PI * 0.5, PI * 0.5, 10, TSSites.INK, 8.0, true)
		s._blob(ci, [Vector2(-90, -24), Vector2(60, -24), Vector2(70, -70), Vector2(-60, -70), Vector2(-90, -110)], TSSites.RED)
		ci.draw_polyline(PackedVector2Array([Vector2(-84, -40), Vector2(56, -40)]), TSSites.GOLD, 5.0, true)
	if lv >= 3:
		s._ellipse(ci, Vector2(-30, -86), 34.0, 30.0, Color(0.7, 0.5, 0.36))
		ci.draw_line(Vector2(-40, -112), Vector2(-20, -112), TSSites.INK, 4.0, true)
		TSSites.present(s, ci, Vector2(10, -70), 0.9)
		TSSites.present(s, ci, Vector2(36, -70), 0.7)
	if lv >= 4:
		ci.draw_line(Vector2(80, -30), Vector2(130, -40), TSSites.INK, 3.0, true)
		for j in 5:
			var at := Vector2(80 + j * 12, -34 - j * 2)
			var jingle := sin(s._t * 8.0 + j) * 2.0
			ci.draw_circle(at + Vector2(0, 6 + jingle), 5.0, TSSites.GOLD, true, -1.0, true)
		TSSites.twinkle(s, ci, Vector2(-20, -100), 70.0, TSSites.BUTTER, 4)


# Cookie Oven: Clay Lump, Brick Oven, Chimney, Cookie Trays, Gingerbread Shelf.
static func _cookie_oven(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	var brick := Color(0.84, 0.44, 0.38)
	if lv == 0:
		s._ellipse(ci, Vector2(0, -14), 50.0, 26.0, brick.darkened(0.15))
		return
	if lv >= 2:
		s._box(ci, Rect2(Vector2(20, -150), Vector2(24, 70)), brick.darkened(0.1))
		TSSites.snow_cap(s, ci, Vector2(32, -150), 16.0)
		TSSites.puffs(s, ci, Vector2(32, -160))
	TSSites.dome(s, ci, Vector2.ZERO, 80.0, brick)
	for row in 3:
		var y := -18.0 - row * 22.0
		var half := sqrt(maxf(6400.0 - y * y, 0.0))
		ci.draw_line(Vector2(-half + 6, y), Vector2(half - 6, y), Color(TSSites.INK, 0.25), 2.0, true)
	TSSites.snow_cap(s, ci, Vector2(0, -78), 50.0)
	TSSites.dome(s, ci, Vector2.ZERO, 34.0, Color(0.32, 0.22, 0.24))
	ci.draw_circle(Vector2(0, -12), 12.0, Color(1.0, 0.6, 0.3, 0.6 + 0.3 * sin(s._t * 9.0)), true, -1.0, true)
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-136, -30), Vector2(64, 30)), TSSites.WOOD)
		s._box(ci, Rect2(Vector2(-134, -40), Vector2(60, 10)), TSSites.CHROME)
		for j in 3:
			ci.draw_circle(Vector2(-124 + j * 20, -46), 8.0, Color(0.9, 0.66, 0.4), true, -1.0, true)
	if lv >= 4:
		s._box(ci, Rect2(Vector2(90, -64), Vector2(70, 64)), TSSites.WOOD.lightened(0.1))
		for j in 2:
			_gingerbread_man(s, ci, Vector2(108 + j * 34, -70), 0.6)


static func _gingerbread_man(s: TSShipScene, ci: CanvasItem, at: Vector2, size: float) -> void:
	var g := Color(0.78, 0.5, 0.3)
	s._blob(ci, [at + Vector2(-14, 0) * size, at + Vector2(-6, -20) * size, at + Vector2(-20, -26) * size, at + Vector2(-16, -34) * size, at + Vector2(-6, -30) * size,
		at + Vector2(-8, -42) * size, at + Vector2(8, -42) * size, at + Vector2(6, -30) * size, at + Vector2(16, -34) * size, at + Vector2(20, -26) * size,
		at + Vector2(6, -20) * size, at + Vector2(14, 0) * size, at + Vector2(0, -8) * size], g)
	ci.draw_circle(at + Vector2(0, -46) * size, 10.0 * size, TSSites.INK, true, -1.0, true)
	ci.draw_circle(at + Vector2(0, -46) * size, 8.0 * size, g, true, -1.0, true)


# Ice Sculpture: Ice Block, Rough Carving, Critter Sculpture, Pedestal, Sparkling Ice.
static func _ice_sculpture(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var ice := Color(TSSites.ICE, 0.95)
	var base := Vector2.ZERO
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-56, -40), Vector2(112, 40)), Color(0.92, 0.94, 1.0))
		TSSites.snow_cap(s, ci, Vector2(0, -42), 56.0)
		base = Vector2(0, -40)
	if lv <= 1:
		var r := 1.0 if lv == 0 else 0.92
		s._blob(ci, [base + Vector2(-50, 0) * r, base + Vector2(50, 0) * r, base + Vector2(46, -110) * r, base + Vector2(-46, -110) * r], ice)
		if lv == 1:
			ci.draw_line(base + Vector2(-20, -80), base + Vector2(10, -96), Color(1, 1, 1, 0.8), 4.0, true)
			ci.draw_arc(base + Vector2(0, -60), 26.0, PI * 1.1, PI * 1.9, 10, Color(TSSites.INK, 0.3), 3.0, true)
		return
	# A critter carved in ice: round body, two ears, a shine.
	s._ellipse(ci, base + Vector2(0, -50), 48.0, 46.0, ice)
	for side in [-1.0, 1.0]:
		s._blob(ci, [base + Vector2(side * 30, -82), base + Vector2(side * 40, -122), base + Vector2(side * 10, -92)], ice)
	ci.draw_circle(base + Vector2(-14, -56), 4.0, Color(TSSites.INK, 0.6), true, -1.0, true)
	ci.draw_circle(base + Vector2(14, -56), 4.0, Color(TSSites.INK, 0.6), true, -1.0, true)
	ci.draw_arc(base + Vector2(-16, -70), 26.0, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.9), 4.0, true)
	if lv >= 4:
		TSSites.twinkle(s, ci, base + Vector2(0, -60), 56.0, Color.WHITE, 5)
		for j in 3:
			ci.draw_circle(base + Vector2(-40 + j * 40, -6), 4.0, TSShipScene.LIGHTS[j], true, -1.0, true)


# -- the card's icons --------------------------------------------------------------

static func icon(ic: TSIcon, part: int, broken: bool) -> void:
	var red := Color(0.7, 0.6, 0.62) if broken else TSSites.RED
	var green := Color(0.56, 0.64, 0.58) if broken else TSSites.GREEN
	var gold := Color(0.8, 0.76, 0.66) if broken else TSSites.GOLD
	var snow := TSSites.SNOW
	var wood := Color(0.62, 0.5, 0.44) if broken else Color(0.78, 0.56, 0.38)
	if broken:
		ic._ellipse(Vector2(0.5, 0.72), 0.34, 0.12, snow)
	match part:
		TSProfile.CAMP_FIRE:
			ic._rrect(Rect2(0.2, 0.56, 0.6, 0.16), 0.06, wood)
			if not broken:
				ic._poly([Vector2(0.36, 0.58), Vector2(0.5, 0.2), Vector2(0.64, 0.58)], Color(1.0, 0.55, 0.3))
				ic._circle(Vector2(0.3, 0.54), 0.05, red)
		TSProfile.CAMP_TENT:
			ic._poly(_dome(Vector2(0.5, 0.8), 0.38 if not broken else 0.22), snow)
			if not broken:
				ic._poly(_dome(Vector2(0.5, 0.8), 0.13), Color(0.32, 0.36, 0.56))
		TSProfile.CAMP_BENCH:
			ic._rrect(Rect2(0.14, 0.5, 0.72, 0.1), 0.02, wood)
			if not broken:
				ic._rrect(Rect2(0.26, 0.3, 0.2, 0.2), 0.02, red)
				ic._rrect(Rect2(0.54, 0.34, 0.18, 0.16), 0.02, green)
		TSProfile.CAMP_GARDEN, TSProfile.CAMP_TREEHOUSE:
			if not broken:
				ic._poly([Vector2(0.2, 0.76), Vector2(0.8, 0.76), Vector2(0.5, 0.14)], green)
				ic._circle(Vector2(0.42, 0.56), 0.04, red)
				ic._circle(Vector2(0.6, 0.44), 0.04, gold)
				if part == TSProfile.CAMP_TREEHOUSE:
					ic._circle(Vector2(0.5, 0.14), 0.07, gold)
			else:
				ic._poly([Vector2(0.36, 0.72), Vector2(0.64, 0.72), Vector2(0.5, 0.4)], green)
		TSProfile.CAMP_WELL:
			ic._rrect(Rect2(0.24, 0.5, 0.52, 0.3), 0.05, Color(0.86, 0.82, 0.9))
			if not broken:
				ic._ellipse(Vector2(0.5, 0.5), 0.26, 0.07, Color(0.5, 0.32, 0.24))
				ic._rrect(Rect2(0.44, 0.24, 0.12, 0.08), 0.02, snow)
		TSProfile.CAMP_LOOKOUT:
			ic._line([Vector2(0.3, 0.86), Vector2(0.34, 0.4)], wood, 1.4)
			ic._line([Vector2(0.7, 0.86), Vector2(0.66, 0.4)], wood, 1.4)
			if not broken:
				ic._poly([Vector2(0.22, 0.34), Vector2(0.78, 0.34), Vector2(0.5, 0.1)], red)
				ic._poly([Vector2(0.4, 0.58), Vector2(0.6, 0.58), Vector2(0.56, 0.4), Vector2(0.44, 0.4)], gold)
		TSProfile.CAMP_HAMMOCK:
			ic._line([Vector2(0.14, 0.7), Vector2(0.8, 0.7)], TSSites.INK, 1.2)
			ic._poly([Vector2(0.14, 0.62), Vector2(0.76, 0.62), Vector2(0.8, 0.5), Vector2(0.18, 0.5)], red)
		TSProfile.CAMP_PICNIC:
			ic._rrect(Rect2(0.14, 0.44, 0.72, 0.1), 0.02, red if not broken else wood)
			for x in [0.22, 0.72]:
				ic._rrect(Rect2(x, 0.54, 0.06, 0.28), 0.02, wood)
		TSProfile.CAMP_CLOTHESLINE:
			ic._line([Vector2(0.1, 0.26), Vector2(0.9, 0.26)], TSSites.INK, 0.8)
			if not broken:
				for x in [0.24, 0.5, 0.74]:
					ic._poly([Vector2(x - 0.06, 0.26), Vector2(x + 0.06, 0.26), Vector2(x + 0.06, 0.52), Vector2(x + 0.14, 0.58), Vector2(x - 0.06, 0.6)], red if x != 0.5 else green)
		TSProfile.CAMP_MAILBOX:
			ic._line([Vector2(0.5, 0.86), Vector2(0.5, 0.5)], wood, 1.4)
			ic._rrect(Rect2(0.28, 0.24, 0.44, 0.28), 0.1, red)
		TSProfile.CAMP_WINDMILL:
			ic._poly([Vector2(0.36, 0.86), Vector2(0.64, 0.86), Vector2(0.58, 0.4), Vector2(0.42, 0.4)], snow)
			if not broken:
				for a in [0.6, 2.2, 3.7, 5.3]:
					ic._line([Vector2(0.5, 0.4), Vector2(0.5, 0.4) + Vector2(0.3, 0).rotated(a)], red, 1.6)
		TSProfile.CAMP_DOCK:
			ic._rrect(Rect2(0.32, 0.42, 0.4, 0.36), 0.02, red)
			ic._poly([Vector2(0.26, 0.42), Vector2(0.78, 0.42), Vector2(0.52, 0.2)], wood)
		TSProfile.CAMP_PLAYGROUND:
			ic._poly([Vector2(0.1, 0.82), Vector2(0.9, 0.82), Vector2(0.44, 0.3)], snow)
			if not broken:
				ic._rrect(Rect2(0.5, 0.5, 0.2, 0.08), 0.02, red)
		TSProfile.CAMP_STALL:
			ic._rrect(Rect2(0.16, 0.54, 0.68, 0.3), 0.03, wood)
			if not broken:
				for k in 4:
					ic._poly([Vector2(0.12 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.34), Vector2(0.12 + k * 0.19, 0.34)], red if k % 2 == 0 else snow)
				ic._rrect(Rect2(0.42, 0.42, 0.14, 0.12), 0.02, snow)
		TSProfile.CAMP_GREENHOUSE:
			ic._rrect(Rect2(0.2, 0.5, 0.6, 0.34), 0.02, Color(0.78, 0.5, 0.3))
			if not broken:
				ic._poly([Vector2(0.14, 0.52), Vector2(0.86, 0.52), Vector2(0.5, 0.2)], Color(0.66, 0.4, 0.26))
				ic._line([Vector2(0.16, 0.5), Vector2(0.5, 0.22), Vector2(0.84, 0.5)], snow, 1.0)
		TSProfile.CAMP_SPRING:
			ic._ellipse(Vector2(0.5, 0.64), 0.38, 0.14, TSSites.ICE)
			if not broken:
				ic._line([Vector2(0.3, 0.64), Vector2(0.6, 0.58)], Color.WHITE, 0.8)
		TSProfile.CAMP_OBSERVATORY:
			if not broken:
				ic._poly([Vector2(0.14, 0.6), Vector2(0.72, 0.6), Vector2(0.8, 0.36), Vector2(0.24, 0.36), Vector2(0.12, 0.26)], red)
				ic._line([Vector2(0.14, 0.7), Vector2(0.84, 0.7)], TSSites.INK, 1.0)
				ic._circle(Vector2(0.44, 0.3), 0.1, Color(0.7, 0.5, 0.36))
		TSProfile.CAMP_OVEN:
			ic._poly(_dome(Vector2(0.5, 0.82), 0.38 if not broken else 0.24), Color(0.84, 0.44, 0.38))
			if not broken:
				ic._rrect(Rect2(0.38, 0.62, 0.24, 0.2), 0.1, Color(0.32, 0.22, 0.24))
				ic._ellipse(Vector2(0.5, 0.46), 0.26, 0.06, snow)
		TSProfile.CAMP_STATUE:
			if not broken:
				ic._rrect(Rect2(0.24, 0.72, 0.52, 0.14), 0.02, Color(0.92, 0.94, 1.0))
				ic._circle(Vector2(0.5, 0.48), 0.22, TSSites.ICE)
				ic._poly([Vector2(0.32, 0.38), Vector2(0.28, 0.16), Vector2(0.42, 0.3)], TSSites.ICE)
				ic._poly([Vector2(0.68, 0.38), Vector2(0.72, 0.16), Vector2(0.58, 0.3)], TSSites.ICE)
			else:
				ic._rrect(Rect2(0.3, 0.36, 0.4, 0.4), 0.04, TSSites.ICE)


static func _dome(c: Vector2, r: float) -> Array:
	var pts: Array = []
	for j in 17:
		var a := PI + PI * float(j) / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
