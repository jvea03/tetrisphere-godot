class_name TSSitesValentine
extends RefCounted

## The Valentine's planet's work sites (TSSites): a pink village of roses,
## hearts, a carousel, a swan boat and a chocolate stand. Drawn round each
## spot's foot at (0, 0).

const CREAM := Color(1.0, 0.95, 0.9)
const CHOC := Color(0.5, 0.3, 0.24)
const SOFT := [Color(1.0, 0.62, 0.74), Color(0.95, 0.36, 0.5), Color(1.0, 0.86, 0.9), Color(0.86, 0.66, 1.0), Color(1.0, 0.84, 0.5)]


static func draw(s: TSShipScene, ci: CanvasItem, part: int, lv: int) -> void:
	match part:
		TSProfile.CAMP_FIRE: _heart_fire(s, ci, lv)
		TSProfile.CAMP_TENT: _rose_cottage(s, ci, lv)
		TSProfile.CAMP_BENCH: _card_desk(s, ci, lv)
		TSProfile.CAMP_GARDEN: _rose_garden(s, ci, lv)
		TSProfile.CAMP_WELL: _kissing_well(s, ci, lv)
		TSProfile.CAMP_LOOKOUT: _cupid_tower(s, ci, lv)
		TSProfile.CAMP_HAMMOCK: _porch_swing(s, ci, lv)
		TSProfile.CAMP_PICNIC: _sweet_picnic(s, ci, lv)
		TSProfile.CAMP_CLOTHESLINE: _heart_garland(s, ci, lv)
		TSProfile.CAMP_MAILBOX: _love_letters(s, ci, lv)
		TSProfile.CAMP_WINDMILL: _heart_mill(s, ci, lv)
		TSProfile.CAMP_DOCK: _swan_dock(s, ci, lv)
		TSProfile.CAMP_PLAYGROUND: _carousel(s, ci, lv)
		TSProfile.CAMP_TREEHOUSE: _blossom_treehouse(s, ci, lv)
		TSProfile.CAMP_STALL: _chocolate_stand(s, ci, lv)
		TSProfile.CAMP_GREENHOUSE: _flower_shop(s, ci, lv)
		TSProfile.CAMP_SPRING: _love_fountain(s, ci, lv)
		TSProfile.CAMP_OBSERVATORY: _gazebo(s, ci, lv)
		TSProfile.CAMP_OVEN: _chocolate_kitchen(s, ci, lv)
		TSProfile.CAMP_STATUE: _cupid_statue(s, ci, lv)


static func _rose(s: TSShipScene, ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r + 2.0, TSSites.INK, true, -1.0, true)
	ci.draw_circle(c, r, col, true, -1.0, true)
	ci.draw_arc(c, r * 0.55, 0.3, PI * 1.6, 10, col.darkened(0.25), 2.0, true)


static func _floating_hearts(s: TSShipScene, ci: CanvasItem, c: Vector2, rise: float, n := 3) -> void:
	for j in n:
		var age := fposmod(s._t * 0.35 + float(j) / float(n), 1.0)
		s._heart(ci, c + Vector2(sin(age * 6.0 + j * 2.0) * 16.0, -age * rise), 9.0 * (1.0 - age * 0.4), Color(SOFT[j % 2], 1.0 - age))


# Heart Fire: Cold Ashes, Little Fire, Heart Stones, Fondue Pot, Heart Bonfire.
static func _heart_fire(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 52.0)
	if lv >= 2:
		# Stones laid in a heart round the fire.
		for j in 14:
			var t := TAU * float(j) / 14.0
			var at := Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * 3.0
			s._ellipse(ci, Vector2(at.x, at.y * 0.3 + 4.0), 9.0, 6.0, TSSites.PINK.lightened(0.3))
	for turn in [0.35, -0.35]:
		ci.draw_line(Vector2(-26, 6).rotated(turn), Vector2(26, 6).rotated(turn), TSSites.WOOD.darkened(0.45) if lv == 0 else TSSites.WOOD, 10.0, true)
	if lv == 0:
		TSSites.puffs(s, ci, Vector2(0, -6), Color(0.66, 0.64, 0.7), 60.0, 2)
		return
	var flick := 1.0 + 0.1 * sin(s._t * 11.0)
	var big := 1.4 if lv >= 4 else 1.0
	s._blob(ci, [Vector2(-20 * big, 0), Vector2(0, -50.0 * big * flick), Vector2(20 * big, 0)], Color(1.0, 0.46, 0.5))
	s._blob(ci, [Vector2(-10 * big, 0), Vector2(0, -26.0 * big * flick), Vector2(10 * big, 0)], TSSites.BUTTER, false)
	if lv >= 3:
		for leg in [-1.0, 1.0]:
			ci.draw_line(Vector2(leg * 48.0, 8.0), Vector2(0, -140.0), TSSites.INK, 4.0, true)
		ci.draw_line(Vector2(0, -140), Vector2(0, -128), TSSites.INK, 2.0, true)
		s._blob(ci, [Vector2(-20, -128), Vector2(20, -128), Vector2(16, -104), Vector2(-16, -104)], CHOC)
		s._ellipse(ci, Vector2(0, -128), 18.0, 4.0, CHOC.darkened(0.2), false)
	if lv >= 4:
		_floating_hearts(s, ci, Vector2(0, -70), 90.0, 4)


