# Pure game-logic model for the Tetrisphere-style board. No rendering, no input.
#
# The shell is built from *pieces*: whole Tetris pieces lying flat on the ball,
# each within one depth layer. Every cell stack records which piece sits at
# each depth, so a piece stays a single object that is matched, destroyed,
# dropped by gravity and drawn as a unit.
#
# The rules:
# - When a drop makes three or more orthogonally connected pieces of the same
#   type touch, the whole connected group is destroyed. "Orthogonally
#   connected" means sharing a face: side by side in a layer, or stacked
#   directly above or below -- which is how a piece dropped onto its own kind
#   joins it.
# - Destroying pieces exposes the layer underneath. Grey blockers touching a
#   destroyed piece shatter with it.
# - A piece with nothing left beneath any of its blocks falls to the next
#   lower depth layer, as one rigid piece, until something holds it.
# - After gravity settles, matches are checked again; any new one explodes by
#   itself, and so on: chain reactions.
class_name TSBoard
extends RefCounted

const COLS := 20          # longitude cells; wraps around
const ROWS := 8           # latitude cells; hard edges (the band rim)
const SHELL_DEPTH := 3    # every cell starts this many blocks deep, unless the level says otherwise
const MAX_STACK := 9      # pile any cell this high and the shell overloads
const MIN_MATCH := 3      # connected same-type pieces that explode
const TILE_BUDGET := 1200   # search steps per attempt at tiling one layer
const HOLE := -1          # stack entry where a piece was destroyed or fell away

# +col, +row, -col, -row
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

# The pieces, each fixed in one orientation. Tetrisphere pieces never rotate,
# so an orientation IS a piece: the flat line and the upright line are two
# different pieces with two different colours, and they do not match each
# other. Everything else uses its usual Tetris resting pose. To add another
# orientation, append it here and give it a colour in TSBoardView.TYPE_COLORS.
# Offsets use +y as "up the ball" (screen up).
#
# The small grey blocker square is part of the shell only (never dealt to the
# player) and never matches. It breaks when a destroyed piece touches it, or
# when the player slides a piece into it.
#
# The plus is not a Tetris piece: five blocks, Expert's extra shape. It comes
# after the blocker so the older kind numbers keep their meaning.
const SHAPES := [
	{"name": "I flat", "offsets": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	{"name": "I upright", "offsets": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]},
	{"name": "O", "offsets": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	# A capital T: a bar of three across the top with a stem of two hanging
	# from its middle (+y is up the ball) -- five cells, like the capital L.
	{"name": "T", "offsets": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 1), Vector2i(1, 0)]},
	{"name": "S", "offsets": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
	{"name": "Z", "offsets": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"name": "J", "offsets": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]},
	# A capital L: an upright stem of three with a foot of three out to the right
	# along the bottom (+y is up the ball), sharing the corner: legs of equal length.
	{"name": "L", "offsets": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]},
	{"name": "Blocker", "offsets": [Vector2i(0, 0)]},
	{"name": "Plus", "offsets": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]},
	# The Any Piece booster's wild block: one cell that turns into whichever
	# piece gives the biggest match where it lands (see wild_kind). It is only
	# ever in the player's hand -- on the ball it is always a real kind.
	{"name": "Any Piece", "offsets": [Vector2i(0, 0)]},
	# The tie-down: a 1x1 stake holding the critter in, with one to three
	# layers (TSBoard.ties). Every one must be broken before the critter can
	# escape. Like the armour, a layer comes off only when pieces around it are
	# broken -- a match beside it, a bomb, a rock -- never by a slide.
	{"name": "Tie-down", "offsets": [Vector2i(0, 0)]},
	# The geode: a 1x2 stone (lying either way on the ball) that takes
	# GEODE_HITS hits -- pieces broken around it, a bomb, a rock -- and on the
	# last one cracks open and fires a rock of its own (TSBoard.geodes).
	{"name": "Geode", "offsets": [Vector2i(0, 0), Vector2i(1, 0)]},
]
const TYPE_COUNT := 13
const I_FLAT := 0
const I_UPRIGHT := 1
const O := 2
const T := 3
const L := 7
const BLOCKER := 8
const PLUS := 9
const WILD := 10
const TIE := 11
const TIE_MAX_LAYERS := 3
const GEODE := 12
const GEODE_HITS := 3
const VINE_GROW_EVERY := 3   # drops that cut no vine before the vines spread by one piece

# cells[col][row] -> Array of piece ids, deepest first. A HOLE marks an empty
# depth with something still above it; stacks never end in a HOLE, so a
# stack's size is the depth just above its topmost block.
var cells: Array = []
var shell_depth := SHELL_DEPTH   # how deep this ball started (level 1's is a single layer)
var plate_kind := {}      # piece id -> kind (index into SHAPES)
var plate_cols := {}      # piece id -> Array[Vector2i], the columns it occupies
## Armoured blockers: a second layer over the grey. A hit -- a match beside
## it, a bomb, a rock -- knocks the armour off and leaves a plain blocker; a
## second hit breaks that. Sliding can't break armour: it stops a slide.
var armored := {}         # blocker id -> true while its armour is on
var ties := {}            # tie-down id -> layers left (1 to TIE_MAX_LAYERS)
var geodes := {}          # geode id -> hits left (1 to GEODE_HITS)
## Creeping vines (TSLevels.has_vines): a vine wraps a whole piece or blocker.
## A wrapped piece never matches and never slides -- it stops a slide, like
## armour -- and a hit (a pop beside it, a bomb, a rock) cuts the vine off and
## leaves the piece. Left alone, the vines spread: every VINE_GROW_EVERY drops
## that cut none, one more piece showing beside a vine is wrapped.
var vined := {}           # piece id -> true while a vine wraps it
var vine_clock := 0       # drops since a vine was last cut (or grew)
## Lock & key (TSLevels.has_locks): padlocked grey blockers that nothing can
## break, and one key -- an ordinary piece with a key on it, buried a layer
## down. Pop the key piece and every padlock on the egg snaps open, leaving
## plain blockers.
var locked := {}          # blocker id -> true while padlocked
var key_piece := HOLE     # the key's piece id, until it is popped
var _vine_cut := false    # a vine was cut during this resolve
## Prism stones (TSLevels.has_prisms): clear crystal blockers tinted one piece's
## colour. Only a match of that colour popping beside one breaks it (the Any
## Piece counts as every colour); any other hit -- another colour's pop, a
## bomb, a rock -- just makes it chime. A slide can't smash one.
var prisms := {}          # blocker id -> the piece kind (colour) that breaks it
## Fog (TSLevels.has_fog): clouds of 2x2 cells hiding the colour of what is
## under them. A pop beside a fogged cell blows that cell clear; a bomb or rock
## that touches a cloud blows the whole cloud away.
var fog := {}             # Vector2i cell -> its cloud's number
var _matching := false    # breaking pieces by a match just now (only that breaks a prism)
var _blast := false       # breaking pieces by a bomb or rock just now (it clears whole clouds)
var _wild_id := HOLE      # the Any Piece just dropped, which counts as every colour
var _geode_breaks: Array = []   # where geodes cracked open this resolve: each fires a rock
var initial_blocks := 0
var cleared_blocks := 0

var _next_id := 0
var _rng := RandomNumberGenerator.new()
var _tile_kinds: Array = []    # pieces the current level builds its shell from
var _blocker_share := 0.0
var _mix := 1.0               # how hard the generator keeps same shapes apart
var _seed_group_max := 2      # largest same-type group a fresh shell may hold
var _blocker_cap := 1.0       # most of a layer the generator may fill with blockers


