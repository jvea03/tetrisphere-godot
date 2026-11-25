class_name TSAnalytics
extends RefCounted

## Firebase Analytics on Android and iOS (the EggAnalytics plugin, one per
## platform with the same methods): Firebase's own first_open, plus a few game
## events Google Ads imports as conversions, so the install campaigns learn
## which installs turn into players. Elsewhere (the editor, tests, desktop)
## Firebase does nothing.
##
## Every event here also goes to GameAnalytics (the GA autoload,
## scripts/meta/game_analytics.gd) on both Android and iOS, as levels,
## first-run steps and design events. Both follow the same rules: the
## Settings switch, the kill switch and, where the law asks first, the
## player's yes (TSPrivacyRegion). The IDs are the Egg Escape
## Firebase project's Android and iOS apps (Project settings > Your apps; the
## iOS key is Cloud console > Credentials > "iOS key"): client IDs every copy
## of the app carries, not secrets.

const API_KEY := "AIzaSyDQl6mbpdOcKRZ18pWDE7SzssjGYpxW_-k"
const APP_ID := "1:261470909369:android:38d287eea0687404e43c68"
const IOS_API_KEY := "AIzaSyDXKbGVxg4lnmRyfxeellVWpwdqykfSlMI"
const IOS_APP_ID := "1:261470909369:ios:365fbf047205bf41e43c68"
const PROJECT_ID := "egg-escape-196b6"
const SENDER_ID := "261470909369"

static var _plugin: Object
static var recent: Array = []   # the last events sent, as [name, params], newest last (for tests)
static var _load_began := -1    # Time.get_ticks_msec() as the cutscene handed over to level 1


static func _ready_plugin() -> Object:
	if _plugin == null and APP_ID != "" and Engine.has_singleton("EggAnalytics") and _allowed():
		_plugin = Engine.get_singleton("EggAnalytics")
		if OS.get_name() == "iOS":
			_plugin.start(IOS_API_KEY, IOS_APP_ID, PROJECT_ID, SENDER_ID)
		else:
			_plugin.start(API_KEY, APP_ID, PROJECT_ID, SENDER_ID)
	return _plugin


## The Meta SDK (Android, EggMeta + the EggAnalytics plugin's setMeta) runs only
## while analytics are allowed, the same rule as Firebase: it is told on every
## change, and on every event as a backstop. Never starts the plugin itself.
static var _meta_on := false


static func sync_meta() -> void:
	if _plugin == null or OS.get_name() != "Android" or not _plugin.has_method("setMeta"):
		return
	var want := _allowed()
	if want != _meta_on:
		_meta_on = want
		_plugin.setMeta(want)


## Starts Firebase as the game opens, so its first_open counts every install.
static func start() -> void:
	_ready_plugin()


static func event(name: String, params := {}) -> void:
	recent.append([name, params])
	if recent.size() > 20:
		recent.pop_front()
	var p := _ready_plugin()
	sync_meta()
	if p != null and _allowed():
		p.logEvent(name, params)
	_to_ga(name, params)


## Firebase may run: the kill switch, the Settings switch and the consent.
static func _allowed() -> bool:
	return TSTunables.get_bool("analytics_enabled") and TSPrivacyRegion.analytics_allowed()


## The GameAnalytics autoload, or null (looked up rather than named, so this
## class still compiles where autoloads are not loaded).
static func ga() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GA") if tree != null else null


## The economy, as GameAnalytics resource events (its Resources dashboard):
## coins and materials spent on `item_type`/`item_id` ("Camp"/"Engine",
## "Critter"/"Unlock") and earned from `source_type`/`source_id` ("Level"/"Win",
## "Chest"/"Rare"). GameAnalytics only, under the same rules as the rest.
static func spent(item_type: String, item_id: String, coins: int, materials := 0) -> void:
	var g := ga()
	if g == null or not g.enabled:
		return
	g.resource("Sink", item_type, item_id, coins, "Coins")
	g.resource("Sink", item_type, item_id, materials, "Materials")


