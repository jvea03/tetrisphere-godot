class_name TSPrivacyRegion
extends RefCounted

## Whether this player is in a place where analytics needs their agreement
## FIRST: the EU, the rest of the EEA, the UK and Switzerland (as Duckdoku).
## The game is not sold in the EU, but the UK, Norway, Iceland, Liechtenstein
## and Switzerland have it, and a player can travel. There nothing is sent
## until the player says yes on Home's card; everywhere else analytics is on,
## with a Settings switch to turn it off.
##
## Two signals, either one is enough, because asking too often costs one card
## and asking too rarely is the real problem:
##   - the phone's region setting (the country in its language, e.g. en_GB)
##   - the phone's time zone: UTC+0 to UTC+3, which covers every one of these
##     countries (and asks a few players nearby, e.g. in Africa, as well)
## Google's consent library is not used for this: it also answers "consent
## required" for US state privacy laws.

const COUNTRIES := [
	"AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU",
	"IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", # EU
	"IS", "LI", "NO", # the rest of the EEA
	"GB", "UK", # the United Kingdom
	"CH", # Switzerland
]

## Tests set this to 0 (not regulated) or 1 (regulated); -1 means look for real.
static var override: int = -1


## The two-letter country in the phone's locale ("en_GB" -> "GB"), or "".
static func locale_country() -> String:
	return country_of(OS.get_locale())


## "en_GB" / "en-GB" / "zh_Hans_CN" -> the country, "" if there is none ("fr").
static func country_of(locale: String) -> String:
	var parts := locale.replace("-", "_").split("_")
	for i in range(parts.size() - 1, 0, -1):
		if parts[i].length() == 2 and parts[i] == parts[i].to_upper():
			return parts[i]
	return ""


static func is_regulated() -> bool:
	if override >= 0:
		return override == 1
	return COUNTRIES.has(locale_country()) or _european_time_zone()


## UTC+0 to UTC+3, the span of the EU, EEA, UK and Swiss time zones (summer
## time included).
static func _european_time_zone() -> bool:
	var bias := int(Time.get_time_zone_from_system().get("bias", -9999))
	return bias >= 0 and bias <= 180


## May analytics run for this player right now?
static func analytics_allowed() -> bool:
	# a "no" on the consent card always stands, wherever the player is now
	if TSProfile.analytics_consent == "no":
		return false
	return TSProfile.analytics_enabled and (not is_regulated() or TSProfile.analytics_consent == "yes")


## Show the question: regulated, never answered, and the switch not off.
static func needs_prompt() -> bool:
	return is_regulated() and TSProfile.analytics_consent == "" and TSTunables.get_bool("analytics_enabled")


## What the Settings switch should show: on only if analytics really is running.
static func switch_state() -> bool:
	return analytics_allowed()
