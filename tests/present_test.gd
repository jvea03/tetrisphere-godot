# Christmas presents at the crash site: most taps give nothing, now and then
# coins or materials (about PRESENT_CHANCE), and after a gift none for
# PRESENT_COOLDOWN seconds. Run with:
#   Godot.exe --headless --path . res://tests/present_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(12)
	seed(7)
	var gifts := 0
	var kinds := {}
	for i in 2000:
		TSProfile.present_paid_at = 0   # no cooldown, to measure the odds
		var g := TSProfile.open_present()
		if not g.is_empty():
			gifts += 1
			kinds[g.keys()[0]] = true
	_check("about 15%% of taps give something (%d of 2000)" % gifts, gifts > 220 and gifts < 380)
	_check("coins and materials both come up", kinds.has("coins") and kinds.has("materials"))
	TSProfile.present_paid_at = int(TSClock.now())
	var any := false
	for i in 500:
		any = any or not TSProfile.open_present().is_empty()
	_check("nothing for 5 minutes after a gift", not any)
	TSProfile.present_paid_at = int(TSClock.now()) - TSProfile.PRESENT_COOLDOWN
	var back := false
	for i in 200:
		back = back or not TSProfile.open_present().is_empty()
	_check("then presents can pay again", back)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
