# Visual QA for the critter's run at the shell (TSCreature's Mood.BUMP): starts
# a level, sets the critter off, and saves bump_1_windup.png, bump_2_hit.png
# (the bonk, the egg starting to rock), bump_3_rock.png and bump_4_dizzy.png.
#   OUT=<folder> Godot.exe --path . res://tests/bump_capture.tscn -- 3
extends "res://scripts/game.gd"

var _frames := 0
var _shots := [[0.25, "bump_1_windup"], [0.55, "bump_2_hit"], [0.6, "bump_3_rock"], [1.3, "bump_4_dizzy"]]
var _bumps := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	TSProfile.use_test_profile(int(args[0]) if args.size() > 0 else 3)
	super()
	_creature.bumped.connect(func(_d: Vector3) -> void: _bumps += 1)


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 60:
		_creature.react(TSCreature.Mood.BUMP)
	if _frames > 60 and not _shots.is_empty() and _creature._mood_t >= float(_shots[0][0]):
		_shot(str(_shots.pop_front()[1]))
		if _shots.is_empty():
			print("BUMPS ", _bumps, " egg basis after hit ", view.basis)
	if _frames == 400:
		print("BUMPS ", _bumps, " egg back to rest ", view.basis == Basis.IDENTITY)
		get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join(name + ".png"))