# Rose Cottage: Torn Tarp, Cottage, Heart Door, Rose Vines, Heart Roof.
static func _rose_cottage(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	s._ellipse(ci, Vector2(0, 6), 110.0, 16.0, TSSites.SHADOW, false)
	if lv == 0:
		ci.draw_line(Vector2(-50, 0), Vector2(-40, -44), TSSites.WOOD, 5.0, true)
		s._blob(ci, [Vector2(-90, 4), Vector2(-40, -40), Vector2(30, -14), Vector2(90, 6)], Color(0.9, 0.78, 0.8))
		return
	s._box(ci, Rect2(Vector2(-80, -90), Vector2(160, 90)), CREAM)
	TSSites.roof(s, ci, Vector2(-96, -86), Vector2(96, -86), 66.0, TSSites.ROSE if lv >= 4 else TSSites.PINK)
	s._box(ci, Rect2(Vector2(-60, -66), Vector2(28, 26)), Color(0.72, 0.86, 1.0))
	s._box(ci, Rect2(Vector2(34, -66), Vector2(28, 26)), Color(0.72, 0.86, 1.0))
	if lv >= 2:
		s._blob(ci, [Vector2(-16, 0), Vector2(16, 0), Vector2(16, -40), Vector2(-16, -40)], TSSites.ROSE)
		s._heart(ci, Vector2(0, -24), 9.0, TSSites.PINK)
	else:
		s._box(ci, Rect2(Vector2(-16, -40), Vector2(32, 40)), TSSites.WOOD)
	if lv >= 3:
		for side in [-1.0, 1.0]:
			var vine := PackedVector2Array()
			for j in 8:
				vine.append(Vector2(side * (80.0 - sin(j * 1.3) * 6.0), -float(j) * 12.0))
			ci.draw_polyline(vine, Color(0.36, 0.62, 0.42), 4.0, true)
			for j in 3:
				_rose(s, ci, Vector2(side * 80.0, -20.0 - j * 28.0), 6.0, TSSites.ROSE)
	if lv >= 4:
		s._heart(ci, Vector2(0, -122), 22.0 + sin(s._t * 3.0) * 1.5, TSSites.RED)
		_floating_hearts(s, ci, Vector2(40, -130), 60.0, 2)


# Card Desk: Loose Planks, Desk, Paper Rack, Lace Lamp, Heart Awning.
static func _card_desk(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0, 6.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4, Color(0.8, 0.62, 0.52))
		return
	if lv >= 4:
		for x in [-80.0, 80.0]:
			s._post(ci, Vector2(x, 0), Vector2(x, -140), 6.0, CREAM)
		for j in 6:
			var x0 := -90.0 + j * 30.0
			s._blob(ci, [Vector2(x0, -150), Vector2(x0 + 30, -150), Vector2(x0 + 30, -126), Vector2(x0 + 15, -116), Vector2(x0, -126)], TSSites.PINK if j % 2 == 0 else CREAM)
	if lv >= 2:
		s._box(ci, Rect2(Vector2(-60, -112), Vector2(120, 50)), TSSites.WOOD.lightened(0.1))
		for j in 4:
			s._box(ci, Rect2(Vector2(-52 + j * 28, -104), Vector2(20, 34)), [TSSites.PINK, CREAM, TSSites.ROSE, Color(0.86, 0.66, 1.0)][j])
	for x in [-56.0, 56.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -48), 5.0)
	s._box(ci, Rect2(Vector2(-74, -62), Vector2(148, 16)), Color(0.9, 0.72, 0.6))
	if lv >= 3:
		s._post(ci, Vector2(50, -62), Vector2(50, -110), 3.0, TSSites.INK)
		s._blob(ci, [Vector2(30, -110), Vector2(70, -110), Vector2(60, -130), Vector2(40, -130)], CREAM)
		ci.draw_circle(Vector2(50, -104), 14.0, Color(TSSites.BUTTER, 0.3), true, -1.0, true)
		s._box(ci, Rect2(Vector2(-40, -78), Vector2(40, 16)), CREAM)
		s._heart(ci, Vector2(-20, -70), 6.0, TSSites.ROSE)


# Rose Garden: Bare Dirt, Sprouts, Rosebuds, Roses, Heart Topiary.
static func _rose_garden(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	s._ellipse(ci, Vector2(0, -6), 110.0, 28.0, Color(0.62, 0.46, 0.4))
	if lv == 0:
		return
	for n in 7:
		var at := Vector2(-84 + n * 28, -6 + (n % 2) * 10)
		var h := 20.0 if lv == 1 else 40.0
		ci.draw_line(at, at + Vector2(0, -h), Color(0.36, 0.62, 0.42), 4.0, true)
		s._ellipse(ci, at + Vector2(-6, -h * 0.5), 6.0, 3.0, Color(0.48, 0.78, 0.5), false)
		if lv >= 2:
			_rose(s, ci, at + Vector2(0, -h), 5.0 if lv == 2 else 9.0, [TSSites.ROSE, TSSites.PINK, TSSites.RED][n % 3])
	if lv >= 4:
		for x in [-130.0, 130.0]:
			s._post(ci, Vector2(x, 0), Vector2(x, -40), 6.0)
			s._heart(ci, Vector2(x, -70), 30.0, Color(0.36, 0.66, 0.42))
			_rose(s, ci, Vector2(x - 8, -74), 4.0, TSSites.ROSE)


# Kissing Well: Pile of Stones, Stone Well, Heart Roof, Bucket of Petals, Rose Boxes.
static func _kissing_well(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-34, -6), Vector2(10, -10), Vector2(40, -2), Vector2(-6, -26)], Color(0.86, 0.78, 0.82))
		return
	s._box(ci, Rect2(Vector2(-56, -60), Vector2(112, 60)), Color(0.9, 0.82, 0.86))
	s._ellipse(ci, Vector2(0, -60), 56.0, 13.0, Color(0.42, 0.5, 0.74))
	if lv >= 2:
		for x in [-48.0, 48.0]:
			s._post(ci, Vector2(x, -60), Vector2(x, -140), 7.0, CREAM)
		TSSites.roof(s, ci, Vector2(-70, -138), Vector2(70, -138), 48.0, TSSites.PINK)
		s._heart(ci, Vector2(0, -150), 11.0, TSSites.ROSE)
	if lv >= 3:
		var bob := sin(s._t * 1.2) * 4.0
		ci.draw_line(Vector2(0, -138), Vector2(0, -100 + bob), TSSites.INK, 2.0, true)
		s._blob(ci, [Vector2(-14, -100 + bob), Vector2(14, -100 + bob), Vector2(10, -78 + bob), Vector2(-10, -78 + bob)], TSSites.WOOD)
		for j in 3:
			ci.draw_circle(Vector2(-6 + j * 6, -102 + bob), 4.0, TSSites.PINK, true, -1.0, true)
	if lv >= 4:
		for side in [-1.0, 1.0]:
			s._box(ci, Rect2(Vector2(side * 66 - 18, -30), Vector2(36, 22)), TSSites.WOOD)
			for j in 3:
				_rose(s, ci, Vector2(side * 66 - 10 + j * 10, -34), 5.0, TSSites.ROSE)


