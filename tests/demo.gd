# Visual QA harness: boots the real game, then plays a greedy opening so a
# capture shows an excavated shell rather than an untouched one. Run with:
#   Godot.exe --path . res://tests/demo.tscn
extends "res://scripts/game.gd"

const DEMO_DROPS := 6


func _ready() -> void:
	seed(1234)
	TSProfile.use_test_profile(12)
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for _i in DEMO_DROPS:
		if state != State.PLAYING:
			break
		_aim_best(rng)
		_drop()
	# The camera no longer follows the aim by itself; turn to the last drop.
	if state == State.PLAYING:
		_face(_piece_centre())


func _aim_best(rng: RandomNumberGenerator) -> void:
	var offsets: Array = TSBoard.SHAPES[cur_type]["offsets"]
	var best_score := -999999
	for _i in 40:
		var at := Vector2i(
			rng.randi_range(0, TSBoard.COLS - 1), rng.randi_range(0, TSBoard.ROWS - 1)
		)
		if not board.footprint_valid(offsets, at):
			continue
		var probe := board.clone()
		var res := probe.place_and_resolve(offsets, at, cur_type)
		var s := int(res["removed"]) * 10 + int(res["pieces"]) * 25
		if s > best_score:
			best_score = s
			cursor = at
	_clamp_cursor()
