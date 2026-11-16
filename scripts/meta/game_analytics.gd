extends Node

## Anonymous gameplay analytics, sent to GameAnalytics over its REST API (v2),
## as Duckdoku does. No native plugin: plain HTTPS from here, so it behaves the
## same on Android and iOS and cannot break a build. See docs/analytics.md for
## the setup (the key pairs below, the dashboard, and the event list).
##
## What it sends: a random id made on this device, the session, the build, the
## OS version and device model, and the events the game reports (levels, ads,
## purchases, the first-run steps, script errors). Never the advertising id,
## the player's leaderboard name or anything typed. Settings has a switch
## (TSProfile.analytics_enabled), Tunables "analytics_enabled" is the kill
## switch, and where the law asks first (TSPrivacyRegion) nothing runs until
## the player says yes.
##
## It only runs on a phone (or when a test forces it): the editor, desktop
## builds and the test suite's throwaway profiles report nothing.
##
## TSAnalytics (Firebase on Android) forwards its events here, so the game
## reports through one place: see scripts/meta/analytics.gd.

## One key pair per platform: a GameAnalytics game is one platform with one
## pair, under the studio The Little Guy Games: iOS is "Egg Escape: Puzzle
## Break" (game 361868), Android "Egg Escape (Android)" (game 361869), both
## made 16 Nov 2026 as Collection API games. A platform whose pair is empty
## reports to the public sandbox below, where events are thrown away.
const GAME_KEY_IOS := "f61d06cb40d99cadbdad2554463e777a"
const SECRET_KEY_IOS := "4ae0a2ac57c450dcc3d9d49e651c8efb9456fad0"
const GAME_KEY_ANDROID := "9d1e552d58aac7606cc72aaca5eedbdd"
const SECRET_KEY_ANDROID := "0a6e50c61a3550985fc14aa6728fc038068676e6"
const USE_SANDBOX := false

## GameAnalytics' public sandbox pair, used by any platform without its own.
const GAME_KEY_SANDBOX := "5c6bcb5402204249437fb5a7a80a4959"
const SECRET_KEY_SANDBOX := "16813a12f718bc5c620f56944e1abc3ea13ccbac"

const API_LIVE := "https://api.gameanalytics.com/v2/"
const API_SANDBOX := "https://sandbox-api.gameanalytics.com/v2/"
const SDK_VERSION := "rest api v2"
const SESSION_TIMEOUT := 30 # seconds in the background before a new session
const FLUSH_SECONDS := 20.0
const BATCH_SIZE := 50
const MAX_QUEUE := 400 # oldest are dropped past this, so a long offline stretch cannot grow without end
const MAX_EVENT_AGE := 86400 # saved events older than this are not sent: the server refuses stale timestamps
const QUEUE_PATH := "user://analytics_queue.json"
const STATE_PATH := "user://analytics_state.cfg"

## Real USD prices, in cents, of the store products (tools/asc_iaps.py and
## docs/android.md). A business event reports what the player paid, which the
## store's localised price string cannot give.
const PRICE_CENTS := {
	"egg_coins_5000": 99, "egg_coins_16000": 299, "egg_coins_50000": 699,
	"egg_coins_120000": 1299, "egg_coins_320000": 2999,
	"egg_materials_500": 99, "egg_materials_1600": 299, "egg_materials_5000": 699,
	"egg_materials_12000": 1299, "egg_materials_32000": 2999,
	"egg_bundle_starter": 99, "egg_bundle_value": 299, "egg_bundle_mega": 699,
	"egg_featured_hatchers_hoard": 499, "egg_no_ads_pass": 499, "egg_battle_pass": 499,
	"egg_popup_hatch_day_2026": 499, "egg_popup_starter_sprinkle": 99, "egg_popup_flash_sale": 499,
}

var enabled := false
var log_events := false # print every event; for checking the wiring

var _user_id := ""
var _session_id := ""
var _session_num := 0
var _session_start := 0
var _transaction_num := 0
var _ts_offset := 0 # server time minus device time, from the init call
var _initialized := false
var _dead := false # the server refused the keys or switched the game off
var _queue: Array = []
var _http: HTTPRequest
var _busy := false
var _pending := "" # "init" or "events"
var _sending := 0 # how many events the request in flight carries
var _paused_at := 0
var _attempts := {} # progression key -> starts this run
var _forced_platform := ""
var _wired := false
var _errors: TSErrorReporter # the game's own script errors, sent as error events


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.has("analytics-test"):
		_forced_platform = "android"
	log_events = args.has("analytics-log")
	# Wait a frame before touching the profile: the first scene's _ready runs
	# after the autoloads', and a test switches to its throwaway profile there.
	# Loading the save here first would hand every test the real one.
	_begin.call_deferred()