# Cupid's Tower: Pile of Logs, Platform, Bow Rack, Roof, Heart Flag.
static func _cupid_tower(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(-10, 0), 4)
		return
	for x in [-44.0, 44.0]:
		s._post(ci, Vector2(x, 0), Vector2(x * 0.8, -150), 9.0, CREAM.darkened(0.1))
	s._box(ci, Rect2(Vector2(-56, -160), Vector2(112, 14)), TSSites.WOOD)
	if lv >= 2:
		for side in [-1.0, 1.0]:
			s._post(ci, Vector2(side * 44, -40), Vector2(side * -40, -110), 4.0, CREAM.darkened(0.1))
		# A bow hung on the rail, and an arrow.
		ci.draw_arc(Vector2(-20, -190), 26.0, -PI * 0.5, PI * 0.5, 14, TSSites.INK, 7.0, true)
		ci.draw_arc(Vector2(-20, -190), 26.0, -PI * 0.5, PI * 0.5, 14, TSSites.GOLD, 4.0, true)
		ci.draw_line(Vector2(-20, -216), Vector2(-20, -164), TSSites.INK, 1.5, true)
	for x in [-44.0, 44.0]:
		s._post(ci, Vector2(x, -160), Vector2(x, -220), 5.0, CREAM.darkened(0.1))
	if lv >= 3:
		TSSites.roof(s, ci, Vector2(-62, -218), Vector2(62, -218), 50.0, TSSites.PINK)
	if lv >= 4:
		s._post(ci, Vector2(0, -268), Vector2(0, -320), 3.0, TSSites.INK)
		var wave := sin(s._t * 4.0) * 4.0
		s._blob(ci, [Vector2(0, -320), Vector2(42, -310 + wave), Vector2(0, -298)], CREAM)
		s._heart(ci, Vector2(16, -310 + wave * 0.5), 7.0, TSSites.ROSE)


# Porch Swing: Tangled Rope, Swing Seat, Heart Pillows, Canopy, Fairy Lights.
static func _porch_swing(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 4.0)
	if lv == 0:
		var rope := PackedVector2Array()
		for j in 10:
			rope.append(Vector2(-60 + j * 12, -4 + sin(j * 1.6) * 6))
		ci.draw_polyline(rope, Color(0.9, 0.84, 0.7), 4.0, true)
		return
	for x in [-100.0, 100.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -150), 8.0, CREAM.darkened(0.08))
	s._post(ci, Vector2(-104, -150), Vector2(104, -150), 8.0, CREAM.darkened(0.08))
	var a := sin(s._t * 1.2) * 0.08
	var seat := Vector2(0, -150) + Vector2(0, 110).rotated(a)
	for side in [-60.0, 60.0]:
		ci.draw_line(Vector2(side, -150), seat + Vector2(side, 0), TSSites.INK, 2.5, true)
	s._box(ci, Rect2(seat + Vector2(-66, -8), Vector2(132, 14)), TSSites.WOOD.lightened(0.1))
	s._box(ci, Rect2(seat + Vector2(-66, -44), Vector2(132, 12)), TSSites.WOOD.lightened(0.1))
	if lv >= 2:
		s._heart(ci, seat + Vector2(-34, -22), 16.0, TSSites.PINK)
		s._heart(ci, seat + Vector2(30, -22), 16.0, TSSites.ROSE)
	if lv >= 3:
		for j in 6:
			var x0 := -110.0 + j * 36.7
			s._blob(ci, [Vector2(x0, -176), Vector2(x0 + 36.7, -176), Vector2(x0 + 36.7, -152), Vector2(x0 + 18.3, -142), Vector2(x0, -152)], TSSites.PINK if j % 2 == 0 else CREAM)
	if lv >= 4:
		TSSites.bulbs(s, ci, Vector2(-100, -140), Vector2(100, -140), 14.0, 9)


