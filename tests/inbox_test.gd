# The inbox on a throwaway profile, with no network: a file's messages are read
# (a broken file, or a broken message, is left out), each phone keeps the ones
# for its level, streak and date, the tile shows only while one waits, and a
# reward is given once.
# Run with:
#   Godot.exe --headless --path . res://tests/inbox_test.tscn
# With a window and OUT=folder it also saves inbox_home.png, inbox_card.png and
# inbox_long.png (two messages of the longest kind).
extends "res://scripts/screens/home.gd"

const FILE := """{"messages": [
	{"id": "plain", "title": "Hello", "body": "Welcome!"},
	{"id": "gift", "title": "A gift", "rewards": {"coins": 500, "materials": 40, "bomb": 2, "swap": 1, "rocks": 3, "skips": 4, "gems": 9}},
	{"id": "high", "title": "Veterans", "min_level": 50},
	{"id": "low", "title": "Newcomers", "max_level": 5},
	{"id": "streak", "title": "Regulars", "min_streak": 30},
	{"id": "later", "title": "Soon", "from": "2999-01-01"},
	{"id": "over", "title": "Gone", "until": "2000-01-01"},
	{"title": "No id"},
	{"id": "no-title"},
	"not a message"
]}"""

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSProfile.login_streak_count = 1
	TSProfile.inbox_done = {}
	TSInbox.messages = []
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ids() -> Array:
	return TSInbox.active().map(func(m: Dictionary) -> String: return m["id"])


func _press(text: String) -> void:
	for b: Button in (_inbox["box"] as Control).find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == text:
			b.pressed.emit()
			return
	_check("found the %s button" % text, false)


func _shot(file: String) -> void:
	if OS.get_environment("OUT") == "":
		return
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT").path_join(file))


func _run() -> void:
	TSUI.conceal(_sale["root"])
	_check("a broken file isn't read", TSInbox.parse("{oops") == null and TSInbox.parse("[1]") == null and TSInbox.parse("{}") == null)
	_check("an empty one is", (TSInbox.parse("{\"messages\": []}") as Array).is_empty())
	_refresh_inbox()
	_check("no messages: no tile", not inbox_btn.visible)

	var read: Array = TSInbox.parse(FILE)
	_check("broken messages are left out (%d)" % read.size(), read.size() == 7)
	TSInbox.messages = read
	_refresh_inbox()
	var ids := _ids()
	_check("this player gets the two meant for them, last in the file first (%s)" % str(ids), ids == ["gift", "plain"])
	_check("the tile shows and counts them", inbox_btn.visible and inbox_badge.get_meta("label").text == "2")

	var m: Dictionary = read[2]
	_check("a level rule", TSInbox.applies(m, 50, 0, "2026-11-06") and not TSInbox.applies(m, 49, 0, "2026-11-06"))
	m = read[3]
	_check("an upper level rule", TSInbox.applies(m, 5, 0, "2026-11-06") and not TSInbox.applies(m, 6, 0, "2026-11-06"))
	m = read[4]
	_check("a streak rule", TSInbox.applies(m, 1, 30, "2026-11-06") and not TSInbox.applies(m, 1, 29, "2026-11-06"))
	m = {"min_level": 0, "max_level": 0, "min_streak": 0, "from": "2026-11-20", "until": "2026-11-30"}
	_check("dates include both ends", TSInbox.applies(m, 1, 0, "2026-11-20") and TSInbox.applies(m, 1, 0, "2026-11-30") and not TSInbox.applies(m, 1, 0, "2026-11-19") and not TSInbox.applies(m, 1, 0, "2026-12-01"))

	await _shot("inbox_home.png")
	var coins := TSProfile.coin_count
	var materials := TSProfile.materials
	var bombs := TSProfile.bomb_count
	var swaps := TSProfile.swap_count
	var rocks := TSProfile.rock_count
	var skips := TSProfile.time_skips
	_open_inbox()
	await get_tree().process_frame
	_check("the inbox opens", _inbox["root"].visible)
	await _shot("inbox_card.png")
	_press("Collect")
	await get_tree().process_frame
	_check("Collect gives each reward", TSProfile.coin_count == coins + 500 and TSProfile.materials == materials + 40 and TSProfile.bomb_count == bombs + 2 and TSProfile.swap_count == swaps + 1 and TSProfile.rock_count == rocks + 3 and TSProfile.time_skips == skips + 4)
	_check("and the next message stays up", _inbox["root"].visible and _ids() == ["plain"] and inbox_badge.get_meta("label").text == "1")
	TSInbox.claim(read[1])
	_check("a reward is given once", TSProfile.coin_count == coins + 500)
	_press("OK")
	await get_tree().process_frame
	_check("the last message read: no tile", _ids().is_empty() and not inbox_btn.visible)

	var long := "A long message from the studio, as long as a message can be, to see that it still fits on a short phone with its rewards and its button. ".repeat(3)
	var gift := {"id": "a", "title": "The longest title you would ever write here", "body": long, "rewards": {"coins": 500000, "materials": 40000, "bomb": 2, "swap": 1, "rocks": 3, "skips": 4}}
	TSInbox.messages = TSInbox.parse(JSON.stringify({"messages": [gift, {"id": "b", "title": gift["title"], "body": long, "rewards": gift["rewards"]}, {"id": "c", "title": "Third"}]}))
	_check("the text is cut to size", str(TSInbox.messages[0]["body"]).length() == TSInbox.MAX_BODY)
	await get_tree().create_timer(0.5).timeout   # the card closed by the last message has gone
	_open_inbox()
	await get_tree().process_frame
	await _shot("inbox_long.png")
	TSUI.conceal(_inbox["root"])
	TSInbox.messages = []

	# Remote settings ride in the same file.
	_check("no settings: the shipped numbers", TSTunables.get_int("interstitial_from_level") == 30)
	var taken := TSInbox.take(JSON.stringify({"messages": [], "settings_name": "ads-l10", "settings": {
		"interstitial_from_level": 10, "interstitial_every_n_wins": 2.0, "social_enabled": true,
		"ad_chest_per_day": -1, "ad_build_per_day": 2.5, "coins_per_star": "500", "piece_budget_extra": 99999999, "no_such_key": 7}}))
	_check("a file's settings are taken", taken and TSTunables.get_int("interstitial_from_level") == 10 and TSTunables.get_int("interstitial_every_n_wins") == 2 and TSTunables.get_bool("social_enabled") and TSTunables.remote_name == "ads-l10")
	_check("bad values keep the shipped ones (negative, fraction, text)", TSTunables.get_int("ad_chest_per_day") == 3 and TSTunables.get_int("ad_build_per_day") == 3 and TSTunables.get_int("coins_per_star") == 100)
	_check("a huge number is capped", TSTunables.get_int("piece_budget_extra") == TSTunables.MAX_REMOTE)
	_check("a broken file changes nothing", not TSInbox.take("{oops") and TSTunables.get_int("interstitial_from_level") == 10)
	TSInbox.take("{\"messages\": []}")
	_check("a key taken out goes back to its default", TSTunables.get_int("interstitial_from_level") == 30 and not TSTunables.get_bool("social_enabled") and TSTunables.remote_name == "")

	TSProfile.inbox_done = {}
	TSProfile.persist = false
	TSInbox.fetch(self, func() -> void: pass)
	_check("a throwaway profile asks the network for nothing", find_children("*", "HTTPRequest", true, false).is_empty())

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
