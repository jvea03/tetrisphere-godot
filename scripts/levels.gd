# Level definitions. A level chooses which pieces the shell is tiled from and
# which pieces the player is dealt; the rules themselves live in board.gd.
# This file also holds the difficulty tiers and the level plan -- which tier
# every level plays at -- taken from Duckdoku.
class_name TSLevels
extends RefCounted

# The five difficulty tiers, Duckdoku's: Beginner, Intermediate, Hard, Expert,
# Extreme. Each sets Tetrisphere's three levers.
#
# The pieces. Beginner is the two lines, flat and upright (and, from level 9,
# any two pieces). Intermediate adds the 2x2 O square. Hard mixes any three
# of the six pieces -- the lines, the square, the plus, the capital L and T --
# and Expert and Extreme any four (see tier_mix); the lists below are each
# tier's first mix. Every piece a level deals is also tiled into its shell,
# so each one has somewhere to match from the first drop.
#
# The size of the creature in the core. A level is won when the creature can
# escape: through a square hole `escape_size` cells across, dug all the way
# down to the core. The bigger the creature, the bigger the hole it needs.
# `scale` is how big it is drawn, relative to the core, so the difficulty is
# visible once you dig down to it.
#
# The deal. `common_bias` is the chance the next piece dealt is the one most
# common on the board, buried or not (see TSBoard.deal_piece); otherwise it
# is one of the others, evenly. An even deal is 1 / the number of pieces --
# 0.5 for Beginner's two, 0.33 for three, 0.25 for four -- so above that you
# mostly get the piece with the most places to match, below it the rarer ones.
#
# The plus is hard to place, and four pieces share out the match spots, so
# Expert and Extreme give some of it back: a smaller critter than their
# pieces alone would suggest (2x2 and 4x4) and a deal that leans hard on
# the common piece. Armour (ARMOR_SHARE) then sets the pace: the win rates
# are tuned with tests/sim.gd to about 95 / 50 / 30 / 20 / 10% for the
# casual sim bot, Beginner to Extreme.
const LINES := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT]
const WITH_O := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O]
const WITH_PLUS := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O, TSBoard.PLUS]
const DIFFICULTIES := [
	{"name": "BEGINNER", "pieces": LINES, "escape_size": 2, "scale": 0.55, "common_bias": 0.8},
	{"name": "INTERMEDIATE", "pieces": WITH_O, "escape_size": 3, "scale": 0.7, "common_bias": 0.65},
	{"name": "HARD", "pieces": WITH_O, "escape_size": 4, "scale": 0.85, "common_bias": 0.5},
	{"name": "EXPERT", "pieces": WITH_PLUS, "escape_size": 3, "scale": 0.55, "common_bias": 0.7},
	{"name": "EXTREME", "pieces": WITH_PLUS, "escape_size": 4, "scale": 0.85, "common_bias": 0.95},
]
const DEFAULT_DIFFICULTY := 1   # INTERMEDIATE
const DIFF_EXTREME := 4

