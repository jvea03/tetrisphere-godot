class_name TSCreature
extends Node3D

## The critter sealed in the egg: a glowing core in the avatar's colour with
## a face that keeps turning toward the viewer (face_toward, every frame), and
## a mood that keeps changing while the level is played -- breathing,
## looking around, wiggling, pushing at the shell toward the most-dug way out
## (harder the nearer it is to open), cheering a chain, and scared when a
## heart is lost (and jumpier on the last heart), and now and then making a
## run at the shell: it bonks into it and the egg wobbles (`bumped`, which
## the game answers with a knock and the wobble). The game calls react() on
## those moments and sets `hope`, `hole_dir` and `nervous` after each drop.
## Moods move only the inner body, so the escape tween on this node is free
## to shrink it and fly it out.

enum Mood { IDLE, LOOK, WIGGLE, PUSH, SCARED, HAPPY, BUMP }

## A run at the shell (Mood.BUMP) hit it, toward `dir` (unit, from the egg's middle).
signal bumped(dir: Vector3)

const R := TSBoardView.CORE_RADIUS
## Each size of critter (the egg's difficulty sets its scale) has its own
## colour and its own little extra: the small one a leaf sprout, the middle
## one bunny ears, the big one a pair of horns. KINDS is smallest first.
const KINDS := [
	{"body": Color(1.0, 0.85, 0.36), "extra": "sprout"},
	{"body": Color(0.52, 0.86, 0.72), "extra": "ears"},
	{"body": Color(1.0, 0.56, 0.52), "extra": "horns"},
]
const LEAF := Color(0.45, 0.8, 0.42)
const HORN := Color(1.0, 0.8, 0.38)
const INNER_EAR := Color(1.0, 0.7, 0.78)
const PUSH_REACH := 0.22     # how far a push carries the body toward the way out
const PUSH_BEAT := 0.7       # seconds per push
const BUMP_LEN := 1.9        # a run at the shell: wind-up, dash, bonk, bounce back, dizzy
const BUMP_HIT := 0.5        # ...the moment it hits
const BUMP_WEIGHT := 0.45    # how often it picks one (IDLE is 2.0): every half a minute or so

var hope := 0.0              # 0..1: how near the most-dug way out is to open
var hole_dir := Vector3.ZERO # toward that way out (unit), or zero for none
var nervous := false         # down to the last heart: scared more often

var _body: Node3D            # wobbles, squashes and bumps; the face rides on it
var _core: MeshInstance3D
var _patch: MeshInstance3D    # the lighter face patch behind the eyes
var _extras: Array = []       # the kind's sprout, ears or horns
var kind := -1
var _face: Node3D
var _eyes: Array = []        # per eye: {"eye": Node3D, "pupil": Node3D, "rest": Vector3}
var _mouth: MeshInstance3D
var _sweat: MeshInstance3D
var _mood := Mood.IDLE
var _mood_t := 0.0
var _mood_len := 2.5
var _look := Vector2.ZERO    # where the pupils are, -1..1 each way
var _look_to := Vector2.ZERO
var _blink_in := 2.0
var _blink_t := -1.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _cam_dir := Vector3.BACK # toward the camera from the egg's middle (face_toward)
var _bump_dir := Vector3.RIGHT
var _bump_hit := false       # this run's bonk sent


