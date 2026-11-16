class_name TSErrorReporter
extends Logger

## Catches the game's own script errors (a null call, a bad index, a
## push_error) and hands them to GameAnalytics (GA) as error events, so a bug that
## only shows up on some phone is seen instead of silently ending a session.
##
## Godot calls a Logger from whichever thread hit the error, so everything
## here is behind a mutex and does nothing with the engine: it only notes the
## message. The same error is reported once per run (they repeat every frame
## otherwise) and at most MAX_PER_RUN in all.
##
## It cannot see a native crash (the engine itself dying): those only show up
## in Play Console's Android vitals and Xcode's crash reports.

const MAX_PER_RUN := 25
const MAX_LENGTH := 500

var _mutex := Mutex.new()
var _pending: Array[String] = []
var _seen := {}


## Script frames added to a report (innermost first), so an engine-level
## message ("slot >= slot_max", "data.tree is null") says which line of ours
## led to it. Empty when nothing of ours was running (a timer, a plugin).
const MAX_FRAMES := 3

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	var message := "%s%s @ %s:%d (%s)" % [code, (": " + rationale) if rationale != "" else "", file.get_file(), line, function]
	var where := PackedStringArray()
	for bt in script_backtraces:
		if bt == null:
			continue
		for i in mini(bt.get_frame_count(), MAX_FRAMES - where.size()):
			where.append("%s:%d %s" % [bt.get_frame_file(i).get_file(), bt.get_frame_line(i), bt.get_frame_function(i)])
		if where.size() >= MAX_FRAMES:
			break
	if not where.is_empty():
		message += " | " + " < ".join(where)
	message = message.left(MAX_LENGTH)
	var key := message.hash()
	_mutex.lock()
	if not _seen.has(key) and _seen.size() < MAX_PER_RUN:
		_seen[key] = true
		_pending.append(message)
	_mutex.unlock()


## The messages noted since the last call (and forgets them).
func take() -> Array[String]:
	_mutex.lock()
	var out := _pending.duplicate()
	_pending.clear()
	_mutex.unlock()
	return out