# Sweetheart Picnic: Fallen Log, Blanket, Basket, Heart Cloth, Chocolate Spread.
static func _sweet_picnic(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	if lv == 0:
		s._blob(ci, [Vector2(-70, 0), Vector2(60, 0), Vector2(60, -26), Vector2(-70, -26)], TSSites.WOOD.darkened(0.1))
		return
	s._blob(ci, [Vector2(-110, 0), Vector2(100, 0), Vector2(80, -36), Vector2(-90, -36)], TSSites.PINK if lv >= 3 else CREAM)
	for j in 4:
		ci.draw_line(Vector2(-100 + j * 52, 0), Vector2(-84 + j * 42, -36), Color(TSSites.RED, 0.5), 4.0, true)
	if lv >= 3:
		s._heart(ci, Vector2(0, -18), 14.0, TSSites.ROSE)
	if lv >= 2:
		s._blob(ci, [Vector2(-80, -20), Vector2(-30, -20), Vector2(-34, -54), Vector2(-76, -54)], TSSites.WOOD.lightened(0.15))
		ci.draw_arc(Vector2(-55, -54), 20.0, PI, TAU, 10, TSSites.INK, 4.0, true)
	if lv >= 4:
		s._box(ci, Rect2(Vector2(30, -40), Vector2(48, 20)), CHOC)
		for j in 3:
			s._heart(ci, Vector2(38 + j * 16, -34), 6.0, CHOC.lightened(0.2))
		s._post(ci, Vector2(90, -20), Vector2(90, -60), 5.0, Color(0.86, 0.92, 1.0))
		_rose(s, ci, Vector2(90, -64), 7.0, TSSites.RED)


# Heart Garland: Loose Line, Line, Paper Hearts, Ribbons, Bunting.
static func _heart_garland(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0, 4.0)
	if lv == 0:
		var rope := PackedVector2Array()
		for j in 10:
			rope.append(Vector2(-70 + j * 14, -4 + sin(j * 1.6) * 6))
		ci.draw_polyline(rope, Color(0.9, 0.84, 0.7), 4.0, true)
		return
	for x in [-120.0, 120.0]:
		s._post(ci, Vector2(x, 0), Vector2(x, -130), 8.0, CREAM.darkened(0.08))
	var line := PackedVector2Array()
	for j in 13:
		var u := float(j) / 12.0
		line.append(Vector2(-120.0 + u * 240.0, -126.0 + sin(u * PI) * 18.0))
	ci.draw_polyline(line, TSSites.INK, 2.5, true)
	if lv >= 2:
		for j in range(1, 12, 2):
			var sway := sin(s._t * 2.0 + j) * 2.0
			s._heart(ci, line[j] + Vector2(sway, 16), 12.0, SOFT[j % SOFT.size()])
	if lv >= 3:
		for x in [-120.0, 120.0]:
			for side in [-1.0, 1.0]:
				var flap := sin(s._t * 3.0 + side) * 4.0
				ci.draw_line(Vector2(x, -128), Vector2(x + side * 12.0 + flap, -96), TSSites.ROSE, 5.0, true)
	if lv >= 4:
		var g := PackedVector2Array()
		for j in 13:
			var u := float(j) / 12.0
			g.append(Vector2(-120.0 + u * 240.0, -150.0 + sin(u * PI) * 10.0))
		ci.draw_polyline(g, TSSites.INK, 2.0, true)
		for j in 12:
			s._blob(ci, [g[j], g[j + 1], (g[j] + g[j + 1]) * 0.5 + Vector2(0, 18)], [TSSites.PINK, CREAM][j % 2], false)


# Love Letter Box: Dented Can, Mailbox, Pink Paint, Heart Flag, Letter Pile.
static func _love_letters(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 40.0)
	if lv == 0:
		s._blob(ci, [Vector2(-20, 0), Vector2(24, -4), Vector2(20, -30), Vector2(-24, -26)], Color(0.7, 0.7, 0.76))
		return
	s._post(ci, Vector2(0, 0), Vector2(0, -70), 8.0, CREAM.darkened(0.1))
	s._blob(ci, [Vector2(-30, -70), Vector2(30, -70), Vector2(30, -110), Vector2(0, -122), Vector2(-30, -110)], TSSites.PINK if lv >= 2 else Color(0.8, 0.78, 0.84))
	ci.draw_rect(Rect2(Vector2(-16, -96), Vector2(32, 5)), TSSites.INK)
	if lv >= 2:
		s._heart(ci, Vector2(0, -80), 8.0, TSSites.ROSE)
	if lv >= 3:
		var up := sin(s._t * 1.5) * 0.1
		s._post(ci, Vector2(32, -80), Vector2(32, -80) + Vector2(0, -40).rotated(up), 4.0, TSSites.INK)
		s._heart(ci, Vector2(44, -116), 10.0, TSSites.RED)
	if lv >= 4:
		for j in 4:
			var at := Vector2(-50 + j * 20, -2 - (j % 2) * 6)
			s._box(ci, Rect2(at, Vector2(26, 18)), CREAM)
			s._heart(ci, at + Vector2(13, 10), 5.0, TSSites.ROSE)
		_floating_hearts(s, ci, Vector2(0, -126), 60.0, 2)


# Heart Windmill: Broken Blades, Spinning, Heart Sails, Little Door, Flower Boxes.
static func _heart_mill(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var h := 90.0 if lv == 0 else 210.0
	s._blob(ci, [Vector2(-46, 0), Vector2(46, 0), Vector2(26, -h), Vector2(-26, -h)], CREAM)
	if lv == 0:
		TSSites.planks(s, ci, Vector2(60, 0), 2, Color(0.84, 0.8, 0.78))
		return
	TSSites.roof(s, ci, Vector2(-34, -h), Vector2(34, -h), 40.0, TSSites.ROSE)
	if lv >= 3:
		s._blob(ci, [Vector2(-14, 0), Vector2(14, 0), Vector2(14, -36), Vector2(0, -46), Vector2(-14, -36)], TSSites.PINK)
		s._heart(ci, Vector2(0, -120), 12.0, TSSites.PINK)
	if lv >= 4:
		for j in 7:
			_rose(s, ci, Vector2(-48 + j * 16, -4), 6.0, [TSSites.ROSE, TSSites.PINK, TSSites.BUTTER][j % 3])
	var hub := Vector2(0, -h + 10)
	var spin := s._t * (1.6 if lv >= 2 else 1.0)
	for j in 4:
		var d := Vector2.from_angle(spin + j * PI * 0.5)
		if lv >= 2:
			ci.draw_line(hub, hub + d * 60.0, TSSites.INK, 5.0, true)
			s._heart(ci, hub + d * 78.0, 24.0, TSSites.PINK if j % 2 == 0 else CREAM)
		else:
			var across := Vector2(-d.y, d.x) * 14.0
			s._blob(ci, [hub + d * 18.0, hub + d * 100.0, hub + d * 100.0 + across, hub + d * 18.0 + across], Color(0.86, 0.8, 0.72))
	ci.draw_circle(hub, 9.0, TSSites.INK, true, -1.0, true)


# Swan Boat Dock: Driftwood, Little Dock, Swan Boat, Lantern Post, Heart Float.
static func _swan_dock(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		TSSites.planks(s, ci, Vector2(0, 0), 3, Color(0.8, 0.7, 0.6))
		return
	for x in [-26.0, 26.0]:
		s._post(ci, Vector2(x, 10), Vector2(x, -66), 7.0, TSSites.WOOD.darkened(0.2))
	for j in 6:
		s._box(ci, Rect2(Vector2(-34, -10.0 - j * 11.0), Vector2(68, 9)), CREAM.darkened(0.06))
	if lv >= 2:
		var bob := sin(s._t * 1.4) * 3.0
		var boat := Vector2(-110, -10 + bob)
		s._ellipse(ci, boat, 46.0, 16.0, Color.WHITE)
		var neck := PackedVector2Array([boat + Vector2(30, -4), boat + Vector2(44, -30), boat + Vector2(36, -54), boat + Vector2(24, -56)])
		ci.draw_polyline(neck, TSSites.INK, 13.0, true)
		ci.draw_polyline(neck, Color.WHITE, 8.0, true)
		s._blob(ci, [boat + Vector2(24, -58), boat + Vector2(12, -52), boat + Vector2(24, -50)], Color(1.0, 0.6, 0.3), false)
		s._blob(ci, [boat + Vector2(-40, -6), boat + Vector2(-10, -20), boat + Vector2(-20, 0)], Color(0.96, 0.96, 1.0))
	if lv >= 3:
		s._post(ci, Vector2(30, -70), Vector2(30, -140), 5.0, TSSites.INK)
		TSSites.lantern(s, ci, Vector2(30, -150), TSSites.PINK)
	if lv >= 4:
		var ring := Vector2(110, 0 + sin(s._t * 2.0) * 3.0)
		s._heart(ci, ring, 22.0, TSSites.ROSE)
		s._heart(ci, ring + Vector2(0, 1), 10.0, Color(0.6, 0.82, 1.0))


# Carousel: Loose Poles, Platform, Ponies, Canopy, Heart Lights.
static func _carousel(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 140.0)
	if lv == 0:
		for j in 4:
			var a := Vector2(-80 + j * 40, -2 - (j % 2) * 8)
			s._post(ci, a, a + Vector2(40, -8 + j * 4), 6.0, TSSites.GOLD)
		return
	s._ellipse(ci, Vector2(0, -10), 130.0, 26.0, CREAM)
	s._ellipse(ci, Vector2(0, -16), 124.0, 22.0, TSSites.PINK.lightened(0.2), false)
	s._post(ci, Vector2(0, -16), Vector2(0, -170), 10.0, TSSites.GOLD)
	if lv >= 2:
		for j in 4:
			var a := s._t * 0.6 + j * PI * 0.5
			var x := cos(a) * 96.0
			var depth := sin(a)
			if depth < -0.2:
				continue
			var bob := sin(s._t * 3.0 + j) * 8.0
			var at := Vector2(x, -40.0 + bob + depth * 8.0)
			ci.draw_line(Vector2(x, -170), Vector2(x, -16 + depth * 8.0), TSSites.GOLD, 3.0, true)
			s._ellipse(ci, at, 22.0, 13.0, [Color.WHITE, TSSites.PINK, Color(0.86, 0.66, 1.0), TSSites.BUTTER][j])
			ci.draw_circle(at + Vector2(signf(-sin(a)) * 20.0, -14), 9.0, [Color.WHITE, TSSites.PINK, Color(0.86, 0.66, 1.0), TSSites.BUTTER][j], true, -1.0, true)
	if lv >= 3:
		for j in 8:
			var x0 := -140.0 + j * 35.0
			s._blob(ci, [Vector2(x0, -170), Vector2(x0 + 35, -170), Vector2(x0 + 35, -150), Vector2(x0 + 17.5, -140), Vector2(x0, -150)], TSSites.PINK if j % 2 == 0 else CREAM)
		TSSites.roof(s, ci, Vector2(-146, -168), Vector2(146, -168), 60.0, TSSites.ROSE)
	if lv >= 4:
		s._heart(ci, Vector2(0, -240), 16.0 + sin(s._t * 3.0), TSSites.RED)
		for j in 7:
			var on := fposmod(s._t * 1.5 + j * 0.37, 1.0) < 0.7
			s._heart(ci, Vector2(-120 + j * 40, -146), 6.0, TSSites.BUTTER if on else Color(0.7, 0.6, 0.6))


# Blossom Treehouse: Bare Tree, Blossoms, Little House, Heart Ladder, Lanterns.
static func _blossom_treehouse(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0)
	s._blob(ci, [Vector2(-26, 0), Vector2(26, 0), Vector2(16, -250), Vector2(-16, -250)], TSSites.WOOD.darkened(0.1))
	for b in [[Vector2(0, -170), Vector2(-90, -230)], [Vector2(0, -200), Vector2(80, -260)], [Vector2(0, -240), Vector2(-30, -300)]]:
		s._post(ci, b[0], b[1], 9.0, TSSites.WOOD.darkened(0.1))
	if lv == 0:
		return
	var clumps := [Vector2(-80, -250), Vector2(70, -270), Vector2(0, -300), Vector2(-30, -240), Vector2(40, -230)]
	for c in clumps:
		ci.draw_circle(c, 58.0, TSSites.INK, true, -1.0, true)
	for n in clumps.size():
		ci.draw_circle(clumps[n], 54.0, [Color(1.0, 0.78, 0.86), Color(1.0, 0.9, 0.94), Color(0.98, 0.66, 0.78)][n % 3], true, -1.0, true)
	for j in 5:
		var age := fposmod(s._t * 0.2 + float(j) / 5.0, 1.0)
		ci.draw_circle(Vector2(-80 + j * 40 + sin(age * 7.0) * 20.0, -220.0 + age * 220.0), 4.0, Color(1.0, 0.8, 0.88, 1.0 - age), true, -1.0, true)
	s._box(ci, Rect2(Vector2(-80, -150), Vector2(160, 14)), TSSites.WOOD)
	if lv >= 2:
		s._box(ci, Rect2(Vector2(-50, -216), Vector2(100, 66)), CREAM)
		TSSites.roof(s, ci, Vector2(-62, -214), Vector2(62, -214), 48.0, TSSites.ROSE)
		s._heart(ci, Vector2(0, -184), 12.0, TSSites.PINK)
	if lv >= 3:
		for side in [-70.0, -50.0]:
			ci.draw_line(Vector2(side, -136), Vector2(side, -10), Color(0.9, 0.84, 0.7), 3.0, true)
		for j in 5:
			s._heart(ci, Vector2(-60, -116 + j * 22), 7.0, TSSites.PINK)
	if lv >= 4:
		for j in 3:
			var at := Vector2(30 + j * 30, -136 + (j % 2) * 10)
			ci.draw_line(at + Vector2(0, -14), at, TSSites.INK, 1.5, true)
			TSSites.lantern(s, ci, at + Vector2(0, 10), TSSites.PINK)


# Chocolate Stand: Crates, Stall, Awning, Chocolate Boxes, Bell & Sign.
static func _chocolate_stand(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0, 6.0)
	if lv == 0:
		s._box(ci, Rect2(Vector2(-60, -44), Vector2(50, 44)), TSSites.WOOD)
		s._box(ci, Rect2(Vector2(-4, -36), Vector2(44, 36)), TSSites.WOOD.darkened(0.1))
		return
	for x in [-80.0, 80.0]:
		s._post(ci, Vector2(x, -60), Vector2(x, -170), 7.0, CREAM.darkened(0.1))
	s._box(ci, Rect2(Vector2(-90, -64), Vector2(180, 64)), CHOC)
	if lv >= 2:
		for j in 6:
			var x0 := -100.0 + j * 33.4
			s._blob(ci, [Vector2(x0, -190), Vector2(x0 + 33.4, -190), Vector2(x0 + 33.4, -160), Vector2(x0 + 16.7, -150), Vector2(x0, -160)], TSSites.PINK if j % 2 == 0 else CREAM)
	if lv >= 3:
		for j in 3:
			var c := Vector2(-56 + j * 56, -64)
			var pts: Array = []
			for n in 28:
				var t := TAU * float(n) / 28.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) - 13.0) * 1.3)
			s._blob(ci, pts, [TSSites.RED, TSSites.PINK, Color(0.86, 0.66, 1.0)][j])
			ci.draw_line(c + Vector2(0, -4), c + Vector2(0, -36), TSSites.BUTTER, 3.0, true)
	if lv >= 4:
		TSSites.sign(s, ci, Vector2(0, -214), "SWEETS", 116.0)
		var ring := sin(s._t * 6.0) * 0.3 if fposmod(s._t, 4.0) < 0.6 else 0.0
		var bell := Vector2(80, -150)
		s._blob(ci, [bell + Vector2(-10, 0).rotated(ring), bell + Vector2(10, 0).rotated(ring), bell + Vector2(14, 22).rotated(ring), bell + Vector2(-14, 22).rotated(ring)], TSSites.GOLD)