func _begin() -> void:
	TSProfile.ensure_loaded()
	_load_state()
	enabled = _allowed()
	if enabled:
		_start()


## Whether analytics may run for this player right now: a phone (or a forced
## test), the kill switch, the real save, the Settings switch and, where the
## law asks first, a yes.
func _allowed() -> bool:
	if _platform() == "" or not TSTunables.get_bool("analytics_enabled"):
		return false
	if _forced_platform == "" and not TSProfile.persist:
		return false # a test's throwaway profile
	return TSPrivacyRegion.analytics_allowed()


## Opens a session, wiring everything up the first time. Called at launch when
## analytics is allowed, and again if the player turns it on later.
func _start() -> void:
	if not _wired:
		_wire()
	_load_state() # a fresh random ID if it was deleted by an opt-out
	_load_queue()
	_begin_session()
	flush()


func _wire() -> void:
	_wired = true
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	var timer := Timer.new()
	timer.wait_time = FLUSH_SECONDS
	timer.autostart = true
	timer.timeout.connect(func():
		_save_state() # keeps "last seen" fresh, for closing this session if the app is killed
		flush())
	add_child(timer)
	Ads.rewarded_result.connect(func(earned: bool): design("Ad:Rewarded:" + ("Earned" if earned else "Skipped")))
	# Shown = Closed + Abandoned (killed mid-ad, reported at the next launch);
	# NoFill closed at once with nothing on screen. The source part says
	# where: "Level" after a win, "Home" for one owed from a closed win card.
	Ads.interstitial_started.connect(func(source: String): design("Ad:Interstitial:Shown:" + source))
	Ads.interstitial_closed.connect(func():
		design("Ad:Interstitial:%s:%s" % ["Closed" if Ads.last_interstitial_filled else "NoFill", Ads.last_interstitial_source]))
	Billing.purchase_result.connect(_on_purchase_result)
	_errors = TSErrorReporter.new()
	OS.add_logger(_errors)


## The player said yes (the consent card, or Settings -> Share usage data):
## starts at once, in the same run.
func enable_after_consent() -> void:
	enabled = _allowed()
	TSAnalytics.start()
	if enabled:
		_start()


## The player turned analytics off (the consent card or Settings -> Share usage
## data): nothing more is sent, whatever was waiting is thrown away and the
## random ID and the saved state are deleted.
func set_opt_out(opted_out: bool) -> void:
	if opted_out:
		enabled = false
		_queue.clear()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QUEUE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
		_user_id = ""
		_session_num = 0


# ---------------------------------------------------------------- reporting

## A free-form event, "Part:Part:Part" (up to five parts), with an optional number.
func design(event_id: String, value = null) -> void:
	var ev := {"category": "design", "event_id": _id(event_id, 5)}
	if value != null:
		ev["value"] = float(value)
	_push(ev)


## A level or other attempt: status "Start", "Complete" or "Fail".
func progression(status: String, p1: String, p2: String = "", score: int = -1) -> void:
	var key := p1 + ":" + p2
	var id := "%s:%s" % [status, _id(p1, 1)]
	if p2 != "":
		id += ":" + _id(p2, 1)
	var ev := {"category": "progression", "event_id": id}
	if status == "Start":
		_attempts[key] = int(_attempts.get(key, 0)) + 1
	else:
		ev["attempt_num"] = maxi(int(_attempts.get(key, 1)), 1)
		if status == "Complete":
			_attempts[key] = 0
		if score >= 0:
			ev["score"] = score
	_push(ev)


## Coins (or another currency) coming in ("Source") or going out ("Sink").
func resource(flow: String, item_type: String, item_id: String, amount: int, currency: String = "Coins") -> void:
	if amount == 0:
		return
	_push({"category": "resource", "event_id": "%s:%s:%s:%s" % [flow, _id(currency, 1), _id(item_type, 1), _id(item_id, 1)], "amount": absi(amount)})


## A real-money purchase, amount in cents of USD.
func business(product_id: String, cents: int, cart_type: String = "Shop") -> void:
	_transaction_num += 1
	_save_state()
	_push({"category": "business", "event_id": "IAP:" + _id(product_id, 1), "amount": cents, "currency": "USD", "cart_type": _id(cart_type, 1), "transaction_num": _transaction_num})


func _on_purchase_result(product_id: String, success: bool) -> void:
	if not success:
		return
	var cents: int = int(PRICE_CENTS.get(product_id, 0))
	if cents > 0:
		business(product_id, cents, "Popup" if product_id.begins_with("egg_popup_") else "Shop")


