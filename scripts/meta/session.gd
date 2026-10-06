class_name TSSession
extends RefCounted

## Keeps a ball in play across a trip to Home and back -- and, on disk, across
## the app being closed (Duckdoku's GameSession): leaving the game parks the board here, and
## Home's PLAY becomes CONTINUE. Consumed when the game restores from it.

static var has_saved_game: bool = false
static var state: Dictionary = {} # everything game.gd needs to pick the ball back up

## Set by Home's Daily Egg tile, consumed by the game's _ready.
static var daily_requested: bool = false
## A level quit from its lose card: its next fresh start is not a first attempt.
static var retried_level: int = -1


static func clear() -> void:
	has_saved_game = false
	state = {}
	forget()


# -- on disk -----------------------------------------------------------------
# A ball in play also goes to disk -- when it is parked, and when the app is
# sent to the background mid-ball -- so it survives Android ending the app.
# The next launch loads it back as the parked ball (Home's CONTINUE). Only
# the real profile does this; test profiles never touch the disk.

const PATH := "user://parked_ball.json"


## Writes a ball (a state as _park() makes it) to disk.
static func write(s: Dictionary) -> void:
	if not TSProfile.persist or s.is_empty():
		return
	var b: TSBoard = s["board"]
	var board := b.to_dict()
	board["shell_depth"] = b.shell_depth
	board["initial_blocks"] = b.initial_blocks
	board["cleared_blocks"] = b.cleared_blocks
	var data := s.duplicate()
	data["board"] = board
	data["cursor"] = [(s["cursor"] as Vector2i).x, (s["cursor"] as Vector2i).y]
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


## Drops the ball on disk (it was resumed, won, lost or replaced).
static func forget() -> void:
	if TSProfile.persist and FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## At launch: a ball left on disk becomes the parked ball. A file that won't
## read is dropped.
static func restore() -> void:
	if not TSProfile.persist or has_saved_game or not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary) or not (data as Dictionary).has("board"):
		forget()
		return
	var d: Dictionary = data
	var b := TSBoard.new()
	b.load_dict(d["board"])
	b.shell_depth = int(d["board"].get("shell_depth", b.shell_depth))
	b.initial_blocks = int(d["board"].get("initial_blocks", 0))
	b.cleared_blocks = int(d["board"].get("cleared_blocks", 0))
	state = {
		"board": b, "daily": bool(d.get("daily", false)), "level": int(d.get("level", 1)),
		"difficulty": int(d.get("difficulty", 0)), "cur_type": int(d.get("cur_type", 0)),
		"next_type": int(d.get("next_type", 0)), "cursor": Vector2i(int(d["cursor"][0]), int(d["cursor"][1])),
		"lives": int(d.get("lives", 1)), "first_attempt": bool(d.get("first_attempt", false)),
		"lose_ad_used": bool(d.get("lose_ad_used", false)),
	}
	has_saved_game = true