# Flower Shop: Glass Shards, Frame, Glass Panes, Bouquets, Heart Window.
static func _flower_shop(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 100.0)
	if lv == 0:
		for at in [Vector2(-40, -4), Vector2(0, -10), Vector2(40, -2)]:
			s._blob(ci, [at, at + Vector2(20, -10), at + Vector2(10, 10)], Color(0.84, 0.92, 1.0))
		return
	var shape := [Vector2(-90, 0), Vector2(90, 0), Vector2(90, -90), Vector2(0, -150), Vector2(-90, -90)]
	if lv >= 2:
		s._blob(ci, shape, Color(0.84, 0.94, 1.0, 0.6))
	for v in [[Vector2(-90, 0), Vector2(-90, -90)], [Vector2(90, 0), Vector2(90, -90)], [Vector2(-90, -90), Vector2(0, -150)], [Vector2(90, -90), Vector2(0, -150)], [Vector2(-90, -50), Vector2(90, -50)]]:
		s._post(ci, v[0], v[1], 4.0, CREAM)
	if lv >= 3:
		for j in 4:
			var at := Vector2(-60 + j * 40, -10)
			s._blob(ci, [at + Vector2(-10, 0), at + Vector2(10, 0), at + Vector2(12, -18), at + Vector2(-12, -18)], [TSSites.WOOD, TSSites.PINK, TSSites.WOOD, Color(0.86, 0.66, 1.0)][j])
			for f in 3:
				_rose(s, ci, at + Vector2(-8 + f * 8, -26 - (f % 2) * 6), 5.0, SOFT[(j + f) % SOFT.size()])
	if lv >= 4:
		s._heart(ci, Vector2(0, -110), 22.0, Color(1.0, 0.7, 0.8, 0.85))
		TSSites.twinkle(s, ci, Vector2(0, -110), 34.0, Color.WHITE, 3)


