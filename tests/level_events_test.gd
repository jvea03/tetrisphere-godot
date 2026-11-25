# level_10_won and valuable_player (Google Ads) and the Meta standard events.
# Off-device, TSAnalytics.recent is what would be sent. The once-flags live on
# the profile and round-trip through the encrypted save. Run with:
#   godot --headless --path . res://tests/level_events_test.tscn
extends Node

var _failures := 0


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ready() -> void:
	TSProfile.use_test_profile(1)
	_run.call_deferred()


func _count(name: String) -> int:
	var n := 0
	for e in TSAnalytics.recent:
		if e[0] == name:
			n += 1
	return n


func _param(name: String, key: String) -> Variant:
	for i in range(TSAnalytics.recent.size() - 1, -1, -1):
		if TSAnalytics.recent[i][0] == name:
			return TSAnalytics.recent[i][1].get(key, null)
	return null


## Firebase event names: 1-40 chars, a letter first, letters digits and
## underscores, and not a reserved prefix (firebase_, google_, ga_).
func _firebase_name_ok(name: String) -> bool:
	if name.length() < 1 or name.length() > 40:
		return false
	if name.begins_with("firebase_") or name.begins_with("google_") or name.begins_with("ga_"):
		return false
	var reserved := ["ad_click", "ad_impression", "app_remove", "error", "first_open", "in_app_purchase", "session_start", "screen_view", "user_engagement"]
	if reserved.has(name):
		return false
	var first := name.unicode_at(0)
	if not ((first >= 65 and first <= 90) or (first >= 97 and first <= 122)):
		return false
	for i in name.length():
		var c := name.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true


func _reset_flags() -> void:
	TSProfile.reached_level_10 = false
	TSProfile.level_10_won_sent = false
	TSProfile.won_level_1 = false
	TSProfile.meta_level_sent = false
	TSProfile.meta_tutorial_sent = false
	TSProfile.valuable_player_sent = false
	TSProfile.rewarded_earned_count = 0
	TSAnalytics.recent.clear()


func _allow() -> void:
	TSPrivacyRegion.override = 0
	TSProfile.analytics_enabled = true
	TSProfile.analytics_consent = ""


