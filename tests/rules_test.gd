# Hand-built positions that pin down the rules the sim bots never exercise
# directly: sliding, matches spreading through connected pieces, gravity, and
# chain reactions. Run with:
#   Godot.exe --headless --path . --script res://tests/rules_test.gd
extends SceneTree

const FLAT := TSBoard.I_FLAT
const UP := TSBoard.I_UPRIGHT

var _failures := 0


func _initialize() -> void:
	_test_slide()
	_test_slide_match_and_gravity()
	_test_slide_from_surface()
	_test_match()
	_test_no_match()
	_test_match_spreads()
	_test_gravity_and_chain()
	_test_pattern_generator()
	_test_square_and_plus()
	_test_search_generator()
	_test_escape()
	_test_deal()
	_test_bomb()
	_test_swap_and_rocks()
	_test_armor()
	_test_pieces_stay_whole()
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _empty_board() -> TSBoard:
	var b := TSBoard.new()
	for c in TSBoard.COLS:
		var column: Array = []
		for r in TSBoard.ROWS:
			column.append([])
		b.cells.append(column)
	return b


func _flat(b: TSBoard, x: int, row: int, depth := 0) -> int:
	return b._add_plate(FLAT, [Vector2i(x, row), Vector2i(x + 1, row), Vector2i(x + 2, row), Vector2i(x + 3, row)], depth)


func _upright(b: TSBoard, col: int, row: int, depth := 0) -> int:
	return b._add_plate(UP, [Vector2i(col, row), Vector2i(col, row + 1), Vector2i(col, row + 2), Vector2i(col, row + 3)], depth)


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


# Sliding moves a piece already on the ball: blockers in its way are smashed,
# another Tetris piece stops it, and blockers themselves cannot be slid.
func _test_slide() -> void:
	var b := _empty_board()
	var mover := _flat(b, 0, 2)
	var blocker := b._add_plate(TSBoard.BLOCKER, [Vector2i(4, 2)])
	var wall := _flat(b, 6, 2)
	var far := b._add_plate(TSBoard.BLOCKER, [Vector2i(15, 6)])

	_check("slide preview: pushing into the blocker smashes 1", b.slide_preview(mover, Vector2i(1, 0)) == 1)
	var res := b.slide(mover, Vector2i(1, 0))
	_check("the piece on the ball moves one cell", bool(res["moved"]) and b.plate_cols[mover][0] == Vector2i(1, 2))
	_check("the blocker in its way is smashed", int(res["smashed"]) == 1 and not b.plate_kind.has(blocker))

	res = b.slide(mover, Vector2i(1, 0))
	_check("sliding into open space moves without smashing", bool(res["moved"]) and int(res["smashed"]) == 0)

	var before := b.count_blocks()
	res = b.slide(mover, Vector2i(1, 0))
	_check("sliding into another Tetris piece is blocked", not bool(res["moved"]))
	_check("a blocked slide changes nothing",
		b.plate_kind.has(wall) and b.count_blocks() == before and b.plate_cols[mover][0] == Vector2i(2, 2))
	_check("blockers themselves cannot be slid", not bool(b.slide(far, Vector2i(1, 0))["moved"]))


