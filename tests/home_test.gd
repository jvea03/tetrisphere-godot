# Checks Home's camp and ship build nodes on a throwaway profile: only the
# camp's nodes show at first, a node's card builds and then upgrades its spot
# for coins, none of it moves the collection level, finishing the camp brings
# out the ship's nodes, and a short wallet turns the button into Get Coins.
# Run with:
#   Godot.exe --path . res://tests/home_test.tscn
extends "res://scripts/screens/home.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSProfile.coin_count = 100000
	TSProfile.part_level = []
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level.append(0)
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _run() -> void:
	var parts: Array = _world._node_parts()
	var only_camp := not parts.is_empty()
	for p in parts:
		only_camp = only_camp and TSProfile.is_camp(p)
	_check("the camp's nodes show, and no ship part's yet (%d nodes)" % parts.size(), _world.nodes_enabled and only_camp and parts.size() == TSProfile.camp_spot_count())

	var points := TSProfile.collection_points()
	var coins := TSProfile.coin_count
	var cost := TSProfile.part_next_cost(TSProfile.CAMP_FIRE)
	_open_part(TSProfile.CAMP_FIRE)
	_check("a node opens its card, offering to build", _part["root"].visible and (_part["go"] as Button).text.begins_with("Build"))
	_on_part_pressed()
	_check("building spends %d coins and builds it" % cost, TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 1 and TSProfile.coin_count == coins - cost)
	_check("and the card moves on to the upgrade", _part["root"].visible and (_part["go"] as Button).text.begins_with("Upgrade"))
	_on_part_pressed()
	_check("upgrading from the same card", TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 2)
	_check("none of it counts toward the collection level", TSProfile.collection_points() == points)

	# Finish the camp but the last step, then take that through the card.
	for p in TSProfile.PART_COUNT:
		if TSProfile.is_camp(p):
			TSProfile.part_level[p] = TSProfile.PART_MAX_LEVEL
	TSProfile.part_level[TSProfile.CAMP_LOOKOUT] = TSProfile.PART_MAX_LEVEL - 1
	_world.refresh_parts()
	_open_part(TSProfile.CAMP_LOOKOUT)
	_on_part_pressed()
	parts = _world._node_parts()
	var only_ship := not parts.is_empty()
	for p in parts:
		only_ship = only_ship and not TSProfile.is_camp(p)
	_check("finishing the camp brings out a node for every ship part, and leaves none on the camp (%d)" % parts.size(), only_ship and parts.size() == TSProfile.PART_COUNT - TSProfile.camp_spot_count())

	TSProfile.coin_count = 10
	_open_part(TSProfile.PART_ENGINE)
	_check("short of coins, the button offers Get Coins", (_part["go"] as Button).text.begins_with("Get Coins"))
	var level := TSProfile.part_level_of(TSProfile.PART_ENGINE)
	TSProfile.coin_count = 100000
	_fill_part_card()
	_on_part_pressed()
	_check("with coins again, the engine is fixed", TSProfile.part_level_of(TSProfile.PART_ENGINE) == level + 1)
	_check("a node's screen spot is somewhere real", _world.node_screen_position(TSProfile.PART_ENGINE).is_finite())

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
