# Visual QA for the in-game cards: plays a level with a throwaway profile and
# opens the card named on the command line (pause, win, lose, or an empty
# booster: bomb, swap, rocks; or `any` to hold the Any Piece). Run with:
#   Godot.exe --path . res://tests/card_capture.tscn -- win
extends "res://scripts/game.gd"

var _frames := 0
var _card := ""


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.coin_count = 3200
	var args := OS.get_cmdline_user_args()
	_card = args[0] if args.size() > 0 else "pause"
	if OS.get_environment("OUT") != "":
		# OUT=folder: saves <card>.png there a few seconds in, and quits.
		var t0 := get_tree()
		t0.create_timer(3.0).timeout.connect(func():
			await RenderingServer.frame_post_draw
			t0.root.get_texture().get_image().save_png(OS.get_environment("OUT").path_join(_card + ".png"))
			t0.quit())
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames != 20:
		return
	match _card:
		"pause":
			_open_pause()
		"win":
			lives = 2
			_debug_win()
		"lose":
			lives = 0
			lose_reason = "OUT OF LIVES"
			_lose()
		"bomb":
			TSProfile.bomb_count = 0
			_toggle_bomb()
		"swap":
			TSProfile.swap_count = 0
			_use_any_piece()
		"any":
			TSProfile.swap_count = 2
			_use_any_piece()
		"rocks":
			TSProfile.rock_count = 0
			_fire_rocks()
