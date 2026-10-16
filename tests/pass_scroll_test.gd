# The Battle Pass opens where the player is: the most recent tier unlocked at
# the top of the list -- or the first with a reward still to claim, if one is
# further up. Run with:
#   Godot.exe --path . res://tests/pass_scroll_test.tscn
extends Control

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(40)
	_run.call_deferred()


## Opens the pass and returns the tier whose row sits at the top of the list.
func _open() -> int:
	var screen: Control = (load("res://scenes/battle_pass.tscn") as PackedScene).instantiate()
	add_child(screen)
	for _i in 6:
		await get_tree().process_frame
	var scroll: ScrollContainer = screen._tier_scroll
	var top := -1
	for k in screen._tier_list.get_child_count():
		var row := screen._tier_list.get_child(k) as Control
		if row.position.y + row.size.y > scroll.scroll_vertical + 1:
			top = k + 1
			break
	screen.queue_free()
	await get_tree().process_frame
	return top


func _run() -> void:
	TSProfile._roll_battle_pass()
	TSProfile.battle_pass_purchased = false
	TSProfile.battle_pass_xp = TSProfile.battle_pass_stars_for_tier(20)
	for t in 19:
		TSProfile.battle_pass_free_claimed[t] = true
	TSProfile.battle_pass_free_claimed[19] = false
	var at := await _open()
	_check("at tier %d, the pass opens with tier 20 at the top (found %d)" % [TSProfile.battle_pass_tier(), at], at == 20)
	TSProfile.battle_pass_free_claimed[11] = false
	at = await _open()
	_check("with tier 12's reward unclaimed, it opens there instead (found %d)" % at, at == 12)
	TSProfile.battle_pass_xp = 0
	at = await _open()
	_check("a new pass opens at the top (found %d)" % at, at == 1)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
