# The win card's rewarded ad, pressed as a player would, with the simulated
# ad: the coins come again, the button says so, the next interstitial is
# spared, Next waits while the ad plays, and after 5 a day the button is gone.
# Run with:
#   Godot.exe --path . res://tests/ad_win_test.tscn
extends "res://scripts/game.gd"

var _frames := 0
var _failures := 0


func _ready() -> void:
	TSProfile.use_test_profile(40)
	TSProfile.coin_count = 10000
	TSProfile.ad_rewards_used = {}
	super()


func _process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == 10:
		_run()


func _check(label: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_failures += 1


func _double_button() -> Button:
	for c in (_win_card["box"] as Node).get_children():
		if c is Button and (c as Button).text.contains("Double Coins"):
			return c
	return null


## The win card's coin count shows this.
func _shows(text: String) -> bool:
	return (_win_card["box"] as Node).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == text)


func _run() -> void:
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	var b := _double_button()
	_check("the win card offers to double its coins (+%d)" % _win_coins, _win_card["root"].visible and b != null and b.text.contains(TSProfile.fmt_coins(_win_coins)))
	_win_ad_due = true
	var level := current_level
	var coins := TSProfile.coin_count
	b.pressed.emit()
	_check("the ad plays", Ads.is_busy() and b.disabled and b.text == "Ad playing...")
	_on_next_pressed()
	_check("Next waits while it plays", current_level == level and state == State.WON)
	await get_tree().create_timer(Ads.SIMULATED_SECONDS + 1.0).timeout
	_check("then the coins come again", TSProfile.coin_count == coins + _win_coins)
	_check("the button says so", b.disabled and b.text == "Coins doubled!")
	_check("and the next interstitial is spared", not _win_ad_due)
	_check("one of today's five used", TSProfile.ad_rewards_left("win_coins") == 4)
	# With the day's five used, no button.
	TSProfile.ad_rewards_used = {"win_coins": 5}
	_close_cards()
	_start_level(level)
	_debug_win()
	await get_tree().create_timer(3.0).timeout
	_check("after five a day the card has no double button", _win_card["root"].visible and _double_button() == null)
	# Remove Ads: no video, at once.
	TSProfile.ad_rewards_used = {}
	TSProfile.no_ads = true
	_close_cards()
	_start_level(level)
	_debug_win()
	while _double_button() == null:   # pressed as soon as it shows, mid-count
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	b = _double_button()
	coins = TSProfile.coin_count
	_check("with Remove Ads it is free", b != null and b.text.begins_with("Free"))
	b.pressed.emit()
	_check("and pays at once", TSProfile.coin_count == coins + _win_coins and not Ads.is_busy() and b.text == "Coins doubled!")
	await get_tree().create_timer(1.5).timeout
	_check("doubled mid-count, the count ends on the doubled coins (+%s)" % TSProfile.fmt_coins(_win_coins * 2), _shows("+" + TSProfile.fmt_coins(_win_coins * 2)))
	TSProfile.no_ads = false
	print("")
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