# A slide only moves pieces: bringing three same-type pieces together does not
# destroy them -- a drop does. And only pieces of the type you hold can slide.
func _test_slide_match_and_gravity() -> void:
	var b := _empty_board()
	var a := _flat(b, 0, 5)
	var c := _flat(b, 4, 5)        # A and C: a flat pair, end to end
	var mover := _flat(b, 0, 3)    # two rows below A
	var up := _upright(b, 12, 0)
	_check("holding a flat line, a flat line on the ball can slide", b.can_slide(mover, FLAT))
	_check("holding a flat line, an upright on the ball cannot", not b.can_slide(up, FLAT))
	_check("holding an upright, a flat line on the ball cannot", not b.can_slide(mover, UP))

	var res := b.slide(mover, Vector2i(0, 1))
	_check("sliding a line up against a flat pair moves it", bool(res["moved"]) and b.plate_cols[mover][0] == Vector2i(0, 4))
	_check("...but never triggers a match: all three are still there",
		b.plate_kind.has(a) and b.plate_kind.has(c) and b.plate_kind.has(mover) and not res.has("pieces"))

	# The drop is what matches: a flat line dropped onto the slid one joins the
	# group of three it now touches.
	var drop := b.place_and_resolve(TSBoard.SHAPES[FLAT]["offsets"], Vector2i(0, 4), FLAT)
	_check("a drop onto the slid group destroys it", int(drop["pieces"]) == 4 and not b.plate_kind.has(mover))

	var g := _empty_board()
	_flat(g, 0, 2)                   # a floor under columns 0-3
	var rider := _upright(g, 0, 0, 1)  # upright on the floor's left end, one layer up
	g.slide(rider, Vector2i(-1, 0))  # off the floor's edge, over nothing
	_check("a piece slid out over a hole falls to the layer below", g.depth_of(rider) == 0)


# On real Level 1 balls: holding a flat line, some flat line on the surface can
# always be slid into the grey row beside it, smashing the grey.
func _test_slide_from_surface() -> void:
	var always := true
	for seed_value in 20:
		var ball := TSBoard.new()
		ball.generate(seed_value, TSLevels.LEVELS[0])
		var found := false
		for c in TSBoard.COLS:
			for r in TSBoard.ROWS:
				var id := ball.top_piece(c, r)
				if found or not ball.can_slide(id, FLAT):
					continue
				for dir in TSBoard.DIRS:
					if ball.slide_preview(id, dir) > 0:
						found = true
		if not found:
			always = false
	_check("20 Level 1 balls: a flat line on the surface can always slide through grey", always)


func _test_match() -> void:
	var b := _empty_board()
	var a := _flat(b, 0, 5)
	var c := _flat(b, 4, 5)
	var touching_blocker := b._add_plate(TSBoard.BLOCKER, [Vector2i(8, 5)])
	var far_blocker := b._add_plate(TSBoard.BLOCKER, [Vector2i(15, 5)])
	var shape: Array = TSBoard.SHAPES[FLAT]["offsets"]
	var at := Vector2i(2, 5)

	var preview := b.combo_preview(shape, at, FLAT, b.landing_depth(shape, at))
	var res := b.place_and_resolve(shape, at, FLAT)
	_check("drop onto two touching flat lines destroys all three", int(res["pieces"]) == 3)
	_check("aim preview agrees with the drop", preview == int(res["pieces"]))
	_check("both lines are gone", not b.plate_kind.has(a) and not b.plate_kind.has(c))
	_check("a blocker touching a destroyed piece shatters", not b.plate_kind.has(touching_blocker))
	_check("a blocker not touching anything destroyed stays", b.plate_kind.has(far_blocker))


func _test_no_match() -> void:
	var b := _empty_board()
	var a := _flat(b, 0, 5)
	var shape: Array = TSBoard.SHAPES[FLAT]["offsets"]
	var at := Vector2i(0, 5)

	var preview := b.combo_preview(shape, at, FLAT, b.landing_depth(shape, at))
	var res := b.place_and_resolve(shape, at, FLAT)
	_check("drop onto a single line is no match", int(res["chain"]) == 0)
	_check("aim preview warns of the miss", preview == 0)
	_check("the missed piece stays on the ball", b.plate_kind.has(a) and b.count_blocks() == 8)


# The drop touches only A, but A is connected to B, and B to C: the whole
# connected group goes, including C, which the dropped piece never touched.
func _test_match_spreads() -> void:
	var b := _empty_board()
	var a := _flat(b, 0, 2)
	var bb := _flat(b, 0, 3)
	var c := _flat(b, 4, 3)
	var shape: Array = TSBoard.SHAPES[FLAT]["offsets"]
	var at := Vector2i(0, 2)   # lands on A only

	var preview := b.combo_preview(shape, at, FLAT, b.landing_depth(shape, at))
	var res := b.place_and_resolve(shape, at, FLAT)
	_check("the whole connected group is destroyed (4 pieces)", int(res["pieces"]) == 4)
	_check("a piece the drop never touched goes with its group", not b.plate_kind.has(c))
	_check("aim preview counts the whole group", preview == 4)
	_check("group pieces A and B are gone", not b.plate_kind.has(a) and not b.plate_kind.has(bb))


