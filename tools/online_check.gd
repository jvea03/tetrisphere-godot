# The online leaderboards and stickers against the real Firebase project, end
# to end, from a throwaway profile with its own sign-in file (the machine's
# real save is never touched). It signs in once (one anonymous user), writes
# a row on a test board ("check_e2e", which the game never shows), reads it
# back, asks a place, sends a sticker to a made-up receiver, and checks that
# the rules turn away what they should. It prints the test user's id so its
# data can be deleted in the console afterwards. Run with:
#   Godot.exe --headless --path . res://tools/online_check.tscn
extends Node

const BOARD := "check_e2e"
const RECEIVER := "e2e-receiver"
var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


## Waits for a callback-style call: fn(done) where done(result).
func _ask(fn: Callable, seconds := 15.0) -> Variant:
	var box := []
	fn.call(func(r: Variant = null) -> void: box.append(r))
	var t := 0.0
	while box.is_empty() and t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
	return box[0] if not box.is_empty() else "TIMEOUT"


## A raw call: true if Firebase accepted it.
func _raw(method: String, path: String, body: Variant) -> bool:
	var r: Variant = await _ask(func(done: Callable) -> void:
		Online._call(method, Online.DOCS + path, body, func(ok: bool, _d: Variant) -> void: done.call(ok)))
	return r == true


func _ready() -> void:
	TSProfile.use_test_profile(20)
	TSProfile.player_name = "E2E Test"
	Online.check_mode = true
	Online.auth_path = "user://online_check_auth.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Online.auth_path))
	_run()


func _run() -> void:
	# 1. A row on the test board (signs in on the way).
	var wrote: bool = await _raw("PATCH", "/boards/%s/entries/{uid}" % BOARD, {"fields": Online.to_fields({"name": "E2E Test", "avatar": 8, "stars": 42, "t": 1})})
	_check("signed in anonymously (uid %s)" % Online.uid, Online.uid != "")
	_check("wrote this player's row", wrote)

	# 2. Read the board back, as the game does.
	Online.fetch(BOARD, true)
	var t := 0.0
	while Online.entries(BOARD).is_empty() and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	var rows: Array = Online.entries(BOARD)
	_check("read the board back (%s)" % str(rows), rows.size() >= 1 and rows.any(func(e: Dictionary) -> bool: return e["is_player"] and e["stars"] == 42 and e["name"] == "E2E Test"))

	# 3. Places, by the count query.
	var below: Variant = await _ask(func(done: Callable) -> void: Online.place_on(BOARD, 10, done))
	var above: Variant = await _ask(func(done: Callable) -> void: Online.place_on(BOARD, 50, done))
	_check("10 stars would place 2nd (%s), 50 first (%s)" % [str(below), str(above)], below == 2 and above == 1)

	var size: Variant = await _ask(func(done: Callable) -> void: Online.board_size(BOARD, done))
	_check("counts the board's players (%s)" % str(size), size == 1)

	# 4. A sticker, as the game sends it.
	var sent: Variant = await _ask(func(done: Callable) -> void: Online.send_sticker(RECEIVER, "congrats", done))
	_check("sent a sticker", sent == true)

	# 5. Names: this player takes one (again is fine), and can't write another's.
	var mine := "E2E %d" % (randi() % 1000000)
	var claimed: Variant = await _ask(func(done: Callable) -> void: Online.claim_name(mine, done))
	var again: Variant = await _ask(func(done: Callable) -> void: Online.claim_name(mine, done))
	_check("claimed a name, and it stays this player's (%s, %s)" % [str(claimed), str(again)], claimed == "ok" and again == "ok")
	_check("rules: no claiming a name for someone else", not await _raw("POST", "/names?documentId=%s" % Online.name_key(mine + "x"), {"fields": Online.to_fields({"uid": "someone-else", "name": "x2", "t": 1})}))
	Online.release_name(Online.name_key(mine))

	# 6. What the rules must refuse.
	_check("rules: no sticker that isn't one of the game's", not await _raw("PATCH", "/stickers/%s/got/{uid}" % RECEIVER, {"fields": Online.to_fields({"name": "E2E Test", "avatar": 8, "sticker": "rude", "t": 1})}))
	_check("rules: no writing someone else's row", not await _raw("PATCH", "/boards/%s/entries/someone-else" % BOARD, {"fields": Online.to_fields({"name": "Fake", "avatar": 1, "stars": 999, "t": 1})}))
	_check("rules: no reading someone else's stickers", not await _raw("GET", "/stickers/%s/got" % RECEIVER, null))
	_check("rules: no impossible star totals", not await _raw("PATCH", "/boards/%s/entries/{uid}" % BOARD, {"fields": Online.to_fields({"name": "E2E Test", "avatar": 8, "stars": 999999, "t": 1})}))
	_check("rules: no sticker with a 40-letter name", not await _raw("PATCH", "/stickers/%s/got/{uid}" % RECEIVER, {"fields": Online.to_fields({"name": "x".repeat(40), "avatar": 8, "sticker": "sad", "t": 1})}))

	# 7. This player's own stickers: readable (none waiting).
	Online.last_error = ""
	Online.check_stickers(true)
	await get_tree().create_timer(4.0).timeout
	_check("read its own stickers (%s)" % Online.last_error, Online.last_error == "")

	print("")
	print("TEST USER: ", Online.uid)
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