func _init(colour: Color) -> void:
	_rng.randomize()
	_body = Node3D.new()
	add_child(_body)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R * 0.99
	sm.height = R * 1.98
	sm.radial_segments = 48
	sm.rings = 24
	core.mesh = sm
	core.material_override = TSToon.material(colour, 1.0, 0.12)   # a faint glow of its own
	_body.add_child(core)
	_core = core
	# Big shiny eyes and pink cheeks: -z faces the viewer, +z runs into the core.
	_face = Node3D.new()
	_body.add_child(_face)
	# A lighter patch for the face, pressed against the core: two-tone, like a
	# plush toy, so the eyes stand out.
	_patch = _part(Vector3(0.0, -0.1, 0.55), 2.05, Vector3(1.0, 0.8, 0.28), colour.lightened(0.5), 0.15, false)
	_face.add_child(_patch)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.80, 0.35, -0.05)
		_face.add_child(eye)
		eye.add_child(_part(Vector3.ZERO, 0.75, Vector3.ONE, Color.WHITE, 0.1, true))
		var pupil := Node3D.new()
		pupil.position = Vector3(-side * 0.06, -0.05, -0.5)
		eye.add_child(pupil)
		pupil.add_child(_part(Vector3.ZERO, 0.40, Vector3.ONE, TSToon.INK, 0.0, false))
		# Two sparkles, the big one catching the light.
		pupil.add_child(_part(Vector3(-0.13, 0.17, -0.37), 0.13, Vector3.ONE, Color.WHITE, 1.0, false))
		pupil.add_child(_part(Vector3(0.12, -0.13, -0.37), 0.06, Vector3.ONE, Color.WHITE, 1.0, false))
		_eyes.append({"eye": eye, "pupil": pupil, "rest": pupil.position})
		# Blush, pressed flat against the curve of the core.
		_face.add_child(_part(Vector3(side * 1.45, -0.50, 0.35), 0.36, Vector3(1.0, 0.55, 0.35), Color(1.0, 0.58, 0.68), 0.25, false))
	# A mouth that shows only when it has something to say (a gasp, a strain,
	# a cheer), and a bead of sweat.
	_mouth = _part(Vector3(0.0, -0.66, -0.08), 0.34, Vector3.ONE, TSToon.INK, 0.0, false)
	_face.add_child(_mouth)
	_sweat = _part(Vector3(1.7, 0.9, 0.25), 0.24, Vector3(0.8, 1.25, 0.6), Color(0.62, 0.86, 1.0), 0.5, true)
	_face.add_child(_sweat)
	_set_mood(Mood.IDLE, 2.0)


## The kind of critter for a size (TSLevels' "scale"): 0 small, 1 middle, 2 big.
static func kind_for_scale(s: float) -> int:
	return 0 if s < 0.62 else (1 if s < 0.78 else 2)


## Dresses the critter as a kind (KINDS): its colour, face patch and extra.
func set_kind(k: int) -> void:
	k = clampi(k, 0, KINDS.size() - 1)
	if k == kind:
		return
	kind = k
	var body: Color = KINDS[k]["body"]
	_core.material_override = TSToon.material(body, 1.0, 0.12)
	_patch.material_override = TSToon.material(body.lightened(0.5), 1.0, 0.15, false, false)
	for e in _extras:
		e.queue_free()
	_extras = []
	# On the face node: +y is up on screen and the core's middle is R into +z,
	# so the top of the head is near (0, R, R). Kept inside the shell's first
	# layer at the biggest size.
	match str(KINDS[k]["extra"]):
		"sprout":
			_extra(Vector3(0.0, R * 0.9, R * 0.9), 0.2, Vector3(1.0, 3.0, 1.0), LEAF.darkened(0.15), true)
			_extra(Vector3(-0.62, R * 0.9 + 0.62, R * 0.9), 0.56, Vector3(1.5, 0.62, 0.7), LEAF, true).rotation.z = 0.5
			_extra(Vector3(0.62, R * 0.9 + 0.62, R * 0.9), 0.56, Vector3(1.5, 0.62, 0.7), LEAF, true).rotation.z = -0.5
		"ears":
			for side in [-1.0, 1.0]:
				var ear := _extra(Vector3(side * 1.15, R * 0.86, R * 0.85), 0.62, Vector3(0.62, 1.45, 0.5), body, true)
				ear.rotation.z = -side * 0.22
				var inner := _part(Vector3(0.0, -0.05, -0.32), 0.62, Vector3(0.55, 0.78, 0.3), INNER_EAR, 0.2, false)
				ear.add_child(inner)
		"horns":
			for side in [-1.0, 1.0]:
				var horn := _extra(Vector3(side * 1.3, R * 0.8, R * 0.85), 0.48, Vector3(0.85, 1.7, 0.85), HORN, true)
				horn.rotation.z = -side * 0.4


func _extra(offset: Vector3, radius: float, squash: Vector3, tint: Color, inked: bool) -> MeshInstance3D:
	var p := _part(offset, radius, squash, tint, 0.12, inked)
	_face.add_child(p)
	_extras.append(p)
	return p