func generate(seed_value: int, level: Dictionary) -> void:
	_tile_kinds = level["pieces"]
	_blocker_share = float(level.get("blocker_share", 0.0))
	_mix = float(level.get("mix", 1.0))
	_seed_group_max = int(level.get("seed_group_max", 2))
	_blocker_cap = float(level.get("blocker_cap", 1.0))
	shell_depth = int(level.get("shell_depth", SHELL_DEPTH))
	_rng.seed = seed_value
	cells.clear()
	plate_kind.clear()
	plate_cols.clear()
	_next_id = 0
	for c in COLS:
		var column: Array = []
		for r in ROWS:
			column.append([])
		cells.append(column)

	# A smooth, even shell, as every level in the reference footage opens,
	# tiled layer by layer with whole pieces. The pattern generator lays out the
	# surface and the bottom layer; the search fills whatever is left between
	# them, fitting around both, so its extra grey stays out of sight. A
	# one-layer ball is all surface. Two pattern layers must not touch, so a
	# two-layer ball gets the pattern on top only.
	var searched: Array = []
	for d in shell_depth:
		searched.append(d)
	if level.get("generator", "search") == "pattern" and _pattern_fits():
		var patterned: Array = [0, shell_depth - 1] if shell_depth >= 3 else [shell_depth - 1]
		for d in patterned:
			_pattern_layer(d)
			searched.erase(d)
	for d in searched:
		_tile_layer(d)

	# Armour, last, so the tiling (and every baked ball without armour) is
	# unchanged: each blocker is armoured with the level's armor_share chance.
	armored.clear()
	var armor_share := float(level.get("armor_share", 0.0))
	if armor_share > 0.0:
		for id in plate_kind:
			if int(plate_kind[id]) == BLOCKER and _rng.randf() < armor_share:
				armored[id] = true
	_place_ties(int(level.get("ties", 0)), int(level.get("tie_layers", TIE_MAX_LAYERS)))
	_place_geodes(int(level.get("geodes", 0)))
	_place_vines(int(level.get("vines", 0)))
	_place_locks(int(level.get("locks", 0)))
	_place_prisms(int(level.get("prisms", 0)))
	_place_fog(int(level.get("fog", 0)))

	initial_blocks = count_blocks()
	cleared_blocks = 0


# --- pattern generator -------------------------------------------------------
#
# For the two-line levels (flat and upright lines), a hand-built layout that
# keeps every same-type group to a pair -- so no match is ready-made -- while
# only about a quarter of the layer is grey. Search on its own could not get
# below about 40%. A layer is four 5-column units round the ring, each a
# 4-wide stack of flat lines with an upright line beside it, one in each
# 4-row half. The plain unit:
#
#     row 7   F F F F U    top half      flat pair
#     row 6   F F F F U
#     row 5   . . . . U                  grey row
#     row 4   F F F F U                  flat pair
#     row 3   F F F F U    bottom half
#     row 2   . . . . U                  grey row
#     row 1   F F F F U                  flat pair
#     row 0   F F F F U
#
# Flat stacks never meet end to end (an upright sits between each), and grey
# rows cut every flat run to two. The two uprights of a unit meet across the
# middle, making a pair -- which is what gives a dropped upright somewhere to
# match. (Nudging the halves a column apart kept the rules intact but left
# each upright alone, so a fresh ball had no upright match anywhere and the
# fair deal never handed one out.)
#
# That plain unit is the only way to stack 6 flat rows in 8 with no run of
# three, so on its own every ball looked the same, only turned. So two or
# three units in each layer take a third grey row instead, laid out any of the
# 16 ways that still keep flat runs to two (e.g. F . F F . F F . from the
# bottom): 20% grey for a plain unit, 30% for a varied one -- 25-27.5% a
# layer -- and a varied unit nearly always in view. Hundreds of
# different-looking balls. Two pattern layers cannot touch directly -- their
# flat rows would stack -- so this lays out the surface and the bottom, and
# the search fills the layer between.

const PLAIN_UNIT := [true, true, false, true, true, false, true, true]   # flat rows, row 0 up


## Tie-downs, after the armour (so every ball without them is unchanged):
## `count` plain grey blockers on the surface become tie-downs of 1 to
## `max_layers` layers, spread round the ball -- each as far as can be from
## the ones already placed, and off the rows by the caps where they are hard
## to see -- so the player sees them all and has to work
## the whole egg. With too few surface blockers, buried ones make up the rest.
func _place_ties(count: int, max_layers: int) -> void:
	ties.clear()
	if count <= 0:
		return
	var middle: Array = []     # on the surface, away from the caps: easy to see
	var surface: Array = []
	var buried: Array = []
	for id in plate_kind:
		if int(plate_kind[id]) != BLOCKER or armored.has(id):
			continue
		var v: Vector2i = plate_cols[id][0]
		if top_piece(v.x, v.y) != id:
			buried.append(id)
		elif v.y >= 1 and v.y <= ROWS - 2:
			middle.append(id)
		else:
			surface.append(id)
	middle.sort()
	surface.sort()
	buried.sort()
	for pool in [middle, surface, buried]:
		while ties.size() < count and not (pool as Array).is_empty():
			var best: int = pool[_rng.randi_range(0, (pool as Array).size() - 1)]
			if not ties.is_empty():
				var best_gap := -1
				for id in pool:
					var gap := 999
					var v: Vector2i = plate_cols[id][0]
					for t in ties:
						var w: Vector2i = plate_cols[t][0]
						gap = mini(gap, absi(wrap_col(v.x - w.x + COLS / 2) - COLS / 2) + absi(v.y - w.y))
					if gap > best_gap:
						best_gap = gap
						best = id
			(pool as Array).erase(best)
			plate_kind[best] = TIE
			ties[best] = _rng.randi_range(1, clampi(max_layers, 1, TIE_MAX_LAYERS))


## Geodes, after the tie-downs (so every ball without them is unchanged): up
## to `count` pairs of plain grey blockers side by side on the surface --
## across or up and down the ball -- become one 1x2 geode each, with
## GEODE_HITS hits to go. Pairs away from the caps first, and each as far as
## can be from the geodes already placed.
func _place_geodes(count: int) -> void:
	geodes.clear()
	if count <= 0:
		return
	var plain := func(id: int) -> bool:
		if id == HOLE or int(plate_kind[id]) != BLOCKER or armored.has(id):
			return false
		var v: Vector2i = plate_cols[id][0]
		return top_piece(v.x, v.y) == id
	var pairs: Array = []   # [cells, middle?]
	for c in COLS:
		for r in ROWS:
			var a := top_piece(c, r)
			if not plain.call(a):
				continue
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				var s: Vector2i = step
				var nb := Vector2i(wrap_col(c + s.x), r + s.y)
				if not in_rows(nb.y):
					continue
				var b := top_piece(nb.x, nb.y)
				if plain.call(b) and depth_of(a) == depth_of(b):
					pairs.append([[Vector2i(c, r), nb], r >= 1 and nb.y <= ROWS - 2])
	var placed: Array = []   # cells of the geodes so far
	while placed.size() < count * 2 and not pairs.is_empty():
		var pool: Array = pairs.filter(func(p: Array) -> bool: return bool(p[1]))
		if pool.is_empty():
			pool = pairs
		var best: Array = pool[_rng.randi_range(0, pool.size() - 1)]
		if not placed.is_empty():
			var best_gap := -1
			for p in pool:
				var gap := 999
				for v in p[0]:
					for w in placed:
						var vv: Vector2i = v
						var ww: Vector2i = w
						gap = mini(gap, absi(wrap_col(vv.x - ww.x + COLS / 2) - COLS / 2) + absi(vv.y - ww.y))
				if gap > best_gap:
					best_gap = gap
					best = p
		var cols: Array = best[0]
		var d := depth_of(top_piece(cols[0].x, cols[0].y))
		for v in cols:
			var vv: Vector2i = v
			_remove_plate(top_piece(vv.x, vv.y))
		var id := _add_plate(GEODE, cols, d)
		geodes[id] = GEODE_HITS
		placed.append_array(cols)
		# No other pair may reuse these cells.
		pairs = pairs.filter(func(p: Array) -> bool:
			for v in p[0]:
				if cols.has(v):
					return false
			return true)