# ------------------------------------------------------------------ session

func _begin_session() -> void:
	# a session the app left behind (killed in the background) ends first,
	# at the moment it last was seen
	var state := ConfigFile.new()
	if state.load(STATE_PATH) == OK and str(state.get_value("state", "prev_session_id", "")) != "":
		_push_for({"category": "session_end", "length": maxi(int(state.get_value("state", "prev_active", 0)) - int(state.get_value("state", "prev_start", 0)), 0)},
			str(state.get_value("state", "prev_session_id", "")), int(state.get_value("state", "prev_num", 0)), int(state.get_value("state", "prev_active", 0)))
	_session_id = _uuid()
	_session_num += 1
	_session_start = int(Time.get_unix_time_from_system())
	_save_state()
	_push({"category": "user"})
	design("Session:Start", _session_num)
	if TSProfile.interstitial_abandoned: # the last run was killed mid-ad
		TSProfile.interstitial_abandoned = false
		design("Ad:Interstitial:Abandoned")


func _notification(what: int) -> void:
	if not enabled:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_paused_at = int(Time.get_unix_time_from_system())
		_save_state()
		_save_queue()
		flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var away := int(Time.get_unix_time_from_system()) - _paused_at
		if _paused_at > 0 and away > SESSION_TIMEOUT:
			_push_for({"category": "session_end", "length": maxi(_paused_at - _session_start, 0)}, _session_id, _session_num, _paused_at)
			_session_id = _uuid()
			_session_num += 1
			_session_start = int(Time.get_unix_time_from_system())
			_save_state()
			_push({"category": "user"})
		_paused_at = 0


# --------------------------------------------------------------------- queue

## Who sees which ads: "noads" owns the No Ads pass, "payer" bought anything
## else, "free" has bought nothing (see game.gd _roll_interstitial).
func _player_type() -> String:
	if TSProfile.no_ads:
		return "noads"
	return "payer" if TSProfile.is_payer else "free"


func _push(ev: Dictionary) -> void:
	_push_for(ev, _session_id, _session_num, int(Time.get_unix_time_from_system()))


func _push_for(ev: Dictionary, session_id: String, session_num: int, at: int) -> void:
	if not enabled:
		return
	var info := Engine.get_version_info()
	var full := {
		"v": 2, "user_id": _user_id, "sdk_version": SDK_VERSION, "os_version": _os_version(),
		"custom_01": _player_type(), # split anything in Explore by Custom 01
		"manufacturer": "unknown", "device": _device(), "platform": _platform(),
		"session_id": session_id, "session_num": session_num, "build": _build(),
		"engine_version": "godot %d.%d.%d" % [info["major"], info["minor"], info["patch"]],
		"client_ts": at,
	}
	full.merge(ev, true)
	_queue.append(full)
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(_queue.size() - MAX_QUEUE)
	if log_events:
		print("[GA] ", JSON.stringify(ev))
	if _queue.size() >= BATCH_SIZE:
		flush()


## Sends what is waiting. Safe to call any time: it does nothing while a
## request is in flight, offline (the events stay queued) or switched off.
func flush() -> void:
	if enabled and _errors != null:
		for message in _errors.take():
			_push({"category": "error", "severity": "error", "message": message})
	if not enabled or _dead or _busy or _queue.is_empty() or _http == null:
		return
	if not _initialized:
		_post("init", JSON.stringify({"platform": _platform(), "os_version": _os_version(), "sdk_version": SDK_VERSION}))
		return
	var batch: Array = _queue.slice(0, BATCH_SIZE)
	_sending = batch.size()
	var out := []
	for ev in batch:
		var copy: Dictionary = ev.duplicate()
		copy["client_ts"] = int(copy["client_ts"]) + _ts_offset
		out.append(copy)
	_post("events", JSON.stringify(out))


func _post(kind: String, body: String) -> void:
	_busy = true
	_pending = kind
	var url := (API_SANDBOX if _sandbox() else API_LIVE) + _game_key() + "/" + kind
	var headers := ["Content-Type: application/json", "Authorization: " + _auth(body)]
	if _http.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		_busy = false


func _auth(body: String) -> String:
	return Marshalls.raw_to_base64(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _secret_key().to_utf8_buffer(), body.to_utf8_buffer()))


## The key pair for the platform this build runs on. A platform without its
## own pair uses the sandbox, so its events never reach the dashboard and
## never mix into another platform's numbers.
func _has_own_keys() -> bool:
	if _forced_platform != "":
		return false # a test run never reports to a real game
	if _platform() == "android":
		return GAME_KEY_ANDROID != "" and SECRET_KEY_ANDROID != ""
	return GAME_KEY_IOS != "" and SECRET_KEY_IOS != ""


