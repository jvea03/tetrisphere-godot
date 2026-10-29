class_name TSAnalytics
extends RefCounted

## Firebase Analytics on Android (the EggAnalytics plugin): Firebase's own
## first_open, plus a few game events Google Ads imports as conversions, so
## the install campaign learns which installs turn into players. Elsewhere
## (the editor, tests, iOS) it does nothing. The IDs are the Egg Escape
## Firebase project's Android app (Project settings > Your apps): client IDs
## every copy of the app carries, not secrets.

const API_KEY := "AIzaSyDQl6mbpdOcKRZ18pWDE7SzssjGYpxW_-k"
const APP_ID := "1:261470909369:android:38d287eea0687404e43c68"
const PROJECT_ID := "egg-escape-196b6"
const SENDER_ID := "261470909369"

static var _plugin: Object


static func _ready_plugin() -> Object:
	if _plugin == null and APP_ID != "" and Engine.has_singleton("EggAnalytics"):
		_plugin = Engine.get_singleton("EggAnalytics")
		_plugin.start(API_KEY, APP_ID, PROJECT_ID, SENDER_ID)
	return _plugin


## Starts Firebase as the game opens, so its first_open counts every install.
static func start() -> void:
	_ready_plugin()


static func event(name: String, params := {}) -> void:
	var p := _ready_plugin()
	if p != null:
		p.logEvent(name, params)


## A level won or lost (Firebase's level_end), and the first level won
## (tutorial_complete: the player is past the first lesson).
static func level_end(level: int, won: bool, kind: String) -> void:
	event("level_end", {"level_name": "%s_%d" % [kind, level], "success": won})
	if won and kind == "level":
		if level == 1:
			event("tutorial_complete")
		elif level in [5, 10, 20]:
			event("level_%d_won" % level)