## Vines, after the geodes (so every ball without them is unchanged): `count`
## coloured pieces showing on the surface, away from the caps where they can,
## each as far as can be from the vines already placed, are wrapped.
func _place_vines(count: int) -> void:
	vined.clear()
	vine_clock = 0
	if count <= 0:
		return
	var middle: Array = []
	var edge: Array = []
	for c in COLS:
		for r in ROWS:
			var p := top_piece(c, r)
			if p == HOLE or is_obstacle(int(plate_kind[p])) or middle.has(p) or edge.has(p):
				continue
			if r >= 1 and r <= ROWS - 2:
				middle.append(p)
			else:
				edge.append(p)
	for pool in [middle, edge]:
		while vined.size() < count and not (pool as Array).is_empty():
			var best: int = pool[_rng.randi_range(0, (pool as Array).size() - 1)]
			if not vined.is_empty():
				var best_gap := -1
				for id in pool:
					var gap := 999
					var v: Vector2i = plate_cols[id][0]
					for w_id in vined:
						var w: Vector2i = plate_cols[w_id][0]
						gap = mini(gap, absi(wrap_col(v.x - w.x + COLS / 2) - COLS / 2) + absi(v.y - w.y))
					if gap > best_gap:
						best_gap = gap
						best = id
			(pool as Array).erase(best)
			vined[best] = true


## Padlocks and the key, last: `count` plain grey blockers showing on the
## surface are padlocked, and one coloured piece a layer down becomes the key
## -- one with no padlock above any of its cells, so it can always be dug to.
## (A one-layer egg has nowhere to bury it, so its key lies on top.)
func _place_locks(count: int) -> void:
	locked.clear()
	key_piece = HOLE
	if count <= 0:
		return
	var plain: Array = []
	for id in plate_kind:
		if int(plate_kind[id]) == BLOCKER and not armored.has(id) and not vined.has(id):
			var v: Vector2i = plate_cols[id][0]
			if top_piece(v.x, v.y) == id:
				plain.append(id)
	plain.sort()
	while locked.size() < count and not plain.is_empty():
		var pick: int = plain[_rng.randi_range(0, plain.size() - 1)]
		plain.erase(pick)
		locked[pick] = true
	if locked.is_empty():
		return
	var want := 1 if shell_depth >= 2 else 0   # how many layers down the key lies
	var keys: Array = []
	for id in plate_kind:
		if is_obstacle(int(plate_kind[id])) or vined.has(id):
			continue
		var ok := true
		for col in plate_cols[id]:
			var v: Vector2i = col
			var stack: Array = cells[v.x][v.y]
			var d := stack.find(id)
			if stack.size() - 1 - d != want:
				ok = false
				break
			for above in range(d + 1, stack.size()):
				if locked.has(int(stack[above])):
					ok = false
					break
			if not ok:
				break
		if ok:
			keys.append(id)
	keys.sort()
	if keys.is_empty():
		locked.clear()   # nowhere fair for the key: no padlocks either
		return
	key_piece = keys[_rng.randi_range(0, keys.size() - 1)]


## Prism stones, after the padlocks: `count` plain grey blockers showing on the
## surface become prisms, tinted in turn with the colours of the level's pieces
## (so the colour that breaks each is always dealt), and never touching a prism
## of the same colour -- one big match can't take them all at once.
func _place_prisms(count: int) -> void:
	prisms.clear()
	if count <= 0 or _tile_kinds.is_empty():
		return
	var plain: Array = []
	for id in plate_kind:
		if int(plate_kind[id]) == BLOCKER and not armored.has(id) and not vined.has(id) and not locked.has(id):
			var v: Vector2i = plate_cols[id][0]
			if top_piece(v.x, v.y) == id:
				plain.append(id)
	plain.sort()
	var colour := _rng.randi_range(0, _tile_kinds.size() - 1)
	while prisms.size() < count and not plain.is_empty():
		var pick: int = plain[_rng.randi_range(0, plain.size() - 1)]
		plain.erase(pick)
		var kind := int(_tile_kinds[colour % _tile_kinds.size()])
		var clash := false
		for n in _neighbors(pick):
			if prisms.has(n) and int(prisms[n]) == kind:
				clash = true
		if clash:
			continue
		prisms[pick] = kind
		colour += 1


## Fog, last: `clouds` 2x2 patches of the surface, away from the caps where
## they can be and apart from each other, never over the key.
func _place_fog(clouds: int) -> void:
	fog.clear()
	if clouds <= 0:
		return
	var key_cells: Array = plate_cols[key_piece] if key_piece != HOLE and plate_cols.has(key_piece) else []
	var tries := 0
	var n := 0
	while n < clouds and tries < 200:
		tries += 1
		var at := Vector2i(_rng.randi_range(0, COLS - 1), _rng.randi_range(1, ROWS - 3))
		var patch: Array = []
		var ok := true
		for dc in 2:
			for dr in 2:
				var cell := Vector2i(wrap_col(at.x + dc), at.y + dr)
				if key_cells.has(cell):
					ok = false
				for dir in DIRS:   # a cell clear of every other cloud, all round
					var dv: Vector2i = dir
					if fog.has(Vector2i(wrap_col(cell.x + dv.x), cell.y + dv.y)) or fog.has(cell):
						ok = false
				patch.append(cell)
		if not ok:
			continue
		for cell in patch:
			fog[cell] = n
		n += 1


## Clears the fog over `cell` -- and, by a bomb or rock, its whole cloud --
## logging each cleared cell to `fx` ("fog").
func _clear_fog(cell: Vector2i, step: int, fx: Array) -> void:
	if not fog.has(cell):
		return
	var cloud := int(fog[cell])
	var gone: Array = [cell]
	if _blast:
		gone = fog.keys().filter(func(c: Vector2i) -> bool: return int(fog[c]) == cloud)
	for c in gone:
		var v: Vector2i = c
		fog.erase(v)
		fx.append([v.x, v.y, maxi((cells[v.x][v.y] as Array).size() - 1, 0), BLOCKER, step, "fog"])


## Whether a pop beside piece `n` hits it: blockers, tie-downs and geodes
## shatter (or chip), and a vine round anything is cut.
func _hit_by_pop(n: int) -> bool:
	return is_obstacle(int(plate_kind[n])) or vined.has(n)


## Blockers, tie-downs and geodes: never dealt, never matched, never slid.
static func is_obstacle(kind: int) -> bool:
	return kind == BLOCKER or kind == TIE or kind == GEODE


## How many tie-downs are still standing: the critter can't escape until 0.
## All the hits the tie-downs still need, every layer of every one.
func tie_layers_left() -> int:
	var n := 0
	for id in ties:
		n += int(ties[id])
	return n


func ties_left() -> int:
	return ties.size()


func _pattern_fits() -> bool:
	return COLS % 5 == 0 and ROWS == 8


func _pattern_layer(d: int) -> void:
	var offset := _rng.randi_range(0, 4)
	var units := COLS / 5
	var varied := {}
	# A ball opens facing the aim's starting spot, the first columns of the
	# ring; the unit there is always a varied one, so a level shows what sets
	# it apart before it is turned.
	varied[posmod(1 - offset, COLS) / 5] = true
	var want := _rng.randi_range(2, 3)
	while varied.size() < want:
		varied[_rng.randi_range(0, units - 1)] = true
	var variants := _pattern_variants()
	for k in units:
		var flat_rows: Array = PLAIN_UNIT
		if varied.has(k):
			flat_rows = variants[_rng.randi_range(0, variants.size() - 1)]
		_pattern_unit(d, offset + 5 * k, flat_rows)


# Every column of flat rows with exactly three grey rows and no run of three
# flats, bottom row first.
static func _pattern_variants() -> Array:
	var out: Array = []
	for mask in 1 << ROWS:
		var rows: Array = []
		var run := 0
		var ok := true
		for r in ROWS:
			var flat := (mask >> r) & 1 == 1
			rows.append(flat)
			run = run + 1 if flat else 0
			ok = ok and run <= 2
		if ok and rows.count(false) == 3:
			out.append(rows)
	return out