# F1 and F2 are a flat pair holding up U. Dropping a third flat destroys the
# pair; U loses its support, falls a layer, lands beside the upright pair V1
# and V2 -- three connected uprights -- and those explode too.
func _test_gravity_and_chain() -> void:
	var b := _empty_board()
	_flat(b, 3, 2)                 # F1, depth 0
	_flat(b, 7, 2)                 # F2, touches F1 end to end
	var u := _upright(b, 3, 0, 1)  # U, depth 1, held up only by F1 at (3, 2)
	var v1 := _upright(b, 2, 0)    # V1 and V2: an upright pair, depth 0
	var v2 := _upright(b, 1, 0)
	var keep := b._add_plate(TSBoard.BLOCKER, [Vector2i(15, 6)])
	_check("setup: U starts in layer 1", b.depth_of(u) == 1)

	var shape: Array = TSBoard.SHAPES[FLAT]["offsets"]
	var res := b.place_and_resolve(shape, Vector2i(4, 2), FLAT)
	_check("the drop sets off a chain of 2", int(res["chain"]) == 2)
	_check("the chain destroys 6 pieces (3 flats, then 3 uprights)", int(res["pieces"]) == 6)
	_check("the falling piece and the pair it landed by are gone",
		not b.plate_kind.has(u) and not b.plate_kind.has(v1) and not b.plate_kind.has(v2))
	_check("pieces away from the chain are untouched", b.plate_kind.has(keep))

	# Gravity on its own: a piece that loses its only support drops a layer.
	_gravity_only()


# Level 1's generator, over many seeds: never a ready-made match, a surface at
# most 27.5% grey (two or three varied units a layer), and a whole, gap-free ball
# every time.
func _test_pattern_generator() -> void:
	var level: Dictionary = TSLevels.LEVELS[0]
	var worst_group := 0
	var worst_surface := 0.0
	var least_surface := 1.0
	var all_full := true
	for seed_value in 50:
		var b := TSBoard.new()
		b.generate(seed_value, level)
		worst_group = maxi(worst_group, b.largest_group())
		worst_surface = maxf(worst_surface, b.grey_share(true))
		least_surface = minf(least_surface, b.grey_share(true))
		for c in TSBoard.COLS:
			for r in TSBoard.ROWS:
				var stack: Array = b.cells[c][r]
				if stack.size() != TSBoard.SHELL_DEPTH or stack.has(TSBoard.HOLE):
					all_full = false
	_check("50 balls: no same-type group bigger than a pair (worst %d)" % worst_group, worst_group <= 2)
	_check("50 balls: surface at most 27.5%% grey (worst %.1f%%)" % (worst_surface * 100.0), worst_surface <= 0.2751)
	_check("50 balls: every cell filled to full depth, no gaps", all_full)
	_check("50 balls: every surface is varied, none all plain units (least %.1f%% grey)" % (least_surface * 100.0), least_surface >= 0.2499)

	# Both lines must have somewhere to match on a fresh ball, or the fair deal
	# only ever hands out one of them.
	var both := true
	for seed_value in 20:
		var b := TSBoard.new()
		b.generate(seed_value, level)
		if not (b.has_combo_spot(FLAT) and b.has_combo_spot(UP)):
			both = false
	_check("20 balls: flat and upright lines both have a match spot at the start", both)


