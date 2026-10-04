# Builds the whole scene in code and drives the game loop. Keeping the scene
# graph out of the .tscn means the whole prototype stays readable in one place.
extends Node3D

enum State { PLAYING, WON, LOST }

# Framing distance tracks the shell radius. A fixed close distance blows up
# near-side blocks under perspective until the board is unreadable.
const CAM_DIST_MIN := 17.0
const CAM_DIST_MAX := 28.0
const CAM_LAG := 5.0
const BOARD_ZOOM := 0.93   # camera distance scale: under 1 draws the egg bigger
const NEXT_TRAY_H := 86.0        # the next piece's tray: room for any piece at NEXT_PX
# A bomb is earned by a chain reaction, or by destroying this many pieces at once.
const BOMB_PIECES := 5
const HOLD_PX := 24.0      # cell size of the held-piece preview
const NEXT_PX := 18.0
const PIECE_COLUMN_X := 20.0   # the next piece and the holding tray, down the left
const TRAY_SIZE := 124.0       # the holding tray: room for any piece at HOLD_PX
const CAMERA_MARGIN := 48.0    # the least room left at the top for a phone's camera
const NEXT_MID_Y := 192.0       # below the top margin: the next piece, centred here over the tray
const TRAY_TOP := 256.0         # below the top margin: the holding tray
const BOOSTER_SPACING := 150.0  # the Any Piece and Rocks buttons, either side of the bomb
const ROCKS_PER_SHOT := 2       # rocks fired per use of the Rocks booster
# A drop that makes no combo costs a life. The reference HUD shows three slots.
const LIVES := 3
const HEART_ALIVE := Color(1.0, 0.42, 0.55)
const HEART_LOST := Color(0.88, 0.84, 0.84)
const TITLE_PINK := Color(1.0, 0.55, 0.70)

# Touch gestures -- there are no on-screen buttons:
#   swipe                 turn the ball
#   tap                   aim your piece there
#   double-tap            drop it
#   hold, then drag       slide a piece like yours (if legal)
# A touch that moves before HOLD_TIME is a swipe; one that stays put that long
# is a hold. Distances are in the 720-wide logical pixels of the viewport.
enum Gesture { NONE, PENDING, TURNING, SLIDING, IGNORE }
const HOLD_TIME := 0.35         # seconds held still before a touch grabs a piece
const MOVE_TOL := 16.0          # movement that turns a touch into a swipe
const DOUBLE_TAP_TIME := 0.35   # most time between the two taps of a double-tap
const DOUBLE_TAP_DIST := 48.0   # and how close together they must land
const TURN_RATE := 0.008        # radians of turn per pixel swiped
const TILT_LIMIT := 0.9         # how far up or down the ball can be tilted
const SLIDE_STEP := 56.0        # pixels of drag per cell a held piece slides


var board: TSBoard
var level: Dictionary = TSLevels.rules_for_tier(TSLevels.DEFAULT_DIFFICULTY)   # the level's pieces and shell rules
var difficulty := TSLevels.DEFAULT_DIFFICULTY   # index into TSLevels.DIFFICULTIES
var view: TSBoardView
var state: State = State.PLAYING

var cursor := Vector2i(0, TSBoard.ROWS / 2)
var cur_type := 0
var next_type := 0

var best_clear := 0        # most pieces cleared by a single drop
var best_chain := 0
var bomb_armed := false     # bombs themselves are kept in TSProfile.bomb_count
var lives := LIVES
var lose_reason := ""
var current_level := 1
var is_daily := false       # a Daily Egg: never touches level progress
var is_first_attempt := true # won without a lost ball or a paid rescue: +2 stars
var lose_ad_used := false   # the lose card's ad life, once per ball
var _win_ad_due := false    # this win falls on an interstitial
var _win_stars := 0
var _win_coins := 0
var _win_materials := 0       # building materials the win paid
var _win_chest := ""
var _win_bonus := ""
const FIRST_ATTEMPT_STAR_BONUS := 2
const LIVES_REFILL_COST := 2500
var aim_combo := 0          # pieces the current aim would clear; 0 = no combo
# Per-block depths once the piece has been slid into the shell; empty while it
# is simply aimed at the surface.
var selected := -1          # the piece on the ball picked for sliding (TSBoard.HOLE for none)

var _camera: Camera3D
var _ghost_root: Node3D
var _eyes: Node3D
var _creature: Node3D     # core + eyes: the character you are digging out
var _env: Environment
var _key_light: DirectionalLight3D
var _sky_mat: ShaderMaterial   # the background: a sky for the time of day (TSToon.SKIES)
var _escaping := false    # true while it flies out, before the win banner shows
var _escape_tween: Tween
var _cam_theta := 0.0
var _cam_phi := 0.0
var _cam_dist := 21.0
# Where the camera is heading; swipes move these and the camera eases after.
var _cam_target_theta := 0.0
var _cam_target_phi := 0.0

var _gesture := Gesture.NONE
var _touch_start := Vector2.ZERO
var _touch_ms := 0
var _slide_drag := Vector2.ZERO      # drag not yet turned into a slide step
var _last_tap_ms := -100000
var _last_tap_pos := Vector2.ZERO

var _lbl_level: Label
var _btn_bomb: Button       # the bomb booster, bottom centre
var _bomb_badge: Label      # how many bombs you have, on the button's corner
var _btn_swap: Button       # the Any Piece booster, left of the bomb
var _btn_rocks: Button      # the Rocks booster, right of the bomb
var _booster_badges := {}   # "swap" / "rocks" -> its count badge
var _rocks_flying := false  # rocks in the air: no drops until they land
var _rocks_shot := 0        # counts shots, so rocks from a restarted ball never land
var _hold_box: Control
var _next_box: Control
var _hold_tray: Panel      # the tray the held piece sits in
var _top := 0.0             # the top margin, clear of a phone camera (see the HUD)
var _next_mid_y := 0.0      # NEXT_MID_Y and TRAY_TOP below that margin
var _tray_top := 0.0
var _drawn_hold := -1       # the piece kinds last drawn in the tray and the next slot
var _drawn_next := -1
var _deal_tweens: Array = [] # the deal animation (see _animate_deal)
var _hearts: Array[Polygon2D] = []
var _tie_pill: PanelContainer   # tie-downs left, beside the hearts, on levels with them
var _tie_label: Label
var _ties_seen := -1            # tie-downs standing at the last HUD refresh (-1: a new ball)
var _level_ties := 0            # how many this ball started with
var _hud: Control
const FUSE_SPARKS := [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.2), Color(1.0, 1.0, 0.9)]
const ROCK_DUST := Color(0.82, 0.78, 0.72)
const BOMB_DROP_PX := 96.0
const BOMB_DROP_SECONDS := 0.32
var _fx: TSFxLayer          # the boosters' sparks, puffs, rings and flashes
var _shake := 0.0           # how hard the camera shakes, in world units, fading out
var _sparkle_clock := 0.0   # paces the armed bomb's fuse sparks and the Any Piece's shimmer
var _swap_flyer: Control    # the Any Piece's icon while it flies to the tray
var _pause_btn: Button
var _pause: Dictionary
var _win_card: Dictionary
var _lose_card: Dictionary
var _ad_card: Dictionary
var _ad_reward := ""        # a booster id ("bomb", "swap", "rocks"), "life" or "next_level"
var _ad_watching := false
var _tutorial: TSTutorial


func _ready() -> void:
	TSProfile.ensure_loaded()
	TSSfx.ensure_buses()
	_build_environment()
	_build_hud()
	board = TSBoard.new()
	view = TSBoardView.new()
	add_child(view)
	view.setup(board)
	_ghost_root = Node3D.new()
	add_child(_ghost_root)
	if TSSession.daily_requested:
		TSSession.daily_requested = false
		_start_daily()
	elif TSSession.has_saved_game:
		_resume()
	else:
		_start_level(TSProfile.last_level)


func _build_environment() -> void:
	# Hand-drawn look: a paper background, and one warm light that the cel
	# shader turns into flat tones (see TSToon). No shadows or reflections --
	# a drawing does not have them -- and just a little ambient, so the shadow
	# side keeps its lilac tone instead of washing out.
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = TSToon.PAPER
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.92, 0.95)
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	_key_light = key
	key.light_energy = 0.9
	key.light_color = Color(1.0, 0.97, 0.92)
	key.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(key)

	_camera = Camera3D.new()
	_camera.fov = 48.0
	# Portrait: fix the field of view across the narrow width, so the ball fills
	# the screen side to side whatever the phone's height.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(_camera)
	# The paper: a quad far behind the ball that rides with the camera and is
	# big enough to fill the tallest phone screen.
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(200.0, 400.0)
	paper.mesh = quad
	_sky_mat = TSToon.paper()
	paper.material_override = _sky_mat
	paper.position = Vector3(0.0, 0.0, -90.0)
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_camera.add_child(paper)

	# The prize buried under the shell. Reference frame shows a wide-eyed
	# creature sealed inside, not an inert trophy, so the core gets a face.
	# Core and eyes hang off one node so the creature can escape as a whole.
	_creature = Node3D.new()
	add_child(_creature)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = TSBoardView.CORE_RADIUS * 0.99
	sm.height = TSBoardView.CORE_RADIUS * 1.98
	sm.radial_segments = 48
	sm.rings = 24
	core.mesh = sm
	# The player's avatar critter (Collection), with a faint glow of its own.
	core.material_override = TSToon.material(TSProfile.critter_color(TSProfile.avatar()), 1.0, 0.12)
	_creature.add_child(core)

	# The face rides around the core to stay toward the viewer, so it reads
	# through whichever hole the player has opened rather than only one side.
	# Big shiny eyes and pink cheeks: -z faces the viewer, +z runs into the core.
	_eyes = Node3D.new()
	_creature.add_child(_eyes)
	for side in [-1.0, 1.0]:
		_eyes.add_child(_make_eye_part(Vector3(side * 0.80, 0.35, -0.05), 0.75, Vector3.ONE, Color(1.0, 1.0, 1.0), 0.1, true))
		_eyes.add_child(_make_eye_part(Vector3(side * 0.74, 0.30, -0.55), 0.40, Vector3.ONE, TSToon.INK, 0.0, false))
		# Two sparkles in each eye, the big one catching the light.
		_eyes.add_child(_make_eye_part(Vector3(side * 0.74 - 0.13, 0.47, -0.92), 0.13, Vector3.ONE, Color.WHITE, 1.0, false))
		_eyes.add_child(_make_eye_part(Vector3(side * 0.74 + 0.12, 0.17, -0.92), 0.06, Vector3.ONE, Color.WHITE, 1.0, false))
		# Blush, pressed flat against the curve of the core.
		_eyes.add_child(_make_eye_part(Vector3(side * 1.45, -0.50, 0.35), 0.36, Vector3(1.0, 0.55, 0.35), Color(1.0, 0.58, 0.68), 0.25, false))


func _make_eye_part(offset: Vector3, radius: float, squash: Vector3, tint: Color, glow: float, inked: bool) -> MeshInstance3D:
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


