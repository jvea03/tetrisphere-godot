class_name TSBots
extends RefCounted

## Computer players that top up a thin Daily, Weekly or Season leaderboard to
## FILL (the "bots_fill_to" tunable, 20; 0 turns them off). Each real player on
## the board takes one bot's place. Nothing about a bot goes to the server:
## every phone works them out from the board's id, so everyone sees the same
## names, critters and scores. Their stars grow as the board's day, week or
## season goes by, and they stand in the final places too, so what a player
## sees is what they are paid (TSProfile.resolve_board_results). The Snowball
## Fight boards have none. docs/online.md.

const NAMES := [
	"Sunny", "Pip", "Marshmallow", "Bean", "Clover", "Waffles", "Juniper", "Tofu", "Biscuit", "Pebble",
	"Noodle", "Maple", "Sprout", "Dumpling", "Comet", "Peaches", "Mochi", "Rascal", "Button", "Ziggy",
	"Poppy", "Nacho", "Willow", "Gizmo", "Pickle", "Luna", "Cocoa", "Bumble", "Fern", "Pretzel",
	"Sparky", "Olive", "Taffy", "Moss", "Kiwi", "Dizzy", "Honey", "Rocket", "Plum", "Snickers",
]
const UID_PREFIX := "bot_"
## The most stars a bot ends a board with: a day, a week, and per day of a
## season -- within reach of someone who plays a good few levels.
const TOP_DAILY := 30
const TOP_WEEKLY := 140
const TOP_SEASON_PER_DAY := 14


static func is_bot(uid: String) -> bool:
	return uid.begins_with(UID_PREFIX)


static func has_bots(board: String) -> bool:
	return board.get_slice("_", 0) in ["daily", "weekly", "season"]


## How many bots a board with `real` players on it gets.
static func fill_count(board: String, real: int) -> int:
	if not has_bots(board):
		return 0
	return clampi(mini(TSTunables.get_int("bots_fill_to"), NAMES.size()) - real, 0, NAMES.size())


## How far through its day, week or season the current board is, 0 to 1.
static func progress(board: String) -> float:
	var left := 0.0
	var length := 86400.0
	match board.get_slice("_", 0):
		"daily":
			left = TSProfile.seconds_until_board_day()
		"weekly":
			left = TSProfile.seconds_until_board_week()
			length *= 7.0
		_:
			left = TSProfile.seconds_until_season_reset()
			length *= TSProfile.period_length_days("season")
	return clampf(1.0 - left / length, 0.0, 1.0)


static func _top(board: String) -> int:
	match board.get_slice("_", 0):
		"daily":
			return TOP_DAILY
		"weekly":
			return TOP_WEEKLY
	return TOP_SEASON_PER_DAY * TSProfile._board_length_days("season", board.get_slice("_", 1))


## The first `count` of this board's bots, as leaderboard rows, `at` of the way
## through it (1.0: finished). A bot with no star yet is not on the board, as a
## player isn't.
static func rows(board: String, count: int, at: float) -> Array:
	var order: Array = range(NAMES.size())
	order.sort_custom(func(a: int, b: int) -> bool: return hash("%s#%s" % [board, NAMES[a]]) < hash("%s#%s" % [board, NAMES[b]]))
	var out: Array = []
	var top := _top(board)
	for k in mini(count, order.size()):
		var who: int = order[k]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|bot|%d" % [board, who])
		var final := maxi(1, roundi(top * lerpf(0.06, 1.0, pow(rng.randf(), 1.7))))
		var start := pow(rng.randf(), 2.0) * 0.5   # most are early birds
		var done := lerpf(0.65, 1.0, rng.randf())
		var critter := TSProfile.npc_critter(rng.randi())
		var stars := floori(final * clampf((at - start) / (done - start), 0.0, 1.0))
		if stars > 0:
			out.append({"uid": UID_PREFIX + str(who), "name": NAMES[who], "avatar": critter, "stars": stars, "is_player": false})
	return out


## How many of a finished board's `count` bots ended with more than `stars`.
static func beating(board: String, count: int, stars: int) -> int:
	return rows(board, count, 1.0).filter(func(e: Dictionary) -> bool: return int(e["stars"]) > stars).size()