func _part(offset: Vector3, radius: float, squash: Vector3, tint: Color, glow: float, inked: bool) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	part.mesh = mesh
	part.position = offset
	part.scale = squash
	part.material_override = TSToon.material(tint, 1.0, glow, false, inked)
	return part


## Keeps the face on the side of the core toward the camera, `dir` (unit)
## being the camera's direction from the middle of the egg.
func face_toward(dir: Vector3, camera_at: Vector3) -> void:
	_cam_dir = dir
	_face.position = dir * (R * 0.99)
	_face.look_at(camera_at, Vector3.UP)


## Something happened: switch to `mood` for `seconds` (a scare, a cheer).
func react(mood: Mood, seconds := -1.0) -> void:
	var lengths := {Mood.SCARED: 1.8, Mood.HAPPY: 1.4, Mood.BUMP: BUMP_LEN}
	_set_mood(mood, seconds if seconds > 0.0 else float(lengths.get(mood, 2.0)))


func mood() -> Mood:
	return _mood


func _set_mood(m: Mood, seconds: float) -> void:
	if m == Mood.BUMP:
		_aim_bump()
	_mood = m
	_mood_t = 0.0
	_mood_len = seconds
	_look_to = Vector2.ZERO


## The next mood on its own, the way out and the hearts left weighing in.
func _pick_mood() -> void:
	var weights := {
		Mood.IDLE: 2.0,
		Mood.LOOK: 2.0,
		Mood.WIGGLE: 1.5,
		Mood.PUSH: 0.6 + 4.0 * hope if hole_dir != Vector3.ZERO else 0.0,
		Mood.SCARED: 2.5 if nervous else 0.0,
		Mood.BUMP: BUMP_WEIGHT,
	}
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := _rng.randf() * total
	var pick := Mood.IDLE
	for m in weights:
		roll -= float(weights[m])
		if roll <= 0.0:
			pick = m
			break
	var lengths := {Mood.IDLE: _rng.randf_range(2.0, 3.5), Mood.LOOK: _rng.randf_range(2.4, 3.6),
		Mood.WIGGLE: _rng.randf_range(1.2, 1.8), Mood.PUSH: PUSH_BEAT * 3.0, Mood.SCARED: 1.6,
		Mood.BUMP: BUMP_LEN}
	_set_mood(pick, float(lengths[pick]))


## Where the next run goes: off to one side of the camera's view of it (so the
## dash shows), a little toward the viewer.
func _aim_bump() -> void:
	var side := _cam_dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	side = side.normalized().rotated(_cam_dir, _rng.randf_range(-PI, PI))
	_bump_dir = (side + _cam_dir * 0.35).normalized()
	_bump_hit = false


## How far the body can go before it meets the shell, in its own units: the
## egg's inside is R across and the whole critter is scaled down inside it.
func _room() -> float:
	return maxf(0.15, R * (1.0 / maxf(scale.x, 0.3) - 1.0) * 0.92)