# The win: a hole 3 cells square, dug right down to the core.
func _test_escape() -> void:
	var b := _empty_board()
	var at := {}
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			at[Vector2i(c, r)] = b._add_plate(TSBoard.BLOCKER, [Vector2i(c, r)])

	# A trench 3 wide but only 2 deep: not wide enough, however open it is.
	for c in [5, 6, 7]:
		for r in [2, 3]:
			b._remove_plate(at[Vector2i(c, r)])
	_check("a 3x2 opening is not an escape", not b.has_escape(3))
	_check("...and the best 3x3 patch counts its 6 open cells", int(b.best_escape_patch(3)["open"]) == 6)

	for c in [5, 6, 7]:
		b._remove_plate(at[Vector2i(c, 4)])
	_check("a 3x3 hole to the core lets the creature escape", b.has_escape(3))

	# A piece lying across the top of the pit still blocks the way out.
	var lid := b._add_plate(FLAT, [Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)], 1)
	_check("a piece bridging over the hole blocks the escape", not b.has_escape(3))
	b._remove_plate(lid)

	# The ball wraps: a hole straddling the seam between column 19 and 0 counts.
	var w := _empty_board()
	var cells := {}
	for c in TSBoard.COLS:
		for r in TSBoard.ROWS:
			cells[Vector2i(c, r)] = w._add_plate(TSBoard.BLOCKER, [Vector2i(c, r)])
	for c in [19, 0, 1]:
		for r in [5, 6, 7]:
			w._remove_plate(cells[Vector2i(c, r)])
	_check("a hole across the ball's seam counts", w.has_escape(3))


func _gravity_only() -> void:
	var g := _empty_board()
	var floor_piece := _flat(g, 0, 4)
	var rider := _upright(g, 0, 1, 1)
	g._remove_plate(floor_piece)
	var moved := g._settle()
	_check("an unsupported piece falls to the next layer", moved.has(rider) and g.depth_of(rider) == 0)


# The dealer favours the piece most common on the board by `common_bias`,
# counting every piece, buried or showing.
func _test_deal() -> void:
	var b := _empty_board()
	_flat(b, 0, 0)
	_flat(b, 4, 0)
	_flat(b, 8, 0)
	_upright(b, 0, 4)
	_upright(b, 1, 4)
	# Two more uprights, buried under grey all along. Only three flats show
	# against two uprights, but the buried pair count too.
	_upright(b, 12, 1)
	_upright(b, 16, 1)
	for col in [12, 16]:
		for r in range(1, 5):
			b._add_plate(TSBoard.BLOCKER, [Vector2i(col, r)], 1)
	var counts := b.piece_counts([FLAT, UP])
	_check("counts every piece, buried ones too (3 flat, 4 upright): %s" % counts,
		counts[FLAT] == 3 and counts[UP] == 4)
	_check("most common on the board is the upright, though fewer show", b.most_common([FLAT, UP]) == UP)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for bias in [0.8, 0.5, 0.2, 0.0, 1.0]:
		var common := 0
		for _i in 2000:
			if b.deal_piece([FLAT, UP], bias, rng) == UP:
				common += 1
		var share := float(common) / 2000.0
		_check("bias %.1f deals the common piece %.1f%% of the time" % [bias, share * 100.0], absf(share - bias) < 0.04)

	var tie := _empty_board()
	_flat(tie, 0, 0)
	_upright(tie, 0, 2)
	_check("a tie has no most common piece", tie.most_common([FLAT, UP]) == TSBoard.HOLE)
	var flats := 0
	for _i in 2000:
		if tie.deal_piece([FLAT, UP], 0.9, rng) == FLAT:
			flats += 1
	_check("a tie deals evenly whatever the bias (%.1f%% flat)" % (flats / 20.0), absf(flats / 2000.0 - 0.5) < 0.04)


# A bomb destroys whole pieces: any piece showing in the blast goes entirely,
# even the blocks outside the circle, and grey touching them shatters.
func _test_bomb() -> void:
	var b := _empty_board()
	var hit := _flat(b, 0, 3)          # cols 0-3; the blast at (0, 3) reaches cols 18-2
	var grey := b._add_plate(TSBoard.BLOCKER, [Vector2i(4, 3)])   # touches `hit`, outside the blast
	var far := _flat(b, 10, 3)
	var res := b.detonate(Vector2i(0, 3), 2)
	_check("bomb destroys a piece whole, blocks outside the blast too", not b.plate_kind.has(hit))
	_check("bomb shatters grey touching a destroyed piece", not b.plate_kind.has(grey))
	_check("bomb leaves pieces outside the blast alone", b.plate_kind.has(far))
	_check("bomb counts the pieces it destroys (%d)" % int(res["pieces"]), int(res["pieces"]) >= 1)
	_check("no stubs left after a bomb", _all_whole(b))


