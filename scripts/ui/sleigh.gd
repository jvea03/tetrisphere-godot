class_name TSSleigh
extends Control

## During the Christmas Battle Pass season, now and then, Santa's sleigh -- a
## silhouette, pulled by three reindeer with Rudy's red nose glowing at the
## front -- glides across the sky, galloping and bobbing, then is gone for a
## while. Drawn facing right in a SIZE box (`flip` faces it left).
##
## On its own (Home) it flies across `area` -- a Callable giving the stretch
## of sky in its parent's coordinates, Rect2() when none is in view -- moving
## itself. With `steer` off (a level, where it is drawn into a texture) it only
## keeps time: the host reads `flying`, `progress` and `flip` and places it.

const SIZE := Vector2(520.0, 170.0)
const INK := Color(0.3, 0.26, 0.4)       # the silhouette
const NOSE := Color(1.0, 0.25, 0.28)
const CROSS_SECONDS := 10.0
const FIRST_WAIT := Vector2(6.0, 14.0)    # seconds before the first pass
const GAP := Vector2(35.0, 70.0)          # and between passes

var area: Callable
var steer := true
var flying := false
var progress := 0.0                       # 0..1 across, while flying
var flip := false                         # flying right to left
var _wait := 0.0
var _t := 0.0
var _painted := -1.0
var _rng := RandomNumberGenerator.new()


## Whether the sleigh flies now: the Christmas season.
static func in_season() -> bool:
	return TSProfile.season_theme() == "christmas"


func _ready() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_wait = _rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	visible = not steer
	set_process(in_season())


func _process(delta: float) -> void:
	_t += delta
	if not flying:
		_wait -= delta
		if _wait > 0.0:
			return
		if steer and (not area.is_valid() or (area.call() as Rect2).size.x <= 0.0):
			_wait = 3.0   # no sky in view: look again soon
			return
		flying = true
		progress = 0.0
		flip = _rng.randf() < 0.5
		if steer:
			visible = true
	progress += delta / CROSS_SECONDS
	if progress >= 1.0:
		flying = false
		_wait = _rng.randf_range(GAP.x, GAP.y)
		if steer:
			visible = false
		return
	if steer:
		var sky: Rect2 = area.call()
		var k := clampf(sky.size.x / 1100.0, 0.5, 1.0)
		scale = Vector2(-k if flip else k, k)
		var u := 1.0 - progress if flip else progress
		var x := lerpf(sky.position.x - SIZE.x, sky.end.x + SIZE.x * 0.2, u)
		# Climbing gently as it goes, bobbing, kept within the band of sky.
		position = Vector2(x, sky.position.y + maxf(sky.size.y - SIZE.y * k, 0.0) * (0.9 - 0.35 * progress) + sin(progress * TAU * 1.5) * 10.0)
	if _t - _painted >= 1.0 / 20.0:   # galloping at 20 frames a second is plenty
		_painted = _t
		queue_redraw()


func _draw() -> void:
	draw_sleigh(self, _t)


## The silhouette, in its SIZE box facing right, `t` seconds into its gallop.
static func draw_sleigh(ci: CanvasItem, t: float) -> void:
	# The reins, from the sleigh's nose to each reindeer.
	for x0 in [230.0, 330.0, 430.0]:
		ci.draw_line(Vector2(165, 66), Vector2(x0 + 30.0, 70.0), INK, 2.5, true)
	# The sleigh: a curling front, a runner underneath on two struts.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 66), Vector2(148, 70), Vector2(166, 52), Vector2(178, 58), Vector2(170, 92), Vector2(140, 110), Vector2(32, 110), Vector2(8, 88)]), INK)
	ci.draw_polyline(PackedVector2Array([Vector2(-6, 118), Vector2(0, 126), Vector2(150, 126), Vector2(168, 118), Vector2(176, 104), Vector2(170, 96)]), INK, 6.0, true)
	for x in [40.0, 120.0]:
		ci.draw_line(Vector2(x, 108), Vector2(x, 126), INK, 5.0, true)
	# Santa (round, a pompom on his hat) and his sack.
	ci.draw_circle(Vector2(36, 52), 26.0, INK, true, -1.0, true)
	ci.draw_line(Vector2(30, 28), Vector2(42, 22), INK, 6.0, true)
	ci.draw_circle(Vector2(84, 54), 27.0, INK, true, -1.0, true)
	ci.draw_circle(Vector2(94, 22), 14.0, INK, true, -1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(82, 16), Vector2(104, 12), Vector2(116, -4)]), INK)
	ci.draw_circle(Vector2(117, -5), 5.5, INK, true, -1.0, true)
	ci.draw_line(Vector2(104, 50), Vector2(150, 62), INK, 7.0, true)   # an arm on the reins
	# The reindeer, Rudy in front.
	for k in 3:
		var x0 := 230.0 + 100.0 * float(k)
		var g := t * 9.0 + float(k) * 1.3   # each gallops a beat apart
		var bob := sin(g) * 4.0
		var body := PackedVector2Array()
		for j in 20:
			var a := TAU * float(j) / 20.0
			body.append(Vector2(x0 + cos(a) * 34.0, 78.0 + bob + sin(a) * 14.0))
		ci.draw_colored_polygon(body, INK)
		ci.draw_line(Vector2(x0 + 24, 74 + bob), Vector2(x0 + 40, 52 + bob), INK, 9.0, true)   # neck
		var head := PackedVector2Array()
		for j in 14:
			var a := TAU * float(j) / 14.0
			head.append(Vector2(x0 + 47.0 + cos(a) * 12.0, 48.0 + bob + sin(a) * 7.0))
		ci.draw_colored_polygon(head, INK)
		ci.draw_line(Vector2(x0 + 36, 30 + bob), Vector2(x0 + 30, 22 + bob), INK, 3.0, true)
		for side in [-1.0, 1.0]:   # antlers
			var base := Vector2(x0 + 41.0 + side * 3.0, 43.0 + bob)
			var tip := base + Vector2(-6.0 + side * 6.0, -24.0)
			ci.draw_line(base, tip, INK, 3.5, true)
			ci.draw_line(base.lerp(tip, 0.5), base.lerp(tip, 0.5) + Vector2(-9.0, -6.0), INK, 3.0, true)
			ci.draw_line(base.lerp(tip, 0.8), base.lerp(tip, 0.8) + Vector2(7.0, -6.0), INK, 3.0, true)
		ci.draw_line(Vector2(x0 - 32, 72 + bob), Vector2(x0 - 42, 64 + bob), INK, 5.0, true)   # tail
		# Legs, front and back pairs, stretching and tucking in turn.
		for leg in [[x0 + 22.0, 0.0], [x0 + 14.0, 0.6], [x0 - 22.0, PI], [x0 - 14.0, PI + 0.6]]:
			var swing := sin(g + float(leg[1])) * 0.7
			var hip := Vector2(float(leg[0]), 86.0 + bob)
			var knee := hip + Vector2(0, 16).rotated(swing)
			ci.draw_line(hip, knee, INK, 5.0, true)
			ci.draw_line(knee, knee + Vector2(0, 15).rotated(swing * 1.6 - 0.3), INK, 4.0, true)
		if k == 2:
			var nose := Vector2(x0 + 60.0, 50.0 + bob)
			var glow := 0.75 + 0.25 * sin(t * 5.0)
			ci.draw_circle(nose, 15.0 * glow, Color(NOSE, 0.25), true, -1.0, true)
			ci.draw_circle(nose, 6.0, NOSE, true, -1.0, true)
