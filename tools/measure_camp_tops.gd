# How tall each camp spot (and the solar panels) is drawn at every level:
# each painter on its own, on a clear background, at a few moments of its
# animation (sails turn, flags wave), and the highest solid pixel over its
# spot. Prints TSShipScene.SPOT_TOPS -- what a build node floats just over.
# Rerun after redrawing a spot:
#   Godot.exe --path . --script res://tools/measure_camp_tops.gd
extends SceneTree

const PAINTERS := ["_draw_campfire", "_draw_tent", "_draw_bench", "_draw_garden", "_draw_well", "_draw_lookout", "_draw_solar",
	"_draw_hammock", "_draw_picnic", "_draw_clothesline", "_draw_mailbox", "_draw_windmill", "_draw_dock", "_draw_playground",
	"_draw_treehouse", "_draw_stall", "_draw_greenhouse", "_draw_spring", "_draw_observatory", "_draw_oven", "_draw_statue"]
const CANVAS := Vector2i(1200, 1100)
const FOOT := Vector2(600.0, 1000.0)   # where the spot lands on the canvas
const SOLID := 0.6                     # alpha that counts as drawn (not glow, smoke or shadow)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TSProfile.use_test_profile(60)
	# Every wave open, so each spot draws even at level 0 (the scene's own
	# _levels say how built it is).
	TSProfile.part_level = []
	for i in TSProfile.PART_COUNT:
		TSProfile.part_level.append(TSProfile.PART_MAX_LEVEL)
	var scene := TSShipScene.new()
	scene.size = Vector2(720, 1280)
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var sub := SubViewport.new()
	sub.size = CANVAS
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var canvas := Control.new()
	canvas.size = Vector2(6000, 6000)   # moved far out for a far spot, it must still cover the view or it is culled
	sub.add_child(canvas)
	var now := {"painter": ""}   # a lambda keeps a copy of a local, so the painter goes in here
	canvas.draw.connect(func():
		if now["painter"] != "":
			scene.call(now["painter"], canvas))
	# Which part each painter's spot belongs to, by where it stands.
	var spot_of := {}
	for i in scene.GROUND_NODES:
		spot_of[scene.GROUND_NODES[i]] = i
	var lines := PackedStringArray()
	for name in PAINTERS:
		now["painter"] = name
		var part := -1
		var tops := []
		for lvl in TSProfile.PART_MAX_LEVEL + 1:
			var best := 0.0
			for t in [0.0, 0.45, 0.9, 1.35, 1.8, 2.25]:
				scene._t = t
				for i in scene.GROUND_NODES:
					scene._levels[i] = lvl
				# Find this painter's spot: the one whose drawing lands on the canvas.
				canvas.position = Vector2.ZERO
				var found := _spot_for(scene, name)
				part = int(spot_of.get(found, -1))
				canvas.position = FOOT - found
				canvas.queue_redraw()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := sub.get_texture().get_image()
				best = maxf(best, _height(img))
			tops.append(roundi(best))
		lines.append("%d: %s,   # %s" % [part, str(tops), TSProfile.PARTS[part]["name"]])
		print("TOP ", lines[lines.size() - 1])
	print("SPOT_TOPS := {\n\t" + "\n\t".join(lines) + "\n}")
	quit()


## The spot a painter draws round, from TSShipScene's own list of them.
func _spot_for(scene: TSShipScene, name: String) -> Vector2:
	const SPOTS := {"_draw_campfire": "FIRE", "_draw_tent": "TENT", "_draw_bench": "BENCH", "_draw_garden": "GARDEN", "_draw_well": "WELL",
		"_draw_lookout": "LOOKOUT", "_draw_solar": "SOLAR", "_draw_hammock": "HAMMOCK", "_draw_picnic": "PICNIC", "_draw_clothesline": "CLOTHESLINE",
		"_draw_mailbox": "MAILBOX", "_draw_windmill": "WINDMILL", "_draw_dock": "DOCK", "_draw_playground": "PLAYGROUND", "_draw_treehouse": "TREEHOUSE",
		"_draw_stall": "STALL", "_draw_greenhouse": "GREENHOUSE", "_draw_spring": "SPRING", "_draw_observatory": "OBSERVATORY", "_draw_oven": "OVEN",
		"_draw_statue": "STATUE"}
	return scene.get_script().get_script_constant_map()[SPOTS[name]]


## How far above FOOT the highest solid pixel is, within reach of the spot.
func _height(img: Image) -> float:
	var x0 := int(FOOT.x) - 330
	var x1 := int(FOOT.x) + 330
	for y in int(FOOT.y):
		for x in range(x0, x1, 2):
			if img.get_pixel(x, y).a >= SOLID:
				return FOOT.y - float(y)
	return 0.0
