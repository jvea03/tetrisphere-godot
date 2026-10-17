# The real game, playing itself for the video ads (tools/make_video.gd): a
# throwaway profile, then a bot that aims each piece -- turning the egg to it
# -- drops it, and goes again until the critter is out.
extends "res://scripts/game.gd"

const LEVEL := 8
const MAX_DROPS := 16
const AIM_SECONDS := 0.55    # the egg turns to the aimed piece
const SETTLE_SECONDS := 0.8  # the clear plays out before the next aim

signal won


func _ready() -> void:
	seed(1234)
	TSProfile.use_test_profile(LEVEL)
	TSProfile.ad_rewards_date = TSClock.date_string()
	TSProfile.ad_rewards_used = {"win_coins": 99}   # no Double Coins ad on the win card
	super()


func playing() -> bool:
	return state == State.PLAYING


## Plays the level out; `won` once the critter escapes.
func autoplay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 0
	while state == State.PLAYING and n < MAX_DROPS:
		_aim(rng)
		_face(_piece_centre())
		await get_tree().create_timer(AIM_SECONDS).timeout
		_drop()
		n += 1
		await get_tree().create_timer(SETTLE_SECONDS).timeout
	if state == State.WON:
		won.emit()


## tests/sim.gd's player: clears, pieces and the escape hole opening up.
func _aim(rng: RandomNumberGenerator) -> void:
	var offsets: Array = TSBoard.SHAPES[cur_type]["offsets"]
	var best := -999999
	var esc := _escape_size()
	for _i in 160:
		var at := Vector2i(rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1))
		if not board.footprint_valid(offsets, at):
			continue
		var probe := board.clone()
		var res := probe.place_and_resolve(offsets, at, cur_type)
		var s := int(res["removed"]) * 10 + int(res["pieces"]) * 25 + int(probe.best_escape_patch(esc)["open"]) * 60
		if s > best:
			best = s
			cursor = at
	_clamp_cursor()