func _run() -> void:
	_check("this run is not a phone, so the Meta bridge is not called", OS.get_name() != "Android" and OS.get_name() != "iOS")
	_check("level_10_won keeps its name", TSAnalytics.LEVEL_10_WON == "level_10_won" and _firebase_name_ok(TSAnalytics.LEVEL_10_WON))
	_check("valuable_player keeps its name", TSAnalytics.VALUABLE_PLAYER == "valuable_player" and _firebase_name_ok(TSAnalytics.VALUABLE_PLAYER))
	_check("the why parameter is a Firebase parameter name", _firebase_name_ok("why"))
	_check("Meta's level event is the standard name", TSAnalytics.META_LEVEL_ACHIEVED == "fb_mobile_level_achieved")
	_check("Meta's level parameter is fb_level", TSAnalytics.META_LEVEL_PARAM == "fb_level")
	_check("Meta's tutorial event is the standard name", TSAnalytics.META_TUTORIAL == "fb_mobile_tutorial_completion")

	_allow()
	_reset_flags()
	TSAnalytics.level_end(10, false, "level")
	TSAnalytics.level_end(10, true, "daily")
	TSAnalytics.level_end(10, true, "challenge")
	_check("a loss, a daily and a challenge do not count as level 10", _count(TSAnalytics.LEVEL_10_WON) == 0 and not TSProfile.reached_level_10)

	_reset_flags()
	TSAnalytics.level_end(10, true, "level")
	_check("the first level-10 win sends level_10_won once", _count(TSAnalytics.LEVEL_10_WON) == 1)
	_check("and valuable_player with why level_10", _count(TSAnalytics.VALUABLE_PLAYER) == 1 and str(_param(TSAnalytics.VALUABLE_PLAYER, "why")) == "level_10")
	_check("and Meta fb_mobile_level_achieved with fb_level 10", _count(TSAnalytics.META_LEVEL_ACHIEVED) == 1 and str(_param(TSAnalytics.META_LEVEL_ACHIEVED, "fb_level")) == "10")
	_check("the once-flags are set", TSProfile.level_10_won_sent and TSProfile.meta_level_sent and TSProfile.valuable_player_sent)
	var after_first := TSAnalytics.recent.size()
	TSAnalytics.level_end(10, true, "level")
	TSAnalytics.level_end(10, true, "level")
	_check("replays send level_end only, not level_10_won, valuable_player or Meta again", _count(TSAnalytics.LEVEL_10_WON) == 1 and _count(TSAnalytics.VALUABLE_PLAYER) == 1 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 1 and TSAnalytics.recent.size() == after_first + 2)

	_reset_flags()
	TSAnalytics.level_end(1, true, "level")
	TSAnalytics.level_end(1, true, "level")
	_check("tutorial_complete still fires on every level-1 win", _count("tutorial_complete") == 2)
	_check("Meta's tutorial event fires once", _count(TSAnalytics.META_TUTORIAL) == 1 and TSProfile.meta_tutorial_sent)

	# Level 5 and 20 are not once-gated.
	_reset_flags()
	TSAnalytics.level_end(5, true, "level")
	TSAnalytics.level_end(5, true, "level")
	_check("level_5_won still fires on every win", _count("level_5_won") == 2)

	# Rewarded ads take the one valuable_player; level 10 still sends its own event once.
	_reset_flags()
	TSAnalytics.rewarded_earned()
	TSAnalytics.rewarded_earned()
	TSAnalytics.rewarded_earned()
	_check("the 3rd rewarded ad sends valuable_player why rewarded_ads", _count(TSAnalytics.VALUABLE_PLAYER) == 1 and str(_param(TSAnalytics.VALUABLE_PLAYER, "why")) == "rewarded_ads")
	TSAnalytics.recent.clear()
	TSAnalytics.level_end(10, true, "level")
	_check("level 10 after that still sends level_10_won and Meta, not a second valuable_player", _count(TSAnalytics.LEVEL_10_WON) == 1 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 1 and _count(TSAnalytics.VALUABLE_PLAYER) == 0)

	# Consent: nothing Meta or level_10_won until Allow, then exactly once, no replay needed.
	_reset_flags()
	TSPrivacyRegion.override = 1
	TSProfile.analytics_consent = ""
	TSProfile.analytics_enabled = true
	_check("a regulated phone with no answer is not allowed", not TSPrivacyRegion.analytics_allowed())
	TSAnalytics.level_end(1, true, "level")
	TSAnalytics.level_end(10, true, "level")
	_check("before Allow, level_10_won and both Meta events wait", _count(TSAnalytics.LEVEL_10_WON) == 0 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 0 and _count(TSAnalytics.META_TUTORIAL) == 0)
	_check("the milestones are remembered and not marked sent", TSProfile.reached_level_10 and TSProfile.won_level_1 and not TSProfile.level_10_won_sent and not TSProfile.meta_level_sent and not TSProfile.meta_tutorial_sent)
	TSAnalytics.recent.clear()
	TSProfile.analytics_consent = "yes"
	TSAnalytics.sync_meta()
	_check("Allow sends level_10_won once", _count(TSAnalytics.LEVEL_10_WON) == 1)
	_check("Allow sends both Meta events once", _count(TSAnalytics.META_LEVEL_ACHIEVED) == 1 and str(_param(TSAnalytics.META_LEVEL_ACHIEVED, "fb_level")) == "10" and _count(TSAnalytics.META_TUTORIAL) == 1)
	TSAnalytics.recent.clear()
	TSAnalytics.sync_meta()
	TSAnalytics.level_end(10, true, "level")
	TSAnalytics.level_end(1, true, "level")
	_check("after that, a replay and another sync do not send them again", _count(TSAnalytics.LEVEL_10_WON) == 0 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 0 and _count(TSAnalytics.META_TUTORIAL) == 0 and _count("tutorial_complete") == 1)

	# Legacy saves: already past the milestone, so the update does not emit.
	TSProfile.last_level = 15
	_reset_flags()
	TSProfile.last_level = 15
	_check("a pre-flag save past level 10 is treated as already sent", TSProfile.note_legacy_analytics_flags(false, false) and TSProfile.level_10_won_sent and TSProfile.meta_level_sent and TSProfile.reached_level_10 and TSProfile.won_level_1 and TSProfile.meta_tutorial_sent)
	TSAnalytics.recent.clear()
	_allow()
	TSAnalytics.sync_meta()
	_check("and Allow does not emit level 10 or the tutorial for that save", _count(TSAnalytics.LEVEL_10_WON) == 0 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 0 and _count(TSAnalytics.META_TUTORIAL) == 0)
	TSProfile.last_level = 10
	_reset_flags()
	TSProfile.last_level = 10
	TSProfile.note_legacy_analytics_flags(false, false)
	_check("level 10 not yet won is not backfilled (the tutorial is)", not TSProfile.level_10_won_sent and not TSProfile.reached_level_10 and TSProfile.won_level_1 and TSProfile.meta_tutorial_sent)
	TSProfile.last_level = 1
	_reset_flags()
	TSProfile.last_level = 1
	_check("a brand-new save backfills nothing", not TSProfile.note_legacy_analytics_flags(false, false) and not TSProfile.won_level_1 and not TSProfile.reached_level_10)
	TSProfile.last_level = 40
	TSProfile.reached_level_10 = false
	TSProfile.level_10_won_sent = false
	TSProfile.won_level_1 = false
	TSProfile.meta_level_sent = false
	TSProfile.meta_tutorial_sent = false
	_check("keys this version wrote are not backfilled over", not TSProfile.note_legacy_analytics_flags(true, true) and not TSProfile.level_10_won_sent and not TSProfile.meta_tutorial_sent)

	_roundtrip()

	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## The flags survive a save and a load, including "won, not yet sent".