# One unit from column x: a flat line or four grey squares on each row, as
# flat_rows says, and an upright line in each half of column x + 4.
func _pattern_unit(d: int, x: int, flat_rows: Array) -> void:
	for r in ROWS:
		if flat_rows[r]:
			var cols: Array = []
			for j in 4:
				cols.append(Vector2i(wrap_col(x + j), r))
			_add_plate(I_FLAT, cols, d)
		else:
			for j in 4:
				_add_plate(BLOCKER, [Vector2i(wrap_col(x + j), r)], d)
	for row0 in [0, 4]:
		var upright: Array = []
		for i in 4:
			upright.append(Vector2i(wrap_col(x + 4), row0 + i))
		_add_plate(I_UPRIGHT, upright, d)


# --- tiling ------------------------------------------------------------------

# Tries the level's blocker cap, then no cap at all. Lines only fit straight
# runs of four, so a greedy fill leaves 1-3 cell pockets that blockers plug;
# under a cap the search backs up and rearranges lines instead. How low a cap
# can actually be met depends on the level's rules, so it is a level setting:
# a cap that cannot be met just costs a wasted search before the uncapped one.
func _tile_layer(d: int) -> void:
	for cap in [_blocker_cap, 1.0]:
		var budget := [TILE_BUDGET]
		var allowance := [0]
		if _blocker_share > 0.0:
			allowance[0] = int(ceil(float(cap) * COLS * ROWS))
		if _fill(d, budget, allowance):
			return
	push_warning("TSBoard: layer %d fell back to a plain tiling" % d)
	_fallback_layer(d)


# Randomised backtracking. Each step fills the most boxed-in open cell (fewest
# open neighbours), trying every piece placement that covers it. Pieces never
# rotate, so a pocket often fits only one or two shapes; dealing with pockets
# first is what keeps the search from painting itself into a corner. Blockers
# fit any gap, but only `allowance` of them may be used, so the search is
# pushed to arrange lines without leaving pockets.
#
# A fresh shell never holds a connected same-type group bigger than the
# level's seed_group_max. Below MIN_MATCH, every match is one the player
# builds; above it, a drop next to a ready-made group destroys the whole thing.
func _fill(d: int, budget: Array, allowance: Array) -> bool:
	var target := _most_enclosed_open(d)
	if target.x < 0:
		return true
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	for placement in _placements_covering(target, d, int(allowance[0]) > 0):
		var kind: int = placement[0]
		var cols: Array = placement[1]
		var id := _add_plate(kind, cols, d)
		if kind != BLOCKER and _component(id, _seed_group_max + 1).size() > _seed_group_max:
			_pop_plate(id)
			continue
		if kind == BLOCKER:
			allowance[0] -= 1
		if _fill(d, budget, allowance):
			return true
		_pop_plate(id)
		if kind == BLOCKER:
			allowance[0] += 1
		if budget[0] <= 0:
			return false
	return false


