extends Node

## Local notifications (autoload "Notify"): a few reminders scheduled as the
## game goes to the background, and all cancelled when it comes back -- a
## chest or a build finishing, tomorrow's Daily Egg (or, before it unlocks, the
## next critter to rescue), and a nudge after three days away. None land in
## the night: one due then waits for the morning. Android only, through the
## EggNotify plugin (addons/EggNotify); elsewhere this does nothing.

const CHEST := 1
const BUILD := 2
const DAILY := 3
const COMEBACK := 4
const QUIET_FROM := 21          # no reminders from 9 pm ...
const QUIET_TO := 9             # ... until 9 am, local time
const DAILY_HOUR := 18          # the daily reminder's hour
const COMEBACK_SECONDS := 3 * 86400
const MIN_SECONDS := 5 * 60     # anything sooner isn't worth a reminder

var _plugin: Object = null


func _ready() -> void:
	if Engine.has_singleton("EggNotify"):
		_plugin = Engine.get_singleton("EggNotify")
		_plugin.cancelAll()


func available() -> bool:
	return _plugin != null


func has_permission() -> bool:
	return _plugin != null and bool(_plugin.hasPermission())


## Android 13+'s system prompt (nothing on older phones, which need none).
func request_permission() -> void:
	if _plugin != null:
		_plugin.requestPermission()


func _notification(what: int) -> void:
	if _plugin == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_plugin.cancelAll()
			if TSProfile.notifications_enabled and has_permission():
				for r in reminders():
					_plugin.schedule(int(r["id"]), str(r["title"]), str(r["body"]), int(r["seconds"]))
		NOTIFICATION_APPLICATION_RESUMED:
			_plugin.cancelAll()


## What would be scheduled now: [{id, title, body, seconds}].
static func reminders() -> Array:
	var out: Array = []
	var day := TSClock.local_unix() % 86400
	var chest := 0
	for i in TSChests.SLOT_COUNT:
		if TSChests.is_unlocking(i):
			var s := TSChests.seconds_left(i)
			if s > 0 and (chest == 0 or s < chest):
				chest = s
	if chest >= MIN_SECONDS:
		out.append(_entry(CHEST, "Your chest is ready! 🎁", "Come open it and grab your coins.", chest, day))
	var build := 0
	for i in TSProfile.PART_COUNT:
		if TSProfile.is_part_building(i):
			var s := TSProfile.part_build_seconds_left(i)
			if s > 0 and (build == 0 or s < build):
				build = s
	if build >= MIN_SECONDS:
		out.append(_entry(BUILD, "Your build is finished! 🏕️", "The critters are done building. Come see your camp!", build, day))
	# Today's 6 pm if the Daily Egg is still to crack and it's not yet 6,
	# otherwise tomorrow's.
	var to_daily := DAILY_HOUR * 3600 - day
	if to_daily < MIN_SECONDS or (TSNav.daily_unlocked() and TSProfile.is_daily_completed_today()):
		to_daily += 86400
	if TSNav.daily_unlocked() and TSProfile.login_streak_count >= 2:
		out.append(_entry(DAILY, "Keep your %d-day streak going! 🔥" % TSProfile.login_streak_count, "A new Daily Egg is waiting to be cracked.", to_daily, day))
	elif TSNav.daily_unlocked():
		out.append(_entry(DAILY, "A new Daily Egg is here! 🥚", "Crack today's egg for coins and a streak.", to_daily, day))
	else:
		out.append(_entry(DAILY, "A critter is still stuck in its egg! 🥚", "Come back and rescue the next one.", to_daily, day))
	out.append(_entry(COMEBACK, "The critters miss you! 💛", "Your camp is waiting -- come rescue the next critter.", COMEBACK_SECONDS, day))
	return out


## A reminder `seconds` from now, moved on to the morning if it would land in
## the night (`day`: seconds since local midnight now).
static func _entry(id: int, title: String, body: String, seconds: int, day: int) -> Dictionary:
	var hour := ((day + seconds) % 86400) / 3600
	if hour >= QUIET_FROM or hour < QUIET_TO:
		var into := (day + seconds) % 86400
		var wait := QUIET_TO * 3600 - into
		if wait < 0:
			wait += 86400
		seconds += wait
	return {"id": id, "title": title, "body": body, "seconds": seconds}
