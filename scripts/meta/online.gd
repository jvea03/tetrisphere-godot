extends Node

## The online side, on the game's Firebase project over its REST APIs (so
## Android and iOS work alike, with no SDK): real leaderboards, and stickers
## players send each other from them. See docs/online.md and firestore.rules.
##
## - Sign-in is anonymous: each install gets a Firebase user id, kept in
##   AUTH_PATH with its refresh token. No email, no Google sign-in.
## - A board is boards/{board}/entries/{uid}: name, avatar (a critter), stars.
##   The phone writes its own row whenever its stars change, and reads the top
##   TOP_N. A finished board's place is a count of rows with more stars.
## - A sticker is stickers/{to}/got/{from}: one waiting per sender per
##   receiver (a new one replaces it), so nobody can be flooded. Received
##   ones are shown once, when the player opens Ranks, and deleted.
## Everything is quiet offline, and on a throwaway profile (tests).

signal boards_changed   # a board arrived
signal stickers_arrived

const API_KEY := TSAnalytics.API_KEY
const PROJECT := TSAnalytics.PROJECT_ID
const SIGN_UP := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY
const REFRESH := "https://securetoken.googleapis.com/v1/token?key=" + API_KEY
const DOCS := "https://firestore.googleapis.com/v1/projects/" + PROJECT + "/databases/(default)/documents"
const AUTH_PATH := "user://online_auth.json"
## tools/online_check: talks to Firebase from a throwaway profile, with its
## own sign-in file, so the real save on that machine is never touched.
var check_mode := false
var auth_path := AUTH_PATH
const TOP_N := 50
const FETCH_EVERY := 60.0       # seconds a board stays fresh
const STICKERS_EVERY := 120.0   # seconds between looks for new stickers

var uid := ""
var _id_token := ""
var _refresh_token := ""
var _expires_at := 0.0          # Time.get_unix_time_from_system() the id token lapses
var _signing_in := false
var _waiting: Array = []        # calls queued for the sign-in

var boards := {}                # board id -> {"entries": [...], "at": unix time}
var received: Array = []        # stickers waiting to be shown: {from, name, avatar, sticker}
var _stickers_at := -1.0e9
var _pushed := {}               # board id -> the stars last written
var last_error := ""


func enabled() -> bool:
	return check_mode or force_fake or (TSProfile.persist and TSNav.leaderboards_open())


# -- a fake leaderboard, for testing in the editor ------------------------------------
# Run from the Godot editor with the real save (not a test's throwaway profile,
# not tools/online_check, not as_released), the boards fill with made-up
# players and nothing goes to Firebase: a sticker sent to one "arrives", and
# about half the time they send one back a few seconds later, so receiving can
# be tried too. Every sticker is owned there (TSStickers.owns). A release
# build never does any of this.
const FAKE_NAMES := ["Sunny", "Pip", "Marshmallow", "Bean", "Clover", "Waffles", "Juniper", "Tofu", "Biscuit", "Pebble",
	"Noodle", "Maple", "Sprout", "Dumpling", "Comet", "Peaches", "Mochi", "Rascal", "Button", "Ziggy"]


var _fake_greeted := false
var force_fake := false   # tests/menu_capture `fake`: on a throwaway profile too

func fake() -> bool:
	return force_fake or (OS.has_feature("editor") and not TSNav.as_released and not check_mode and TSProfile.persist)


## A fake board's rows: the same for a board id every time.
func _fake_rows(board: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fake_" + board)
	var per_day := 1 if board.begins_with("daily") else (4 if board.begins_with("weekly") else 12)
	var rows: Array = []
	for k in FAKE_NAMES.size():
		rows.append({"uid": "fake_%d" % k, "name": FAKE_NAMES[k], "avatar": rng.randi_range(0, TSProfile.CRITTER_COUNT - 1),
			"stars": rng.randi_range(0, 30) * per_day, "is_player": false})
	rows.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]))
	return rows


## A fake player sometimes answers a sticker with one of their own.
func _fake_reply(to_uid: String) -> void:
	if randf() < 0.5:
		return
	var k := int(to_uid.trim_prefix("fake_"))
	var reply: String = TSStickers.ALL.keys().pick_random()
	get_tree().create_timer(randf_range(2.0, 5.0)).timeout.connect(func() -> void:
		received.append({"from": to_uid, "name": FAKE_NAMES[k % FAKE_NAMES.size()], "avatar": k * 7 % TSProfile.CRITTER_COUNT, "sticker": reply})
		stickers_arrived.emit())


# -- boards ------------------------------------------------------------------------

