class_name TSSites
extends RefCounted

## Seasonal work sites. Each season's planet (TSProfile.planet_theme) has
## its own 20 camp spots in place of the autumn camp's: the same places,
## costs, waves and levels, but each spot is something else there, with its
## own name, stages (TSProfile.SITES) and drawings. On Christmas the campfire
## is a Yule Log Fire and the market stall a Cocoa Stand; at New Year the
## lookout is a Clock Tower; at Valentine's the garden is a Rose Garden. The
## camp starts again on every planet (TSProfile.take_voyage), so each season's
## sites are built up from their makings.
##
## The scene (TSShipScene) asks draw() for a spot on a planet with sites; the
## card's icon (TSIcon "part") asks icon(). Each season's drawings are in its
## own file (sites_christmas.gd, sites_newyear.gd, sites_valentine.gd), drawn
## round the spot's foot at (0, 0), y up the screen negative, already scaled
## for the spot's depth.

const THEMES := ["christmas", "newyear"]

const INK := TSShipScene.INK
const WOOD := TSShipScene.WOOD
const BUTTER := TSShipScene.BUTTER
const SHADOW := TSShipScene.SHADOW
const GOLD := TSShipScene.GOLD
const CHROME := TSShipScene.CHROME
const ACCENT := TSShipScene.ACCENT
const RED := Color(0.94, 0.3, 0.34)
const GREEN := Color(0.3, 0.66, 0.42)
const SNOW := Color(0.99, 0.99, 1.0)
const ICE := Color(0.78, 0.92, 1.0)
const PINK := Color(1.0, 0.62, 0.74)
const ROSE := Color(0.95, 0.36, 0.5)
const LILAC := Color(0.76, 0.66, 1.0)
const NIGHT := Color(0.3, 0.28, 0.52)
const STONE := Color(0.78, 0.76, 0.84)


static func has(theme: String) -> bool:
	return THEMES.has(theme)


## Draws camp spot `part` at level `lv` for `theme`, its foot at `p`, `k` its
## depth's scale.
static func draw(s: TSShipScene, ci: CanvasItem, theme: String, part: int, lv: int, p: Vector2, k: float) -> void:
	# The layer draws in world coordinates, shifted by its own position.
	var off: Vector2 = (ci as Control).position if ci is Control else Vector2.ZERO
	ci.draw_set_transform(p - off, 0.0, Vector2(k, k))
	match theme:
		"christmas":
			TSSitesChristmas.draw(s, ci, part, lv)
		"newyear":
			TSSitesNewYear.draw(s, ci, part, lv)
		"valentine":
			TSSitesValentine.draw(s, ci, part, lv)
	ci.draw_set_transform(-off)


## The card's icon for a spot on a planet with sites (unit square, TSIcon's helpers).
static func icon(ic: TSIcon, theme: String, part: int, broken: bool) -> void:
	match theme:
		"christmas":
			TSSitesChristmas.icon(ic, part, broken)
		"newyear":
			TSSitesNewYear.icon(ic, part, broken)
		"valentine":
			TSSitesValentine.icon(ic, part, broken)


# -- shared pieces (local coordinates) -----------------------------------------

static func shadow(s: TSShipScene, ci: CanvasItem, w: float, y := 8.0) -> void:
	s._ellipse(ci, Vector2(0, y), w, w * 0.16 + 4.0, SHADOW, false)


## A heap of makings: lumps at `spots`, in `col`.
static func heap(s: TSShipScene, ci: CanvasItem, spots: Array, col: Color, rx := 24.0, ry := 14.0) -> void:
	for n in spots.size():
		s._ellipse(ci, spots[n], rx - (n % 2) * 4.0, ry - (n % 2) * 2.0, col.darkened(0.06 * (n % 3)))


## Planks lying about.
static func planks(s: TSShipScene, ci: CanvasItem, at: Vector2, n: int, col := WOOD) -> void:
	for j in n:
		var a := at + Vector2(-40.0 + j * 28.0, -4.0 - (j % 2) * 8.0)
		s._post(ci, a, a + Vector2(36.0, -6.0 + j * 5.0), 7.0, col)


