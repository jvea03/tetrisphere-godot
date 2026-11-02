# Visual QA: plays a level with a throwaway profile, sets up the moment named
# on the command line and saves the screen as a PNG in OUT (a folder):
#   match      level 1's walkthrough, on its card about matching
#   hearts     level 1's walkthrough, on its hearts card
#   miss       a miss on level 1 (no heart lost: the note under the hearts)
#   miss2      a miss on level 2 (a heart lost)
#   win2       level 2's win card (Next Level only)
#   win6       level 6's win card (close and Double Coins back)
#   toohigh    level 1's note for a drop turned away
# Run (not headless, so there is a screen to save) with:
#   OUT=C:/somewhere Godot.exe --path . res://tests/qa_capture.tscn -- miss
extends "res://scripts/game.gd"

var _frames := 0
var _shot := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_shot = args[0] if args.size() > 0 else "miss"
	var at := {"match": 1, "hearts": 1, "miss": 1, "miss2": 2, "win2": 2, "win6": 6, "toohigh": 1}
	TSProfile.use_test_profile(int(at.get(_shot, 1)))
	TSProfile.tutorial_seen = not _shot in ["match", "hearts"]
	TSProfile.slide_tutorial_seen = true
	TSProfile.ad_rewards_used = {}
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 20:
		_set_up()


func _set_up() -> void:
	var wait := 0.3
	match _shot:
		"match", "hearts":
			for _i in (3 if _shot == "match" else 4):
				_tutorial._advance()
			wait = 1.0
		"miss", "miss2":
			_missed()
			_refresh_hud()
		"toohigh":
			_hearts_note("Too high here: drop it somewhere else!")
		"win2", "win6":
			_debug_win()
			wait = 3.0
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("OUT").path_join(_shot + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("SAVED ", path)
	get_tree().quit()