## "daily_2026-11-14", "weekly_W2915", "season_S2": the shared board for a
## period and the key TSProfile keeps its stars under.
static func board_id(period: String, key: String) -> String:
	return "%s_%s" % [period, key.replace("/", "-")]


## Writes the player's row on a board (name, avatar, stars), if any changed.
func push(board: String, stars: int) -> void:
	if fake() or stars <= 0:
		return   # no row until there's a star to show (none below level 7)
	var sig := "%d|%s|%d" % [stars, TSProfile.player_name, TSProfile.avatar()]   # what the row says now
	if not enabled() or str(_pushed.get(board, "")) == sig:
		return
	_pushed[board] = sig
	var fields := {"name": TSProfile.player_name, "avatar": TSProfile.avatar(), "stars": stars, "t": int(Time.get_unix_time_from_system())}
	_call("PATCH", "%s/boards/%s/entries/%s" % [DOCS, board, uid_placeholder()], {"fields": to_fields(fields)}, func(ok: bool, _data: Variant) -> void:
		if not ok:
			_pushed.erase(board)
		elif not TSProfile.boards_joined.has(board):
			TSProfile.boards_joined.append(board)   # only boards played online can pay a prize
			TSProfile.save())


## Fetches a board's top TOP_N (if it isn't fresh), then boards_changed.
func fetch(board: String, force := false) -> void:
	if not enabled():
		return
	if fake():
		boards[board] = {"entries": _fake_rows(board), "at": Time.get_unix_time_from_system()}
		boards_changed.emit.call_deferred()
		return
	var have: Dictionary = boards.get(board, {})
	if not force and not have.is_empty() and Time.get_unix_time_from_system() - float(have["at"]) < FETCH_EVERY:
		return
	var query := {"structuredQuery": {
		"from": [{"collectionId": "entries"}],
		"orderBy": [{"field": {"fieldPath": "stars"}, "direction": "DESCENDING"}],
		"limit": TOP_N}}
	_call("POST", "%s/boards/%s:runQuery" % [DOCS, board], query, func(ok: bool, data: Variant) -> void:
		if not ok or not data is Array:
			return
		var entries: Array = []
		for item: Variant in data:
			if not item is Dictionary or not (item as Dictionary).has("document"):
				continue
			var doc: Dictionary = item["document"]
			var f := from_fields(doc.get("fields", {}))
			var id := str(doc.get("name", "")).get_file()
			entries.append({"uid": id, "name": str(f.get("name", "?")), "avatar": int(f.get("avatar", 0)), "stars": int(f.get("stars", 0)), "is_player": id == uid})
		boards[board] = {"entries": entries, "at": Time.get_unix_time_from_system()}
		boards_changed.emit())


## The rows of a board as last fetched (empty until one arrives).
func entries(board: String) -> Array:
	return (boards.get(board, {}) as Dictionary).get("entries", [])


## How many players are on a board. done(n), or done(-1) if it couldn't ask.
func board_size(board: String, done: Callable) -> void:
	if not enabled() or fake():
		done.call(-1 if not fake() else 20)
		return
	var query := {"structuredAggregationQuery": {"structuredQuery": {"from": [{"collectionId": "entries"}]}, "aggregations": [{"alias": "n", "count": {}}]}}
	_call("POST", "%s/boards/%s:runAggregationQuery" % [DOCS, board], query, func(ok: bool, data: Variant) -> void:
		if not ok or not data is Array or (data as Array).is_empty():
			done.call(-1)
			return
		var res: Dictionary = (data as Array)[0].get("result", {})
		var n: Dictionary = (res.get("aggregateFields", {}) as Dictionary).get("n", {})
		done.call(int(n.get("integerValue", "0"))))


## A finished board's place for `stars`: 1 + how many rows have more. Calls
## done(place), or done(0) if it couldn't ask.
func place_on(board: String, stars: int, done: Callable) -> void:
	if not enabled():
		done.call(0)
		return
	if fake():
		done.call(1 + _fake_rows(board).filter(func(e: Dictionary) -> bool: return int(e["stars"]) > stars).size())
		return
	var query := {"structuredAggregationQuery": {
		"structuredQuery": {"from": [{"collectionId": "entries"}],
			"where": {"fieldFilter": {"field": {"fieldPath": "stars"}, "op": "GREATER_THAN", "value": {"integerValue": str(stars)}}}},
		"aggregations": [{"alias": "n", "count": {}}]}}
	_call("POST", "%s/boards/%s:runAggregationQuery" % [DOCS, board], query, func(ok: bool, data: Variant) -> void:
		if not ok or not data is Array or (data as Array).is_empty():
			done.call(0)
			return
		var res: Dictionary = (data as Array)[0].get("result", {})
		var n: Dictionary = (res.get("aggregateFields", {}) as Dictionary).get("n", {})
		done.call(int(n.get("integerValue", "0")) + 1))


