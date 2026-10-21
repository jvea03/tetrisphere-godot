# Home's rewarded ads, pressed as a player would, with the simulated ad: half
# an hour off an unlocking chest and off a build (3 a day each, the buttons
# gone after), the mine's haul doubled once, an ad that doesn't finish giving
# the button back, and Daily Streaks' login coins doubled once.
# Run with:
#   Godot.exe --path . res://tests/ad_home_test.tscn
extends "res://scripts/screens/home.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(12)
	TSProfile.home_tutorial_seen = true
	TSProfile.daily_callout_seen = true
	TSProfile.camp_callout_seen = true
	TSProfile.coin_count = 100000
	TSProfile.materials = 10000
	TSProfile.ad_rewards_used = {}
	super()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _ad_done() -> void:
	await get_tree().create_timer(Ads.SIMULATED_SECONDS + 0.5).timeout


func _run() -> void:
	# A chest.
	TSChests.slots[0] = {"rarity": TSChests.LEGENDARY, "unlock_end": TSChests._now() + 3 * 3600}
	_refresh_chest_tray()
	_open_skip(0)
	var ad: Button = _skip["ad"]
	_check("an unlocking chest's card offers an ad (3 left today)", ad.visible and ad.text.contains("-30 min") and ad.text.contains("3 left"))
	var left := TSChests.seconds_left(0)
	ad.pressed.emit()
	_check("it plays", Ads.is_busy() and ad.disabled)
	_refresh_chest_tray()
	_check("and the card's once-a-second refresh leaves it playing", ad.disabled and ad.text == "Ad playing...")
	await _ad_done()
	_check("then the chest is half an hour nearer", TSChests.seconds_left(0) <= left - 1800 and TSChests.is_unlocking(0))
	_check("and the button counts down (2 left)", ad.visible and not ad.disabled and ad.text.contains("2 left"))
	for k in 2:
		ad.pressed.emit()
		await _ad_done()
	_check("after 3 the button is gone", not ad.visible and TSProfile.ad_rewards_left("chest") == 0)
	TSUI.conceal(_skip["root"])
	# A chest with under half an hour left opens.
	TSProfile.ad_rewards_used = {}
	TSChests.slots[0]["unlock_end"] = TSChests._now() + 600
	_open_skip(0)
	(_skip["ad"] as Button).pressed.emit()
	await _ad_done()
	_check("a chest with less than half an hour left is ready, its card gone", TSChests.is_ready(0) and not _skip["root"].visible)

	# Time skips on a chest: a minute each.
	TSProfile.time_skips = 0
	TSChests.slots[0] = {"rarity": TSChests.RARE, "unlock_end": TSChests._now() + 600}
	_open_skip(0)
	_check("with no time skips the chest card doesn't offer them", not (_skip["skips"] as Control).visible)
	TSUI.conceal(_skip["root"])
	TSProfile.time_skips = 4
	_open_skip(0)
	_check("with some it offers them", (_skip["skips"] as Control).visible and (_skip["skip_one"] as Button).text == "Skip 1 min" and (_skip["skip_all"] as Button).text == "Use all 4")
	left = TSChests.seconds_left(0)
	(_skip["skip_one"] as Button).pressed.emit()
	_check("one takes a minute off", TSProfile.time_skips == 3 and TSChests.seconds_left(0) <= left - 60 and TSChests.is_unlocking(0))
	TSProfile.time_skips = 99
	_refresh_skip()
	(_skip["skip_all"] as Button).pressed.emit()
	await get_tree().create_timer(0.4).timeout
	_check("enough finish it, and its card closes", TSChests.is_ready(0) and not _skip["root"].visible and TSProfile.time_skips > 80)
	TSChests.slots[0] = {}
	_refresh_chest_tray()

	# A build.
	var p := -1
	for i in TSProfile.PART_COUNT:
		if TSProfile.part_build_block(i) == "":
			p = i
			break
	_open_part(p)
	_on_part_pressed()
	await get_tree().create_timer(0.4).timeout   # the card closing as the build starts
	TSProfile.part_builds[p]["end"] = TSProfile._now_unix() + 3 * 3600
	_open_part(p)
	ad = _part["ad"]
	_check("a build under way offers an ad (3 left today)", ad.visible and ad.text.contains("3 left"))
	left = TSProfile.part_build_seconds_left(p)
	ad.pressed.emit()
	await _ad_done()
	_check("then the build is half an hour nearer (2 left)", TSProfile.part_build_seconds_left(p) <= left - 1800 and ad.text.contains("2 left"))
	TSProfile.part_builds[p]["end"] = TSProfile._now_unix() + 600
	var level := TSProfile.part_level_of(p)
	ad.pressed.emit()
	await _ad_done()
	_check("one with less left finishes and is collected", TSProfile.part_level_of(p) == level + 1 and not TSProfile.is_part_building(p))
	TSUI.conceal(_part["root"])

	# The mine.
	TSProfile.mine_since = TSProfile._now_unix() - 3600
	var mats := TSProfile.materials
	_collect_mine()
	var n: int = _mine["n"]
	ad = _mine["ad"]
	_check("collecting the mine shows its haul (+%d) and the ad to double it" % n, n > 0 and _mine["root"].visible and ad.visible and ad.text.contains("+%d" % n))
	# An ad that doesn't finish: nothing, and the button back.
	Ads.rewarded_result.connect(func(_e): pass, CONNECT_ONE_SHOT)
	ad.pressed.emit()
	Ads._busy = false
	Ads.rewarded_result.emit(false)
	await get_tree().process_frame
	_check("an ad that doesn't finish pays nothing and gives the button back", TSProfile.materials == mats + n and ad.visible and not ad.disabled and ad.text.contains("Double it"))
	await _ad_done()   # the simulated ad's own timer, now spent
	TSProfile.mine_last_haul = n
	ad.pressed.emit()
	await _ad_done()
	_check("a finished one doubles it", TSProfile.materials == mats + 2 * n and not ad.visible and (_mine["body"] as Label).text.contains("+%d" % (2 * n)))
	TSUI.conceal(_mine["root"])

	# Daily Streaks: today's login coins, again.
	TSProfile.login_streak_last_date = TSClock.date_string()
	TSProfile.login_reward_claimed_date = ""
	TSProfile.login_reward_doubled_date = ""
	var streak: Control = load("res://scenes/streak.tscn").instantiate()
	add_child(streak)
	await get_tree().process_frame
	var login_ad: Button = streak._login["ad"]
	_check("before the login coins are claimed there is no ad", not login_ad.visible)
	streak._on_login_tap()
	var got := TSProfile.login_reward_claimed_amount
	_check("once claimed, an ad offers them again (+%d)" % got, login_ad.visible and login_ad.text.contains("+%s" % TSProfile.fmt_coins(got)))
	var coins := TSProfile.coin_count
	login_ad.pressed.emit()
	await _ad_done()
	_check("and pays them, once", TSProfile.coin_count == coins + got and not login_ad.visible)
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