# Portrait phone layout, in 720-wide logical pixels. The top block hangs from
# the top edge and the readouts from the bottom edge, so a taller phone just
# gives the ball more room in between. Nothing on screen takes touches (except
# the end-of-game banner), so every touch reaches _unhandled_input as a gesture.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Every label is handwritten, in ink on the paper (see TSToon).
	var theme := Theme.new()
	theme.default_font = TSToon.hand_font()
	root.theme = theme
	layer.add_child(root)
	_hud = root

	# --- top ---
	# Everything up here sits below _top: the phone's safe area, and never
	# less than CAMERA_MARGIN, so a notch or punch-hole camera never covers
	# it. The level in the top-left corner, the hearts in the middle, and the
	# pause button (with the settings) top right.
	_top = maxf(TSUI.safe_top(), CAMERA_MARGIN)
	_next_mid_y = _top + NEXT_MID_Y
	_tray_top = _top + TRAY_TOP
	_lbl_level = _make_label(root, Vector2(24.0, _top - 6.0), 42)
	_lbl_level.add_theme_color_override("font_color", TITLE_PINK)
	_lbl_level.add_theme_color_override("font_outline_color", TSToon.INK)
	_lbl_level.add_theme_constant_override("outline_size", 12)
	# Three hearts 46 px apart, centred on the screen's middle.
	var hearts_at := _pin(root, Control.PRESET_CENTER_TOP, Vector2(-70.0, _top + 30.0))
	for i in LIVES:
		# Each heart is drawn twice: a larger one in ink behind, as its outline.
		var ink := Polygon2D.new()
		ink.polygon = _heart_shape(1.3)
		ink.color = TSToon.INK
		ink.position = Vector2(24.0 + i * 46.0, 0.0)
		hearts_at.add_child(ink)
		var heart := Polygon2D.new()
		heart.polygon = _heart_shape(1.05)
		heart.position = Vector2(24.0 + i * 46.0, -0.5)
		hearts_at.add_child(heart)
		_hearts.append(heart)
	# Tie-downs left, a pill to the right of the hearts, on levels that have them.
	var ties_at := _pin(root, Control.PRESET_CENTER_TOP, Vector2(92.0, _top + 8.0))
	_tie_pill = PanelContainer.new()
	_tie_pill.add_theme_stylebox_override("panel", TSUI.sb(TSUI.CARD, 20, 3, 2, 6))
	_tie_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tie_pill.visible = false
	var tie_row := TSUI.hbox(6)
	tie_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tie_pill.add_child(tie_row)
	tie_row.add_child(TSIcon.make("tie", 36))
	_tie_label = TSUI.label("", 28, TSUI.INK)
	tie_row.add_child(_tie_label)
	ties_at.add_child(_tie_pill)
	var pause_at := _pin(root, Control.PRESET_TOP_RIGHT, Vector2(-96.0, _top - 4.0))
	_pause_btn = TSUI.icon_button("pause", 76, TSUI.CARD)
	_pause_btn.pressed.connect(_open_pause)
	pause_at.add_child(_pause_btn)

	# Held and next pieces drawn flat, as in the footage, stacked down the left:
	# the next piece on top, and the piece you hold below it, sitting in its
	# tray. Pieces never rotate, so what you see is exactly what drops.
	# The next piece waits on a slimmer tray of its own above, so the two read
	# as a pair: what you hold, and what comes after.
	var next_tray := Panel.new()
	next_tray.position = Vector2(PIECE_COLUMN_X + 14.0, _next_mid_y - NEXT_TRAY_H * 0.5)
	next_tray.size = Vector2(TRAY_SIZE - 28.0, NEXT_TRAY_H)
	var next_style := _tray_style()
	next_style.bg_color = next_style.bg_color.lightened(0.35)
	next_tray.add_theme_stylebox_override("panel", next_style)
	next_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(next_tray)
	_next_box = Control.new()
	_next_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_next_box)
	_hold_tray = Panel.new()
	_hold_tray.position = Vector2(PIECE_COLUMN_X, _tray_top)
	_hold_tray.size = Vector2(TRAY_SIZE, TRAY_SIZE)
	_hold_tray.add_theme_stylebox_override("panel", _tray_style())
	_hold_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hold_tray)
	_hold_box = Control.new()
	_hold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_tray.add_child(_hold_box)

	var boosters_at := _pin(root, Control.PRESET_CENTER_BOTTOM, Vector2(0.0, 0.0))
	_build_bomb_button(boosters_at)
	_btn_swap = _build_booster_button(boosters_at, "swap", -BOOSTER_SPACING, _use_any_piece)
	_btn_rocks = _build_booster_button(boosters_at, "rocks", BOOSTER_SPACING, _fire_rocks)
	# The boosters' animations play on their own layer, over the HUD and
	# under the cards.
	_fx = TSFxLayer.new()
	root.add_child(_fx)
	_build_dialogs(root)
	_tutorial = TSTutorial.new()
	root.add_child(_tutorial)
	TSUI.juice(root)


func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TSToon.INK)
	l.add_theme_color_override("font_outline_color", TSToon.PAPER)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


# A zero-size anchor point pinned to a screen edge or corner, so children can
# be laid out in pixels relative to it.
func _pin(parent: Control, preset: Control.LayoutPreset, offset: Vector2) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x
	c.offset_bottom = offset.y
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


# The bomb booster: a round button with a bomb drawn on it and a count badge.
# Tapping it arms a bomb, so the next double-tap blasts instead of dropping;
# tapping again stows it. It is the one control on screen, and touches that
# land on it are kept out of the gestures (see _touch_input).
func _build_bomb_button(anchor: Control) -> void:
	const SIZE := 124.0
	_btn_bomb = Button.new()
	_btn_bomb.position = Vector2(-SIZE * 0.5, -258.0)
	_btn_bomb.size = Vector2(SIZE, SIZE)
	_btn_bomb.pivot_offset = Vector2(SIZE, SIZE) * 0.5
	# No keyboard focus: a focused button would swallow Space on desktop.
	_btn_bomb.focus_mode = Control.FOCUS_NONE
	_btn_bomb.pressed.connect(func() -> void:
		if state == State.PLAYING:
			_toggle_bomb())
	anchor.add_child(_btn_bomb)

	var icon := Control.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: _draw_bomb(icon, Vector2(SIZE, SIZE) * 0.5 + Vector2(-4.0, 6.0)))
	_btn_bomb.add_child(icon)

	_bomb_badge = Label.new()
	_bomb_badge.position = Vector2(SIZE - 42.0, SIZE - 42.0)   # clear of the fuse
	_bomb_badge.size = Vector2(46.0, 46.0)
	_bomb_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bomb_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bomb_badge.add_theme_font_size_override("font_size", 26)
	_bomb_badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := _panel_style(HEART_ALIVE)
	badge_bg.set_corner_radius_all(23)
	badge_bg.border_color = TSToon.INK
	_bomb_badge.add_theme_stylebox_override("normal", badge_bg)
	_bomb_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_bomb.add_child(_bomb_badge)


