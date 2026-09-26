class_name TSHaptics
extends RefCounted

## Vibration, gated by the Settings toggle. Handheld vibration is a harmless
## no-op where unsupported.

static func light() -> void:
	_vibrate(15)


static func medium() -> void:
	_vibrate(30)


static func heavy() -> void:
	_vibrate(50)


static func _vibrate(ms: int) -> void:
	if TSProfile.haptics_enabled:
		Input.vibrate_handheld(ms)