# Love Fountain: Puddle, Heart Pool, Fountain Jet, Swans, Rose Rim.
static func _love_fountain(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	if lv == 0:
		s._ellipse(ci, Vector2.ZERO, 40.0, 10.0, TSShipScene.WATER, false)
		return
	s._ellipse(ci, Vector2.ZERO, 100.0, 28.0, Color(0.62, 0.86, 1.0))
	for j in 12:
		var a := TAU * float(j) / 12.0
		var at := Vector2(cos(a) * 104.0, sin(a) * 30.0)
		if lv >= 4:
			_rose(s, ci, at, 9.0, [TSSites.ROSE, TSSites.PINK][j % 2])
		else:
			s._ellipse(ci, at, 16.0, 10.0, Color(0.94, 0.86, 0.9))
	if lv >= 2:
		var pts := PackedVector2Array()
		for j in 9:
			var u := float(j) / 8.0
			pts.append(Vector2(-40.0 + u * 80.0, -110.0 * 4.0 * u * (1.0 - u)))
		ci.draw_polyline(pts, Color(0.8, 0.94, 1.0, 0.9), 6.0, true)
		s._heart(ci, Vector2(0, -16), 18.0, TSSites.PINK)
	if lv >= 3:
		for side in [-1.0, 1.0]:
			var at := Vector2(side * 50.0 + sin(s._t * 0.6) * 8.0, 2)
			s._ellipse(ci, at, 14.0, 8.0, Color.WHITE)
			var neck := PackedVector2Array([at + Vector2(-side * 8.0, -2), at + Vector2(-side * 14.0, -18), at + Vector2(-side * 6.0, -24)])
			ci.draw_polyline(neck, TSSites.INK, 7.0, true)
			ci.draw_polyline(neck, Color.WHITE, 4.0, true)


# Wedding Gazebo: Rubble, Round Base, Gazebo Roof, Bell, Heart Banner.
static func _gazebo(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 110.0)
	if lv == 0:
		TSSites.heap(s, ci, [Vector2(-40, 0), Vector2(10, -6), Vector2(50, 2), Vector2(-10, -26)], TSSites.STONE, 26.0, 16.0)
		return
	s._ellipse(ci, Vector2(0, -6), 100.0, 22.0, CREAM.darkened(0.05))
	if lv >= 2:
		for x in [-84.0, -30.0, 30.0, 84.0]:
			s._post(ci, Vector2(x, -10), Vector2(x, -140), 6.0, CREAM)
		TSSites.dome(s, ci, Vector2(0, -136), 100.0, TSSites.PINK)
		s._post(ci, Vector2(0, -236), Vector2(0, -260), 4.0, TSSites.GOLD)
		ci.draw_circle(Vector2(0, -264), 7.0, TSSites.GOLD, true, -1.0, true)
	if lv >= 3:
		var swing := sin(s._t * 2.4) * 0.25 if fposmod(s._t, 5.0) < 1.5 else 0.0
		var hang := Vector2(0, -136)
		ci.draw_line(hang, hang + Vector2(0, 14), TSSites.INK, 2.0, true)
		var pts: Array = []
		for v in [Vector2(-14, 0), Vector2(14, 0), Vector2(10, -20), Vector2(-10, -20)]:
			pts.append(hang + Vector2(0, 34) + (v as Vector2).rotated(swing))
		s._blob(ci, pts, TSSites.GOLD)
	if lv >= 4:
		var g := PackedVector2Array()
		for j in 13:
			var u := float(j) / 12.0
			g.append(Vector2(-84.0 + u * 168.0, -136.0 + sin(u * PI) * 16.0))
		ci.draw_polyline(g, TSSites.INK, 2.0, true)
		for j in range(1, 12, 2):
			s._heart(ci, g[j] + Vector2(0, 10), 8.0, SOFT[j % SOFT.size()])
		_floating_hearts(s, ci, Vector2(0, -250), 60.0, 2)


# Chocolate Kitchen: Clay Lump, Oven, Chimney, Heart Cookies, Cake Shelf.
static func _chocolate_kitchen(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 90.0)
	var clay := Color(0.92, 0.66, 0.66)
	if lv == 0:
		s._ellipse(ci, Vector2(0, -14), 50.0, 26.0, clay.darkened(0.15))
		return
	if lv >= 2:
		s._box(ci, Rect2(Vector2(20, -150), Vector2(24, 70)), clay.darkened(0.1))
		_floating_hearts(s, ci, Vector2(32, -160), 70.0, 2)
	TSSites.dome(s, ci, Vector2.ZERO, 80.0, clay)
	TSSites.dome(s, ci, Vector2.ZERO, 34.0, Color(0.36, 0.22, 0.24))
	ci.draw_circle(Vector2(0, -12), 12.0, Color(1.0, 0.6, 0.4, 0.6 + 0.3 * sin(s._t * 9.0)), true, -1.0, true)
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-136, -30), Vector2(64, 30)), TSSites.WOOD)
		for j in 3:
			s._heart(ci, Vector2(-124 + j * 20, -38), 8.0, [Color(0.86, 0.6, 0.4), TSSites.PINK, Color(0.86, 0.6, 0.4)][j])
	if lv >= 4:
		s._box(ci, Rect2(Vector2(90, -64), Vector2(70, 64)), TSSites.WOOD.lightened(0.1))
		s._box(ci, Rect2(Vector2(100, -96), Vector2(50, 32)), CHOC)
		s._box(ci, Rect2(Vector2(100, -100), Vector2(50, 8)), TSSites.PINK)
		s._heart(ci, Vector2(125, -108), 7.0, TSSites.RED)