# The level plan, Duckdoku's difficulty curve level for level (its level
# design sheet, "Difficulty Curve"): the tier of each of levels 1-50, which
# are baked into LEVEL_BANK so every player gets the same fifty balls. From
# LEVEL_LOOP_START on, the tiers repeat LEVEL_LOOP_TEMPLATE (Duckdoku's
# levels 51-70) and each ball is generated from its level's seed, so a level
# is the same ball every time it is played. Duckdoku's other two columns --
# board size (6x6 / 8x8 / 10x10) and starting hints -- have no Tetrisphere
# equivalent (the egg is one size, and there are no hints), so only the tier
# carries over.
# 0 Beginner, 1 Intermediate, 2 Hard, 3 Expert, 4 Extreme.
const LEVEL_PLAN := [
	0, 0, 0, 0, 0, 0, 1, 1, 0, 0, # 1-10
	1, 0, 0, 1, 2, 1, 2, 1, 1, 2, # 11-20
	1, 3, 2, 1, 4, 1, 2, 1, 1, 3, # 21-30
	2, 1, 2, 2, 1, 1, 4, 1, 2, 3, # 31-40
	1, 2, 1, 2, 1, 4, 1, 1, 2, 0, # 41-50
]
const LEVEL_LOOP_TEMPLATE := [
	1, 1, 2, 3, 2, 4, 1, 2, 1, 3, # 51-60
	4, 1, 2, 2, 1, 2, 3, 1, 2, 4, # 61-70
]
const LEVEL_LOOP_START := 51
const LEVEL_BANK := "res://levels/levels.json"
const SEARCH_MIX := -1.0   # see rules_for_tier; below -1 changes nothing
## The share of each tier's blockers that wear armour (TSBoard.armored): a hit
## knocks it off, and only then can the blocker be broken -- sliding into it
## does nothing. None in Beginner, more as the tiers climb.
const ARMOR_SHARE := [0.0, 0.5, 0.3, 0.45, 0.12]   # tuned with the 5-cell L and T in the mix
## Tie-downs (TSBoard.TIE): 1x1 stakes of one to three layers, every one of
## which must be broken before the critter can escape. They arrive at
## TIE_FROM_LEVEL and are on every other level from there (the even ones);
## per tier, how many a level has and the most layers each may have.
const TIE_FROM_LEVEL := 10
const TIE_COUNT := [1, 2, 2, 2, 2]
const TIE_LAYERS := [2, 2, 2, 2, 3]
## Geodes (TSBoard.GEODE): 1x2 stones that take three hits and fire a rock as
## they crack open. From GEODE_FROM_LEVEL on the odd levels (tie-downs have
## the even ones), GEODE_COUNT[tier] to an egg.
const GEODE_FROM_LEVEL := 13
const GEODE_COUNT := [1, 1, 2, 2, 2]

static var _bank: Dictionary = {}
static var _bank_loaded := false


## The tier a level plays at.
static func difficulty_for_level(level: int) -> int:
	if level >= 1 and level <= LEVEL_PLAN.size():
		return LEVEL_PLAN[level - 1]
	return LEVEL_LOOP_TEMPLATE[posmod(level - LEVEL_LOOP_START, LEVEL_LOOP_TEMPLATE.size())]


static func tier_name(level: int) -> String:
	return str(DIFFICULTIES[difficulty_for_level(level)]["name"])


## A generated level's seed, so it is the same ball on every attempt. A level
## in SEED_SHIFT takes the seed that many steps on: its first egg played as a
## wall, far below its tier's win rate (chosen with `tests/sim.gd -- probe`).
static func seed_for_level(level: int) -> int:
	return shifted_seed(level, int(SEED_SHIFT.get(level, 0)))


static func base_seed(level: int) -> int:
	return hash("tetrisphere_level_%d" % level)


## Level `level`'s egg number `shift` (0 is its own). A seed family of its own
## -- not base_seed + shift, since neighbouring levels' seeds are 1 apart and
## "the next seed" would be another level's egg.
static func shifted_seed(level: int, shift: int) -> int:
	return base_seed(level) if shift == 0 else hash("tetrisphere_level_%d_egg_%d" % [level, shift])


const SEED_SHIFT := {
	14: 6, 16: 1, 52: 7, 57: 4,          # Intermediate
	34: 3, 42: 1, 58: 6, 63: 6, 64: 2,   # Hard
	22: 5, 54: 5, 60: 4,                 # Expert
	46: 2, 61: 2, 70: 3,                 # Extreme
}