func _process(delta: float) -> void:
	_t += delta
	_mood_t += delta
	if _mood_t >= _mood_len:
		_pick_mood()
	var bump := Vector3.ZERO
	var squash := 1.0
	var roll := 0.0
	var pupil := 1.0
	var white := 1.0
	var open := 1.0          # eyelids: 1 open, 0 shut
	var mouth := Vector3.ZERO   # the mouth's shape (zero: none)
	var sweat := false
	var fade := clampf(minf(_mood_t, _mood_len - _mood_t) * 4.0, 0.0, 1.0)   # eases each mood in and out
	match _mood:
		Mood.IDLE:
			squash = 1.0 + 0.025 * sin(_t * 2.2)
		Mood.LOOK:
			# Glances somewhere new every so often, holding each look.
			if _rng.randf() < delta * 1.4:
				_look_to = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.8))
			squash = 1.0 + 0.02 * sin(_t * 2.2)
		Mood.WIGGLE:
			roll = sin(_t * 15.0) * 0.28 * fade
			squash = 1.0 + 0.04 * sin(_t * 30.0) * fade
			_look_to = Vector2(sin(_t * 15.0) * 0.5, 0.0)
		Mood.PUSH:
			# Shoves at the shell toward the way out, three times, straining.
			var beat := fmod(_mood_t, PUSH_BEAT) / PUSH_BEAT
			var shove := pow(sin(beat * PI), 2.0) * fade
			bump = hole_dir * PUSH_REACH * (0.6 + 0.4 * hope) * shove
			squash = 1.0 - 0.04 * shove
			open = 1.0 - 0.55 * shove
			mouth = Vector3(1.3, 0.45, 0.5) * maxf(0.4, shove)
			sweat = true
		Mood.SCARED:
			# Wide eyes with tiny pupils, trembling, shrinking back, gasping.
			bump = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.035 * fade
			squash = 1.0 - 0.05 * fade
			pupil = lerpf(1.0, 0.45, fade)
			white = lerpf(1.0, 1.15, fade)
			_look_to = Vector2(sin(_t * 9.0) * 0.6, 0.2)
			mouth = Vector3(0.8, 1.1, 0.5) * fade
			sweat = true
		Mood.BUMP:
			# Backs up and crouches, dashes at the shell, bonks flat against it
			# with its eyes squeezed shut, bounces back, then sees stars.
			var t := _mood_t
			var reach := _room()
			if t < 0.32:
				var k := t / 0.32
				bump = -_bump_dir * reach * 0.18 * sin(k * PI * 0.5)
				squash = 1.0 - 0.08 * k
				open = 1.0 - 0.35 * k
				mouth = Vector3(1.0, 0.35, 0.5)
			elif t < BUMP_HIT:
				var k := (t - 0.32) / (BUMP_HIT - 0.32)
				bump = _bump_dir * reach * lerpf(-0.18, 1.0, k * k)
				squash = 1.0 + 0.1 * k
				open = 0.65
			else:
				if not _bump_hit:
					_bump_hit = true
					bumped.emit(_bump_dir)
				var k := t - BUMP_HIT
				# Out from the shell with a springy, dying bounce.
				bump = _bump_dir * reach * maxf(0.0, cos(k * 9.0)) * exp(-k * 5.0)
				squash = 1.0 - 0.16 * exp(-k * 7.0) * cos(k * 30.0)
				if k < 0.35:
					open = 0.1
					mouth = Vector3(1.2, 0.8, 0.5)
				else:
					# Dizzy: pupils rolling round, a wobbly head.
					_look_to = Vector2(cos(_t * 9.0), sin(_t * 9.0)) * 0.7
					roll = sin(_t * 7.0) * 0.12 * fade
					mouth = Vector3(0.9, 0.5, 0.5) * fade
		Mood.HAPPY:
			# A hop of joy with happy closed eyes and a big open smile.
			bump = Vector3.UP * absf(sin(_mood_t * 9.0)) * 0.15 * fade
			squash = 1.0 + 0.05 * sin(_mood_t * 18.0) * fade
			open = lerpf(1.0, 0.18, fade)
			mouth = Vector3(1.3, 1.0, 0.5) * fade
	# Now and then a blink (not while scared stiff).
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0 and _mood != Mood.SCARED:
		_blink_t = 0.0
		_blink_in = _rng.randf_range(2.0, 4.5)
	if _blink_t >= 0.0:
		_blink_t += delta
		open = minf(open, absf(cos(_blink_t / 0.16 * PI * 0.5)))
		if _blink_t >= 0.32:
			_blink_t = -1.0
	_look = _look.lerp(_look_to, minf(1.0, delta * 10.0))

	_body.position = bump
	_body.scale = Vector3(1.0 / squash, squash, 1.0 / squash) if squash != 1.0 else Vector3.ONE
	if roll != 0.0:
		_face.rotate_object_local(Vector3.BACK, roll)
	for e in _eyes:
		(e["eye"] as Node3D).scale = Vector3(white, white * maxf(0.08, open), white)
		var p := e["pupil"] as Node3D
		p.position = (e["rest"] as Vector3) + Vector3(_look.x * 0.3, _look.y * 0.2, 0.0)
		p.scale = Vector3.ONE * pupil
	_mouth.visible = mouth.length() > 0.05
	_mouth.scale = mouth
	_sweat.visible = sweat
	if sweat:
		_sweat.position = Vector3(1.7, 0.9 - fmod(_t * 0.6, 0.6), 0.25)