# Cupid Statue: Big Rock, Rough Carving, Cupid Statue, Pedestal, Golden Cupid.
static func _cupid_statue(s: TSShipScene, ci: CanvasItem, lv: int) -> void:
	TSSites.shadow(s, ci, 70.0)
	var stone := TSSites.GOLD if lv >= 4 else Color(0.94, 0.9, 0.94)
	var base := Vector2.ZERO
	if lv >= 3:
		s._box(ci, Rect2(Vector2(-56, -40), Vector2(112, 40)), Color(0.96, 0.9, 0.94))
		s._heart(ci, Vector2(0, -20), 10.0, TSSites.PINK)
		base = Vector2(0, -40)
	if lv <= 1:
		s._blob(ci, [base + Vector2(-50, 0), base + Vector2(50, 0), base + Vector2(40, -80), base + Vector2(0, -110), base + Vector2(-40, -80)], stone)
		if lv == 1:
			ci.draw_arc(base + Vector2(0, -60), 24.0, PI * 1.1, PI * 1.9, 10, Color(TSSites.INK, 0.3), 3.0, true)
		return
	# A round little cupid: body, wings, a bow drawn.
	for side in [-1.0, 1.0]:
		s._blob(ci, [base + Vector2(side * 20, -70), base + Vector2(side * 60, -100), base + Vector2(side * 54, -70), base + Vector2(side * 30, -56)], stone.lightened(0.15))
	s._ellipse(ci, base + Vector2(0, -50), 34.0, 40.0, stone)
	ci.draw_circle(base + Vector2(-10, -58), 3.5, Color(TSSites.INK, 0.7), true, -1.0, true)
	ci.draw_circle(base + Vector2(10, -58), 3.5, Color(TSSites.INK, 0.7), true, -1.0, true)
	ci.draw_arc(base + Vector2(0, -50), 8.0, 0.3, PI - 0.3, 8, Color(TSSites.INK, 0.7), 2.0, true)
	ci.draw_arc(base + Vector2(40, -50), 22.0, -PI * 0.6, PI * 0.6, 12, TSSites.INK, 5.0, true)
	ci.draw_line(base + Vector2(20, -50), base + Vector2(64, -50), TSSites.INK, 2.0, true)
	s._heart(ci, base + Vector2(68, -50), 6.0, TSSites.ROSE)
	if lv >= 4:
		TSSites.twinkle(s, ci, base + Vector2(0, -60), 56.0, Color.WHITE, 4)


# -- the card's icons --------------------------------------------------------------