## A baked level's ball (see TSBoard.to_dict), or {} for a generated one.
static func baked_board(level: int) -> Dictionary:
	if not _bank_loaded:
		_bank_loaded = true
		var f := FileAccess.open(LEVEL_BANK, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_bank = parsed
	return _bank.get(str(level), {})


## The Daily Egg: a level picked from today's date, never a Beginner one --
## the same for everyone all day and different tomorrow.
static func daily_level() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("daily_" + Time.get_date_string_from_system())
	var level := rng.randi_range(11, 70)
	while difficulty_for_level(level) == 0:
		level += 1
	return level


## A tier's full level rules: LEVELS[0] with that tier's pieces. The line
## pattern only knows flat and upright lines, so a tier with more pieces tiles
## every layer by search -- which, with the O's and pluses to fill its
## pockets, lands about as little grey on the surface as the pattern does.
## Those tiers also let same types sit side by side (a negative mix; groups
## still never pass seed_group_max): three or four pieces spread the match
## spots thin, and a ball kept fully apart left too few to aim at.
static func rules_for_tier(tier: int) -> Dictionary:
	var rules := _with_pieces(LEVELS[0].duplicate(true), DIFFICULTIES[tier]["pieces"])
	rules["armor_share"] = float(ARMOR_SHARE[tier])
	return rules


static func _with_pieces(rules: Dictionary, pieces: Array) -> Dictionary:
	rules["pieces"] = pieces.duplicate()
	if pieces != LINES:
		rules["generator"] = "search"
		rules["mix"] = SEARCH_MIX
	else:
		rules["generator"] = LEVELS[0]["generator"]
		rules["mix"] = LEVELS[0]["mix"]
	return rules


## Early levels that break from their tier's pieces, each a little lesson in
## shapes: level 3 is only the square and the upright line, level 4 only the
## flat line and the plus, and level 6 the upright line and the plus -- so it
## never looks like level 5, which is the two lines. Dealt and tiled into the
## shell alike.
const LEVEL_PIECES := {
	3: [TSBoard.O, TSBoard.I_UPRIGHT],
	4: [TSBoard.I_FLAT, TSBoard.PLUS],
	6: [TSBoard.I_UPRIGHT, TSBoard.PLUS],
}

## After level BEGINNER_MIX_FROM, a Beginner level is any two of the four
## pieces rather than always the two lines: each takes the next pair in this
## rotation (by how many such levels came before it), so the six pairs all
## come round in turn and no two in a row match.
const BEGINNER_MIX_FROM := 9
const BEGINNER_PAIRS := [
	[TSBoard.I_FLAT, TSBoard.O],
	[TSBoard.I_UPRIGHT, TSBoard.PLUS],
	[TSBoard.I_FLAT, TSBoard.I_UPRIGHT],
	[TSBoard.O, TSBoard.PLUS],
	[TSBoard.I_UPRIGHT, TSBoard.O],
	[TSBoard.I_FLAT, TSBoard.PLUS],
]


## The six pieces the harder tiers mix from: the two lines, the square, the
## plus, the capital L and the capital T.
const PIECE_POOL := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O, TSBoard.PLUS, TSBoard.L, TSBoard.T]
## How many of PIECE_POOL each mixing tier uses: Hard any three, Expert and
## Extreme any four. Each level of the tier takes the next combination in turn
## (by how many levels of that tier came before it), so every combination
## comes round and no two in a row match. Each tier keeps its own turn.
const TIER_MIX := {2: 3, 3: 4, 4: 4}


## Every way to pick k of PIECE_POOL, in a fixed order.
static func _combos(k: int, from := 0) -> Array:
	if k == 0:
		return [[]]
	var out: Array = []
	for i in range(from, PIECE_POOL.size() - k + 1):
		for rest in _combos(k - 1, i + 1):
			out.append([PIECE_POOL[i]] + rest)
	return out


## The pieces a Hard, Expert or Extreme level is built from.
static func tier_mix(level: int) -> Array:
	var tier := difficulty_for_level(level)
	var combos := _combos(int(TIER_MIX[tier]))
	var before := 0
	for l in range(1, level):
		if difficulty_for_level(l) == tier:
			before += 1
	return combos[before % combos.size()]


## The two pieces a Beginner level from BEGINNER_MIX_FROM on is built from.
static func beginner_pair(level: int) -> Array:
	var before := 0
	for l in range(BEGINNER_MIX_FROM, level):
		if difficulty_for_level(l) == 0:
			before += 1
	return BEGINNER_PAIRS[before % BEGINNER_PAIRS.size()]