## Smoke or steam rising from `at`.
static func puffs(s: TSShipScene, ci: CanvasItem, at: Vector2, col := Color(0.9, 0.9, 0.94), rise := 80.0, n := 3) -> void:
	for j in n:
		var age := fposmod(s._t * 0.35 + float(j) / float(n), 1.0)
		ci.draw_circle(at + Vector2(sin(age * 5.0 + j) * 10.0, -age * rise), 7.0 + age * 14.0, Color(col, 0.6 * (1.0 - age)), true, -1.0, true)


## A five-pointed star, inked.
static func star(ci: CanvasItem, c: Vector2, r: float, fill: Color, turn := 0.0) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI * 0.5 + turn + TAU * float(j) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 2.5, true)


## A candy-cane striped pole from `a` to `b`.
static func cane(ci: CanvasItem, a: Vector2, b: Vector2, w: float) -> void:
	ci.draw_line(a, b, INK, w + 5.0, true)
	ci.draw_line(a, b, SNOW, w, true)
	var n := int(a.distance_to(b) / (w * 1.6))
	for j in range(0, n, 2):
		ci.draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), RED, w, true)


## A pennant waving on a pole whose top is `top`.
static func flag(s: TSShipScene, ci: CanvasItem, top: Vector2, col: Color, pole := 50.0) -> void:
	ci.draw_line(top + Vector2(0, pole), top, INK, 4.0, true)
	var wave := sin(s._t * 4.0) * 4.0
	s._blob(ci, [top, top + Vector2(38, 9 + wave), top + Vector2(0, 20)], col)


## A string of twinkling bulbs from `a` to `b`, sagging `sag`.
static func bulbs(s: TSShipScene, ci: CanvasItem, a: Vector2, b: Vector2, sag := 12.0, n := 7) -> void:
	s._fairy_lights(ci, a, b, sag, n, 1.0)


## A little sign board with `text` on it, centred at `c`.
static func sign(s: TSShipScene, ci: CanvasItem, c: Vector2, text: String, w: float, fill := Color(1.0, 0.98, 0.9), ink := INK) -> void:
	s._box(ci, Rect2(c - Vector2(w * 0.5, 18.0), Vector2(w, 36.0)), fill)
	s._text(ci, c + Vector2(-w * 0.5 + 6.0, 9.0), text, 22.0, ink)


## A lantern glowing at `c`.
static func lantern(s: TSShipScene, ci: CanvasItem, c: Vector2, glow := BUTTER) -> void:
	ci.draw_circle(c, 16.0, Color(glow, 0.25 + 0.1 * sin(s._t * 3.0)), true, -1.0, true)
	s._box(ci, Rect2(c - Vector2(8, 10), Vector2(16, 20)), glow)


## A wrapped present standing on `at`.
static func present(s: TSShipScene, ci: CanvasItem, at: Vector2, size := 1.0) -> void:
	s._draw_present(ci, at, size)


## A snowy cap over a roof's top at `top`, `w` across.
static func snow_cap(s: TSShipScene, ci: CanvasItem, top: Vector2, w: float) -> void:
	s._draw_snow_cap(ci, top, w)


## A pointed roof: a triangle from `l` to `r` peaking `h` up.
static func roof(s: TSShipScene, ci: CanvasItem, l: Vector2, r: Vector2, h: float, col: Color) -> void:
	s._blob(ci, [l, r, (l + r) * 0.5 + Vector2(0, -h)], col)


## A dome (half disc) on `c`, radius `r`.
static func dome(s: TSShipScene, ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	s._blob(ci, Array(s._half_circle(c, r)), col)


## Sparkles twinkling round `c` within `r`.
static func twinkle(s: TSShipScene, ci: CanvasItem, c: Vector2, r: float, col := Color.WHITE, n := 3) -> void:
	for j in n:
		var a := float(j) * 2.4
		s._sparkle(ci, c + Vector2(cos(a), sin(a)) * r, 7.0 * (0.5 + 0.5 * sin(s._t * 3.0 + j * 1.9)), col)
