# Settings' volume sliders: each sets its bus's volume (squared, so half way
# is -12 dB) and 0 mutes it, the old On/Off flag following; the slider row
# moves the profile as it is dragged. Run with:
#   Godot.exe --headless --path . res://tests/volume_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(5)
	TSSfx.ensure_buses()
	var music := AudioServer.get_bus_index(TSSfx.MUSIC_BUS)
	var sfx := AudioServer.get_bus_index(TSSfx.SFX_BUS)
	TSProfile.set_volume("music", 1.0)
	TSProfile.set_volume("sfx", 1.0)
	TSSfx.apply_settings()
	_check("full volume: 0 dB, not muted", is_zero_approx(AudioServer.get_bus_volume_db(music)) and not AudioServer.is_bus_mute(music))
	TSProfile.set_volume("music", 0.5)
	TSSfx.apply_settings()
	_check("half way: about -12 dB (%.1f)" % AudioServer.get_bus_volume_db(music), absf(AudioServer.get_bus_volume_db(music) + 12.04) < 0.1)
	TSProfile.set_volume("sfx", 0.0)
	TSSfx.apply_settings()
	_check("0 mutes it, and turns its old flag off", AudioServer.is_bus_mute(sfx) and not TSProfile.sfx_enabled and TSProfile.music_enabled)
	TSProfile.set_volume("sfx", 3.0)
	_check("a value past the end is clamped", is_equal_approx(TSProfile.sfx_volume, 1.0) and TSProfile.sfx_enabled)

	var row := TSUI.volume_row("music", "Music", "music")
	add_child(row)
	var slider: HSlider = row.find_children("*", "HSlider", true, false)[0]
	_check("the row's slider starts at the profile's level", is_equal_approx(slider.value, 0.5))
	slider.value = 0.25
	_check("moving it sets the volume", is_equal_approx(TSProfile.music_volume, 0.25) and absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.0625)) < 0.1)
	slider.value = 0.0
	_check("and at 0 the music is off", AudioServer.is_bus_mute(music) and not TSProfile.music_enabled)

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