## A level's full rules: its tier's, except where noted. Level 1's egg is
## only two layers deep (every other egg is three), so the critter is never
## far below -- a gentle first ball; levels 3, 4 and 6 have their own pieces
## (LEVEL_PIECES); Beginner levels from BEGINNER_MIX_FROM on are any two
## pieces (beginner_pair); and Hard, Expert and Extreme levels mix three or
## four of the six pieces (tier_mix).
static func rules_for_level(level: int) -> Dictionary:
	var rules := rules_for_tier(difficulty_for_level(level))
	if has_geodes(level):
		rules["geodes"] = GEODE_COUNT[difficulty_for_level(level)]
	if has_ties(level):
		var tier := difficulty_for_level(level)
		rules["ties"] = TIE_COUNT[tier]
		rules["tie_layers"] = TIE_LAYERS[tier]
	if level == 1:
		rules["shell_depth"] = 2
	if LEVEL_PIECES.has(level):
		rules = _with_pieces(rules, LEVEL_PIECES[level])
	elif TIER_MIX.has(difficulty_for_level(level)):
		rules = _with_pieces(rules, tier_mix(level))
	elif level >= BEGINNER_MIX_FROM and difficulty_for_level(level) == 0:
		rules = _with_pieces(rules, beginner_pair(level))
	# Two or more five-cell pieces and no square to fill the gaps between them
	# leave few ways to match: such a heavy mix digs a hole one size smaller,
	# and is challenge enough without tie-downs on top.
	if heavy_mix(rules["pieces"]):
		rules["escape_size"] = int(DIFFICULTIES[difficulty_for_level(level)]["escape_size"]) - 1
		rules.erase("ties")
		rules.erase("tie_layers")
	return rules


# The rules every level shares. This is Beginner's; rules_for_tier swaps in
# each tier's pieces.
const LEVELS := [
	{
		"name": "RESCUE 1:1",
		# Dealt to the player, and tiled into the shell (set per tier).
		"pieces": LINES,
		# "pattern" lays the surface and bottom layer out from a fixed
		# flat/upright pattern that is 20% grey (see TSBoard); the search fills
		# the hidden middle layer. Search alone ran about 40% grey here.
		"generator": "pattern",
		# Largest connected same-type group a fresh ball may hold. At 2, every
		# match is one the player builds; above 3, a drop beside a ready-made
		# group would destroy the whole group.
		"seed_group_max": 2,
		# Most of each layer the generator may fill with blockers, as a share.
		# It backs up and rearranges pieces to stay under this, where it can.
		"blocker_cap": 1.0,
		# Chance the generator reaches for a blocker before trying a piece.
		"blocker_share": 0.08,
		# How hard the generator keeps same types apart (0 = not at all;
		# negative draws them together, up to seed_group_max), so
		# the colours interleave instead of forming bands.
		"mix": 1.0,
		# Never hand over a piece with nowhere to make a match when another
		# piece has somewhere; a forced miss would cost a life however you play.
		"fair_deal": true,
	},
]


## Whether this level's egg has tie-downs (see TIE_FROM_LEVEL).
static func has_ties(level: int) -> bool:
	return level >= TIE_FROM_LEVEL and level % 2 == 0


## A mix with two or more five-cell pieces (plus, L, T) and no O square:
## the hardest to match in, so its hole is one size smaller (rules_for_level).
static func heavy_mix(pieces: Array) -> bool:
	if pieces.has(TSBoard.O):
		return false
	var big := 0
	for k in pieces:
		if (TSBoard.SHAPES[int(k)]["offsets"] as Array).size() >= 5:
			big += 1
	return big >= 2


## Whether this level's egg has geodes (see GEODE_FROM_LEVEL).
static func has_geodes(level: int) -> bool:
	return level >= GEODE_FROM_LEVEL and level % 2 == 1