func _most_enclosed_open(d: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_open := 5
	for c in COLS:
		for r in ROWS:
			if _occupant(c, r, d) != HOLE:
				continue
			var open := 0
			for dir in DIRS:
				var dv: Vector2i = dir
				var rr := r + dv.y
				if in_rows(rr) and _occupant(wrap_col(c + dv.x), rr, d) == HOLE:
					open += 1
			if open < best_open:
				best_open = open
				best = Vector2i(c, r)
				if open == 0:
					return best   # nothing is more constrained than an enclosed cell
	return best


# Every placement of the level's pieces that covers `target` using only open
# cells of layer d, as [kind, columns]. Placements touching the fewest pieces of
# their own type come first (ties random), so types interleave instead of
# growing into single-colour patches. The blocker, if the level has one and the
# allowance is not spent, goes first with probability blocker_share and last
# otherwise, so it seeds the shell with a few blockers and patches whatever no
# line fits.
func _placements_covering(target: Vector2i, d: int, blocker_ok: bool) -> Array:
	var out: Array = []
	for kind in _tile_kinds:
		var offsets: Array = SHAPES[kind]["offsets"]
		for pivot in offsets:
			var p: Vector2i = pivot
			var cols: Array = []
			for o in offsets:
				var v: Vector2i = o
				var r := target.y + v.y - p.y
				if not in_rows(r):
					break
				var c := wrap_col(target.x + v.x - p.x)
				if _occupant(c, r, d) != HOLE:
					break
				cols.append(Vector2i(c, r))
			if cols.size() == offsets.size():
				# Sort key: same-type contacts weighted by the level mix, plus noise.
				var touching := _contacts(kind, cols, d).size()
				out.append([kind, cols, _mix * touching + _rng.randf()])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	if blocker_ok and _blocker_share > 0.0:
		var blocker := [BLOCKER, [target]]
		if _rng.randf() < _blocker_share:
			out.push_front(blocker)
		else:
			out.append(blocker)
	return out


func _fallback_layer(d: int) -> void:
	# Only reached if the search fails. Blockers never match, so filling every
	# open cell with them can never create a ready-made group, whatever sits
	# above or below.
	for c in COLS:
		for r in ROWS:
			if _occupant(c, r, d) == HOLE:
				_add_plate(BLOCKER, [Vector2i(c, r)], d)


# --- pieces ------------------------------------------------------------------

# Puts a piece on top of each of its columns, or into layer `depth` if given.
func _add_plate(kind: int, cols: Array, depth: int = -1) -> int:
	var id := _next_id
	_next_id += 1
	plate_kind[id] = kind
	plate_cols[id] = cols
	for col in cols:
		var v: Vector2i = col
		var stack: Array = cells[v.x][v.y]
		if depth < 0:
			stack.append(id)
		else:
			while stack.size() <= depth:
				stack.append(HOLE)
			stack[depth] = id
	return id


# Undo for tiling. Clears the piece at its own depth, which in a layer being
# filled beneath an already-laid surface is not the top of the stack.
func _pop_plate(id: int) -> void:
	_remove_plate(id)


func _remove_plate(id: int) -> void:
	for col in plate_cols[id]:
		var v: Vector2i = col
		var stack: Array = cells[v.x][v.y]
		stack[stack.find(id)] = HOLE
		_trim(stack)
	plate_kind.erase(id)
	plate_cols.erase(id)
	armored.erase(id)
	ties.erase(id)
	geodes.erase(id)
	vined.erase(id)
	locked.erase(id)
	prisms.erase(id)


# A hole with nothing above it is just open space; drop it from the stack.
static func _trim(stack: Array) -> void:
	while not stack.is_empty() and int(stack[stack.size() - 1]) == HOLE:
		stack.pop_back()


func depth_of(id: int) -> int:
	var v: Vector2i = plate_cols[id][0]
	return (cells[v.x][v.y] as Array).find(id)


# The piece at (c, r, d), or HOLE if that spot is open.
func _occupant(c: int, r: int, d: int) -> int:
	var stack: Array = cells[c][r]
	if d < 0 or d >= stack.size():
		return HOLE
	return int(stack[d])


# Pieces sharing a face with piece p: beside it in its layer, or directly
# above or below it.
func _neighbors(p: int) -> Array:
	var found := {}
	for col in plate_cols[p]:
		var v: Vector2i = col
		var stack: Array = cells[v.x][v.y]
		var d := stack.find(p)
		if d > 0:
			found[stack[d - 1]] = true
		if d + 1 < stack.size():
			found[stack[d + 1]] = true
		for dir in DIRS:
			var dv: Vector2i = dir
			var r := v.y + dv.y
			if not in_rows(r):
				continue
			var side: Array = cells[wrap_col(v.x + dv.x)][r]
			if d < side.size():
				found[side[d]] = true
	found.erase(p)
	found.erase(HOLE)
	return found.keys()


# The connected same-type group containing piece `id`, stopping at `limit`.
func _component(id: int, limit: int = 1 << 20) -> Array:
	var kind: int = plate_kind[id]
	var seen := {id: true}
	var pending: Array = [id]
	var out: Array = []
	while not pending.is_empty():
		var p: int = pending.pop_back()
		out.append(p)
		if out.size() >= limit:
			return out
		for n in _neighbors(p):
			if not seen.has(n) and int(plate_kind[n]) == kind and not vined.has(n):
				seen[n] = true
				pending.append(n)
	return out


# The same-type pieces a `kind` piece lying on `cols` in layer d would share a
# face with, found without placing it.
func _contacts(kind: int, cols: Array, d: int) -> Array:
	var found := {}
	for col in cols:
		var v: Vector2i = col
		for p in [_occupant(v.x, v.y, d - 1), _occupant(v.x, v.y, d + 1)]:
			if p != HOLE and int(plate_kind[p]) == kind and not vined.has(p):
				found[p] = true
		for dir in DIRS:
			var dv: Vector2i = dir
			var n := Vector2i(wrap_col(v.x + dv.x), v.y + dv.y)
			if not in_rows(n.y) or cols.has(n):
				continue
			var p := _occupant(n.x, n.y, d)
			if p != HOLE and int(plate_kind[p]) == kind and not vined.has(p):
				found[p] = true
	return found.keys()


# --- gravity and matching ----------------------------------------------------

# Is anything directly beneath any block of piece p (or is it on the core)?
func _supported(p: int) -> bool:
	for col in plate_cols[p]:
		var v: Vector2i = col
		var d := (cells[v.x][v.y] as Array).find(p)
		if d == 0 or _occupant(v.x, v.y, d - 1) != HOLE:
			return true
	return false


# Lets every unsupported piece fall a layer at a time, as a rigid piece, until
# everything rests on something. Returns the pieces that moved.
func _settle() -> Array:
	var moved := {}
	var changed := true
	while changed:
		changed = false
		for p in plate_cols.keys():
			if _supported(p):
				continue
			for col in plate_cols[p]:
				var v: Vector2i = col
				var stack: Array = cells[v.x][v.y]
				var d := stack.find(p)
				stack[d] = HOLE
				stack[d - 1] = p
				_trim(stack)
			moved[p] = true
			changed = true
	return moved.keys()


# Every group of MIN_MATCH or more connected same-type pieces that includes
# one of `seeds`, plus the blockers touching them: everything that explodes.
func _matches(seeds: Array) -> Dictionary:
	var doomed := {}
	var checked := {}
	for s in seeds:
		var id: int = s
		if checked.has(id) or not plate_kind.has(id) or is_obstacle(int(plate_kind[id])) or vined.has(id):
			continue
		var group := _component(id)
		for g in group:
			checked[g] = true
		if group.size() < MIN_MATCH:
			continue
		for p in group:
			doomed[p] = true
			for n in _neighbors(p):
				if _hit_by_pop(n):
					doomed[n] = true
	return doomed


# Destroys these pieces, logging each block to `fx` (where it stood, and the
# chain step it went at) so the view can play the clear in place. A block that
# only takes a hit carries a sixth field: "armor" (its armour knocked off) or
# "hit" (a tie-down's layer, a geode's chip); a plain break has none.
func _destroy(doomed: Dictionary, step: int, fx: Array) -> int:
	var removed := 0
	# A vine takes the hit first, whatever it wraps: it is cut ("vine" in the
	# fx, in the colour of what it held) and the piece stays.
	for p in doomed.keys():
		if vined.has(p):
			vined.erase(p)
			doomed.erase(p)
			_vine_cut = true
			vine_clock = 0
			for col in plate_cols[p]:
				var v: Vector2i = col
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), int(plate_kind[p]), step, "vine"])
	# A prism breaks only to a match of its own colour popping beside it (the
	# Any Piece counting as every colour); any other hit, it chimes ("prism").
	for p in doomed.keys():
		if not prisms.has(p):
			continue
		var want := int(prisms[p])
		var right := false
		if _matching:
			for n in _neighbors(p):
				if doomed.has(n) and not is_obstacle(int(plate_kind[n])) and (int(plate_kind[n]) == want or n == _wild_id):
					right = true
		if not right:
			doomed.erase(p)
			var pv: Vector2i = plate_cols[p][0]
			fx.append([pv.x, pv.y, (cells[pv.x][pv.y] as Array).find(p), want, step, "prism"])
	# A padlocked blocker shrugs the hit off ("locked": a clink, nothing breaks).
	for p in doomed.keys():
		if locked.has(p):
			doomed.erase(p)
			var lv: Vector2i = plate_cols[p][0]
			fx.append([lv.x, lv.y, (cells[lv.x][lv.y] as Array).find(p), BLOCKER, step, "locked"])
	# An armoured blocker takes the hit instead: its armour chips off (a
	# puff of grey in the fx) and it stays as a plain blocker.
	for p in doomed.keys():
		if armored.has(p):
			armored.erase(p)
			doomed.erase(p)
			for col in plate_cols[p]:
				var v: Vector2i = col
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), BLOCKER, step, "armor"])
	# A tie-down loses one layer per hit (a chip of it in the fx) and breaks
	# with its last.
	for p in doomed.keys():
		if ties.has(p) and int(ties[p]) > 1:
			ties[p] = int(ties[p]) - 1
			doomed.erase(p)
			for col in plate_cols[p]:
				var v: Vector2i = col
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), TIE, step, "hit"])
	# A geode takes a hit the same way; on its last it cracks open, and the
	# rock inside flies (the caller plays it: see geode_shots in the result).
	for p in doomed.keys():
		if not geodes.has(p):
			continue
		if int(geodes[p]) > 1:
			geodes[p] = int(geodes[p]) - 1
			doomed.erase(p)
			for col in plate_cols[p]:
				var v: Vector2i = col
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), GEODE, step, "hit"])
		else:
			_geode_breaks.append(plate_cols[p][0])
	# The key popping: every padlock on the egg snaps open ("unlock").
	if key_piece != HOLE and doomed.has(key_piece):
		for p in locked:
			var uv: Vector2i = plate_cols[p][0]
			fx.append([uv.x, uv.y, (cells[uv.x][uv.y] as Array).find(p), BLOCKER, step, "unlock"])
		locked.clear()
		key_piece = HOLE
	for p in doomed:
		var kind: int = plate_kind[p]
		for col in plate_cols[p]:
			var v: Vector2i = col
			if prisms.has(p):   # a prism shattering, in its colour
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), int(prisms[p]), step, "prism_break"])
			else:
				fx.append([v.x, v.y, (cells[v.x][v.y] as Array).find(p), kind, step])
		removed += (plate_cols[p] as Array).size()
	# The fog over and beside every block broken blows away.
	if not fog.is_empty():
		for p in doomed:
			for col in plate_cols[p]:
				var v: Vector2i = col
				_clear_fog(v, step, fx)
				for dir in DIRS:
					var dv: Vector2i = dir
					if in_rows(v.y + dv.y):
						_clear_fog(Vector2i(wrap_col(v.x + dv.x), v.y + dv.y), step, fx)
	for p in doomed:
		_remove_plate(p)
	cleared_blocks += removed
	return removed


# The chain: explode what matches among `seeds`, let gravity settle, check the
# pieces that fell, repeat until nothing new matches. `step` is the fx step of
# the first explosion.
func _chain(seeds: Array, fx: Array, step: int) -> Dictionary:
	var chain := 0
	var removed := 0
	var pieces := 0
	var guard := 0
	while guard < 256:
		guard += 1
		var doomed := _matches(seeds)
		if doomed.is_empty():
			break
		chain += 1
		for p in doomed:
			if not is_obstacle(int(plate_kind[p])) and not vined.has(p):
				pieces += 1
		_matching = true
		removed += _destroy(doomed, step + chain - 1, fx)
		_matching = false
		seeds = _settle()
	return {"chain": chain, "removed": removed, "pieces": pieces}


# --- play --------------------------------------------------------------------

func count_blocks() -> int:
	var n := 0
	for c in COLS:
		for r in ROWS:
			for p in cells[c][r]:
				if int(p) != HOLE:
					n += 1
	return n


func wrap_col(c: int) -> int:
	return posmod(c, COLS)


func in_rows(r: int) -> bool:
	return r >= 0 and r < ROWS


func height(c: int, r: int) -> int:
	if not in_rows(r):
		return MAX_STACK + 99
	return cells[wrap_col(c)][r].size()