# The Any Piece and Rocks boosters: round buttons like the bomb's, either side of
# it, each with its drawn icon and a count badge. Unlike the bomb they act at
# once when tapped -- nothing to arm.
func _build_booster_button(anchor: Control, id: String, x: float, action: Callable) -> Button:
	const SIZE := 124.0
	var btn := Button.new()
	btn.position = Vector2(x - SIZE * 0.5, -258.0)
	btn.size = Vector2(SIZE, SIZE)
	btn.pivot_offset = Vector2(SIZE, SIZE) * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		if state == State.PLAYING:
			action.call())
	anchor.add_child(btn)

	var icon := TSIcon.make(id, 92.0)
	icon.position = Vector2(16.0, 12.0)
	icon.size = Vector2(92.0, 92.0)
	btn.add_child(icon)

	var badge := Label.new()
	badge.position = Vector2(SIZE - 42.0, SIZE - 42.0)
	badge.size = Vector2(46.0, 46.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := _panel_style(HEART_ALIVE)
	badge_bg.set_corner_radius_all(23)
	badge_bg.border_color = TSToon.INK
	badge.add_theme_stylebox_override("normal", badge_bg)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	_booster_badges[id] = badge
	return btn


# A cartoon bomb with a happy face: round body in ink outline with a shine,
# a cap, a curled fuse and a spark.
static func _draw_bomb(ci: Control, c: Vector2) -> void:
	var body := 33.0
	var ink := TSToon.INK
	ci.draw_circle(c, body + 4.0, ink, true, -1.0, true)
	ci.draw_circle(c, body, Color(0.36, 0.33, 0.52), true, -1.0, true)
	ci.draw_circle(c + Vector2(-12.0, -13.0), 7.0, Color(1.0, 1.0, 1.0, 0.8), true, -1.0, true)
	ci.draw_circle(c + Vector2(-19.0, -4.0), 3.0, Color(1.0, 1.0, 1.0, 0.6), true, -1.0, true)
	# Face: two dot eyes with a glint, pink cheeks and a small smile.
	for side in [-1.0, 1.0]:
		var eye: Vector2 = c + Vector2(side * 10.0, 2.0)
		ci.draw_circle(eye, 4.5, ink, true, -1.0, true)
		ci.draw_circle(eye + Vector2(-1.5, -1.5), 1.5, Color.WHITE, true, -1.0, true)
		ci.draw_circle(c + Vector2(side * 19.0, 10.0), 5.0, Color(1.0, 0.55, 0.68, 0.85), true, -1.0, true)
	ci.draw_arc(c + Vector2(0.0, 7.0), 5.0, 0.2, PI - 0.2, 12, ink, 2.5, true)
	# Cap, tilted up and to the right where the fuse comes out.
	var cap := c + Vector2(21.0, -24.0)
	var along := Vector2(1.0, -1.0).normalized()
	var across := Vector2(along.y, -along.x)
	var cap_pts := PackedVector2Array([
		cap - across * 9.0 - along * 5.0, cap + across * 9.0 - along * 5.0,
		cap + across * 9.0 + along * 7.0, cap - across * 9.0 + along * 7.0,
	])
	ci.draw_colored_polygon(cap_pts, Color(0.78, 0.76, 0.86))
	cap_pts.append(cap_pts[0])
	ci.draw_polyline(cap_pts, ink, 3.0, true)
	# Fuse.
	var tip := cap + along * 7.0
	var fuse := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		fuse.append(tip + Vector2(t * 16.0, -t * 14.0 + sin(t * PI) * -6.0))
	ci.draw_polyline(fuse, ink, 4.0, true)
	# Spark: an eight-point star, orange round a yellow heart.
	var spark := fuse[fuse.size() - 1]
	for layer in [[13.0, 6.0, ink], [11.0, 5.0, Color(1.0, 0.55, 0.25)], [6.0, 3.0, Color(1.0, 0.92, 0.45)]]:
		var pts := PackedVector2Array()
		for i in 16:
			var rad: float = layer[0] if i % 2 == 0 else layer[1]
			var a := TAU * float(i) / 16.0
			pts.append(spark + Vector2(cos(a), sin(a)) * rad)
		ci.draw_colored_polygon(pts, layer[2])


static func _panel_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(18)
	s.set_border_width_all(2)
	s.border_color = TSToon.INK
	return s


## Starts (or restarts) a level from the player's progression: its own ball
## and difficulty (TSLevels), and the bombs it brings.
func _start_level(level_number: int) -> void:
	TSProfile.coin_notices.clear()
	is_daily = false
	current_level = level_number
	TSProfile.last_level = maxi(TSProfile.last_level, level_number)
	TSProfile.note_level_started(level_number)
	difficulty = TSLevels.difficulty_for_level(level_number)
	_start(TSLevels.seed_for_level(level_number), TSLevels.baked_board(level_number))
	if TSSession.retried_level == level_number:
		is_first_attempt = false
		TSSession.retried_level = -1
	_maybe_start_tutorials()


## The Daily Egg: today's level, which never touches level progress.
func _start_daily() -> void:
	TSProfile.coin_notices.clear()
	is_daily = true
	current_level = TSLevels.daily_level()
	difficulty = TSLevels.difficulty_for_level(current_level)
	TSProfile.record_daily_play()
	_start(hash("daily_" + Time.get_date_string_from_system()))


## A fresh ball: the baked one when the level has one (levels 1-50), else
## generated from the seed.
func _start(seed_value: int, baked: Dictionary = {}) -> void:
	level = TSLevels.rules_for_level(current_level)
	if baked.is_empty():
		board.generate(seed_value, level)
	else:
		board.load_dict(baked)
	_lbl_level.text = "DAILY EGG" if is_daily else "LEVEL %d" % current_level
	_ties_seen = -1
	_apply_sky()
	state = State.PLAYING
	if _escape_tween != null:
		_escape_tween.kill()
	_escaping = false
	_creature.position = Vector3.ZERO
	_creature.scale = Vector3.ONE * _creature_scale()
	cursor = Vector2i(0, TSBoard.ROWS / 2)
	best_clear = 0
	best_chain = 0
	bomb_armed = false
	_rocks_flying = false
	_rocks_shot += 1
	_stop_deal_animation()
	lives = LIVES
	lose_reason = ""
	is_first_attempt = true
	lose_ad_used = false
	selected = TSBoard.HOLE
	cur_type = _fair(_deal())
	next_type = _deal()
	_clamp_cursor()
	_gesture = Gesture.NONE
	_face(_piece_centre())
	_close_cards()
	view.rebuild()
	_refresh_piece()
	_refresh_hud()
	TSProfile.record_quest_event("match")


## Puts a ball parked by _park() back exactly as it was.
func _resume() -> void:
	var s: Dictionary = TSSession.state
	TSSession.clear()
	board = s["board"]
	view.board = board
	is_daily = bool(s["daily"])
	current_level = int(s["level"])
	difficulty = int(s["difficulty"])
	level = TSLevels.rules_for_level(current_level)
	cur_type = int(s["cur_type"])
	next_type = int(s["next_type"])
	cursor = s["cursor"]
	lives = int(s["lives"])
	is_first_attempt = bool(s["first_attempt"])
	lose_ad_used = bool(s["lose_ad_used"])
	state = State.PLAYING
	_escaping = false
	_creature.scale = Vector3.ONE * _creature_scale()
	selected = TSBoard.HOLE
	bomb_armed = false
	_rocks_flying = false
	_rocks_shot += 1
	_stop_deal_animation()
	_lbl_level.text = "DAILY EGG" if is_daily else "LEVEL %d" % current_level
	_ties_seen = -1
	_apply_sky()
	_face(_piece_centre())
	view.rebuild()
	_refresh_piece()
	_refresh_hud()


## Leaving mid-ball: park it so Home's PLAY (now CONTINUE) picks it back up.
func _park() -> void:
	if state != State.PLAYING:
		return
	TSSession.has_saved_game = true
	TSSession.state = {
		"board": board, "daily": is_daily, "level": current_level, "difficulty": difficulty,
		"cur_type": cur_type, "next_type": next_type, "cursor": cursor, "lives": lives,
		"first_attempt": is_first_attempt, "lose_ad_used": lose_ad_used,
	}


func current_offsets() -> Array:
	return TSBoard.SHAPES[cur_type]["offsets"]


func _clamp_cursor() -> void:
	var min_dy := 0
	var max_dy := 0
	for o in current_offsets():
		var v: Vector2i = o
		min_dy = mini(min_dy, v.y)
		max_dy = maxi(max_dy, v.y)
	cursor.y = clampi(cursor.y, -min_dy, TSBoard.ROWS - 1 - max_dy)
	cursor.x = board.wrap_col(cursor.x)


func _move(dc: int, dr: int) -> void:
	cursor.x = board.wrap_col(cursor.x + dc)
	cursor.y += dr
	_clamp_cursor()
	# The keyboard aims by cells rather than by what is on screen, so turn the
	# ball to keep the aim in view.
	_face(_piece_centre())
	_refresh_piece()


# The layer your piece lands in if dropped here.
func _current_depth() -> int:
	return board.landing_depth(current_offsets(), cursor)


# Picks the outermost piece at a cell of the ball as the one to slide. Only a
# piece of the same type as the one you are about to drop can be picked.
func _select_at(cell: Vector2i) -> void:
	var id := board.top_piece(cell.x, cell.y)
	selected = id if board.can_slide(id, cur_type) else TSBoard.HOLE


func _has_selection() -> bool:
	return board.can_slide(selected, cur_type)


# Push the picked piece one cell across the ball. Blockers in the way are
# smashed; any other Tetris piece stops it. A slide only moves pieces --
# anything left unsupported falls, but nothing is matched; matches come from
# drops. Sliding is not a drop, so it never costs a life.
func _slide(dir: Vector2i) -> void:
	if not _has_selection():
		return
	var res := board.slide(selected, dir)
	if not bool(res["moved"]):
		return
	if int(res["smashed"]) > 0:
		view.spawn_clear_fx(res["fx"])
	view.rebuild()
	if _tutorial.on_step("slide"):
		_tutorial.gate_passed()
	if board.has_escape(_escape_size()):
		_win()
	_refresh_piece()
	_refresh_hud()


## Arms or stows a bomb. With none left, the empty button offers an ad (one
## bomb) or a coin buy, the way Duckdoku's empty boosters do.
func _toggle_bomb() -> void:
	if TSProfile.bomb_count <= 0:
		bomb_armed = false
		_open_ad("bomb")
	else:
		bomb_armed = not bomb_armed
		_kick_button(_btn_bomb)
		if bomb_armed:
			# Armed: the fuse catches with a puff of sparks and the bomb shivers.
			var r := _btn_bomb.get_global_rect()
			_fx.burst(r.position + Vector2(r.size.x * 0.78, r.size.y * 0.16), FUSE_SPARKS, 12, 300.0, 0.45, 5.0, 400.0)
			var shiver := _btn_bomb.create_tween()
			for k in 4:
				shiver.tween_property(_btn_bomb, "rotation", 0.14 * (1.0 if k % 2 == 0 else -1.0), 0.05)
			shiver.tween_property(_btn_bomb, "rotation", 0.0, 0.06)
		if bomb_armed and _tutorial.on_step("arm_bomb"):
			_tutorial.gate_passed()
	_refresh_piece()
	_refresh_hud()


## The Any Piece (saved under the booster's old id, "swap"): turns the piece
## you hold into a one-cell wild block (TSBoard.WILD) that becomes whichever
## piece makes the biggest match where it lands -- so any pair on the ball is
## a match waiting for it. It is aimed at the best spot to start. With nothing
## to match anywhere, or already in hand, nothing is spent. Empty, it offers
## an ad or a coin buy, like the bomb.
func _use_any_piece() -> void:
	if _rocks_flying:
		return
	if TSProfile.swap_count <= 0:
		_refresh_hud()
		_open_ad("swap")
		return
	if cur_type == TSBoard.WILD:
		return
	var pick := board.best_piece([TSBoard.WILD])
	if int(pick["kind"]) == TSBoard.HOLE:
		return
	TSProfile.add_boosters("swap", -1)
	TSProfile.record_quest_event("booster")
	TSProfile.save()
	cur_type = TSBoard.WILD
	cursor = pick["at"]
	selected = TSBoard.HOLE
	_gesture = Gesture.NONE
	_clamp_cursor()
	_face(_piece_centre())
	_animate_swap_in()
	TSSfx.play("upgrade")
	TSHaptics.light()
	_refresh_piece()
	_refresh_hud()


## Rocks: fires ROCKS_PER_SHOT rocks from the button at the biggest
## near-matches showing (TSBoard.rock_targets), and each finishes its match
## when it lands. Like the bomb, it never costs a life.
func _fire_rocks() -> void:
	if _rocks_flying:
		return
	if TSProfile.rock_count <= 0:
		_refresh_hud()
		_open_ad("rocks")
		return
	var targets := board.rock_targets(ROCKS_PER_SHOT, cursor)
	if targets.is_empty():
		return
	TSProfile.add_boosters("rocks", -1)
	TSProfile.record_quest_event("booster")
	TSProfile.save()
	# The launcher kicks back with a puff of dust as the rocks leave it.
	_kick_button(_btn_rocks)
	var muzzle := _btn_rocks.get_global_rect().get_center()
	for k in 5:
		_fx.puff(muzzle + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 10.0)), ROCK_DUST, 16.0, 0.5, Vector2(randf_range(-50.0, 50.0), -60.0))
	_throw_rocks(muzzle, targets)
	TSSfx.play("upgrade")
	_refresh_hud()


