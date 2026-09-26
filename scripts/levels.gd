# Level definitions. A level chooses which pieces the shell is tiled from and
# which pieces the player is dealt; the rules themselves live in board.gd.
# This file also holds the difficulty tiers and the level plan -- which tier
# every level plays at -- taken from Duckdoku.
class_name TSLevels
extends RefCounted

# The five difficulty tiers, Duckdoku's: Beginner, Intermediate, Hard, Expert,
# Extreme. Each sets Tetrisphere's three levers.
#
# The pieces. Beginner is the two lines, flat and upright. Intermediate adds
# the 2x2 O square, and Hard keeps it; Expert adds the five-block plus on top,
# and Extreme keeps both. Every piece a tier deals is also tiled into its
# shell, so each one has somewhere to match from the first drop.
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
# pieces-only step would suggest (3x3 and 4x4) and a deal that leans hard on
# the common piece. Tuned with tests/sim.gd to keep Duckdoku's win-rate curve.
const LINES := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT]
const WITH_O := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O]
const WITH_PLUS := [TSBoard.I_FLAT, TSBoard.I_UPRIGHT, TSBoard.O, TSBoard.PLUS]
const DIFFICULTIES := [
	{"name": "BEGINNER", "pieces": LINES, "escape_size": 2, "scale": 0.55, "common_bias": 0.8},
	{"name": "INTERMEDIATE", "pieces": WITH_O, "escape_size": 3, "scale": 0.7, "common_bias": 0.65},
	{"name": "HARD", "pieces": WITH_O, "escape_size": 4, "scale": 0.85, "common_bias": 0.5},
	{"name": "EXPERT", "pieces": WITH_PLUS, "escape_size": 3, "scale": 0.7, "common_bias": 0.85},
	{"name": "EXTREME", "pieces": WITH_PLUS, "escape_size": 4, "scale": 0.85, "common_bias": 0.85},
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

static var _bank: Dictionary = {}
static var _bank_loaded := false


## The tier a level plays at.
static func difficulty_for_level(level: int) -> int:
	if level >= 1 and level <= LEVEL_PLAN.size():
		return LEVEL_PLAN[level - 1]
	return LEVEL_LOOP_TEMPLATE[posmod(level - LEVEL_LOOP_START, LEVEL_LOOP_TEMPLATE.size())]


static func tier_name(level: int) -> String:
	return str(DIFFICULTIES[difficulty_for_level(level)]["name"])


## A generated level's seed, so it is the same ball on every attempt.
static func seed_for_level(level: int) -> int:
	return hash("tetrisphere_level_%d" % level)


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
	return _with_pieces(LEVELS[0].duplicate(true), DIFFICULTIES[tier]["pieces"])


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
## flat line and the plus. Dealt and tiled into the shell alike.
const LEVEL_PIECES := {
	3: [TSBoard.O, TSBoard.I_UPRIGHT],
	4: [TSBoard.I_FLAT, TSBoard.PLUS],
}


## A level's full rules: its tier's, except where noted. Level 1's egg is
## only two layers deep (every other egg is three), so the critter is never
## far below -- a gentle first ball -- and levels 3 and 4 have their own
## pieces (LEVEL_PIECES).
static func rules_for_level(level: int) -> Dictionary:
	var rules := rules_for_tier(difficulty_for_level(level))
	if level == 1:
		rules["shell_depth"] = 2
	if LEVEL_PIECES.has(level):
		rules = _with_pieces(rules, LEVEL_PIECES[level])
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