func _game_key() -> String:
	if not _has_own_keys():
		return GAME_KEY_SANDBOX
	return GAME_KEY_ANDROID if _platform() == "android" else GAME_KEY_IOS


func _secret_key() -> String:
	if not _has_own_keys():
		return SECRET_KEY_SANDBOX
	return SECRET_KEY_ANDROID if _platform() == "android" else SECRET_KEY_IOS


func _sandbox() -> bool:
	return USE_SANDBOX or not _has_own_keys()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var kind := _pending
	_pending = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		return # offline or timed out: the events wait for the next flush
	if code == 401:
		_dead = true
		push_warning("[GA] the server refused the keys (401); analytics is off for this run")
		return
	if kind == "init":
		var data = _parse(body.get_string_from_utf8())
		if code == 200 and data is Dictionary:
			if not bool(data.get("enabled", true)):
				_dead = true
				return
			_ts_offset = int(data.get("server_ts", 0)) - int(Time.get_unix_time_from_system())
			_initialized = true
			flush()
		return
	if code == 200 or code == 400:
		# 400 means the server will never take this batch: drop it rather than retry forever
		if code == 400:
			push_warning("[GA] a batch was refused (400): %s" % body.get_string_from_utf8().left(160))
		_queue = _queue.slice(_sending)
		_sending = 0
		if not _queue.is_empty():
			flush.call_deferred()


# --------------------------------------------------------------------- state

func _load_state() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATE_PATH)
	_user_id = str(cfg.get_value("state", "user_id", ""))
	if _user_id == "":
		_user_id = _uuid()
	_session_num = int(cfg.get_value("state", "session_num", 0))
	_transaction_num = int(cfg.get_value("state", "transaction_num", 0))


func _save_state() -> void:
	if not enabled:
		return # nothing is written to disk before a yes
	var cfg := ConfigFile.new()
	cfg.set_value("state", "user_id", _user_id)
	cfg.set_value("state", "session_num", _session_num)
	cfg.set_value("state", "transaction_num", _transaction_num)
	# what a launch needs to close this session if the app is killed while away
	cfg.set_value("state", "prev_session_id", _session_id)
	cfg.set_value("state", "prev_num", _session_num)
	cfg.set_value("state", "prev_start", _session_start)
	cfg.set_value("state", "prev_active", int(Time.get_unix_time_from_system()))
	cfg.save(STATE_PATH)


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_queue))


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var data = _parse(FileAccess.get_file_as_string(QUEUE_PATH))
	if data is Array:
		var cutoff := int(Time.get_unix_time_from_system()) - MAX_EVENT_AGE
		for ev in data:
			if ev is Dictionary and int(ev.get("client_ts", 0)) >= cutoff:
				_queue.append(ev)


# ------------------------------------------------------------------- helpers

## JSON text to a value, or null if it is not JSON. Unlike JSON.parse_string it
## logs nothing on bad input: a failing server's HTML error page must not
## become an engine error that the error reporter then reports, round and round.
func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


func _platform() -> String:
	if _forced_platform != "":
		return _forced_platform
	match OS.get_name():
		"Android":
			return "android"
		"iOS":
			return "ios"
	return ""


func _os_version() -> String:
	# On Android, get_version() is "<sdk>.<build code>" (36.S918BXXU5CXK1), which
	# the server refuses with a 400. The alias starts with the release ("16 (SDK ...").
	var raw := OS.get_version_alias() if OS.get_name() == "Android" else OS.get_version()
	return "%s %s" % [_platform(), clean_os_version(raw)]


## The server takes only up to three numbers of up to 5 digits ("16", "18.1").
## It refuses every event in a batch with anything else, so send "0" instead.
static func clean_os_version(raw: String) -> String:
	var version := raw.get_slice(" ", 0)
	var re := RegEx.new()
	re.compile("^[0-9]{1,5}(\\.[0-9]{1,5}){0,2}$")
	return version if re.search(version) != null else "0"


func _device() -> String:
	var model := OS.get_model_name()
	return "unknown" if model == "" or model == "GenericDevice" else model.left(32)


func _build() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## Event ids allow letters, digits, spaces and - _ . , ( ) ! ? ; each
## ":"-separated part is cut to 32 characters, and a design id to `parts`.
func _id(text: String, parts: int) -> String:
	var out := []
	var re := RegEx.new()
	re.compile("[^A-Za-z0-9 \\-_.,()!?]")
	for part in text.split(":"):
		out.append(re.sub(part, "_", true).left(32))
		if out.size() >= parts:
			break
	return ":".join(out)


func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