func _roundtrip() -> void:
	var paths := ["user://profile.cfg", "user://profile.cfg.bak", "user://profile.cfg.tmp"]
	var kept := {}
	for path in paths:
		if FileAccess.file_exists(path):
			kept[path] = FileAccess.get_file_as_bytes(path)
	var was_persist := TSProfile.persist
	TSProfile.persist = true
	TSProfile.last_level = 11
	TSProfile.reached_level_10 = true
	TSProfile.level_10_won_sent = false
	TSProfile.won_level_1 = true
	TSProfile.meta_level_sent = false
	TSProfile.meta_tutorial_sent = false
	TSProfile.valuable_player_sent = true
	TSProfile.save()
	TSProfile.reached_level_10 = false
	TSProfile.level_10_won_sent = true
	TSProfile.won_level_1 = false
	TSProfile.meta_level_sent = true
	TSProfile.meta_tutorial_sent = true
	TSProfile.valuable_player_sent = false
	TSProfile._loaded = false
	TSProfile.ensure_loaded()
	_check("a restart keeps reached-but-not-sent", TSProfile.reached_level_10 and not TSProfile.level_10_won_sent and TSProfile.won_level_1 and not TSProfile.meta_level_sent and not TSProfile.meta_tutorial_sent)
	_check("and keeps valuable_player_sent", TSProfile.valuable_player_sent)
	TSAnalytics.recent.clear()
	_allow()
	TSAnalytics.sync_meta()
	_check("that restart still sends level 10 and Meta once when allowed", _count(TSAnalytics.LEVEL_10_WON) == 1 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 1 and _count(TSAnalytics.META_TUTORIAL) == 1)
	TSProfile._loaded = false
	TSProfile.level_10_won_sent = false
	TSProfile.meta_level_sent = false
	TSProfile.meta_tutorial_sent = false
	TSProfile.ensure_loaded()
	TSAnalytics.recent.clear()
	TSAnalytics.sync_meta()
	_check("and a second launch does not send them again", TSProfile.level_10_won_sent and TSProfile.meta_level_sent and TSProfile.meta_tutorial_sent and _count(TSAnalytics.LEVEL_10_WON) == 0 and _count(TSAnalytics.META_LEVEL_ACHIEVED) == 0)
	TSProfile.persist = was_persist
	for path in paths:
		if kept.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_buffer(kept[path])
				f.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