# -- stickers ----------------------------------------------------------------------

## Sends a sticker to a player (replacing any of ours still waiting there).
func send_sticker(to_uid: String, sticker: String, done: Callable) -> void:
	if not enabled() or to_uid == "" or to_uid == uid or not TSStickers.owns(sticker):
		done.call(false)
		return
	if fake():
		get_tree().create_timer(0.4).timeout.connect(func() -> void: done.call(true))
		_fake_reply(to_uid)
		return
	if TSBots.is_bot(to_uid):
		get_tree().create_timer(0.4).timeout.connect(func() -> void: done.call(true))   # nobody to deliver to
		return
	var fields := {"name": TSProfile.player_name, "avatar": TSProfile.avatar(), "sticker": sticker, "t": int(Time.get_unix_time_from_system())}
	_call("PATCH", "%s/stickers/%s/got/%s" % [DOCS, to_uid, uid_placeholder()], {"fields": to_fields(fields)}, func(ok: bool, _data: Variant) -> void:
		done.call(ok))


## Looks for stickers sent to this player (now and then), leaving the new
## ones in `received` (not from anyone blocked) and deleting them online.
func check_stickers(force := false) -> void:
	if fake():
		# The fake leaderboard: one sticker from a fake player, once a run, to try
		# the received card without sending first.
		if not _fake_greeted:
			_fake_greeted = true
			var k := randi() % FAKE_NAMES.size()
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				received.append({"from": "fake_%d" % k, "name": FAKE_NAMES[k], "avatar": k * 7 % TSProfile.CRITTER_COUNT, "sticker": TSStickers.ALL.keys().pick_random()})
				stickers_arrived.emit())
		return
	if not enabled() or (not force and Time.get_unix_time_from_system() - _stickers_at < STICKERS_EVERY):
		return
	_stickers_at = Time.get_unix_time_from_system()
	_call("GET", "%s/stickers/%s/got?pageSize=50" % [DOCS, uid_placeholder()], null, func(ok: bool, data: Variant) -> void:
		if not ok or not data is Dictionary:
			return
		var fresh := false
		for doc: Variant in (data as Dictionary).get("documents", []):
			var f := from_fields((doc as Dictionary).get("fields", {}))
			var from := str((doc as Dictionary).get("name", "")).get_file()
			_call("DELETE", "%s/stickers/%s/got/%s" % [DOCS, uid, from], null, func(_ok: bool, _d: Variant) -> void: pass)
			if TSProfile.blocked_players.has(from) or not TSStickers.ALL.has(str(f.get("sticker", ""))):
				continue
			received.append({"from": from, "name": str(f.get("name", "?")), "avatar": int(f.get("avatar", 0)), "sticker": str(f.get("sticker", ""))})
			fresh = true
		if fresh:
			stickers_arrived.emit())


## Takes the waiting stickers (to show them).
func take_received() -> Array:
	var out := received
	received = []
	return out


## Reports a player's name (for review in the Firebase console).
func report(player: String, name: String) -> void:
	if not enabled() or fake() or TSBots.is_bot(player):
		return
	var fields := {"uid": player, "name": name, "by": uid_placeholder(), "t": int(Time.get_unix_time_from_system())}
	_call("POST", "%s/reports" % DOCS, {"fields": to_fields(fields)}, func(_ok: bool, _d: Variant) -> void: pass)


# -- names -------------------------------------------------------------------------

## Tests stand in for the server: called with (name, done) in claim_name.
var name_answer := Callable()


## A name's id in the registry (names/{key}): capitals and spaces don't count,
## so "Egg Bert" and "eggbert" are the one name.
static func name_key(name: String) -> String:
	var n := name.to_lower()
	for gap in [" ", "\t", " ", "​"]:
		n = n.replace(gap, "")
	return n.sha256_text()


## Takes `name` for this player, unless somebody else has it. done("ok"),
## done("taken"), or done("unavailable") if the server couldn't say (offline).
func claim_name(name: String, done: Callable) -> void:
	if name_answer.is_valid():
		name_answer.call(name, done)
		return
	if fake():
		done.call("ok")
		return
	if not enabled():
		done.call("unavailable")
		return
	var key := name_key(name)
	var fields := {"uid": uid_placeholder(), "name": name, "t": int(Time.get_unix_time_from_system())}
	# Creating the name's document fails if it is there: then see whose it is.
	_call("POST", "%s/names?documentId=%s" % [DOCS, key], {"fields": to_fields(fields)}, func(ok: bool, _data: Variant) -> void:
		if ok:
			done.call("ok")
			return
		_call("GET", "%s/names/%s" % [DOCS, key], null, func(got: bool, data: Variant) -> void:
			if not got or not data is Dictionary or not (data as Dictionary).has("fields"):
				done.call("unavailable")
				return
			done.call("ok" if str(from_fields((data as Dictionary)["fields"]).get("uid", "")) == uid else "taken")))