# Every piece on the board is always whole: the right number of blocks, all in
# one layer. Plays random drops, slides and bombs over many balls.
# Intermediate's O square and Expert's plus match like the lines do: a drop
# onto a touching pair of its own kind destroys all three.
func _test_square_and_plus() -> void:
	var b := _empty_board()
	var o_shape: Array = TSBoard.SHAPES[TSBoard.O]["offsets"]
	var o1 := b._add_plate(TSBoard.O, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)])
	var o2 := b._add_plate(TSBoard.O, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)])
	var res := b.place_and_resolve(o_shape, Vector2i(1, 2), TSBoard.O)
	_check("an O dropped across two touching O's destroys all three", int(res["pieces"]) == 3 and not b.plate_kind.has(o1) and not b.plate_kind.has(o2))

	var p := _empty_board()
	var plus_shape: Array = TSBoard.SHAPES[TSBoard.PLUS]["offsets"]
	var a := p._add_plate(TSBoard.PLUS, [Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 4)])
	var c := p._add_plate(TSBoard.PLUS, [Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4)])
	var flat := _flat(p, 10, 5)
	var at := Vector2i(1, 1)   # onto the first plus's left and bottom arms
	var preview := p.combo_preview(plus_shape, at, TSBoard.PLUS, p.landing_depth(plus_shape, at))
	res = p.place_and_resolve(plus_shape, at, TSBoard.PLUS)
	_check("a plus dropped onto a touching pair of pluses destroys all three", int(res["pieces"]) == 3 and not p.plate_kind.has(a) and not p.plate_kind.has(c))
	_check("aim preview agrees for the plus", preview == 3)
	_check("the plus leaves other kinds alone", p.plate_kind.has(flat))

	var miss := _empty_board()
	_flat(miss, 0, 3)
	_flat(miss, 4, 3)
	res = miss.place_and_resolve(o_shape, Vector2i(3, 3), TSBoard.O)
	_check("an O dropped onto two flat lines matches nothing", int(res["pieces"]) == 0)


# The tiers with the O and the plus tile every layer by search. Their balls
# keep the same promises as Level 1's: no ready-made match, no gaps, every
# piece whole, a surface mostly free of grey -- and every piece the tier deals
# is on the ball.
func _test_search_generator() -> void:
	for tier in [1, 3]:
		var rules := TSLevels.rules_for_tier(tier)
		var pieces: Array = rules["pieces"]
		var worst_group := 0
		var worst_surface := 0.0
		var all_full := true
		var all_whole := true
		var all_present := true
		var spots := 0
		for seed_value in 30:
			var b := TSBoard.new()
			b.generate(900 + seed_value, rules)
			worst_group = maxi(worst_group, b.largest_group())
			worst_surface = maxf(worst_surface, b.grey_share(true))
			all_whole = all_whole and _all_whole(b)
			for c in TSBoard.COLS:
				for r in TSBoard.ROWS:
					var stack: Array = b.cells[c][r]
					if stack.size() != TSBoard.SHELL_DEPTH or stack.has(TSBoard.HOLE):
						all_full = false
			var counts := b.piece_counts(pieces)
			for kind in pieces:
				all_present = all_present and int(counts[int(kind)]) > 0
				if b.has_combo_spot(int(kind)):
					spots += 1
		var tag := str(TSLevels.DIFFICULTIES[tier]["name"]).capitalize()
		_check("%s, 30 balls: no same-type group bigger than a pair (worst %d)" % [tag, worst_group], worst_group <= 2)
		_check("%s, 30 balls: surface at most 35%% grey (worst %.1f%%)" % [tag, worst_surface * 100.0], worst_surface <= 0.35)
		_check("%s, 30 balls: every cell filled to full depth, pieces whole" % tag, all_full and all_whole)
		_check("%s, 30 balls: every piece it deals is in the shell" % tag, all_present)
		_check("%s, 30 balls: %d of %d dealt pieces have a match spot at the start" % [tag, spots, 30 * pieces.size()], spots >= 30 * pieces.size() * 0.8)


