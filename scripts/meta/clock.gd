class_name TSClock
extends RefCounted

## The game's clock: the device's own, corrected by the network's time once
## that has been read (sync, at launch). Builds, the mine, chests, daily
## rewards, streaks, sales and seasons all read the time here, so turning the
## phone's clock forward or back doesn't move them while the player is online.
## Offline, it is the device's clock as before.

const SYNC_URL := "https://www.google.com/generate_204"   # tiny, fast, and its reply carries the time
const TRUST := 120.0     # a device clock within two minutes of the network's is left alone
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var offset := 0.0     # network time minus device time, in seconds
static var synced := false   # the network's time has been read this run


## Seconds since 1970, UTC.
static func now() -> float:
	return Time.get_unix_time_from_system() + offset


## The local time now as unix seconds (for local dates and midnights).
static func local_unix() -> int:
	return int(now()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Today's local date, "2026-10-05".
static func date_string() -> String:
	return Time.get_date_string_from_unix_time(local_unix())


## The local date and time, as Time.get_datetime_dict_from_system() gives it.
static func datetime_dict() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(local_unix())


## Asks the network for the time (one small request, no player data) and
## corrects the clock if the device's is off by more than TRUST. Quietly
## does nothing offline.
static func sync(host: Node) -> void:
	var http := HTTPRequest.new()
	http.timeout = 6.0
	host.add_child(http)
	http.request_completed.connect(func(result: int, _code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			return
		for h in headers:
			if h.to_lower().begins_with("date:"):
				var t := parse_http_date(h.substr(5).strip_edges())
				if t > 0:
					apply_network_time(float(t)))
	if http.request(SYNC_URL, PackedStringArray(), HTTPClient.METHOD_HEAD) != OK:
		http.queue_free()


static func apply_network_time(network: float) -> void:
	var off := network - Time.get_unix_time_from_system()
	offset = off if absf(off) > TRUST else 0.0
	synced = true


## An HTTP date ("Mon, 05 Oct 2026 10:00:00 GMT") as unix seconds; 0 if it
## doesn't read.
static func parse_http_date(s: String) -> int:
	var parts := s.split(" ", false)
	if parts.size() < 5:
		return 0
	var month := MONTHS.find(parts[2]) + 1
	var hms := parts[4].split(":")
	if month <= 0 or hms.size() != 3 or not parts[1].is_valid_int() or not parts[3].is_valid_int():
		return 0
	return int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[3]), "month": month, "day": int(parts[1]),
		"hour": int(hms[0]), "minute": int(hms[1]), "second": int(hms[2]),
	}))