func footprint_cells(offsets: Array, at: Vector2i) -> Array:
	var out: Array = []
	for o in offsets:
		var v: Vector2i = o
		out.append(Vector2i(wrap_col(at.x + v.x), at.y + v.y))
	return out


func footprint_valid(offsets: Array, at: Vector2i) -> bool:
	for cell in footprint_cells(offsets, at):
		if not in_rows(cell.y):
			return false
	return true


# The layer a piece dropped at `at` lands in: flat, resting on the highest
# block beneath it and bridging any lower holes.
func landing_depth(offsets: Array, at: Vector2i) -> int:
	var d := 0
	for cell in footprint_cells(offsets, at):
		d = maxi(d, height(cell.x, cell.y))
	return d


# How many pieces a drop here would explode straight away (0 if it makes no
# match), without changing anything: the new piece joins every same-type group
# it touches. Drives the aim cue and the lives rule's warning. Chain reactions
# that follow are not predicted.
func combo_preview(offsets: Array, at: Vector2i, kind: int, depth: int) -> int:
	if kind == WILD:
		kind = wild_kind(offsets, at, depth)
	var total := 1
	var seen := {}
	for p in _contacts(kind, footprint_cells(offsets, at), depth):
		if seen.has(p):
			continue
		for g in _component(p):
			seen[g] = true
			total += 1
	return total if total >= MIN_MATCH else 0


# What the Any Piece (WILD) becomes when it lands on `at` in layer `depth`:
# of the kinds it would touch, the one making the biggest match (ties go to
# the one it touches most). With no match to make it takes the kind it
# touches most -- the piece beneath it first -- so it still blends in. On bare
# core with nothing beside it, it lands as an I flat.
func wild_kind(offsets: Array, at: Vector2i, depth: int) -> int:
	var cols := footprint_cells(offsets, at)
	var touching := {}   # kind -> contact count
	for col in cols:
		var v: Vector2i = col
		var near: Array = [_occupant(v.x, v.y, depth - 1), _occupant(v.x, v.y, depth + 1)]
		for dir in DIRS:
			var dv: Vector2i = dir
			var n := Vector2i(wrap_col(v.x + dv.x), v.y + dv.y)
			if in_rows(n.y) and not cols.has(n):
				near.append(_occupant(n.x, n.y, depth))
		for i in near.size():
			var p: int = near[i]
			if p == HOLE or is_obstacle(int(plate_kind[p])):
				continue
			# The piece underneath counts double, so it wins a tie.
			touching[int(plate_kind[p])] = int(touching.get(int(plate_kind[p]), 0)) + (2 if i == 0 else 1)
	var best := I_FLAT
	var best_score := -1
	for k in touching:
		var score := combo_preview(offsets, at, int(k), depth) * 100 + int(touching[k])
		if score > best_score:
			best = int(k)
			best_score = score
	return best


# Is there anywhere on the ball a straight drop of `kind` would make a match?
func has_combo_spot(kind: int) -> bool:
	var offsets: Array = SHAPES[kind]["offsets"]
	for c in COLS:
		for r in ROWS:
			var at := Vector2i(c, r)
			if not footprint_valid(offsets, at):
				continue
			if combo_preview(offsets, at, kind, landing_depth(offsets, at)) > 0:
				return true
	return false


# --- dealing -------------------------------------------------------------------
#
# Which piece comes next is a difficulty lever: the dealer favours (or, below
# an even split, avoids) the piece most common on the board. More of a piece
# on the ball means more places for it to match, now or once the layers above
# are dug away, so dealing it more often makes the board easier.

# How many pieces of each of `kinds` are on the board, in every layer --
# buried ones count as much as the ones showing.
func piece_counts(kinds: Array) -> Dictionary:
	var counts := {}
	for k in kinds:
		counts[int(k)] = 0
	for id in plate_kind:
		var kind := int(plate_kind[id])
		if counts.has(kind):
			counts[kind] += 1
	return counts


# The kind among `kinds` with the most pieces on the board, or HOLE if two or
# more tie for the lead.
func most_common(kinds: Array) -> int:
	var counts := piece_counts(kinds)
	var best := HOLE
	var best_n := -1
	var tied := false
	for kind in counts:
		var n: int = counts[kind]
		if n > best_n:
			best = kind
			best_n = n
			tied = false
		elif n == best_n:
			tied = true
	return HOLE if tied else best


# Deal one of `kinds`. With probability `common_bias` it is the board's most
# common piece; otherwise one of the rest, evenly. With two kinds, 0.5 is a
# fair coin, above it favours the common piece, below it the rare one. A tie
# for most common, or a single kind, deals evenly. `rng` may be null, for the
# global generator.
func deal_piece(kinds: Array, common_bias: float, rng: RandomNumberGenerator = null) -> int:
	var roll := rng.randf() if rng != null else randf()
	var common := most_common(kinds)
	if kinds.size() < 2 or common == HOLE:
		return int(kinds[mini(int(roll * kinds.size()), kinds.size() - 1)])
	if roll < common_bias:
		return common
	var rest: Array = []
	for k in kinds:
		if int(k) != common:
			rest.append(int(k))
	# Reuse the part of the roll above the bias to pick among the rest.
	var t := (roll - common_bias) / maxf(1.0 - common_bias, 0.00001)
	return int(rest[mini(int(t * rest.size()), rest.size() - 1)])


# --- sliding pieces on the ball ----------------------------------------------
#
# The player can push a piece already on the ball sideways, one cell at a
# time, within its own layer -- but only a piece of the same type as the one
# they are about to drop. Grey blockers in its way are smashed; any other
# Tetris piece stops it dead, and nothing moves. A slide only moves pieces:
# gravity lets anything left unsupported fall, but it never makes a match.
# Matches come from drops alone.

# The piece whose block is outermost at cell (c, r), or HOLE.
func top_piece(c: int, r: int) -> int:
	if not in_rows(r):
		return HOLE
	var stack: Array = cells[wrap_col(c)][r]
	return HOLE if stack.is_empty() else int(stack[stack.size() - 1])


# May piece `id` be slid while the player holds a piece of type `holding`?
# Only pieces of that same type; never blockers.
func can_slide(id: int, holding: int) -> bool:
	return plate_kind.has(id) and not is_obstacle(int(plate_kind[id])) and int(plate_kind[id]) == holding and not vined.has(id)


# What sliding piece `id` one cell in `dir` would do, without doing it: -1 if
# it cannot move (a Tetris piece or the rim in the way), otherwise how many
# blockers it would smash (0 for a clear move).
func slide_preview(id: int, dir: Vector2i) -> int:
	if not plate_kind.has(id) or is_obstacle(int(plate_kind[id])) or vined.has(id):
		return -1
	var d := depth_of(id)
	var smash := 0
	for col in plate_cols[id]:
		var v: Vector2i = col
		var n := Vector2i(wrap_col(v.x + dir.x), v.y + dir.y)
		if not in_rows(n.y):
			return -1
		var p := _occupant(n.x, n.y, d)
		if p == HOLE or p == id:
			continue
		if int(plate_kind[p]) != BLOCKER or armored.has(p) or vined.has(p) or locked.has(p) or prisms.has(p):   # pieces, armour, vines, padlocks and prisms stop a slide
			return -1
		smash += 1
	return smash


func slide(id: int, dir: Vector2i) -> Dictionary:
	if slide_preview(id, dir) < 0:
		return {"moved": false}
	var d := depth_of(id)
	var from: Array = plate_cols[id]
	var to: Array = []
	for col in from:
		var v: Vector2i = col
		to.append(Vector2i(wrap_col(v.x + dir.x), v.y + dir.y))

	var smash := {}
	for col in to:
		var v: Vector2i = col
		var p := _occupant(v.x, v.y, d)
		if p != HOLE and p != id:
			smash[p] = true
	var fx: Array = []
	var smashed := _destroy(smash, 1, fx)

	# Lift the piece out, then set it down one cell over, in the same layer.
	for col in from:
		var v: Vector2i = col
		cells[v.x][v.y][d] = HOLE
	for col in to:
		var v: Vector2i = col
		var stack: Array = cells[v.x][v.y]
		while stack.size() <= d:
			stack.append(HOLE)
		stack[d] = id
	for col in from:
		var v: Vector2i = col
		_trim(cells[v.x][v.y])
	plate_cols[id] = to

	# Movement only: whatever lost its support falls, but nothing is matched.
	var fell := _settle()
	return {"moved": true, "smashed": smashed, "fell": fell, "fx": fx}


