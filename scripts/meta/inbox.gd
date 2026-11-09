class_name TSInbox
extends RefCounted

## Messages and gifts to players, with no server or accounts: the game reads a
## small file (store/inbox.json on GitHub; see docs/inbox.md) and each phone
## works out which messages are for it, by level, login streak and date. A
## message shows until it is collected or read (TSProfile.inbox_done). One small
## request, no player data; offline, the last file read is used. The same file
## carries the remote settings (TSTunables; docs/remote-settings.md).

const URL := "https://raw.githubusercontent.com/jvea03/tetrisphere-godot/main/store/inbox.json"
const CACHE_PATH := "user://inbox_cache.json"
const MAX_BODY := 200
## What a message can give: its key in the file -> its icon.
const REWARDS := {"coins": "coin", "materials": "materials", "bomb": "bomb", "swap": "swap", "rocks": "rocks", "skips": "skip"}

static var messages: Array = []
static var _fetched := false
static var _cache_read := false


## The messages in a file's text, the broken ones left out; null if it isn't
## an inbox file at all (so a bad edit can't wipe the last good one).
static func parse(text: String) -> Variant:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.get("messages") is Array:
		return null
	var out: Array = []
	for m: Variant in data["messages"]:
		if not m is Dictionary or str(m.get("id", "")) == "" or str(m.get("title", "")) == "":
			continue
		var rewards := {}
		var given: Variant = m.get("rewards", {})
		if given is Dictionary:
			for key: String in REWARDS:
				var n: Variant = given.get(key, 0)
				if (n is float or n is int) and int(n) > 0:
					rewards[key] = int(n)
		out.append({
			"id": str(m["id"]), "title": str(m["title"]), "body": str(m.get("body", "")).left(MAX_BODY), "rewards": rewards,
			"from": str(m.get("from", "")), "until": str(m.get("until", "")),
			"min_level": int(m.get("min_level", 0)), "max_level": int(m.get("max_level", 0)), "min_streak": int(m.get("min_streak", 0)),
		})
	return out


## Whether a message is for a player at this level and login streak, on this
## local date ("2026-11-06"; from and until both count).
static func applies(m: Dictionary, level: int, streak: int, date: String) -> bool:
	if level < int(m["min_level"]) or (int(m["max_level"]) > 0 and level > int(m["max_level"])) or streak < int(m["min_streak"]):
		return false
	return (str(m["from"]) == "" or date >= str(m["from"])) and (str(m["until"]) == "" or date <= str(m["until"]))


## The messages showing for this player now, newest in the file first.
static func active() -> Array:
	load_cache()
	var out: Array = []
	for m: Dictionary in messages:
		if not TSProfile.inbox_done.has(m["id"]) and applies(m, TSProfile.last_level, TSProfile.login_streak_count, TSClock.date_string()):
			out.push_front(m)
	return out


## Gives a message's rewards and retires it, once.
static func claim(m: Dictionary) -> void:
	if TSProfile.inbox_done.has(m["id"]):
		return
	TSProfile.inbox_done[m["id"]] = true
	var rewards: Dictionary = m["rewards"]
	TSProfile.coin_count += int(rewards.get("coins", 0))
	TSProfile.add_materials(int(rewards.get("materials", 0)))
	TSProfile.time_skips += int(rewards.get("skips", 0))
	for booster: String in ["bomb", "swap", "rocks"]:
		if rewards.has(booster):
			TSProfile.add_boosters(booster, int(rewards[booster]))
	TSProfile.save()


## Reads the file once a run and calls `done` if it arrives. Quietly does
## nothing offline, or on a throwaway profile (tests and tools).
static func fetch(host: Node, done: Callable) -> void:
	if _fetched or not TSProfile.persist:
		return
	load_cache()
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.body_size_limit = 64 * 1024
	host.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var text := body.get_string_from_utf8()
		if not take(text):
			return
		_fetched = true
		_cache_read = true
		var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
		done.call())
	if http.request(URL) != OK:
		http.queue_free()


## Uses a file's messages and its settings (TSTunables), if it is an inbox
## file at all.
static func take(text: String) -> bool:
	var read: Variant = parse(text)
	if read == null:
		return false
	messages = read
	var data: Dictionary = JSON.parse_string(text)
	var name: String = data["settings_name"] if data.get("settings_name") is String else ""
	TSTunables.apply_remote(data.get("settings"), name)
	TSAnalytics.user_property("remote_settings", name if name != "" else "default")
	return true


## The last file read, once a run: its messages and settings.
static func load_cache() -> void:
	if _cache_read or not TSProfile.persist:
		return
	_cache_read = true
	if FileAccess.file_exists(CACHE_PATH):
		take(FileAccess.get_file_as_string(CACHE_PATH))
