# Visual QA for the in-game cards: plays a level with a throwaway profile and
# opens the card named on the command line (pause, win, lose, or an empty
# booster: bomb, swap, rocks). Run with:
#   Godot.exe --path . res://tests/card_capture.tscn -- win
extends "res://scripts/game.gd"

var _frames := 0
var _card := ""


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.coin_count = 3200
	var args := OS.get_cmdline_user_args()
	_card = args[0] if args.size() > 0 else "pause"
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
			_use_swap()
		"rocks":
			TSProfile.rock_count = 0
			_fire_rocks()
