# Opens every screen with a scrolling list and checks nothing inside the list
# would swallow a finger's touch before the list sees it (a card or button that
# stops mouse input never hands the touch up, so the list could not be dragged
# from it -- the Shop was nearly all such controls). Run with:
#   Godot.exe --path . res://tests/scroll_touch_test.tscn
extends Node

const SCREENS := ["shop", "collection", "battle_pass", "leaderboard", "clubs", "hunt", "streak"]

var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(30)
	TSProfile.collection_tutorial_seen = true
	TSProfile.club_intro_seen = true
	TSProfile.coin_count = 50000
	call_deferred("_run")


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _run() -> void:
	for name in SCREENS:
		var scene: Control = (load("res://scenes/%s.tscn" % name) as PackedScene).instantiate()
		add_child(scene)
		for _i in 20:
			await get_tree().process_frame
		var lists := scene.find_children("*", "ScrollContainer", true, false)
		var swallowing := 0
		var plain := 0
		for l in lists:
			if l is TSScroll:
				swallowing += (l as TSScroll).swallowing_controls().size()
			else:
				plain += 1
		_check("%s: %d scroll list(s), all touch-friendly" % [name, lists.size()], plain == 0)
		_check("%s: nothing inside its lists swallows a touch (%d found)" % [name, swallowing], swallowing == 0)
		scene.queue_free()
		await get_tree().process_frame
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