## Rocks in flight from `from` (a screen point) -- one to each group of
## `targets`, a block of it showing on top -- and when the last lands, the
## strike (_rocks_land). Drops wait while they fly.
func _throw_rocks(from: Vector2, targets: Array) -> void:
	_rocks_flying = true
	_rocks_shot += 1
	var shot := _rocks_shot
	var flights: Array = []
	for group in targets:
		var aim := from
		for id in group:
			var cols: Array = board.plate_cols[id]
			var v: Vector2i = cols[cols.size() / 2]
			if board.top_piece(v.x, v.y) == int(id):
				aim = _camera.unproject_position(TSBoardView.cell_transform(v.x, v.y, float(board.cells[v.x][v.y].size())).origin)
				break
		flights.append(aim)
	var landed := [0]
	for i in flights.size():
		var rock := TSIcon.make("rocks", 64.0)
		rock.size = Vector2(64.0, 64.0)
		rock.pivot_offset = Vector2(32.0, 32.0)
		rock.position = from - Vector2(32.0, 32.0)
		_hud.add_child(rock)
		var tw := rock.create_tween()
		tw.tween_interval(0.08 * i)
		tw.set_parallel(true)
		tw.tween_property(rock, "position", (flights[i] as Vector2) - Vector2(32.0, 32.0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(rock, "rotation", TAU * 1.5, 0.38)
		tw.tween_property(rock, "scale", Vector2.ONE * 0.7, 0.38)
		# A trail of dust behind it as it flies.
		var trail := func(_t: float) -> void:
			if randf() < 0.4:
				_fx.puff(rock.position + rock.size * 0.5, ROCK_DUST, 9.0, 0.4)
		tw.tween_method(trail, 0.0, 1.0, 0.38)
		tw.set_parallel(false)
		var hit: Vector2 = flights[i]
		tw.tween_callback(func() -> void:
			# It lands: a dusty impact, chips flying, and a small jolt.
			for k in 5:
				_fx.puff(hit + Vector2(randf_range(-24.0, 24.0), randf_range(-16.0, 16.0)), ROCK_DUST, 18.0, 0.55, Vector2(randf_range(-70.0, 70.0), -40.0))
			_fx.burst(hit, [Color(0.6, 0.58, 0.64), Color(0.74, 0.7, 0.78)], 10, 420.0, 0.5, 5.0, 900.0)
			_shake_screen(0.16)
			rock.queue_free()
			landed[0] += 1
			if landed[0] == flights.size():
				if shot == _rocks_shot:
					_rocks_land(targets))


func _rocks_land(targets: Array) -> void:
	_rocks_flying = false
	if state != State.PLAYING or not is_inside_tree():
		return
	var res := board.rock_strike(targets)
	TSSfx.play("chain" if int(res["chain"]) >= 2 else "match")
	TSHaptics.heavy()
	if int(res["pieces"]) > 0:
		TSProfile.record_quest_event("clear", int(res["pieces"]))
	var chain := int(res["chain"])
	best_clear = maxi(best_clear, int(res["pieces"]))
	best_chain = maxi(best_chain, chain)
	view.spawn_clear_fx(res["fx"])
	if chain >= 2:
		view.spawn_popup("CHAIN x%d" % chain, res["fx"])
	TSProfile.save()
	# The ball changed under the held piece: the fair deal still holds.
	cur_type = _fair(cur_type)
	if not _has_selection():
		selected = TSBoard.HOLE
	_clamp_cursor()
	if board.has_escape(_escape_size()):
		_win()
	elif bool(res["overload"]):
		lose_reason = "SHELL OVERLOADED"
		_lose()
	view.rebuild()
	_refresh_piece()
	_refresh_hud()
	_crack_geodes(res)


## Geodes that cracked open in `res` (TSBoard.geodes) each fire a rock from
## where they stood at the biggest near-matches showing, which land like the
## Rocks booster's -- and can crack more geodes in turn.
func _crack_geodes(res: Dictionary) -> void:
	var shots: Array = res.get("geode_shots", [])
	if shots.is_empty() or state != State.PLAYING:
		return
	var targets := board.geode_targets(shots)
	if targets.is_empty():
		return
	var at: Vector2i = shots[0]
	var from := _camera.unproject_position(TSBoardView.cell_transform(at.x, at.y, float(board.height(at.x, at.y))).origin)
	TSSfx.play("bomb", 1.6)
	TSHaptics.medium()
	_throw_rocks(from, targets)


func _drop() -> void:
	if state != State.PLAYING or _rocks_flying:
		return
	var offsets := current_offsets()
	var landing := cursor
	var bomb_was_armed := bomb_armed and TSProfile.bomb_count > 0
	var landing_at := _screen_of_cell(landing)   # before the drop changes the surface there

	var res: Dictionary
	if bomb_was_armed:
		# The bomb is spent now, but goes off only once it has fallen onto the
		# egg (_drop_bomb), and the drop finishes then.
		TSProfile.bomb_count -= 1
		bomb_armed = false
		TSProfile.record_quest_event("booster")
		_drop_bomb(landing, landing_at)
		_refresh_hud()
		return
	else:
		var wild := cur_type == TSBoard.WILD
		res = board.place_and_resolve(offsets, landing, cur_type, _current_depth())
		if wild:
			# The Any Piece lands: a burst of every colour where it becomes one.
			_fx.burst(landing_at, TSFxLayer.RAINBOW, 24, 620.0, 0.7, 9.0, 0.0, true)
			_fx.ring(landing_at, Color.WHITE, 16.0, 150.0, 0.35)
		if int(res["chain"]) == 0:
			lives -= 1
			TSSfx.play("miss")
			TSHaptics.medium()
			if lives <= 0:
				lose_reason = "OUT OF LIVES"
		else:
			# The clear speaks for itself: blocks fly off the ball, and a
			# chain is called out as it floats up.
			TSSfx.play("chain" if int(res["chain"]) >= 2 else "match")
			TSHaptics.light()
	_finish_drop(res, false)


## A bomb falls from the top of the screen onto `cell` (`at` on screen),
## spinning and trailing fuse sparks, and blows up as it lands. While it falls
## it counts as a rock in flight: drops and boosters wait, and a restart or a
## resumed ball cancels it.
func _drop_bomb(cell: Vector2i, at: Vector2) -> void:
	_rocks_flying = true
	_rocks_shot += 1
	var shot := _rocks_shot
	var bomb := TSIcon.make("bomb", BOMB_DROP_PX)
	bomb.size = Vector2.ONE * BOMB_DROP_PX
	bomb.pivot_offset = bomb.size * 0.5
	bomb.position = Vector2(at.x, -BOMB_DROP_PX) - bomb.size * 0.5
	_hud.add_child(bomb)
	_hud.move_child(bomb, _fx.get_index())
	var trail := func(_t: float) -> void:
		_fx.burst(bomb.position + bomb.size * Vector2(0.78, 0.16), FUSE_SPARKS, 1, 120.0, 0.3, 4.0, 200.0)
	var fall := bomb.create_tween()
	fall.set_parallel(true)
	fall.tween_property(bomb, "position", at - bomb.size * 0.5, BOMB_DROP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(bomb, "rotation", 0.6, BOMB_DROP_SECONDS)
	fall.tween_method(trail, 0.0, 1.0, BOMB_DROP_SECONDS)
	fall.set_parallel(false)
	# A squash as it hits, then it goes off.
	fall.tween_property(bomb, "scale", Vector2(1.3, 0.7), 0.05)
	fall.tween_callback(func() -> void:
		bomb.queue_free()
		if shot == _rocks_shot:
			_bomb_lands(cell, at))


func _bomb_lands(cell: Vector2i, at: Vector2) -> void:
	_rocks_flying = false
	if state != State.PLAYING or not is_inside_tree():
		return
	var res := board.detonate(cell, 2)
	_bomb_blast(at)
	TSSfx.play("bomb")
	TSHaptics.heavy()
	if _tutorial.on_step("blast"):
		_tutorial.gate_passed()
	_finish_drop(res, true)


## Everything after a drop's (or a bomb's) clear: the quests, the chain
## call-out, a bomb earned, the next piece dealt, and a win or a loss.
func _finish_drop(res: Dictionary, bomb_was_armed: bool) -> void:
	if int(res["pieces"]) > 0:
		TSProfile.record_quest_event("clear", int(res["pieces"]))

	# A chain reaction gets its call-out.
	var pieces := int(res["pieces"])
	var chain := int(res["chain"])
	best_clear = maxi(best_clear, pieces)
	best_chain = maxi(best_chain, chain)
	view.spawn_clear_fx(res["fx"])
	if chain >= 2:
		view.spawn_popup("CHAIN x%d" % chain, res["fx"])
	# Bombs are earned only once they have arrived (and been taught), at
	# TSProfile.BOMB_UNLOCK_LEVEL.
	if not bomb_was_armed and TSProfile.bombs_unlocked and (chain >= 2 or pieces >= BOMB_PIECES):
		TSProfile.bomb_count += 1
		_pulse_bomb_button()
	TSProfile.save()

	cur_type = _fair(next_type)
	next_type = _deal()
	_animate_deal()
	if not _has_selection():
		selected = TSBoard.HOLE   # the drop may have destroyed the picked piece
	_clamp_cursor()

	if board.has_escape(_escape_size()):
		_win()
	elif lose_reason != "":
		_lose()
	elif bool(res["overload"]):
		lose_reason = "SHELL OVERLOADED"
		_lose()

	view.rebuild()
	_refresh_piece()
	_refresh_hud()
	_crack_geodes(res)


func _refresh_piece() -> void:
	for child in _ghost_root.get_children():
		child.queue_free()
	if state != State.PLAYING:
		return

	if _gesture == Gesture.SLIDING and _has_selection():
		_show_slide_target()
	else:
		_show_aim()
	_draw_piece_boxes()


# The held piece in the middle of its tray, and the next piece centred over
# the tray. A piece is redrawn only when it changes, and left where it is
# while a deal animation is moving it.
func _draw_piece_boxes() -> void:
	if _drawn_hold != cur_type:
		_drawn_hold = cur_type
		_hold_box.size = _draw_piece(_hold_box, cur_type, current_offsets(), HOLD_PX)
		_hold_box.pivot_offset = _hold_box.size * 0.5
	if _drawn_next != next_type:
		_drawn_next = next_type
		_next_box.size = _draw_piece(_next_box, next_type, TSBoard.SHAPES[next_type]["offsets"], NEXT_PX)
		_next_box.pivot_offset = _next_box.size * 0.5
	if _dealing():
		return
	_hold_box.position = _hold_rest()
	_hold_box.scale = Vector2.ONE
	_next_box.position = _next_rest()
	_next_box.modulate.a = 1.0


func _hold_rest() -> Vector2:
	return (Vector2(TRAY_SIZE, TRAY_SIZE) - _hold_box.size) * 0.5


func _next_rest() -> Vector2:
	return Vector2(PIECE_COLUMN_X + (TRAY_SIZE - _next_box.size.x) * 0.5, _next_mid_y - _next_box.size.y * 0.5)


func _dealing() -> bool:
	for tw in _deal_tweens:
		if (tw as Tween).is_valid() and (tw as Tween).is_running():
			return true
	return false


func _stop_deal_animation() -> void:
	for tw in _deal_tweens:
		if (tw as Tween).is_valid():
			(tw as Tween).kill()
	_deal_tweens.clear()
	_hold_tray.position.y = _tray_top
	# An Any Piece cut off mid-flight: the tray it was flying to shows again.
	_hold_box.modulate.a = 1.0
	if is_instance_valid(_swap_flyer):
		_swap_flyer.queue_free()


# After a drop: the next piece falls from its slot into the tray, growing to
# full size on the way, lands with a squash, hops once and settles, and the
# tray dips under it. Then the new next piece drops into the empty slot from
# above with a small bounce.
func _animate_deal() -> void:
	_stop_deal_animation()
	_draw_piece_boxes()
	var slot_centre := Vector2(PIECE_COLUMN_X + TRAY_SIZE * 0.5, _next_mid_y) - _hold_tray.position
	var rest := _hold_rest()
	_hold_box.scale = Vector2.ONE * (NEXT_PX / HOLD_PX)
	_hold_box.position = slot_centre - _hold_box.size * 0.5

	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(_hold_box, "position", rest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_hold_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.set_parallel(false)
	fall.tween_property(_hold_box, "scale", Vector2(1.18, 0.8), 0.06)
	fall.set_parallel(true)
	fall.tween_property(_hold_box, "scale", Vector2(0.92, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_property(_hold_box, "position", rest - Vector2(0.0, 12.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.set_parallel(false)
	fall.set_parallel(true)
	fall.tween_property(_hold_box, "position", rest, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_hold_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deal_tweens.append(fall)

	var dip := create_tween()
	dip.tween_interval(0.2)
	dip.tween_property(_hold_tray, "position:y", _tray_top + 5.0, 0.06).set_ease(Tween.EASE_OUT)
	dip.tween_property(_hold_tray, "position:y", _tray_top, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deal_tweens.append(dip)

	var coming := _next_rest()
	_next_box.position = coming - Vector2(0.0, 56.0)
	_next_box.modulate.a = 0.0
	var drop_in := create_tween()
	drop_in.tween_interval(0.14)
	drop_in.set_parallel(true)
	drop_in.tween_property(_next_box, "position", coming, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop_in.tween_property(_next_box, "modulate:a", 1.0, 0.14)
	_deal_tweens.append(drop_in)


# The Any Piece: its icon leaves the button and swoops up and over to the
# hold tray, spinning and trailing colourful sparkles, then lands in the tray
# with a pop, a burst and a ring.
func _animate_swap_in() -> void:
	_stop_deal_animation()
	_draw_piece_boxes()
	_kick_button(_btn_swap)
	var from := _btn_swap.get_global_rect().get_center()
	var to := _hold_box.get_global_rect().get_center()
	var peak := (from + to) * 0.5 + Vector2(140.0, -180.0)   # an arc up and over the egg's edge
	_swap_flyer = TSIcon.make("swap", 92.0)
	_swap_flyer.size = Vector2(92.0, 92.0)
	_swap_flyer.pivot_offset = Vector2(46.0, 46.0)
	_swap_flyer.position = from - _swap_flyer.size * 0.5
	_hud.add_child(_swap_flyer)
	_hud.move_child(_swap_flyer, _fx.get_index())   # just under the sparkles it trails
	_hold_box.modulate.a = 0.0
	var flyer := _swap_flyer
	var step := func(t: float) -> void:
		var p: Vector2 = from.lerp(peak, t).lerp(peak.lerp(to, t), t)
		flyer.position = p - flyer.size * 0.5
		flyer.rotation = t * TAU
		flyer.scale = Vector2.ONE * lerpf(1.0, 0.75, t)
		if randf() < 0.6:
			_fx.sparkle(p, TSFxLayer.RAINBOW[randi() % TSFxLayer.RAINBOW.size()], 10.0, 0.45)
	var fly := create_tween()
	fly.tween_method(step, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_callback(func() -> void:
		flyer.queue_free()
		_hold_box.modulate.a = 1.0
		_hold_box.scale = Vector2.ONE * 0.5
		_fx.burst(to, TSFxLayer.RAINBOW, 18, 420.0, 0.6, 9.0, 0.0, true)
		_fx.ring(to, Color.WHITE, 20.0, 110.0, 0.35))
	fly.tween_property(_hold_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deal_tweens.append(fly)


# Your piece, aimed as a translucent footprint lying on the shell exactly where
# it will drop in -- the reference footage shows an outline on the surface,
# not a piece hanging in the air. Bright when the drop will match, dim when it
# will not: a miss costs a life, so the player should never have to guess.
func _show_aim() -> void:
	var cols := board.footprint_cells(current_offsets(), cursor)
	var depths: Array = []
	for _c in cols:
		depths.append(float(_current_depth()))
	aim_combo = board.combo_preview(current_offsets(), cursor, cur_type, _current_depth())
	# The Any Piece's footprint wears the colour it will turn into there.
	var shown := board.wild_kind(current_offsets(), cursor, _current_depth()) if cur_type == TSBoard.WILD else cur_type
	if aim_combo > 0:
		_ghost_root.add_child(view.make_plate(shown, cols, depths, 0.75, 0.45))
	else:
		_ghost_root.add_child(view.make_plate(shown, cols, depths, 0.32, 0.0))


# While a piece is held your own piece is put away, and the held piece glows
# instead.
func _show_slide_target() -> void:
	var cols: Array = board.plate_cols[selected]
	var depths: Array = []
	for _c in cols:
		depths.append(float(board.depth_of(selected)))
	_ghost_root.add_child(view.make_plate(int(board.plate_kind[selected]), cols, depths, 0.8, 0.6))


# The holding tray: a sunken paper dish with a soft ink rim, so the piece in
# it reads as held rather than just drawn.
func _tray_style() -> StyleBoxFlat:
	var s := TSUI.sb(Color(0.96, 0.89, 0.80), 24, TSUI.BORDER, 0, 0)
	s.border_width_top = TSUI.BORDER + 5   # the inner lip at the top: sunken
	s.shadow_color = Color(TSToon.INK, 0.18)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0.0, 3.0)
	return s


# The piece drawn flat, the way it looks on the ball: one rounded shape in
# its colour with an ink outline. Each block is a panel that is rounded and
# inked only on the sides where the piece ends, so the blocks join up.
# Returns the drawn piece's size, for centring it.
func _draw_piece(box: Control, kind: int, offsets: Array, px: float) -> Vector2:
	for child in box.get_children():
		child.queue_free()
	# The Any Piece is one cell; drawn at one cell it would be a speck, so the
	# tray shows its booster art, big enough to read as the wild block.
	if kind == TSBoard.WILD:
		var art := TSIcon.make("swap", px * 3.0)
		art.size = Vector2.ONE * px * 3.0
		box.add_child(art)
		return art.size
	var min_x := 99
	var max_x := -99
	var min_y := 99
	var max_y := -99
	for o in offsets:
		var v: Vector2i = o
		min_x = mini(min_x, v.x)
		max_x = maxi(max_x, v.x)
		min_y = mini(min_y, v.y)
		max_y = maxi(max_y, v.y)
	var ink := maxi(2, int(round(px * 0.1)))
	var round_px := int(round(px * 0.35))
	for o in offsets:
		var v: Vector2i = o
		# Board +y is up the ball; screen y runs down.
		var left := offsets.has(v + Vector2i(-1, 0))
		var right := offsets.has(v + Vector2i(1, 0))
		var up := offsets.has(v + Vector2i(0, 1))
		var down := offsets.has(v + Vector2i(0, -1))
		var style := StyleBoxFlat.new()
		style.bg_color = TSBoardView.TYPE_COLORS[kind]
		style.border_color = TSToon.INK
		style.border_width_left = 0 if left else ink
		style.border_width_right = 0 if right else ink
		style.border_width_top = 0 if up else ink
		style.border_width_bottom = 0 if down else ink
		style.corner_radius_top_left = 0 if left or up else round_px
		style.corner_radius_top_right = 0 if right or up else round_px
		style.corner_radius_bottom_left = 0 if left or down else round_px
		style.corner_radius_bottom_right = 0 if right or down else round_px
		style.anti_aliasing = true
		var block := Panel.new()
		block.add_theme_stylebox_override("panel", style)
		block.position = Vector2(float(v.x - min_x) * px, float(max_y - v.y) * px)
		block.size = Vector2(px, px)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(block)
		# A little shine near the top-left of the piece, like the ones on the ball.
		if not left and not up:
			var shine := Panel.new()
			var s_style := StyleBoxFlat.new()
			s_style.bg_color = Color(1.0, 1.0, 1.0, 0.7)
			s_style.set_corner_radius_all(int(px * 0.15))
			shine.add_theme_stylebox_override("panel", s_style)
			shine.position = Vector2(px * 0.22, px * 0.22)
			shine.size = Vector2(px * 0.3, px * 0.18)
			shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(shine)
	return Vector2(max_x - min_x + 1, max_y - min_y + 1) * px


func _refresh_hud() -> void:
	_note_ties()
	_refresh_bomb_button()
	for i in _hearts.size():
		_hearts[i].color = HEART_ALIVE if i < lives else HEART_LOST


# The booster buttons. The bomb is paper when idle, butter yellow while armed;
# every booster is faded and "+" with none left (a tap then offers more), and
# hidden until its unlock level (TSProfile).
func _refresh_bomb_button() -> void:
	var bg := TSBoardView.TYPE_COLORS[TSBoard.I_FLAT] if bomb_armed else TSToon.PAPER
	var normal := _panel_style(bg)
	normal.set_corner_radius_all(62)
	normal.set_border_width_all(4)
	normal.border_color = TSToon.INK
	for style in ["normal", "hover", "pressed", "disabled"]:
		_btn_bomb.add_theme_stylebox_override(style, normal)
	var have := TSProfile.bomb_count
	_btn_bomb.self_modulate.a = 1.0 if have > 0 else 0.55
	_bomb_badge.text = str(have) if have > 0 else "+"
	_btn_bomb.visible = state == State.PLAYING and TSProfile.bombs_unlocked
	for pair in [[_btn_swap, "swap"], [_btn_rocks, "rocks"]]:
		var btn: Button = pair[0]
		var id: String = pair[1]
		var style := _panel_style(TSToon.PAPER)
		style.set_corner_radius_all(62)
		style.set_border_width_all(4)
		for s in ["normal", "hover", "pressed", "disabled"]:
			btn.add_theme_stylebox_override(s, style)
		var count := TSProfile.booster_count(id)
		btn.self_modulate.a = 1.0 if count > 0 else 0.55
		(_booster_badges[id] as Label).text = str(count) if count > 0 else "+"
		btn.visible = state == State.PLAYING and TSProfile.booster_unlocked(id)


# -- booster animations -------------------------------------------------------------

## A booster button used: squashed flat for a beat, then a springy bounce back.
func _kick_button(btn: Control) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.18, 0.82), 0.07)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _shake_screen(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _screen_of_cell(cell: Vector2i) -> Vector2:
	return _camera.unproject_position(TSBoardView.cell_transform(cell.x, cell.y, float(board.height(cell.x, cell.y))).origin)


## Every frame: the camera shake dying away, and -- a few times a second --
## the armed bomb's fuse spitting sparks and the Any Piece shimmering in its tray.
func _animate_boosters(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.6)
		_camera.h_offset = randf_range(-1.0, 1.0) * _shake
		_camera.v_offset = randf_range(-1.0, 1.0) * _shake
	_sparkle_clock += delta
	if _sparkle_clock < 0.12:
		return
	_sparkle_clock = 0.0
	if bomb_armed and _btn_bomb.is_visible_in_tree():
		var r := _btn_bomb.get_global_rect()
		_fx.burst(r.position + Vector2(r.size.x * 0.78, r.size.y * 0.16), FUSE_SPARKS, 2, 140.0, 0.35, 4.0, 300.0)
	if cur_type == TSBoard.WILD and _hold_box.is_visible_in_tree():
		var h := _hold_box.get_global_rect()
		_fx.sparkle(h.position + Vector2(randf() * h.size.x, randf() * h.size.y), TSFxLayer.RAINBOW[randi() % TSFxLayer.RAINBOW.size()], 9.0, 0.5)


## The bomb goes off at `at` (a screen point): a white flash, two shockwaves,
## a spray of sparks falling away, a few puffs of smoke, and a hard shake.
func _bomb_blast(at: Vector2) -> void:
	_fx.flash(Color(1.0, 1.0, 0.92, 0.6), 0.3)
	_fx.ring(at, Color(1.0, 0.72, 0.3), 24.0, 320.0, 0.45)
	_fx.ring(at, Color.WHITE, 12.0, 200.0, 0.3)
	_fx.burst(at, FUSE_SPARKS + [Color(1.0, 0.35, 0.25)], 36, 900.0, 0.7, 7.0, 900.0)
	for i in 6:
		_fx.puff(at + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)), Color(0.55, 0.5, 0.6), 30.0, 0.9, Vector2(randf_range(-60.0, 60.0), -80.0))
	_shake_screen(0.45)


# A bomb was earned: the button pops so the player notices.
func _pulse_bomb_button() -> void:
	var tw := _btn_bomb.create_tween()
	tw.tween_property(_btn_bomb, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_btn_bomb, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# The classic parametric heart, centred on the origin, `s` pixels per unit.
static func _heart_shape(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * float(i) / 32.0
		var x := 16.0 * sin(t) * sin(t) * sin(t)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, -y) * s)
	return pts


func _process(delta: float) -> void:
	_animate_boosters(delta)
	# A touch held still long enough becomes a hold.
	if _gesture == Gesture.PENDING and Time.get_ticks_msec() - _touch_ms >= int(HOLD_TIME * 1000.0):
		_begin_hold()

	# The camera eases toward where swipes (or a keyboard move, or the win) have
	# pointed it -- quickly while a finger is turning the ball, so it tracks
	# the finger, and gently otherwise.
	var rate := 20.0 if _gesture == Gesture.TURNING else CAM_LAG
	var t := minf(1.0, delta * rate)
	_cam_theta += wrapf(_cam_target_theta - _cam_theta, -PI, PI) * t
	_cam_phi = lerpf(_cam_phi, _cam_target_phi, t)

	var dir := Vector3(
		cos(_cam_phi) * sin(_cam_theta), sin(_cam_phi), cos(_cam_phi) * cos(_cam_theta)
	)
	var want_dist := clampf((10.0 + view.max_radius * 1.6) * BOARD_ZOOM, CAM_DIST_MIN * BOARD_ZOOM, CAM_DIST_MAX)
	_cam_dist = lerpf(_cam_dist, want_dist, minf(1.0, delta * 2.0))
	_camera.position = dir * _cam_dist
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	_eyes.position = dir * (TSBoardView.CORE_RADIUS * 0.99)
	_eyes.look_at(_camera.position, Vector3.UP)


# Turn the ball so a point on it (in columns and rows) faces the camera.
func _face(at: Vector2) -> void:
	_cam_target_theta = TAU * (at.x + 0.5) / float(TSBoard.COLS)
	_cam_target_phi = lerpf(
		-TSBoardView.LAT_SPAN, TSBoardView.LAT_SPAN, (at.y + 0.5) / float(TSBoard.ROWS)
	) * 0.55


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
		return

	# Keyboard, for playing on desktop. The mouse works too: a click is a tap,
	# since the project turns mouse input into touches.
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return

	if key.keycode == KEY_ESCAPE or key.keycode == KEY_P:
		if not key.echo:
			if _pause["root"].visible:
				TSUI.conceal(_pause["root"])
			elif state == State.PLAYING:
				_open_pause()
		return
	# Debug builds only: F2 wins the ball, F3 loses it, to try the cards.
	if OS.is_debug_build() and not key.echo and state == State.PLAYING:
		if key.keycode == KEY_F2:
			_debug_win()
			return
		if key.keycode == KEY_F3:
			lives = 0
			lose_reason = "OUT OF LIVES"
			_lose()
			_refresh_hud()
			return
	if key.keycode == KEY_R:
		_restart()
		return
	if state != State.PLAYING or _gesture == Gesture.SLIDING or _any_card_open():
		return

	match key.keycode:
		KEY_A, KEY_LEFT:
			_move(-1, 0)
		KEY_D, KEY_RIGHT:
			_move(1, 0)
		KEY_W, KEY_UP:
			_move(0, 1)
		KEY_S, KEY_DOWN:
			_move(0, -1)
		KEY_SPACE:
			if not key.echo:
				_drop()
		KEY_F:
			if not key.echo:
				_toggle_bomb()
		KEY_G:
			if not key.echo:
				_use_any_piece()
		KEY_T:
			if not key.echo:
				_fire_rocks()


# The whole touch control scheme. One finger at a time: a touch starts out
# PENDING, and becomes a swipe (TURNING) if it moves, a hold if it stays put
# for HOLD_TIME, or a tap if it lifts before either.
func _touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			if state != State.PLAYING or _any_card_open() or (_tutorial.visible and not _lesson_wants_board()):
				return
			# The on-screen buttons handle their own touches; they are not gestures.
			if _on_booster_button(touch.position) \
					or _pause_btn.get_global_rect().has_point(touch.position):
				return
			_gesture = Gesture.PENDING
			_touch_start = touch.position
			_touch_ms = Time.get_ticks_msec()
			return
		# Lifted.
		var was := _gesture
		_gesture = Gesture.NONE
		match was:
			Gesture.PENDING:
				_tap(touch.position)
			Gesture.SLIDING:
				selected = TSBoard.HOLE
				_refresh_piece()
				_refresh_hud()
		return

	var drag := event as InputEventScreenDrag
	if drag.index != 0:
		return
	match _gesture:
		Gesture.PENDING, Gesture.IGNORE:
			# A hold that grabbed nothing can still turn into a swipe.
			if drag.position.distance_to(_touch_start) > MOVE_TOL:
				_gesture = Gesture.TURNING
				_turn(drag.position - _touch_start)
		Gesture.TURNING:
			_turn(drag.relative)
		Gesture.SLIDING:
			_slide_drag += drag.relative
			if _slide_drag.length() >= SLIDE_STEP:
				_slide(_slide_dir(_slide_drag))
				_slide_drag = Vector2.ZERO


# Swiping drags the ball's surface along under the finger: swipe right and
# the ball turns right, swipe down and it tips toward you.
func _turn(pixels: Vector2) -> void:
	_cam_target_theta = wrapf(_cam_target_theta - pixels.x * TURN_RATE, -PI, PI)
	_cam_target_phi = clampf(_cam_target_phi + pixels.y * TURN_RATE, -TILT_LIMIT, TILT_LIMIT)


# One tap aims; a second tap soon after, near the first, drops.
func _tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms <= int(DOUBLE_TAP_TIME * 1000.0) and pos.distance_to(_last_tap_pos) <= DOUBLE_TAP_DIST:
		_last_tap_ms = -100000   # a third tap starts over rather than dropping again
		_drop()
		return
	_last_tap_ms = now
	_last_tap_pos = pos
	_tap_aim(pos)


# A touch held still: grab the piece under the finger to slide it, if it is
# one you are allowed to slide. Anything else just explains why not.
func _begin_hold() -> void:
	var cell := _cell_at(_touch_start)
	if cell.x < 0:
		_gesture = Gesture.IGNORE
		return
	_select_at(cell)
	_gesture = Gesture.SLIDING if _has_selection() else Gesture.IGNORE
	_slide_drag = Vector2.ZERO
	_last_tap_ms = -100000
	_refresh_piece()
	_refresh_hud()


# Which way across the ball a drag means. The ball is round and can be seen
# from any angle, so "up the screen" is not always "up the ball": project the
# held piece's neighbouring cells onto the screen and take the direction
# that best matches the drag.
func _slide_dir(drag: Vector2) -> Vector2i:
	var cell: Vector2i = board.plate_cols[selected][0]
	var depth := float(board.depth_of(selected))
	var from := _camera.unproject_position(TSBoardView.cell_transform(cell.x, cell.y, depth).origin)
	var best := Vector2i(1, 0)
	var best_dot := -INF
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var d: Vector2i = dir
		var to := _camera.unproject_position(
			TSBoardView.cell_transform(board.wrap_col(cell.x + d.x), cell.y + d.y, depth).origin
		)
		var dot := (to - from).normalized().dot(drag.normalized())
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


# A tap on the ball aims your piece so it covers that spot.
func _tap_aim(screen_pos: Vector2) -> void:
	var cell := _cell_at(screen_pos)
	if cell.x < 0:
		return
	var centre := _piece_centre() - Vector2(cursor)
	cursor = Vector2i(cell.x - int(round(centre.x)), cell.y - int(round(centre.y)))
	_clamp_cursor()
	_refresh_piece()


# The ball cell under a screen point: cast the touch into the scene and find
# where it meets the ball's outer surface. (-1, -1) for taps off the ball, or on
# the capped poles where there are no cells.
func _cell_at(screen_pos: Vector2) -> Vector2i:
	var o := _camera.project_ray_origin(screen_pos)
	var d := _camera.project_ray_normal(screen_pos)
	var r := view.max_radius
	# The egg has no neat ray formula, so: skip to a sphere that surely holds
	# it, step along the ray until it first dips inside the outer shell
	# (measured back on the sphere the grid is laid out on), then pin the
	# crossing down by bisection.
	var bound := r * (maxf(TSBoardView.EGG_TALL, 1.0 + TSBoardView.EGG_TAPER) + 0.05)
	var b := o.dot(d)
	var disc := b * b - (o.dot(o) - bound * bound)
	if disc < 0.0:
		return Vector2i(-1, -1)
	var t := maxf(0.0, -b - sqrt(disc))
	var t_end := -b + sqrt(disc)
	var outside := t
	var inside := -1.0
	while t <= t_end:
		if TSBoardView.egg_inverse(o + d * t).length() <= r:
			inside = t
			break
		outside = t
		t += 0.05
	if inside < 0.0:
		return Vector2i(-1, -1)
	for _i in 16:
		var mid := (outside + inside) * 0.5
		if TSBoardView.egg_inverse(o + d * mid).length() <= r:
			inside = mid
		else:
			outside = mid
	var p := TSBoardView.egg_inverse(o + d * inside).normalized()
	var theta := atan2(p.x, p.z)
	var phi := asin(clampf(p.y, -1.0, 1.0))
	var col := posmod(int(floor(theta / TAU * TSBoard.COLS)), TSBoard.COLS)
	var row := int(floor((phi + TSBoardView.LAT_SPAN) / (2.0 * TSBoardView.LAT_SPAN) * TSBoard.ROWS))
	if row < 0 or row >= TSBoard.ROWS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


# The middle of your own piece (not the cursor cell, or a four-wide piece would
# sit off to one side of where you pointed).
func _piece_centre() -> Vector2:
	var offsets := current_offsets()
	var sum := Vector2.ZERO
	for o in offsets:
		var v: Vector2i = o
		sum += Vector2(float(v.x), float(v.y))
	return Vector2(float(cursor.x), float(cursor.y)) + sum / float(offsets.size())


# Only the level's own pieces are ever dealt; blockers are shell-only. How
# often you get the piece most common on the board is set by the difficulty.
func _deal() -> int:
	return board.deal_piece(level["pieces"], float(TSLevels.DIFFICULTIES[difficulty]["common_bias"]))


# The fair deal: if the piece coming up has nowhere on the ball to make a
# combo but another of the level's pieces does, hand over that one instead.
# Otherwise a miss -- and a lost life -- would be forced, however well you play.
func _fair(kind: int) -> int:
	# A paid-for Any Piece is never dealt away.
	if kind == TSBoard.WILD or not level.get("fair_deal", false) or board.has_combo_spot(kind):
		return kind
	for other in level["pieces"]:
		var alt := int(other)
		if alt != kind and board.has_combo_spot(alt):
			return alt
	return kind


# Size of the square hole, in cells, the creature needs to get out -- set by
# the difficulty, which is the creature's size.
func _escape_size() -> int:
	return int(level.get("escape_size", TSLevels.DIFFICULTIES[difficulty]["escape_size"]))


func _creature_scale() -> float:
	return float(TSLevels.DIFFICULTIES[difficulty]["scale"])


# The win: a hole big enough is open, so the creature shrinks to fit and flies
# out through it. The camera turns to face the hole, and the win card waits
# until the creature is clear. The rewards are paid at once, before the
# celebration, so leaving mid-animation cannot lose them (as in Duckdoku).
func _win() -> void:
	state = State.WON
	_escaping = true
	_pay_win()
	# A slide can open the hole; let go of the held piece.
	_gesture = Gesture.NONE
	selected = TSBoard.HOLE
	var k := _escape_size()
	var at: Vector2i = board.best_escape_patch(k)["at"]
	var mid := Vector2i(board.wrap_col(at.x + k / 2), at.y + k / 2)
	_face(Vector2(float(at.x) + float(k - 1) * 0.5, float(at.y) + float(k - 1) * 0.5))
	var out := TSBoardView.cell_transform(mid.x, mid.y, 0.0).origin.normalized()

	_escape_tween = _creature.create_tween()
	_escape_tween.tween_interval(0.5)
	_escape_tween.tween_property(_creature, "scale", Vector3.ONE * 0.25, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_escape_tween.tween_property(_creature, "position", out * 16.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_escape_tween.tween_callback(func() -> void:
		_escaping = false
		_refresh_hud()
		_show_win_card())
	TSSfx.play("win")


## Stars (hearts left, +2 for a first attempt), coins for them, chest progress,
## quests, the Eggsperience and level progress -- all banked at the moment of the win.
func _pay_win() -> void:
	TSProfile.settle_boards()
	var before := TSProfile.coin_count
	var bonus := FIRST_ATTEMPT_STAR_BONUS if is_first_attempt else 0
	_win_stars = TSProfile.add_stars(lives, bonus, difficulty)
	_win_coins = TSProfile.coin_count - before
	_win_materials = TSProfile.MATERIALS_PER_DAILY if is_daily else TSProfile.MATERIALS_PER_WIN
	TSProfile.add_materials(_win_materials)
	_win_chest = "" if is_daily else TSChests.record_win()
	_win_ad_due = false if is_daily else _roll_interstitial()
	if is_daily:
		TSProfile.mark_daily_completed()
		TSProfile.record_quest_event("daily_puzzle")
	else:
		TSProfile.record_quest_event("win")
		TSHunt.note_level_reached(current_level + 1)
		TSProfile.last_level = maxi(TSProfile.last_level, current_level + 1)
		if lives >= LIVES:
			TSProfile.record_quest_event("flawless")
	var lines := PackedStringArray()
	for n in TSProfile.coin_notices:
		lines.append("%s  +%s coins" % [n["label"], TSProfile.fmt_coins(int(n["coins"]))])
	_win_bonus = "\n".join(lines)
	TSProfile.save()


## An ad every Nth win from a level on, and after every win later; payers see
## fewer, and the No Ads pass none (Duckdoku's rhythm, via TSTunables).
func _roll_interstitial() -> bool:
	if TSProfile.no_ads:
		return false
	var every_win_from: int = TSTunables.get_int("interstitial_every_win_from_level")
	if TSProfile.is_payer:
		if current_level < every_win_from:
			return false
	elif current_level >= every_win_from:
		return true
	elif current_level < TSTunables.get_int("interstitial_from_level"):
		return false
	TSProfile.interstitial_win_count += 1
	TSProfile.save()
	return TSProfile.interstitial_win_count % maxi(TSTunables.get_int("interstitial_every_n_wins"), 1) == 0


func _debug_win() -> void:
	for id in board.plate_kind.keys():
		board._remove_plate(id)
	view.rebuild()
	_win()
	_refresh_piece()
	_refresh_hud()


func _restart() -> void:
	if is_daily:
		_start_daily()
	else:
		_start_level(current_level)


func _lose() -> void:
	state = State.LOST
	TSSfx.play("lose")
	TSHaptics.heavy()
	_refresh_lose_card()
	TSUI.reveal(_lose_card["root"], _lose_card["panel"])


# -- cards: pause, win, lose, ads --------------------------------------------------

func _build_dialogs(root: Control) -> void:
	_pause = TSUI.dialog(root, 560)
	var pbox: VBoxContainer = _pause["box"]
	pbox.add_child(TSUI.title("Paused", 48))
	var resume := TSUI.button("Resume", TSUI.GREEN, 30)
	resume.pressed.connect(func(): TSUI.conceal(_pause["root"]))
	pbox.add_child(resume)
	var restart := TSUI.button("Restart Level", TSUI.BUTTER, 26, Vector2(0, 64))
	restart.pressed.connect(func():
		TSUI.conceal(_pause["root"])
		is_first_attempt = false
		_restart())
	pbox.add_child(restart)
	var help := TSUI.card(Color(1.0, 0.95, 0.86), 20, 14, 0)
	help.visible = false
	help.add_child(TSUI.wrap(TSUI.label(TSUI.HOW_TO_PLAY, 20), 480))
	# Help sits a step down from Resume and Restart: two quiet buttons side by
	# side, the rules opening under them.
	var help_row := TSUI.hbox(12)
	var help_btn := TSUI.expand(TSUI.button("How to Play", TSUI.CARD, 24, Vector2(0, 60), 4)) as Button
	help_btn.pressed.connect(func(): help.visible = not help.visible)
	help_row.add_child(help_btn)
	var replay := TSUI.expand(TSUI.button("Walkthrough", TSUI.CARD, 24, Vector2(0, 60), 4)) as Button
	replay.pressed.connect(func():
		TSUI.conceal(_pause["root"])
		_start_tutorial())
	help_row.add_child(replay)
	pbox.add_child(help_row)
	pbox.add_child(help)
	for row in [["music", "Music", "music_enabled"], ["sound", "Sound Effects", "sfx_enabled"], ["vibrate", "Haptics", "haptics_enabled"]]:
		pbox.add_child(_toggle_row(row[0], row[1], row[2]))
	var home := TSUI.button("Home", TSUI.PINK, 28)
	home.pressed.connect(_go_home)
	pbox.add_child(home)

	_win_card = TSUI.dialog(root, 600)
	_lose_card = TSUI.dialog(root, 580)
	_ad_card = TSUI.dialog(root, 560)


func _toggle_row(icon: String, text: String, prop: String) -> Control:
	var row := TSUI.hbox(12)
	row.add_child(TSIcon.make(icon, 44))
	row.add_child(TSUI.expand(TSUI.label(text, 24)))
	var on := TSProfile.get_toggle(prop)
	var b := TSUI.button("On" if on else "Off", TSUI.MINT if on else TSUI.GREY, 22, Vector2(110, 56), 4)
	b.pressed.connect(func():
		var now := not TSProfile.get_toggle(prop)
		TSProfile.set_toggle(prop, now)
		TSSfx.apply_settings()
		b.text = "On" if now else "Off"
		TSUI.restyle(b, TSUI.MINT if now else TSUI.GREY, 4)
		if prop == "haptics_enabled" and now:
			TSHaptics.light())
	row.add_child(b)
	return row


func _open_pause() -> void:
	if state != State.PLAYING or _any_card_open():
		return
	bomb_armed = false
	TSUI.reveal(_pause["root"], _pause["panel"])


func _any_card_open() -> bool:
	for d in [_pause, _win_card, _lose_card, _ad_card]:
		if not d.is_empty() and d["root"].visible:
			return true
	return false


func _close_cards() -> void:
	for d in [_pause, _win_card, _lose_card, _ad_card]:
		if not d.is_empty():
			d["root"].visible = false


## Home from the pause menu: the ball is parked for CONTINUE.
func _go_home() -> void:
	_park()
	SceneFlow.go(SceneFlow.HOME)


func _show_win_card() -> void:
	if not is_inside_tree() or state != State.WON:
		return
	var box: VBoxContainer = _win_card["box"]
	for c in box.get_children():
		c.queue_free()
	var top := TSUI.hbox(8)
	box.add_child(top)
	top.add_child(TSUI.spacer(60))
	top.add_child(TSUI.expand(TSUI.title("Rescued!", 56)))
	var close := TSUI.close_button()
	close.pressed.connect(_on_win_close)
	top.add_child(close)
	var critter := TSIcon.make("critter", 190, TSProfile.avatar())
	critter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(critter)
	box.add_child(TSUI.label("Your %s escaped the egg!" % TSProfile.critter_name(TSProfile.avatar()), 24, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var rewards := TSUI.card(Color(1.0, 0.95, 0.84), 24, 16, 2)
	var row := TSUI.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_child(row)
	var coin_amount := TSUI.label("0", 34)
	row.add_child(_reward_stack("coin", coin_amount))
	row.add_child(_reward_stack("materials", TSUI.label("+%d" % _win_materials, 34)))
	if TSProfile.stars_open():
		var star_amount := TSUI.label("+%d" % _win_stars, 34)
		row.add_child(_reward_stack("star", star_amount))
	if not is_daily and TSNav.features_unlocked():
		var chest := TSIcon.make("chest", 64, 0, _win_chest if _win_chest != "" else "common")
		var chest_text := TSUI.label("+1" if _win_chest != "" else "%d/%d" % [TSChests.WINS_PER_CHEST - TSChests.wins_to_next(), TSChests.WINS_PER_CHEST], 30)
		if _win_chest == "":
			chest.modulate.a = 0.45
		var v := TSUI.vbox(2)
		chest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(chest)
		chest_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(chest_text)
		row.add_child(v)
	box.add_child(rewards)
	if is_first_attempt and TSProfile.stars_open():
		box.add_child(TSUI.label("First try! +%d bonus stars" % FIRST_ATTEMPT_STAR_BONUS, 22, TSFX.COL_GAIN, HORIZONTAL_ALIGNMENT_CENTER))
	if _win_bonus != "":
		box.add_child(TSUI.label(_win_bonus, 22, TSFX.COL_GAIN, HORIZONTAL_ALIGNMENT_CENTER))
	var next := TSUI.button("Back to Home" if is_daily else "Next Level", TSUI.GREEN, 34, Vector2(0, 90))
	next.pressed.connect(_on_next_pressed)
	box.add_child(next)
	TSUI.juice(box)
	TSUI.reveal(_win_card["root"], _win_card["panel"])
	TSFX.confetti(_hud)
	# the coins count up once the card has settled
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(coin_amount):
			TSSfx.play("coin")
			TSFX.sparkle_burst(_hud, coin_amount)
			coin_amount.create_tween().tween_method(func(v: float): coin_amount.text = "+%s" % TSProfile.fmt_coins(int(v)), 0.0, float(_win_coins), 0.6))


func _reward_stack(icon: String, amount: Label) -> Control:
	var v := TSUI.vbox(2)
	var ic := TSIcon.make(icon, 64)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(amount)
	return v


func _on_win_close() -> void:
	if not is_daily and _win_ad_due and not TSProfile.no_ads:
		TSProfile.interstitial_owed = true
		TSProfile.save()
	SceneFlow.go(SceneFlow.HOME)


## Next Level -- through an interstitial when one is due, and past the first
## visits to features that have just unlocked (Duckdoku's detours).
func _on_next_pressed() -> void:
	if is_daily:
		SceneFlow.go(SceneFlow.HOME)
		return
	var next := current_level + 1
	if _win_ad_due and not TSProfile.no_ads:
		_open_ad("next_level")
		_on_ad_watch()
	elif next == TSNav.COLLECTION_UNLOCK_LEVEL and not TSProfile.collection_tutorial_seen:
		SceneFlow.go("res://scenes/collection.tscn")
	elif (next == TSNav.FEATURES_UNLOCK_LEVEL and not TSProfile.home_tutorial_seen) \
			or (next == TSNav.DAILY_UNLOCK_LEVEL and not TSProfile.daily_callout_seen):
		SceneFlow.go(SceneFlow.HOME)
	else:
		_start_level(next)


func _refresh_lose_card() -> void:
	var box: VBoxContainer = _lose_card["box"]
	for c in box.get_children():
		c.queue_free()
	var overload := lose_reason == "SHELL OVERLOADED"
	box.add_child(TSUI.title("Egg overloaded!" if overload else "Out of hearts!", 48))
	var ic := TSIcon.make("heart_empty", 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	if overload:
		box.add_child(TSUI.wrap(TSUI.label("A stack grew too tall. Try the level again!", 24, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
		var again := TSUI.button("Try Again", TSUI.GREEN, 30, Vector2(0, 84))
		again.pressed.connect(func():
			TSSession.retried_level = current_level
			_restart())
		box.add_child(again)
	else:
		box.add_child(TSUI.wrap(TSUI.label("Keep going with the same egg?", 24, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)))
		var refill := TSUI.button("+%d hearts   %s coins" % [LIVES, TSProfile.fmt_coins(LIVES_REFILL_COST)], TSUI.GREEN, 28, Vector2(0, 84))
		refill.disabled = TSProfile.coin_count < LIVES_REFILL_COST
		refill.pressed.connect(func():
			if TSProfile.coin_count < LIVES_REFILL_COST:
				return
			TSProfile.coin_count -= LIVES_REFILL_COST
			TSProfile.save()
			_revive(LIVES))
		box.add_child(refill)
		if not lose_ad_used and not TSProfile.is_payer and not TSProfile.no_ads:
			var ad := TSUI.button("Watch an ad: +1 heart", TSUI.SKY, 26, Vector2(0, 72))
			ad.pressed.connect(func(): _open_ad("life"))
			box.add_child(ad)
	var quit := TSUI.button("Quit", TSUI.GREY, 26, Vector2(0, 68))
	quit.pressed.connect(func():
		if not is_daily:
			TSSession.retried_level = current_level
		TSSession.clear()
		SceneFlow.go(SceneFlow.HOME))
	box.add_child(quit)
	TSUI.juice(box)


## Back into the same egg with `count` hearts. Either rescue ends the first-try bonus.
func _revive(count: int) -> void:
	lives = count
	lose_reason = ""
	state = State.PLAYING
	is_first_attempt = false
	TSUI.conceal(_lose_card["root"])
	_refresh_piece()
	_refresh_hud()


## The ad prompt: a booster id -- "bomb", "swap" or "rocks" (out of it: watch
## for one, or buy some) -- "life" (the lose card's extra heart) or
## "next_level" (an interstitial between levels).
func _open_ad(reward: String) -> void:
	_ad_reward = reward
	_ad_watching = false
	var booster := TSProfile.BOOSTERS.has(reward)
	var box: VBoxContainer = _ad_card["box"]
	for c in box.get_children():
		c.queue_free()
	var titles := {"life": "One More Heart", "next_level": "Next Level"}
	var title: String = ("Out of " + str(TSProfile.BOOSTER_NAMES[reward][2]).capitalize()) if booster else titles[reward]
	box.add_child(TSUI.title(title, 44))
	var ic := TSIcon.make(reward if booster else ("heart" if reward == "life" else "ad"), 130)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var status := TSUI.wrap(TSUI.label("", 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(status)
	_ad_card["status"] = status
	var progress := TSUI.bar(TSUI.SKY, 26)
	progress.visible = false
	box.add_child(progress)
	_ad_card["progress"] = progress
	var buttons := TSUI.vbox(10)
	box.add_child(buttons)
	_ad_card["buttons"] = buttons
	var can_watch := not TSProfile.no_ads and (not booster or not TSProfile.is_payer)
	if TSProfile.no_ads and not booster:
		# the No Ads pass grants the reward outright
		_on_ad_finished()
		return
	if booster:
		var n := TSProfile.booster_buy_count(reward)
		var cost := TSProfile.booster_buy_cost(reward)
		var one: String = TSProfile.BOOSTER_NAMES[reward][1]
		var many: String = TSProfile.BOOSTER_NAMES[reward][2]
		status.text = ("Watch a short ad for 1 %s, or buy %d." % [one, n]) if can_watch else ("Buy %d more %s to keep going." % [n, many])
		var buy := TSUI.button("Buy x%d  ·  %s coins" % [n, TSProfile.fmt_coins(cost)], TSUI.GREEN, 26, Vector2(0, 72))
		buy.disabled = TSProfile.coin_count < cost
		buy.pressed.connect(_on_ad_buy)
		buttons.add_child(buy)
	elif reward == "life":
		status.text = "Watch a short ad to get 1 heart back and keep going."
	else:
		status.text = "Watch a short ad to continue to Level %d." % (current_level + 1)
	if can_watch:
		var watch := TSUI.button("Watch Ad", TSUI.SKY, 28, Vector2(0, 72))
		watch.pressed.connect(_on_ad_watch)
		buttons.add_child(watch)
		var noads := TSUI.button("Remove Ads  ·  %s" % "$4.99", TSUI.LILAC, 22, Vector2(0, 60))
		noads.pressed.connect(_on_no_ads)
		buttons.add_child(noads)
	var cancel := TSUI.button("Not now", TSUI.GREY, 24, Vector2(0, 60))
	cancel.pressed.connect(_close_ad)
	buttons.add_child(cancel)
	_ad_card["cancel"] = cancel
	TSUI.juice(box)
	TSUI.reveal(_ad_card["root"], _ad_card["panel"])


func _on_ad_watch() -> void:
	if _ad_watching or Ads.is_busy():
		return
	_ad_watching = true
	(_ad_card["buttons"] as Control).visible = false
	var progress: ProgressBar = _ad_card["progress"]
	progress.visible = Ads.simulated
	progress.value = 0.0
	(_ad_card["status"] as Label).text = "Ad playing..." if Ads.simulated else "Loading ad..."
	if Ads.simulated:
		create_tween().tween_property(progress, "value", 100.0, Ads.SIMULATED_SECONDS)
	if _ad_reward == "next_level":
		Ads.interstitial_closed.connect(func(): _on_ad_result(true), CONNECT_ONE_SHOT)
		Ads.show_interstitial()
	else:
		Ads.rewarded_result.connect(_on_ad_result, CONNECT_ONE_SHOT)
		Ads.show_rewarded()


func _on_ad_result(earned: bool) -> void:
	if not is_inside_tree():
		return
	_ad_watching = false
	if earned:
		_on_ad_finished()
		return
	(_ad_card["progress"] as Control).visible = false
	(_ad_card["buttons"] as Control).visible = true
	(_ad_card["status"] as Label).text = "The ad didn't finish -- no reward this time."


func _on_ad_finished() -> void:
	match _ad_reward:
		"next_level":
			_ad_card["root"].visible = false
			_start_level(current_level + 1)
		"life":
			_ad_card["root"].visible = false
			lose_ad_used = true
			_revive(1)
		_:
			TSProfile.add_boosters(_ad_reward, 1)
			TSProfile.save()
			(_ad_card["progress"] as Control).visible = false
			(_ad_card["status"] as Label).text = "You earned 1 %s!" % TSProfile.BOOSTER_NAMES[_ad_reward][1]
			var buttons: VBoxContainer = _ad_card["buttons"]
			for c in buttons.get_children():
				c.visible = c == _ad_card["cancel"]
			(_ad_card["cancel"] as Button).text = "Done"
			buttons.visible = true
			_refresh_hud()


func _on_ad_buy() -> void:
	var cost := TSProfile.booster_buy_cost(_ad_reward)
	if _ad_watching or TSProfile.coin_count < cost:
		return
	TSProfile.coin_count -= cost
	TSProfile.add_boosters(_ad_reward, TSProfile.booster_buy_count(_ad_reward))
	TSProfile.save()
	TSSfx.play("upgrade")
	_close_ad()
	_refresh_hud()


func _on_no_ads() -> void:
	if _ad_watching:
		return
	Billing.purchase_result.connect(func(id: String, ok: bool):
		if is_inside_tree() and id == Billing.NO_ADS and ok:
			if TSProfile.BOOSTERS.has(_ad_reward):
				_open_ad(_ad_reward)
			else:
				_on_ad_finished(), CONNECT_ONE_SHOT)
	Billing.purchase(Billing.NO_ADS)


func _close_ad() -> void:
	if _ad_watching:
		return
	TSUI.conceal(_ad_card["root"])


# -- walkthroughs --------------------------------------------------------------------

func _maybe_start_tutorials() -> void:
	if not TSProfile.tutorial_seen and current_level == 1:
		_start_tutorial()
	elif current_level == 2 and not TSProfile.slide_tutorial_seen:
		_start_slide_tutorial()
	elif TSProfile.bombs_unlocked and not TSProfile.bomb_tutorial_seen and current_level >= TSProfile.BOMB_UNLOCK_LEVEL:
		_start_bomb_tutorial()
	elif board.ties_left() > 0 and not TSProfile.tie_tutorial_seen:
		# (the Daily Egg too: it can bring tie-downs before level 10 does)
		_start_tie_tutorial()
	elif not board.geodes.is_empty() and not TSProfile.geode_tutorial_seen:
		_start_geode_tutorial()
	elif TSProfile.swaps_unlocked and not TSProfile.swap_tutorial_seen:
		_start_booster_tutorial(_btn_swap, "swap", "The Any Piece! Tap it to turn your piece into a wild block that becomes whatever it touches -- drop it by any pair to make a match. Here are %d to start." % TSProfile.SWAP_UNLOCK_GRANT)
	elif TSProfile.rocks_unlocked and not TSProfile.rocks_tutorial_seen:
		_start_booster_tutorial(_btn_rocks, "rocks", "Rocks! Tap to fire two rocks: each one lands on a pair and finishes the match. Here are %d shots to start." % TSProfile.ROCKS_UNLOCK_GRANT)


## The first egg with tie-downs: the camera turns to one, the spotlight shows
## it and how it breaks, then the counter by the hearts.
func _start_tie_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or board.ties_left() == 0:
		return
	var id: int = board.ties.keys()[0]
	_face(Vector2(board.plate_cols[id][0]))
	_snap_camera()
	_tutorial.finished.connect(func():
		TSProfile.tie_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([
		{"rect": func() -> Rect2: return _piece_rect(id),
			"text": "A tie-down! These stakes hold the critter in. Break pieces right next to one -- a match, a bomb or a rock -- to knock off a layer. The dots show how many hits it needs."},
		{"rect": _tie_pill.get_global_rect(),
			"text": "This counts the tie-downs left. Break every one AND dig the hole to free the critter!"},
	])


## The first egg with geodes: the camera turns to one and the spotlight shows
## how it breaks, and what it gives back.
func _start_geode_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or board.geodes.is_empty():
		return
	var id: int = board.geodes.keys()[0]
	_face(Vector2(board.plate_cols[id][0]))
	_snap_camera()
	_tutorial.finished.connect(func():
		TSProfile.geode_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([
		{"rect": func() -> Rect2: return _piece_rect(id),
			"text": "A geode! It takes three hits -- break pieces right next to it (the dots count down). On the last one it cracks open and fires a rock that finishes a match for you."},
	])


## Level 1's walkthrough: the ball, the gestures, the pieces, the aim, the hearts.
func _start_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var ball := Rect2(Vector2(60.0, vp.y * 0.28), Vector2(vp.x - 120.0, vp.y * 0.42))
	_tutorial.finished.connect(func():
		TSProfile.tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([
		{"rect": ball, "text": "A little critter is sealed in this egg! Dig a hole big enough and it escapes."},
		{"rect": ball, "text": "Tap the egg to aim your piece. Swipe to turn it around. Hold a piece like yours, then drag, to slide it."},
		{"rect": _piece_column_rect(), "text": "This is the piece you're holding, and the next one above it. Pieces never rotate -- a flat line and an upright line are different pieces."},
		{"rect": ball, "text": "Your aim glows bright where a drop will match. Double-tap to drop! Land it on two or more of its own kind and the whole group pops."},
		{"rect": _hearts_rect(), "text": "A drop that matches nothing costs a heart. Lose all three and the egg wins."},
	])


## Level 2's lesson, hands-on: the egg turns to a flat line that can slide
## (smashing grey if it can), the spotlight waits until the player holds it
## and drags it, and then a card says what sliding does and does not do.
## The player is handed a flat line for it, since only pieces like the one
## you hold will slide.
func _start_slide_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var id := _slide_example(TSBoard.I_FLAT)
	if id == TSBoard.HOLE:
		return   # nothing can slide on this ball; the lesson waits for another
	cur_type = TSBoard.I_FLAT
	var cols: Array = board.plate_cols[id]
	var mid := Vector2.ZERO
	for col in cols:
		mid += Vector2(col)
	_face(mid / float(cols.size()))
	_snap_camera()
	_refresh_piece()
	_refresh_hud()
	_tutorial.finished.connect(func():
		TSProfile.slide_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([
		{"id": "slide", "gate": true, "rect": func() -> Rect2: return _piece_rect(id),
			"text": "Sliding! Press and hold this line for a moment, then drag it sideways. You can slide any piece like the one you're holding."},
		{"rect": _ball_rect(), "text": "A slide smashes grey blocks in its way, but never makes a match by itself -- slide pieces together, then drop one on them. Slides never cost a heart."},
	])


## Whether the walkthrough is waiting for something done on the egg itself --
## the slide lesson's hold-and-drag, the bomb lesson's double-tap -- so
## touches must reach the board. Its dark panels still block everything
## outside the spotlight.
func _lesson_wants_board() -> bool:
	return _tutorial.on_step("slide") or _tutorial.on_step("blast")


## A piece of `kind` showing on the surface that can slide, preferring one
## that smashes grey on the way, near the middle rows -- or HOLE if none can.
func _slide_example(kind: int) -> int:
	var best := TSBoard.HOLE
	var best_score := -1
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			var id := board.top_piece(c, r)
			if not board.can_slide(id, kind):
				continue
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var smash := board.slide_preview(id, dir)
				if smash < 0:
					continue
				var score := smash * 10 + 8 - absi(r * 2 + 1 - TSBoard.ROWS)
				if score > best_score:
					best_score = score
					best = id
	return best


## Where a piece is on screen: round its showing blocks, with some margin.
func _piece_rect(id: int) -> Rect2:
	if not board.plate_cols.has(id):
		return _ball_rect()
	var rect := Rect2()
	var first := true
	for col in board.plate_cols[id]:
		var v: Vector2i = col
		var at := _camera.unproject_position(TSBoardView.cell_transform(v.x, v.y, float((board.cells[v.x][v.y] as Array).size())).origin)
		rect = Rect2(at, Vector2.ZERO) if first else rect.expand(at)
		first = false
	return rect.grow(34.0)


func _ball_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	return Rect2(Vector2(60.0, vp.y * 0.28), Vector2(vp.x - 120.0, vp.y * 0.42))


# Put the camera where it is heading at once, so the walkthrough can point at
# something on the egg straight away.
func _snap_camera() -> void:
	_cam_theta = _cam_target_theta
	_cam_phi = _cam_target_phi
	_process(0.0)


## Level 3's lesson, hands-on: bombs arrive here. The spotlight waits for the
## player to arm one, then for them to double-tap the egg, then says how to
## get more.
func _start_bomb_tutorial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not _btn_bomb.visible:
		return
	_tutorial.finished.connect(func():
		TSProfile.bomb_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([
		{"id": "arm_bomb", "gate": true, "rect": _btn_bomb.get_global_rect(),
			"text": "Bombs! Here are %d to start. Tap the bomb to arm one." % TSProfile.BOMB_UNLOCK_GRANT},
		{"id": "blast", "gate": true, "rect": _ball_rect(),
			"text": "Armed! Now double-tap the egg: the bomb blasts every piece around the spot."},
		{"rect": _btn_bomb.get_global_rect(), "text": "Boom! Bombs never cost a heart. A chain reaction or a big clear earns another, and an empty button offers more."},
	])


func _hearts_rect() -> Rect2:
	var r := _hearts[0].get_global_transform() * Rect2(-24, -24, 48, 48)
	for h in _hearts:
		r = r.merge(h.get_global_transform() * Rect2(-24, -24, 48, 48))
	return r


## Android back: close a card, or pause; from the pause menu, park and go Home.
func on_back_requested() -> bool:
	if _ad_card["root"].visible:
		_close_ad()
		return true
	if _tutorial.visible or _win_card["root"].visible or _lose_card["root"].visible:
		return true
	if _pause["root"].visible:
		TSUI.conceal(_pause["root"])
		return true
	if state == State.PLAYING:
		_open_pause()
		return true
	return false


## The next piece and the holding tray, for the walkthrough to point at.
func _piece_column_rect() -> Rect2:
	var r := _hold_tray.get_global_rect()
	r.position.y -= _tray_top - _next_mid_y + 40.0   # up over the next piece
	r.size.y += _tray_top - _next_mid_y + 40.0
	return r.grow(16.0)


func _on_booster_button(at: Vector2) -> bool:
	for btn in [_btn_bomb, _btn_swap, _btn_rocks]:
		if (btn as Control).visible and (btn as Control).get_global_rect().has_point(at):
			return true
	return false


## The Any Piece's or Rocks' walkthrough, once, the first level it is there.
func _start_booster_tutorial(btn: Button, id: String, text: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not btn.visible:
		return
	_tutorial.finished.connect(func():
		if id == "swap":
			TSProfile.swap_tutorial_seen = true
		else:
			TSProfile.rocks_tutorial_seen = true
		TSProfile.save(), CONNECT_ONE_SHOT)
	_tutorial.start([{"rect": btn.get_global_rect(), "text": text}])


## Tie-downs (TSBoard.TIE): keeps the counter by the hearts up to date, with
## a chime as each one breaks. A new ball (_ties_seen -1) just takes its count.
func _note_ties() -> void:
	var left := board.ties_left()
	if _ties_seen < 0:
		_level_ties = left
	elif left < _ties_seen:
		TSSfx.play("upgrade")
	_ties_seen = left
	_tie_pill.visible = _level_ties > 0
	_tie_label.text = str(left)


## The sky for this level's time of day -- every ten levels the day moves on,
## morning to day to sunset to night to dawn (TSToon.sky_for_level) -- and the
## light on the egg tinted to match.
func _apply_sky() -> void:
	var sky := TSToon.sky_for_level(current_level)
	TSToon.apply_sky(_sky_mat, sky)
	_key_light.light_color = sky["light"]
	_env.ambient_light_color = sky["ambient"]
