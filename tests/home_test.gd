# Checks Home's camp and ship build nodes on a throwaway profile: only the
# first wave's camp nodes show, a node's card starts a build that a critter
# works on for a while (coins and materials paid up front), the finished
# build is collected from its node, Finish Now pays to skip the wait, none of
# it moves the collection level, each finished wave raises the Camp level
# and opens the next, Camp Lv 5 brings out the ship's nodes, and the card
# says why a build can't start -- short of coins, materials or a free critter.
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
	TSProfile.materials = 10000
	TSProfile.part_builds = {}
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


## Lets a build's time run out.
func _time_up(i: int) -> void:
	TSProfile.part_builds[i]["end"] = TSProfile._now_unix() - 1


## Starts a step through its card, lets it finish and collects it from its node.
func _build_through(i: int) -> void:
	_open_part(i)
	_on_part_pressed()
	_time_up(i)
	_open_part(i)


func _run() -> void:
	var parts: Array = _world._node_parts()
	var only_camp := not parts.is_empty()
	for p in parts:
		only_camp = only_camp and TSProfile.is_camp(p)
	_check("the first wave's five camp nodes show, and no ship part's (%d nodes)" % parts.size(), _world.nodes_enabled and only_camp and parts.size() == 5)
	_check("the Camp level and materials show on Home", camp_badge.visible and camp_label.text == "Camp Lv 1" and materials_pill.visible and materials_label.text == "10,000")

	var points := TSProfile.collection_points()
	var coins := TSProfile.coin_count
	var mats := TSProfile.materials
	var cost := TSProfile.part_next_cost(TSProfile.CAMP_FIRE)
	var need := TSProfile.part_next_materials(TSProfile.CAMP_FIRE)
	_open_part(TSProfile.CAMP_FIRE)
	_check("a node opens its card, offering to build", _part["root"].visible and (_part["go"] as Button).text.begins_with("Build"))
	_on_part_pressed()
	_check("Build pays %d coins and %d materials and starts the timer" % [cost, need], TSProfile.is_part_building(TSProfile.CAMP_FIRE) and TSProfile.coin_count == coins - cost and TSProfile.materials == mats - need and TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 0)
	_check("a critter goes to work on it", TSProfile.part_builder(TSProfile.CAMP_FIRE) == TSProfile.avatar())
	_open_part(TSProfile.CAMP_FIRE)
	_check("its card counts down and offers Finish Now", (_part["go"] as Button).text.begins_with("Finish Now"))
	TSProfile.time_skips = 3
	_fill_part_card()
	_check("its card offers time skips", (_part["skips"] as Control).visible and not (_part["skip_one"] as Button).disabled)
	_use_skips(1)   # its 30 seconds gone with one
	_check("a time skip finishes it, collected at once: Lv 1", TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 1 and not TSProfile.is_part_building(TSProfile.CAMP_FIRE) and TSProfile.time_skips == 2)
	_open_part(TSProfile.CAMP_FIRE)
	_on_part_pressed()
	TSUI.conceal(_part["root"])
	_time_up(TSProfile.CAMP_FIRE)
	_open_part(TSProfile.CAMP_FIRE)
	_check("once done, tapping its node collects it: Lv 2", TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 2 and not TSProfile.is_part_building(TSProfile.CAMP_FIRE))
	_open_part(TSProfile.CAMP_FIRE)
	_on_part_pressed()
	coins = TSProfile.coin_count
	_open_part(TSProfile.CAMP_FIRE)
	_on_part_pressed()   # Finish Now
	_check("Finish Now pays coins and finishes the upgrade at once", TSProfile.part_level_of(TSProfile.CAMP_FIRE) == 3 and TSProfile.coin_count < coins)
	_check("none of it counts toward the collection level", TSProfile.collection_points() == points)

	# The mine under the ship: a node of its own; tapping it empties it.
	TSProfile.mine_since = TSProfile._now_unix() - 7200
	var held := TSProfile.mine_stored()
	mats = TSProfile.materials
	_collect_mine()
	_check("the mine's node empties it into materials (+%d)" % held, held > 0 and TSProfile.materials == mats + held and materials_label.text == TSProfile.fmt_wallet(TSProfile.materials))

	# The reasons a build can't start.
	TSProfile.materials = 0
	_open_part(TSProfile.CAMP_TENT)
	_check("short of materials, the card says so", (_part["go"] as Button).disabled and (_part["go"] as Button).text.begins_with("Need"))
	TSProfile.materials = 10000
	var busy := {}
	for c in TSProfile.free_builders():
		busy[c] = true
	for c in busy:
		TSProfile.part_builds[100 + int(c)] = {"end": TSProfile._now_unix() + 999, "critter": int(c)}
	_fill_part_card()
	_check("with every critter busy, the card says so", (_part["go"] as Button).disabled and (_part["go"] as Button).text == "Every critter is busy")
	for c in busy:
		TSProfile.part_builds.erase(100 + int(c))
	TSUI.conceal(_part["root"])

	# Finish the first wave but its last step, and take that through a build.
	for p in TSProfile.CAMP_WAVES[0]:
		TSProfile.part_level[p] = TSProfile.PART_MAX_LEVEL
	TSProfile.part_level[TSProfile.CAMP_WELL] = TSProfile.PART_MAX_LEVEL - 1
	_world.refresh_parts()
	_build_through(TSProfile.CAMP_WELL)
	parts = _world._node_parts()
	_check("finishing a wave makes Camp Lv 2 and brings out the next five (%d)" % parts.size(), camp_label.text == "Camp Lv 2" and parts.size() == 5 and parts.has(TSProfile.CAMP_LOOKOUT) and parts.has(TSProfile.CAMP_MAILBOX))

	# Finish the camp but the last step, then take that through a build.
	for p in TSProfile.PART_COUNT:
		if TSProfile.is_camp(p):
			TSProfile.part_level[p] = TSProfile.PART_MAX_LEVEL
	TSProfile.part_level[TSProfile.CAMP_STATUE] = TSProfile.PART_MAX_LEVEL - 1
	_world.refresh_parts()
	_build_through(TSProfile.CAMP_STATUE)
	_check("the last camp step makes Camp Lv %d" % TSProfile.CAMP_MAX_LEVEL, camp_label.text == "Camp Lv %d" % TSProfile.CAMP_MAX_LEVEL)
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
	TSUI.conceal(_part["root"])
	_build_through(TSProfile.PART_ENGINE)
	_check("with coins again, the engine is fixed", TSProfile.part_level_of(TSProfile.PART_ENGINE) == level + 1)
	_check("a node's screen spot is somewhere real", _world.node_screen_position(TSProfile.PART_ENGINE).is_finite())

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