# The Swap picks the piece with the biggest match and where; Rocks hit the
# biggest groups showing and finish them like a matching drop would.
func _test_swap_and_rocks() -> void:
	var b := _empty_board()
	var f1 := _flat(b, 0, 5)
	var f2 := _flat(b, 4, 5)           # a flat pair: a flat drop onto it makes 3
	var o1 := b._add_plate(TSBoard.O, [Vector2i(12, 1), Vector2i(13, 1), Vector2i(12, 2), Vector2i(13, 2)])
	var o2 := b._add_plate(TSBoard.O, [Vector2i(14, 1), Vector2i(15, 1), Vector2i(14, 2), Vector2i(15, 2)])
	var lone := _upright(b, 18, 2)     # alone: an upright can match nowhere
	var grey := b._add_plate(TSBoard.BLOCKER, [Vector2i(8, 5)])   # touches the flat pair

	var pick := b.best_piece([UP, FLAT])
	_check("the Swap passes over a piece that can't match and picks the flat line", int(pick["kind"]) == FLAT and int(pick["pieces"]) >= 3)
	var flat_offsets: Array = TSBoard.SHAPES[FLAT]["offsets"]
	var at: Vector2i = pick["at"]
	_check("and a spot where the flat line really makes that match", b.combo_preview(flat_offsets, at, FLAT, b.landing_depth(flat_offsets, at)) == int(pick["pieces"]))
	_check("with nothing that can match, the Swap has no pick", int(b.best_piece([UP])["kind"]) == TSBoard.HOLE)

	var targets := b.rock_targets(2, Vector2i(2, 5))
	var hit := {}
	for g in targets:
		for id in g:
			hit[id] = true
	_check("the two rocks go for the two pairs, not the lone upright", targets.size() == 2 and hit.has(f1) and hit.has(f2) and hit.has(o1) and hit.has(o2) and not hit.has(lone))
	var res := b.rock_strike(targets)
	_check("the rocks finish both matches: 4 pieces gone", int(res["pieces"]) == 4 and not b.plate_kind.has(f1) and not b.plate_kind.has(o2))
	_check("grey touching a struck group shatters; the rest stays", not b.plate_kind.has(grey) and b.plate_kind.has(lone))
	_check("with fewer groups than rocks, the rocks take what there is", b.rock_targets(2, Vector2i(0, 0)).size() == 1)


