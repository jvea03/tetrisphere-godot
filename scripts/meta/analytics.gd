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
static var recent: Array = []   # the last events sent, as [name, params], newest last (for tests)
static var _load_began := -1    # Time.get_ticks_msec() as the cutscene handed over to level 1


static func _ready_plugin() -> Object:
	if _plugin == null and APP_ID != "" and Engine.has_singleton("EggAnalytics"):
		_plugin = Engine.get_singleton("EggAnalytics")
		_plugin.start(API_KEY, APP_ID, PROJECT_ID, SENDER_ID)
	return _plugin


## Starts Firebase as the game opens, so its first_open counts every install.
static func start() -> void:
	_ready_plugin()


static func event(name: String, params := {}) -> void:
	recent.append([name, params])
	if recent.size() > 20:
		recent.pop_front()
	var p := _ready_plugin()
	if p != null:
		p.logEvent(name, params)


## A user property: every report can be split by it.
static func user_property(name: String, value: String) -> void:
	var p := _ready_plugin()
	if p != null:
		p.setUserProperty(name, value)


## A new player's way from first_open to level 1's level_start: the crash
## cutscene shown (intro_start); how it ended (intro_end: "skip" for the Skip
## button or Back, "tap" after the last caption, "auto" if left to run out,
## and when); then how long level 1 took to appear after it (level_loaded).
static func intro_start() -> void:
	event("intro_start")


static func intro_end(how: String, seconds: float) -> void:
	event("intro_end", {"how": how, "seconds": roundi(seconds)})
	_load_began = Time.get_ticks_msec()


## Sent once, as the game screen is ready after the cutscene; nothing otherwise.
static func level_loaded() -> void:
	if _load_began < 0:
		return
	event("level_loaded", {"seconds": snappedf((Time.get_ticks_msec() - _load_began) / 1000.0, 0.1)})
	_load_began = -1


## An egg begun (Firebase's level_start), fresh or retried: a player who
## starts a level and never ends it is where churn shows, and starts per
## level count the attempts. Also keeps the max_level user property, the
## furthest level reached, for splitting any report by progress.
## level and success go as text: they are custom dimensions, and Analytics
## shows a number sent to a dimension as "(not set)" (1.3.1 sent numbers).
static func level_start(level: int, kind: String) -> void:
	event("level_start", {"level_name": "%s_%d" % [kind, level], "level": str(level), "kind": kind})
	user_property("max_level", str(TSProfile.last_level))


## A level won or lost (Firebase's level_end), with how long it took (play
## time, cards and pauses aside), the pieces dropped and the hearts left;
## and the first level won (tutorial_complete: past the first lesson).
static func level_end(level: int, won: bool, kind: String, seconds := 0.0, drops := 0, hearts := 0) -> void:
	event("level_end", {"level_name": "%s_%d" % [kind, level], "level": str(level), "kind": kind, "success": "1" if won else "0",
		"seconds": roundi(seconds), "drops": drops, "hearts_left": hearts})
	if won and kind == "level":
		if level == 1:
			event("tutorial_complete")
		elif level in [5, 10, 20]:
			event("level_%d_won" % level)