# Sets the piece into layer `depth` (where a straight drop lands, by default)
# and resolves the matches and chain reactions.
func place_and_resolve(offsets: Array, at: Vector2i, kind: int, depth: int = -1) -> Dictionary:
	_geode_breaks.clear()
	_vine_cut = false
	if depth < 0:
		depth = landing_depth(offsets, at)
	var wild := kind == WILD
	if wild:
		kind = wild_kind(offsets, at, depth)
	var id := _add_plate(kind, footprint_cells(offsets, at), depth)
	_wild_id = id if wild else HOLE
	var fx: Array = []
	var res := _chain([id], fx, 1)
	_wild_id = HOLE
	res["fx"] = fx
	res["overload"] = _overloaded()
	res["geode_shots"] = _geode_breaks.duplicate()   # a rock from each geode that cracked open
	res["vine_grew"] = _grow_vines()   # a piece the vines spread onto, or HOLE
	return res


## After a drop that cut no vine, the vines creep: every VINE_GROW_EVERY such
## drops, one piece showing beside a vine -- not a tie-down, geode or padlock
## -- is wrapped too. Returns its id, or HOLE.
func _grow_vines() -> int:
	if vined.is_empty() or _vine_cut:
		return HOLE
	vine_clock += 1
	if vine_clock < VINE_GROW_EVERY:
		return HOLE
	vine_clock = 0
	var found := {}
	for id in vined:
		for col in plate_cols[id]:
			var v: Vector2i = col
			for dir in DIRS:
				var dv: Vector2i = dir
				var p := top_piece(v.x + dv.x, v.y + dv.y)
				if p == HOLE or vined.has(p) or locked.has(p) or ties.has(p) or geodes.has(p):
					continue
				found[p] = true
	if found.is_empty():
		return HOLE
	var options: Array = found.keys()
	options.sort()
	var grew: int = options[_rng.randi_range(0, options.size() - 1)]
	vined[grew] = true
	return grew


# Blows the top block off) every column within `radius`, then lets gravity and
# any chain reaction follow. Bombs are not drops: they never cost a life.
# A bomb destroys every piece showing inside a circle of `radius` cells --
# whole pieces, never part of one, so a line is never left as a stub -- and,
# as with a match, the blockers touching them shatter too. Gravity and chain
# reactions then follow as after a drop.
func detonate(at: Vector2i, radius: int) -> Dictionary:
	_geode_breaks.clear()
	var doomed := {}
	for dc in range(-radius, radius + 1):
		for dr in range(-radius, radius + 1):
			if dc * dc + dr * dr > radius * radius:
				continue
			var p := top_piece(at.x + dc, at.y + dr)
			if p != HOLE:
				doomed[p] = true
	var pieces := 0
	for p in doomed.keys():
		if is_obstacle(int(plate_kind[p])) or vined.has(p):
			continue
		pieces += 1
		for n in _neighbors(p):
			if _hit_by_pop(n):
				doomed[n] = true
	var fx: Array = []
	_blast = true
	var blasted := _destroy(doomed, 1, fx)
	_blast = false
	var res := _chain(_settle(), fx, 2)
	res["removed"] = int(res["removed"]) + blasted
	res["pieces"] = int(res["pieces"]) + pieces
	res["fx"] = fx
	res["overload"] = _overloaded()
	res["geode_shots"] = _geode_breaks.duplicate()   # a rock from each geode that cracked open
	return res


# --- boosters ----------------------------------------------------------------

# The best drop of any of `kinds` (the Any Piece aims with [WILD]): the piece
# with the biggest match anywhere on the ball, and where -- {"kind", "at", "pieces"}, with kind HOLE
# if none of them can match at all. Ties go to the earlier kind in `kinds`.
func best_piece(kinds: Array) -> Dictionary:
	var best := {"kind": HOLE, "at": Vector2i(0, 0), "pieces": 0}
	for k in kinds:
		var kind := int(k)
		var offsets: Array = SHAPES[kind]["offsets"]
		for c in COLS:
			for r in ROWS:
				var at := Vector2i(c, r)
				if not footprint_valid(offsets, at):
					continue
				var n := combo_preview(offsets, at, kind, landing_depth(offsets, at))
				if n > int(best["pieces"]):
					best = {"kind": kind, "at": at, "pieces": n}
	return best


# Where the Rocks booster's rocks land: up to `count` separate same-type
# groups, each with a piece showing on the surface for a rock to hit, biggest
# first -- a pair is a match one piece short, which is what a rock finishes.
# Returns one Array of piece ids per group. Ties go to the group nearest the
# `near` cell (the aim), so the rocks work where the player is looking.
func rock_targets(count: int, near: Vector2i) -> Array:
	var groups: Array = []
	var seen := {}
	for c in COLS:
		for r in ROWS:
			var p := top_piece(c, r)
			if p == HOLE or seen.has(p) or is_obstacle(int(plate_kind[p])) or vined.has(p):
				continue
			var group := _component(p)
			for g in group:
				seen[g] = true
			var dx := absi(wrap_col(c - near.x + COLS / 2) - COLS / 2)
			groups.append({"ids": group, "size": group.size(), "dist": dx + absi(r - near.y)})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["size"]) != int(b["size"]):
			return int(a["size"]) > int(b["size"])
		return int(a["dist"]) < int(b["dist"]))
	var out: Array = []
	for g in groups.slice(0, count):
		out.append(g["ids"])
	return out


# The rocks land: each group in `groups` is destroyed as if a matching piece
# had joined it, with the blockers touching it, then gravity and chain
# reactions follow as after a drop. Like a bomb, a rock is not a drop and
# never costs a life.
func rock_strike(groups: Array) -> Dictionary:
	_geode_breaks.clear()
	var doomed := {}
	var pieces := 0
	for group in groups:
		for id in group:
			if not plate_kind.has(id) or doomed.has(id):
				continue
			doomed[id] = true
			pieces += 1
			for n in _neighbors(id):
				if _hit_by_pop(n):
					doomed[n] = true
	var fx: Array = []
	_blast = true
	var hit := _destroy(doomed, 1, fx)
	_blast = false
	var res := _chain(_settle(), fx, 2)
	res["removed"] = int(res["removed"]) + hit
	res["pieces"] = int(res["pieces"]) + pieces
	res["fx"] = fx
	res["overload"] = _overloaded()
	res["geode_shots"] = _geode_breaks.duplicate()   # a rock from each geode that cracked open
	return res


## Where the rocks from geodes that cracked open at `from` land: one group
## per rock (see rock_targets), aimed near the first geode.
func geode_targets(shots: Array) -> Array:
	if shots.is_empty():
		return []
	return rock_targets(shots.size(), shots[0])


## Plays out every rock a result's geodes fired -- and the rocks of any geode
## those break in turn -- at once, for code with no flight to show (the sim,
## tests). Returns how many pieces they cleared.
func resolve_geode_shots(res: Dictionary) -> int:
	var shots: Array = res.get("geode_shots", [])
	var pieces := 0
	var guard := 0
	while not shots.is_empty() and guard < 32:
		guard += 1
		var targets := geode_targets(shots)
		if targets.is_empty():
			break
		var more := rock_strike(targets)
		pieces += int(more["pieces"])
		shots = more["geode_shots"]
	return pieces


func _overloaded() -> bool:
	for c in COLS:
		for r in ROWS:
			if cells[c][r].size() > MAX_STACK:
				return true
	return false


func progress() -> float:
	if initial_blocks == 0:
		return 0.0
	return float(cleared_blocks) / float(initial_blocks)