# Armoured blockers: a hit knocks the armour off, a second hit breaks the
# blocker, and a slide can't get through armour at all.
func _test_armor() -> void:
	var b := _empty_board()
	var a := _flat(b, 0, 5)
	var c := _flat(b, 4, 5)
	var armour := b._add_plate(TSBoard.BLOCKER, [Vector2i(8, 5)])
	b.armored[armour] = true
	var shape: Array = TSBoard.SHAPES[FLAT]["offsets"]
	b.place_and_resolve(shape, Vector2i(2, 5), FLAT)
	_check("a match beside an armoured blocker knocks the armour off but leaves the blocker", not b.plate_kind.has(a) and not b.plate_kind.has(c) and b.plate_kind.has(armour) and not b.armored.has(armour))
	var d := _flat(b, 9, 5)
	var e := _flat(b, 13, 5)
	b.place_and_resolve(shape, Vector2i(11, 5), FLAT)
	_check("a second hit breaks it", not b.plate_kind.has(armour) and not b.plate_kind.has(d) and not b.plate_kind.has(e))

	var s := _empty_board()
	var mover := _flat(s, 0, 3)
	var steel := s._add_plate(TSBoard.BLOCKER, [Vector2i(4, 3)])
	s.armored[steel] = true
	_check("sliding into an armoured blocker is blocked", s.slide_preview(mover, Vector2i(1, 0)) < 0 and not bool(s.slide(mover, Vector2i(1, 0))["moved"]) and s.plate_kind.has(steel))
	s.armored.erase(steel)
	_check("once its armour is off, a slide smashes it like any blocker", s.slide_preview(mover, Vector2i(1, 0)) == 1 and bool(s.slide(mover, Vector2i(1, 0))["moved"]) and not s.plate_kind.has(steel))

	var bomb := _empty_board()
	var shell := bomb._add_plate(TSBoard.BLOCKER, [Vector2i(5, 4)])
	bomb.armored[shell] = true
	bomb.detonate(Vector2i(5, 4), 2)
	_check("a bomb counts as a hit: armour off, blocker still there", bomb.plate_kind.has(shell) and not bomb.armored.has(shell))

	var ball := TSBoard.new()
	ball.generate(4242, TSLevels.rules_for_tier(2))
	var blockers := 0
	for id in ball.plate_kind:
		if int(ball.plate_kind[id]) == TSBoard.BLOCKER:
			blockers += 1
	var share := float(ball.armored.size()) / maxf(blockers, 1.0)
	var back := TSBoard.new()
	back.load_dict(ball.to_dict())
	var want: float = TSLevels.ARMOR_SHARE[2]
	_check("a Hard ball armours about %d%% of its blockers (%d%%)" % [roundi(want * 100.0), roundi(share * 100.0)], share > want * 0.4 and share < want * 2.0)
	_check("armour survives saving and copying", back.armored.size() == ball.armored.size() and ball.clone().armored.size() == ball.armored.size())
	var easy := TSBoard.new()
	easy.generate(4242, TSLevels.rules_for_tier(0))
	_check("Beginner balls have no armour", easy.armored.is_empty())


func _test_pieces_stay_whole() -> void:
	for tier in [0, 3]:
		_pieces_stay_whole(tier)


func _pieces_stay_whole(tier: int) -> void:
	var rules := TSLevels.rules_for_tier(tier)
	var pieces: Array = rules["pieces"]
	var rng := RandomNumberGenerator.new()
	var broken := {}
	for s in 12:
		var b := TSBoard.new()
		b.generate(500 + s, rules)
		rng.seed = s
		if not _all_whole(b):
			broken["generate"] = true
		for _t in 40:
			var roll := rng.randf()
			var what := ""
			if roll < 0.6:
				var k: int = pieces[rng.randi() % pieces.size()]
				var at := Vector2i(rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1))
				if b.footprint_valid(TSBoard.SHAPES[k]["offsets"], at):
					b.place_and_resolve(TSBoard.SHAPES[k]["offsets"], at, k)
					what = "drop"
			elif roll < 0.9:
				var id := b.top_piece(rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1))
				if b.plate_kind.has(id) and int(b.plate_kind[id]) != TSBoard.BLOCKER:
					b.slide(id, TSBoard.DIRS[rng.randi() % 4])
					what = "slide"
			else:
				b.detonate(Vector2i(rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1)), 2)
				what = "bomb"
			if what != "" and not _all_whole(b):
				broken[what] = true
	_check("%s pieces stay whole through drops, slides and bombs (broken by: %s)" % [str(TSLevels.DIFFICULTIES[tier]["name"]).capitalize(), broken.keys()], broken.is_empty())


func _all_whole(b: TSBoard) -> bool:
	for id in b.plate_kind:
		var kind := int(b.plate_kind[id])
		var cols: Array = b.plate_cols[id]
		var want := 1 if kind == TSBoard.BLOCKER else (TSBoard.SHAPES[kind]["offsets"] as Array).size()
		if cols.size() != want:
			return false
		var depth := -2
		for col in cols:
			var v: Vector2i = col
			var d := (b.cells[v.x][v.y] as Array).find(id)
			if d < 0 or (depth != -2 and d != depth):
				return false
			depth = d
	return true