static func earned(source_type: String, source_id: String, coins: int, materials := 0) -> void:
	var g := ga()
	if g == null or not g.enabled:
		return
	g.resource("Source", source_type, source_id, coins, "Coins")
	g.resource("Source", source_type, source_id, materials, "Materials")


## A GameAnalytics design event ("Camp:Build:Engine", "Critter:Unlock:Rare").
static func design(event_id: String, value = null) -> void:
	var g := ga()
	if g != null and g.enabled:
		g.design(event_id, value)


## Firebase-only events, for Google Ads to bid on.
const FIREBASE_ONLY := ["ad_rewarded_earned", "valuable_player"]

## Firebase's event names, as GameAnalytics design ids ("ad_inter_owed" ->
## "Ad:Interstitial:Owed"). Levels go as progression events instead.
const GA_NAMES := {
	"ad_inter_due": "Ad:Interstitial:Due",
	"ad_inter_owed": "Ad:Interstitial:Owed",
	"ad_inter_bought_off": "Ad:Interstitial:BoughtOff",
	"ad_inter_skip_pass": "Ad:Interstitial:SkipPass",
	"ad_inter_owed_dropped": "Ad:Interstitial:OwedDropped:NoAds",
	"ad_inter_owed_deferred": "Ad:Interstitial:OwedDeferred:Busy",
	"intro_start": "FirstRun:Intro:Start",
	"tutorial_complete": "Tutorial:Level1:Done",
}


static func _to_ga(name: String, params: Dictionary) -> void:
	var g := ga()
	if g == null or not g.enabled:
		return
	match name:
		"level_start":
			g.progression("Start", _ga_kind(str(params.get("kind", ""))), "Level_%03d" % int(params.get("level", "0")))
		"level_end":
			var kind := _ga_kind(str(params.get("kind", "")))
			g.progression("Complete" if str(params.get("success", "0")) == "1" else "Fail", kind, "Level_%03d" % int(params.get("level", "0")), int(params.get("hearts_left", 0)))
			g.design("Level:Seconds:" + kind, int(params.get("seconds", 0)))
			g.design("Level:Drops:" + kind, int(params.get("drops", 0)))
		"intro_end":
			g.design("FirstRun:Intro:" + str(params.get("how", "")).capitalize(), int(params.get("seconds", 0)))
		"level_loaded":
			g.design("FirstRun:Level1Loaded", float(params.get("seconds", 0.0)))
		_:
			if GA_NAMES.has(name):
				g.design(GA_NAMES[name], params.get("level", null))
			elif FIREBASE_ONLY.has(name):
				pass # GameAnalytics has its own (Ad:Rewarded:Earned, the progression events)
			elif name.begins_with("level_") and name.ends_with("_won"):
				pass # Firebase's Google Ads conversions; GameAnalytics has the progression event
			else:
				g.design("Event:" + name)


## "level" -> "Level", "daily" -> "Daily", "challenge" -> "Challenge".
static func _ga_kind(kind: String) -> String:
	return kind.capitalize() if kind != "" else "Level"


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
			if level == 10:
				valuable_player("level_10")


## A rewarded ad watched to the end (ad_rewarded_earned, with how many this
## player has watched in all). The 3rd makes a valuable player.
const VALUABLE_REWARDED := 3


static func rewarded_earned() -> void:
	TSProfile.rewarded_earned_count += 1
	TSProfile.save()
	event("ad_rewarded_earned", {"count": str(TSProfile.rewarded_earned_count)})
	if TSProfile.rewarded_earned_count >= VALUABLE_REWARDED:
		valuable_player("rewarded_ads")


## valuable_player, once per player: the first of winning level 10 or watching
## the 3rd rewarded ad ("why"). One event for both, so there are enough of them
## for a Google Ads campaign to bid on (store/ads/README.md).
static func valuable_player(why: String) -> void:
	if TSProfile.valuable_player_sent:
		return
	TSProfile.valuable_player_sent = true
	TSProfile.save()
	event("valuable_player", {"why": why})