# The biggest connected same-type group on the board (blockers aside). On a
# fresh ball this must stay below MIN_MATCH, or a match is ready-made.
func largest_group() -> int:
	var best := 0
	var seen := {}
	for p in plate_kind:
		if seen.has(p) or is_obstacle(int(plate_kind[p])):
			continue
		var group := _component(p)
		for g in group:
			seen[g] = true
		best = maxi(best, group.size())
	return best


# The surface as the player sees it, as text: each cell's outermost kind, and
# whether it is one piece with the cell to its right and the one above. It is
# the same however the ball is turned (the smallest over every rotation round
# the ring), so two balls with the same signature look alike, even if what
# lies beneath differs.
func surface_signature() -> String:
	var best := ""
	for shift in COLS:
		var s := ""
		for i in COLS:
			var c := i + shift
			for r in ROWS:
				var id := top_piece(c, r)
				s += str(int(plate_kind[id])) if id != HOLE else "."
				s += "r" if id != HOLE and top_piece(c + 1, r) == id else "-"
				s += "u" if id != HOLE and top_piece(c, r + 1) == id else "-"
		if best == "" or s < best:
			best = s
	return best


# Share of blocks that are grey blockers: across the whole ball, or just the
# outermost block of each cell -- the surface the player actually sees.
func grey_share(surface_only: bool) -> float:
	var grey := 0
	var total := 0
	for c in COLS:
		for r in ROWS:
			var stack: Array = cells[c][r]
			var entries: Array = stack.slice(stack.size() - 1) if surface_only else stack
			for p in entries:
				if int(p) == HOLE:
					continue
				total += 1
				if int(plate_kind[p]) == BLOCKER:
					grey += 1
	return 0.0 if total == 0 else float(grey) / float(total)


func exposed_core_cells() -> int:
	var n := 0
	for c in COLS:
		for r in ROWS:
			if cells[c][r].is_empty():
				n += 1
	return n


# --- escape ------------------------------------------------------------------
#
# The creature in the core escapes -- and the level is won -- once there is a
# hole big enough for it: a k-by-k square of cells dug all the way down to the
# core, with nothing left in them at all. A piece lying across the top of a pit
# still blocks the way out, and a long thin trench is not wide enough, however
# long it is.

# The k-by-k patch closest to being open: its south-west cell ("at", with the
# column wrapping) and how many of its cells are open to the core ("open").
func best_escape_patch(k: int) -> Dictionary:
	var best := {"at": Vector2i(0, 0), "open": -1}
	for c in COLS:
		for r in range(0, ROWS - k + 1):
			var n := 0
			for dc in k:
				for dr in k:
					if cells[wrap_col(c + dc)][r + dr].is_empty():
						n += 1
			if n > int(best["open"]):
				best = {"at": Vector2i(c, r), "open": n}
	return best


func has_escape(k: int) -> bool:
	return ties.is_empty() and has_escape_hole(k)


## The hole alone, ties aside: dug wide enough, whatever still holds it down.
func has_escape_hole(k: int) -> bool:
	return int(best_escape_patch(k)["open"]) >= k * k


# Deep copy of the model, used by lookahead search (and handy for undo).
## The ball as plain data, for the level bank: each cell's stack of piece ids
## (deepest first, HOLE for a gap) and each piece's kind. Columns come back
## from the stacks, so nothing else is needed to play it.
func to_dict() -> Dictionary:
	var kinds := {}
	for id in plate_kind:
		kinds[str(id)] = int(plate_kind[id])
	var stacks: Array = []
	for c in COLS:
		var column: Array = []
		for r in ROWS:
			column.append((cells[c][r] as Array).duplicate())
		stacks.append(column)
	var tie_layers := {}
	for id in ties:
		tie_layers[str(id)] = int(ties[id])
	var out := {"cells": stacks, "kinds": kinds, "armor": armored.keys(), "ties": tie_layers}
	if not geodes.is_empty():
		var hits := {}
		for id in geodes:
			hits[str(id)] = int(geodes[id])
		out["geodes"] = hits
	if not vined.is_empty():
		out["vines"] = vined.keys()
		out["vine_clock"] = vine_clock
	if not locked.is_empty():
		out["locks"] = locked.keys()
	if key_piece != HOLE:
		out["key"] = key_piece
	if not prisms.is_empty():
		var tints := {}
		for id in prisms:
			tints[str(id)] = int(prisms[id])
		out["prisms"] = tints
	if not fog.is_empty():
		var clouds := {}
		for c in fog:
			clouds["%d,%d" % [(c as Vector2i).x, (c as Vector2i).y]] = int(fog[c])
		out["fog"] = clouds
	return out


## Loads a ball saved by to_dict (numbers come back from JSON as floats).
func load_dict(data: Dictionary) -> void:
	cells.clear()
	plate_kind.clear()
	plate_cols.clear()
	armored.clear()
	ties.clear()
	geodes.clear()
	prisms.clear()
	fog.clear()
	vined.clear()
	locked.clear()
	key_piece = HOLE
	vine_clock = 0
	_next_id = 0
	for id_str in data["kinds"]:
		var id := int(id_str)
		plate_kind[id] = int(data["kinds"][id_str])
		plate_cols[id] = []
		_next_id = maxi(_next_id, id + 1)
	var stacks: Array = data["cells"]
	for c in COLS:
		var column: Array = []
		for r in ROWS:
			var stack: Array = []
			for v in stacks[c][r]:
				var id := int(v)
				stack.append(id)
				if id != HOLE and not (plate_cols[id] as Array).has(Vector2i(c, r)):
					plate_cols[id].append(Vector2i(c, r))
			column.append(stack)
		cells.append(column)
	# A saved ball is a fresh one, so its deepest stack is how deep it started.
	shell_depth = 1
	for column in cells:
		for stack in column:
			shell_depth = maxi(shell_depth, (stack as Array).size())
	for id in data.get("armor", []):
		if plate_kind.has(int(id)):
			armored[int(id)] = true
	var tie_layers: Dictionary = data.get("ties", {})
	for id_str in tie_layers:
		if plate_kind.has(int(id_str)):
			ties[int(id_str)] = int(tie_layers[id_str])
	var geode_hits: Dictionary = data.get("geodes", {})
	for id_str in geode_hits:
		if plate_kind.has(int(id_str)):
			geodes[int(id_str)] = int(geode_hits[id_str])
	for id in data.get("vines", []):
		if plate_kind.has(int(id)):
			vined[int(id)] = true
	vine_clock = int(data.get("vine_clock", 0))
	for id in data.get("locks", []):
		if plate_kind.has(int(id)):
			locked[int(id)] = true
	if plate_kind.has(int(data.get("key", HOLE))):
		key_piece = int(data["key"])
	var tints: Dictionary = data.get("prisms", {})
	for id_str in tints:
		if plate_kind.has(int(id_str)):
			prisms[int(id_str)] = int(tints[id_str])
	var clouds: Dictionary = data.get("fog", {})
	for k in clouds:
		var xy: PackedStringArray = str(k).split(",")
		fog[Vector2i(int(xy[0]), int(xy[1]))] = int(clouds[k])
	initial_blocks = count_blocks()
	cleared_blocks = 0


func clone() -> TSBoard:
	var b := TSBoard.new()
	b.initial_blocks = initial_blocks
	b.cleared_blocks = cleared_blocks
	b._next_id = _next_id
	b.shell_depth = shell_depth
	b.plate_kind = plate_kind.duplicate()
	b.plate_cols = plate_cols.duplicate(true)
	b.armored = armored.duplicate()
	b.ties = ties.duplicate()
	b.geodes = geodes.duplicate()
	b.vined = vined.duplicate()
	b.vine_clock = vine_clock
	b.locked = locked.duplicate()
	b.key_piece = key_piece
	b.prisms = prisms.duplicate()
	b.fog = fog.duplicate()
	b.cells = []
	for c in COLS:
		var column: Array = []
		for r in ROWS:
			column.append((cells[c][r] as Array).duplicate())
		b.cells.append(column)
	return b