## Gives up a name this player held (by its key), for others to take.
func release_name(key: String) -> void:
	if key != "" and enabled() and not fake() and not name_answer.is_valid():
		_call("DELETE", "%s/names/%s" % [DOCS, key], null, func(_ok: bool, _d: Variant) -> void: pass)


# -- Firestore values ----------------------------------------------------------------

static func to_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		var v: Variant = d[k]
		if v is bool:
			out[k] = {"booleanValue": v}
		elif v is int:
			out[k] = {"integerValue": str(v)}
		elif v is float:
			out[k] = {"doubleValue": v}
		else:
			out[k] = {"stringValue": str(v)}
	return out


static func from_fields(f: Variant) -> Dictionary:
	var out := {}
	if not f is Dictionary:
		return out
	for k: String in f:
		var v: Dictionary = f[k]
		if v.has("integerValue"):
			out[k] = int(v["integerValue"])
		elif v.has("doubleValue"):
			out[k] = float(v["doubleValue"])
		elif v.has("booleanValue"):
			out[k] = bool(v["booleanValue"])
		elif v.has("stringValue"):
			out[k] = str(v["stringValue"])
	return out


# -- requests and sign-in ------------------------------------------------------------

## The uid in a path, filled in once signed in (_call swaps it).
func uid_placeholder() -> String:
	return "{uid}"


## One REST call, signed in first (anonymously, once per install). done(ok, json).
func _call(method: String, url: String, body: Variant, done: Callable) -> void:
	if _id_token != "" and Time.get_unix_time_from_system() < _expires_at - 60.0:
		_send(method, url, body, done)
		return
	_waiting.append([method, url, body, done])
	_sign_in()


func _send(method: String, url: String, body: Variant, done: Callable) -> void:
	url = url.replace("{uid}", uid)
	if body is Dictionary:
		body = JSON.parse_string(JSON.stringify(body).replace("{uid}", uid))
	var methods := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PATCH": HTTPClient.METHOD_PATCH, "DELETE": HTTPClient.METHOD_DELETE}
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray) -> void:
		http.queue_free()
		var text := bytes.get_string_from_utf8()
		var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		if not ok:
			last_error = "%s %d %s" % [method, code, text.left(200)]
		done.call(ok, JSON.parse_string(text) if text != "" else null))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _id_token])
	if http.request(url, headers, methods[method], JSON.stringify(body) if body != null else "") != OK:
		http.queue_free()
		done.call(false, null)


func _sign_in() -> void:
	if _signing_in:
		return
	_signing_in = true
	if _refresh_token == "":
		_load_auth()
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray) -> void:
		http.queue_free()
		_signing_in = false
		var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary:
			last_error = "sign-in %d" % code
			if code == 400 and _refresh_token != "":
				_refresh_token = ""   # a refresh token gone bad: a new anonymous user next time
			_fail_waiting()
			return
		var d: Dictionary = data
		_id_token = str(d.get("idToken", d.get("id_token", "")))
		_refresh_token = str(d.get("refreshToken", d.get("refresh_token", _refresh_token)))
		uid = str(d.get("localId", d.get("user_id", uid)))
		_expires_at = Time.get_unix_time_from_system() + float(d.get("expiresIn", d.get("expires_in", "3600")))
		_save_auth()
		var calls := _waiting
		_waiting = []
		for c in calls:
			_send(c[0], c[1], c[2], c[3]))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _refresh_token != "":
		http.request(REFRESH, headers, HTTPClient.METHOD_POST, JSON.stringify({"grant_type": "refresh_token", "refresh_token": _refresh_token}))
	else:
		http.request(SIGN_UP, headers, HTTPClient.METHOD_POST, JSON.stringify({"returnSecureToken": true}))


func _fail_waiting() -> void:
	var calls := _waiting
	_waiting = []
	for c in calls:
		(c[3] as Callable).call(false, null)


func _load_auth() -> void:
	if not FileAccess.file_exists(auth_path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(auth_path))
	if d is Dictionary:
		uid = str(d.get("uid", ""))
		_refresh_token = str(d.get("refresh", ""))


func _save_auth() -> void:
	var f := FileAccess.open(auth_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"uid": uid, "refresh": _refresh_token}))
