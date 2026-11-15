# Every critter in the Collection has its own line (TSCritterBios), short
# enough for the card. Run with:
#   Godot.exe --headless --path . res://tests/bios_test.tscn
extends Node


func _ready() -> void:
	var missing: Array = []
	var long: Array = []
	for i in TSProfile.CRITTER_COUNT:
		var n := TSProfile.critter_name(i)
		if not TSCritterBios.BIOS.has(n):
			missing.append(n)
		elif TSCritterBios.bio(n).length() > 70:
			long.append(n)
	var fails := 0
	print(("PASS  " if missing.is_empty() else "FAIL  ") + "every critter has a line %s" % str(missing))
	print(("PASS  " if long.is_empty() else "FAIL  ") + "each fits the card (70 letters) %s" % str(long))
	fails = int(not missing.is_empty()) + int(not long.is_empty())
	print("")
	print("ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(0 if fails == 0 else 1)
