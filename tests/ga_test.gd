# GameAnalytics (the GA autoload, scripts/meta/game_analytics.gd): off on a
# test's throwaway profile; forced on, the game's TSAnalytics events arrive as
# GameAnalytics sessions, progression and design events, a purchase as a
# business event in USD cents; where the law asks first (TSPrivacyRegion)
# nothing runs until a yes, a no stands, and Settings -> Share usage data turns
# it off and on. Nothing goes over the network (the client is held as if the
# server had refused it). Run with:
#   Godot.exe --headless --path . res://tests/ga_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(40)
	_run.call_deferred()


func _events(category: String) -> Array:
	return GA._queue.filter(func(e: Dictionary) -> bool: return e["category"] == category)


func _has(category: String, event_id: String) -> bool:
	return _events(category).any(func(e: Dictionary) -> bool: return str(e.get("event_id", "")) == event_id)


func _last(category: String) -> Dictionary:
	var list := _events(category)
	return list[-1] if not list.is_empty() else {}


func _run() -> void:
	_check("off on a test's throwaway profile", not GA.enabled)

	# Forced on, as a phone outside the regulated countries; never sent.
	GA._forced_platform = "android"
	GA._dead = true   # flush() then never posts
	TSPrivacyRegion.override = 0
	TSProfile.analytics_consent = ""
	TSProfile.analytics_enabled = true
	GA.enable_after_consent()
	_check("on for a phone where no consent is asked", GA.enabled)
	_check("a session opens: a user event and Session:Start", not _events("user").is_empty() and _has("design", "Session:Start"))
	_check("the forced test reports to the sandbox, never a real game", GA._sandbox() and GA._game_key() == GA.GAME_KEY_SANDBOX)

	TSAnalytics.level_start(12, "level")
	_check("a level start is a progression Start", _has("progression", "Start:Level:Level_012"))
	TSAnalytics.level_end(12, true, "level", 83.4, 21, 2)
	var done := _last("progression")
	_check("a win is a Complete with the attempt and the hearts left as score (%s)" % done, str(done.get("event_id", "")) == "Complete:Level:Level_012" and int(done.get("attempt_num", 0)) == 1 and int(done.get("score", -1)) == 2)
	_check("with the play time and drops as design events", _has("design", "Level:Seconds:Level") and _has("design", "Level:Drops:Level"))
	TSAnalytics.level_start(41, "challenge")
	TSAnalytics.level_end(41, false, "challenge", 120.0, 30, 0)
	_check("a challenge lost is a Fail under Challenge", _has("progression", "Fail:Challenge:Level_041"))
	TSAnalytics.event("ad_inter_owed", {"level": 33})
	var owed := _last("design")
	_check("the interstitial events keep Duckdoku's names (%s)" % owed, str(owed.get("event_id", "")) == "Ad:Interstitial:Owed" and int(owed.get("value", 0)) == 33)
	TSAnalytics.intro_start()
	_check("the cutscene is a first-run step", _has("design", "FirstRun:Intro:Start"))

	Billing.purchase_result.emit("egg_coins_5000", true)
	var buy := _last("business")
	_check("a purchase is a business event in USD cents (%s)" % buy, str(buy.get("event_id", "")) == "IAP:egg_coins_5000" and int(buy.get("amount", 0)) == 99 and str(buy.get("currency", "")) == "USD")
	Billing.purchase_result.emit("egg_coins_5000", false)
	_check("a failed purchase is not", _events("business").size() == 1)
	_check("every event carries the platform and who sees ads", GA._queue.all(func(e: Dictionary) -> bool: return e["platform"] == "android" and e["custom_01"] in ["free", "payer", "noads"]))

	# The economy: coins and materials in and out, as resource events.
	TSProfile.coin_count = 10000000
	TSProfile.materials = 1000000
	var critter := -1
	for i in TSProfile.CRITTER_COUNT:
		if not TSProfile.is_critter_unlocked(i) and not TSProfile.is_critter_hidden(i) and not TSProfile.is_critter_pass_exclusive(i):
			critter = i
			break
	var price := TSProfile.critter_unlock_cost(critter)
	TSProfile.unlock_critter(critter)
	var spend := _last("resource")
	_check("buying a critter is a coin sink (%s)" % spend, str(spend.get("event_id", "")) == "Sink:Coins:Critter:Unlock" and int(spend.get("amount", 0)) == price)
	_check("and a design event by its rarity", _events("design").any(func(e: Dictionary) -> bool: return str(e["event_id"]).begins_with("Critter:Unlock:")))
	var part := -1
	for i in TSProfile.PART_COUNT:
		if TSProfile.part_build_block(i) == "":
			part = i
			break
	var part_id := TSProfile.part_name(part).replace(" ", "")
	TSProfile.start_part_build(part)
	_check("a build spends coins and materials on its part (%s)" % part_id, _has("resource", "Sink:Coins:Camp:" + part_id) and _has("resource", "Sink:Materials:Camp:" + part_id))
	_check("and says which part and level", _has("design", "Camp:Build:" + part_id))
	TSProfile.skip_part_build(part)
	_check("finishing it says so", _has("design", "Camp:Built:" + part_id))
	var before := _events("resource").size()
	TSProfile.add_stars(2)
	_check("a win's coins are a source", _events("resource").size() > before and _has("resource", "Source:Coins:Level:Win"))

	# The UK and nearby: nothing until a yes.
	GA.set_opt_out(true)
	_check("opting out stops it and drops what waited", not GA.enabled and GA._queue.is_empty())
	TSPrivacyRegion.override = 1
	TSProfile.analytics_enabled = true
	TSProfile.analytics_consent = ""
	_check("a regulated phone is asked first", TSPrivacyRegion.needs_prompt() and not TSPrivacyRegion.analytics_allowed())
	GA.enable_after_consent()
	_check("and sends nothing before an answer", not GA.enabled)
	TSAnalytics.level_start(13, "level")
	_check("(not even queued)", GA._queue.is_empty())
	TSProfile.analytics_consent = "yes"
	GA.enable_after_consent()
	_check("a yes starts it at once", GA.enabled and _has("design", "Session:Start"))
	TSProfile.analytics_consent = "no"
	TSPrivacyRegion.override = 0
	_check("a no stands wherever the player goes", not TSPrivacyRegion.analytics_allowed() and not TSPrivacyRegion.needs_prompt())

	# Settings -> Share usage data.
	TSProfile.set_toggle("analytics_enabled", true)
	_check("turning it on in Settings undoes the no", TSProfile.get_toggle("analytics_enabled") and TSProfile.analytics_consent == "yes")
	TSProfile.set_toggle("analytics_enabled", false)
	_check("and off turns it off", not TSProfile.get_toggle("analytics_enabled") and not TSPrivacyRegion.analytics_allowed())
	TSTunables.apply({"analytics_enabled": false})
	TSProfile.set_toggle("analytics_enabled", true)
	TSProfile.analytics_consent = ""
	TSPrivacyRegion.override = 1
	_check("the kill switch: no question asked", not TSPrivacyRegion.needs_prompt())
	TSTunables.apply({"analytics_enabled": true})

	_check("os versions the server refuses go as 0", GA.clean_os_version("18.1") == "18.1" and GA.clean_os_version("36.S918BXXU5CXK1") == "0")
	_check("the region comes from the locale's country", TSPrivacyRegion.country_of("en_GB") == "GB" and TSPrivacyRegion.country_of("zh_Hans_CN") == "CN" and TSPrivacyRegion.country_of("fr") == "")

	GA.set_opt_out(true)
	TSPrivacyRegion.override = -1
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