static func icon(ic: TSIcon, part: int, broken: bool) -> void:
	var pink := Color(0.86, 0.78, 0.8) if broken else TSSites.PINK
	var rose := Color(0.78, 0.66, 0.7) if broken else TSSites.ROSE
	var cream := CREAM
	var wood := Color(0.62, 0.5, 0.44) if broken else Color(0.78, 0.56, 0.38)
	if broken:
		ic._ellipse(Vector2(0.5, 0.72), 0.34, 0.12, Color(0.9, 0.8, 0.84))
	match part:
		TSProfile.CAMP_FIRE:
			ic._rrect(Rect2(0.22, 0.62, 0.56, 0.1), 0.04, wood)
			if not broken:
				_heart(ic, Vector2(0.5, 0.42), 0.18, Color(1.0, 0.46, 0.5))
		TSProfile.CAMP_TENT:
			ic._rrect(Rect2(0.2, 0.46, 0.6, 0.38), 0.02, cream)
			ic._poly([Vector2(0.12, 0.48), Vector2(0.88, 0.48), Vector2(0.5, 0.16)], pink)
			if not broken:
				_heart(ic, Vector2(0.5, 0.66), 0.08, rose)
		TSProfile.CAMP_BENCH:
			ic._rrect(Rect2(0.14, 0.56, 0.72, 0.1), 0.02, wood)
			if not broken:
				ic._rrect(Rect2(0.28, 0.3, 0.26, 0.24), 0.02, cream)
				_heart(ic, Vector2(0.41, 0.42), 0.06, rose)
		TSProfile.CAMP_GARDEN:
			ic._ellipse(Vector2(0.5, 0.7), 0.38, 0.14, Color(0.62, 0.46, 0.4))
			if not broken:
				for x in [0.3, 0.5, 0.7]:
					ic._line([Vector2(x, 0.7), Vector2(x, 0.44)], Color(0.36, 0.62, 0.42), 1.0)
					ic._circle(Vector2(x, 0.4), 0.07, rose)
		TSProfile.CAMP_WELL:
			ic._rrect(Rect2(0.26, 0.54, 0.48, 0.28), 0.04, Color(0.9, 0.82, 0.86))
			if not broken:
				ic._poly([Vector2(0.18, 0.3), Vector2(0.82, 0.3), Vector2(0.5, 0.1)], pink)
				_heart(ic, Vector2(0.5, 0.44), 0.07, rose)
		TSProfile.CAMP_LOOKOUT:
			ic._line([Vector2(0.3, 0.86), Vector2(0.34, 0.4)], cream.darkened(0.2), 1.4)
			ic._line([Vector2(0.7, 0.86), Vector2(0.66, 0.4)], cream.darkened(0.2), 1.4)
			if not broken:
				ic._poly([Vector2(0.22, 0.36), Vector2(0.78, 0.36), Vector2(0.5, 0.12)], pink)
				_heart(ic, Vector2(0.5, 0.52), 0.08, rose)
		TSProfile.CAMP_HAMMOCK:
			ic._line([Vector2(0.14, 0.86), Vector2(0.14, 0.2), Vector2(0.86, 0.2), Vector2(0.86, 0.86)], cream.darkened(0.2), 1.2)
			if not broken:
				ic._rrect(Rect2(0.24, 0.56, 0.52, 0.1), 0.02, wood)
				_heart(ic, Vector2(0.4, 0.5), 0.07, pink)
				_heart(ic, Vector2(0.6, 0.5), 0.07, rose)
		TSProfile.CAMP_PICNIC:
			ic._poly([Vector2(0.08, 0.8), Vector2(0.92, 0.8), Vector2(0.8, 0.56), Vector2(0.2, 0.56)], pink)
			if not broken:
				_heart(ic, Vector2(0.5, 0.66), 0.08, rose)
		TSProfile.CAMP_CLOTHESLINE:
			ic._line([Vector2(0.1, 0.26), Vector2(0.9, 0.26)], TSIcon.INK, 0.8)
			if not broken:
				for j in 3:
					_heart(ic, Vector2(0.24 + j * 0.26, 0.42), 0.09, [pink, rose, pink][j])
		TSProfile.CAMP_MAILBOX:
			ic._line([Vector2(0.5, 0.86), Vector2(0.5, 0.5)], wood, 1.4)
			ic._rrect(Rect2(0.28, 0.24, 0.44, 0.28), 0.1, pink)
			if not broken:
				_heart(ic, Vector2(0.5, 0.38), 0.07, rose)
		TSProfile.CAMP_WINDMILL:
			ic._poly([Vector2(0.36, 0.86), Vector2(0.64, 0.86), Vector2(0.58, 0.44), Vector2(0.42, 0.44)], cream)
			if not broken:
				for j in 4:
					_heart(ic, Vector2(0.5, 0.42) + Vector2.from_angle(j * PI * 0.5 + 0.6) * 0.24, 0.09, pink)
		TSProfile.CAMP_DOCK:
			ic._ellipse(Vector2(0.44, 0.66), 0.28, 0.1, Color.WHITE)
			if not broken:
				ic._line([Vector2(0.64, 0.62), Vector2(0.72, 0.4), Vector2(0.64, 0.3)], Color.WHITE, 1.6)
				ic._circle(Vector2(0.62, 0.3), 0.04, Color.WHITE)
		TSProfile.CAMP_PLAYGROUND:
			ic._ellipse(Vector2(0.5, 0.78), 0.4, 0.1, cream)
			ic._line([Vector2(0.5, 0.78), Vector2(0.5, 0.36)], TSSites.GOLD, 1.0)
			if not broken:
				ic._poly([Vector2(0.1, 0.38), Vector2(0.9, 0.38), Vector2(0.5, 0.12)], rose)
				ic._ellipse(Vector2(0.3, 0.6), 0.1, 0.06, pink)
		TSProfile.CAMP_TREEHOUSE:
			ic._line([Vector2(0.5, 0.88), Vector2(0.5, 0.5)], wood, 2.0)
			ic._circle(Vector2(0.5, 0.36), 0.3, Color(1.0, 0.82, 0.9) if not broken else Color(0.7, 0.62, 0.62))
			if not broken:
				_heart(ic, Vector2(0.5, 0.4), 0.08, rose)
		TSProfile.CAMP_STALL:
			ic._rrect(Rect2(0.16, 0.54, 0.68, 0.3), 0.03, CHOC if not broken else wood)
			if not broken:
				for k in 4:
					ic._poly([Vector2(0.12 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.2), Vector2(0.31 + k * 0.19, 0.34), Vector2(0.12 + k * 0.19, 0.34)], pink if k % 2 == 0 else cream)
		TSProfile.CAMP_GREENHOUSE:
			ic._poly([Vector2(0.14, 0.84), Vector2(0.86, 0.84), Vector2(0.86, 0.44), Vector2(0.5, 0.18), Vector2(0.14, 0.44)], Color(0.84, 0.94, 1.0))
			if not broken:
				for x in [0.34, 0.5, 0.66]:
					ic._circle(Vector2(x, 0.64), 0.06, rose)
		TSProfile.CAMP_SPRING:
			ic._ellipse(Vector2(0.5, 0.66), 0.38, 0.14, Color(0.62, 0.86, 1.0))
			if not broken:
				_heart(ic, Vector2(0.5, 0.56), 0.1, pink)
		TSProfile.CAMP_OBSERVATORY:
			ic._ellipse(Vector2(0.5, 0.82), 0.38, 0.08, cream)
			if not broken:
				for x in [0.2, 0.4, 0.6, 0.8]:
					ic._line([Vector2(x, 0.8), Vector2(x, 0.44)], cream.darkened(0.2), 1.0)
				ic._poly(TSSitesChristmas._dome(Vector2(0.5, 0.46), 0.36), pink)
		TSProfile.CAMP_OVEN:
			ic._poly(TSSitesChristmas._dome(Vector2(0.5, 0.82), 0.38 if not broken else 0.24), Color(0.92, 0.66, 0.66))
			if not broken:
				ic._rrect(Rect2(0.38, 0.62, 0.24, 0.2), 0.1, Color(0.36, 0.22, 0.24))
		TSProfile.CAMP_STATUE:
			if broken:
				ic._poly([Vector2(0.2, 0.84), Vector2(0.8, 0.84), Vector2(0.7, 0.4), Vector2(0.5, 0.3), Vector2(0.28, 0.44)], TSSites.STONE)
			else:
				ic._rrect(Rect2(0.24, 0.72, 0.52, 0.14), 0.02, Color(0.96, 0.9, 0.94))
				ic._poly([Vector2(0.4, 0.4), Vector2(0.18, 0.24), Vector2(0.22, 0.42)], Color(1.0, 0.97, 1.0))
				ic._poly([Vector2(0.6, 0.4), Vector2(0.82, 0.24), Vector2(0.78, 0.42)], Color(1.0, 0.97, 1.0))
				ic._circle(Vector2(0.5, 0.5), 0.18, Color(0.96, 0.92, 0.96))
				_heart(ic, Vector2(0.5, 0.78), 0.05, rose)


static func _heart(ic: TSIcon, c: Vector2, r: float, fill: Color) -> void:
	var pts: Array = []
	for n in 24:
		var t := TAU * float(n) / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 16.0))
	ic._poly(pts, fill, r >= 0.12)   # a small one unoutlined, or the ink fills it
