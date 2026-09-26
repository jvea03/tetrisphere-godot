class_name TSSession
extends RefCounted

## Keeps a ball in play across a trip to Home and back within one run of the
## app (Duckdoku's GameSession): leaving the game parks the board here, and
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
