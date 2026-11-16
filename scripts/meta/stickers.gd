class_name TSStickers
extends RefCounted

## Stickers: little faces players send each other from the leaderboards
## (Online.send_sticker). Everyone has the three basic ones (Grr!, Aww...,
## Congrats!); every other one must be earned -- from the Battle Pass,
## starting with the Christmas season (TSProfile's BATTLE_PASS_SEASON_REWARDS
## "free_stickers" / "paid_stickers"), or another event. Each is
## drawn by TSIcon ("sticker", variant = its id). Only these ids are ever
## sent, so there is nothing for anyone to type.

const ALL := {
	"angry": {"name": "Grr!"},
	"sad": {"name": "Aww..."},
	"congrats": {"name": "Congrats!"},
	"jolly": {"name": "Ho Ho Ho!"},
	"snowman": {"name": "Brrr!"},
	"gift": {"name": "For You!"},
	"cocoa": {"name": "Cozy!"},
}
const BASE := ["angry", "sad", "congrats"]


static func owns(id: String) -> bool:
	return BASE.has(id) or TSProfile.stickers_owned.has(id)


## The stickers this player can send, in ALL's order.
static func owned() -> Array:
	return ALL.keys().filter(func(id: String) -> bool: return owns(id))


static func sticker_name(id: String) -> String:
	return str((ALL.get(id, {}) as Dictionary).get("name", id))


## Gives a sticker; false if it was already owned (or isn't one).
static func grant(id: String) -> bool:
	if not ALL.has(id) or owns(id):
		return false
	TSProfile.stickers_owned.append(id)
	return true
