class_name TSSales
extends RefCounted

## Pop-up sales (Duckdoku's PopupSales): time-limited offers that open over
## Home by themselves when their trigger fires, then wait as an icon in
## Home's left column with a countdown until bought or run out. Not in the
## Shop. One offer runs at a time; "enabled": false offers never start.
##
## Triggers, checked in order on each roll():
##  - "dates":      once, between local 00:00 on `start` and 23:59:59 on `end`
##  - "level":      once ever, the first time last_level reaches `level`
##  - "every_days": again and again, `every` days after it last started
##
## What an offer grants is Billing.PRODUCTS[product_id].

const OFFERS := [
	{
		"id": "hatch_day_2026",
		"name": "Hatch Day Feast",
		"product_id": "popup_hatch_day_2026",
		"price": "$4.99", "orig_price": "$19.99",
		"trigger": "dates", "start": "2026-11-26", "end": "2026-11-29", "min_level": 7,
		"enabled": true,
	},
	{
		"id": "starter_sprinkle",
		"name": "Starter Sprinkle",
		"product_id": "popup_starter_sprinkle",
		"price": "$0.99", "orig_price": "$4.99",
		"hours": 48,
		"trigger": "level", "level": 8,
		"enabled": true,
	},
	{
		"id": "flash_sale",
		"name": "Flash Sale",
		"product_id": "popup_flash_sale",
		"price": "$4.99", "orig_price": "$12.99",
		"hours": 24,
		"trigger": "every_days", "every": 3, "min_level": 15,
		"enabled": false,
	},
]

static var active_id: String = ""
static var ends_at: int = 0
static var popup_shown: bool = false
static var fired: Dictionary = {}
static var last_started: Dictionary = {}


static func to_save() -> Dictionary:
	return {"active_id": active_id, "ends_at": ends_at, "popup_shown": popup_shown,
		"fired": fired.duplicate(), "last_started": last_started.duplicate()}


static func from_save(data: Dictionary) -> void:
	active_id = str(data.get("active_id", ""))
	ends_at = int(data.get("ends_at", 0))
	popup_shown = bool(data.get("popup_shown", false))
	fired = data.get("fired", {})
	last_started = data.get("last_started", {})
	if offer(active_id).is_empty():
		active_id = ""


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func offer(id: String) -> Dictionary:
	for o in OFFERS:
		if o["id"] == id:
			return o
	return {}


static func current() -> Dictionary:
	roll_expiry()
	return offer(active_id)


static func seconds_left() -> int:
	if active_id == "":
		return 0
	return maxi(ends_at - _now(), 0)


static func contents(o: Dictionary) -> Dictionary:
	return Billing.PRODUCTS.get(str(o.get("product_id", "")), {})


static func roll_expiry() -> void:
	if active_id != "" and _now() >= ends_at:
		active_id = ""
		ends_at = 0
		popup_shown = false
		TSProfile.save()


static func roll() -> bool:
	roll_expiry()
	if active_id != "":
		return false
	for o in OFFERS:
		if is_due(o, _now(), TSProfile.last_level):
			_start(o)
			return true
	return false


static func is_due(o: Dictionary, now: int, level: int) -> bool:
	if not bool(o.get("enabled", true)):
		return false
	var id: String = o["id"]
	match str(o["trigger"]):
		"dates":
			return level >= int(o.get("min_level", 0)) and not fired.has(id) \
				and now >= _local_unix(str(o["start"]), false) and now <= _local_unix(str(o["end"]), true)
		"level":
			return level >= int(o["level"]) and not fired.has(id)
		"every_days":
			var since: int = now - int(last_started.get(id, 0))
			return level >= int(o["min_level"]) and since >= int(o["every"]) * 86400
	return false


static func _local_unix(date: String, end_of_day: bool) -> int:
	var utc := int(Time.get_unix_time_from_datetime_string(date + ("T23:59:59" if end_of_day else "T00:00:00")))
	return utc - int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _start(o: Dictionary) -> void:
	var id: String = o["id"]
	active_id = id
	if str(o["trigger"]) == "dates":
		ends_at = _local_unix(str(o["end"]), true)
	else:
		ends_at = _now() + int(o["hours"]) * 3600
	popup_shown = false
	fired[id] = true
	last_started[id] = _now()
	TSProfile.save()


static func mark_popup_shown() -> void:
	if not popup_shown:
		popup_shown = true
		TSProfile.save()


static func complete(product_id: String) -> void:
	if active_id != "" and str(offer(active_id).get("product_id", "")) == product_id:
		active_id = ""
		ends_at = 0
		popup_shown = false
		TSProfile.save()


## "23:59:12" under a day, "1d 23h" over.
static func format_left(seconds: int) -> String:
	if seconds >= 86400:
		return "%dd %dh" % [seconds / 86400, (seconds % 86400) / 3600]
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
