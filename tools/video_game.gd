# The real game, playing itself for the video ads (tools/make_video.gd): a
# throwaway profile, then a bot that aims each piece -- turning the egg to it
# -- drops it, and goes again until the critter is out.
extends "res://scripts/game.gd"

var video_level := 8   # make_video sets it (--level) before the game is added
const MAX_DROPS := 16
const AIM_SECONDS := 0.55    # the egg turns to the aimed piece
const SETTLE_SECONDS := 0.8  # the clear plays out before the next aim

signal won


func _ready() -> void:
	seed(1234)
	TSProfile.use_test_profile(video_level)
	TSProfile.ad_rewards_date = TSClock.date_string()
	TSProfile.ad_rewards_used = {"win_coins": 99}   # no Double Coins ad on the win card
	super()


## Turns the egg to the level's blocker -- fog, a prism, a padlock, a vine --
## so the opening shot shows what the caption is about. False if it has none.
func face_blocker() -> bool:
	var at := Vector2(-1, -1)
	if not board.fog.is_empty():
		at = Vector2(board.fog.keys()[0])
	else:
		for group in [board.prisms, board.locked, board.vined]:
			if not (group as Dictionary).is_empty():
				var id: int = (group as Dictionary).keys()[0]
				if board.plate_cols.has(id):
					at = Vector2((board.plate_cols[id] as Array)[0])
				break
	if at.x < 0:
		return false
	_face(at)
	return true


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
