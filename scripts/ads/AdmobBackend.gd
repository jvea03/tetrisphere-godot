extends Node

## The AdMob side of the Ads autoload (scripts/meta/ads.gd), on Poing Studios'
## AdMob plugin (res://addons/admob, v5.1). Ads loads this at runtime on a
## device build, calls setup() with the ad unit ids, then show_rewarded() /
## show_interstitial(); this answers with exactly one rewarded_result(earned)
## or interstitial_closed() each.
##
## One rewarded and one interstitial ad are kept loaded ahead of time, and
## loaded again after each is shown. A rewarded ad asked for before one has
## loaded waits up to WAIT_SECONDS for it, then gives up (no reward).

signal rewarded_result(earned: bool)
signal interstitial_closed()

const WAIT_SECONDS := 8.0     # how long a rewarded ad may keep the player waiting to load
const RETRY_SECONDS := 30.0   # after a failed load, try again this much later

var _units := {}
var _rewarded: RewardedAd = null
var _interstitial: InterstitialAd = null
var _loading_rewarded := false
var _loading_interstitial := false
var _waiting := false         # a rewarded ad has been asked for and is loading
var _earned := false
# The plugin calls back through these, so they're kept for as long as we are.
var _rewarded_load := RewardedAdLoadCallback.new()
var _rewarded_screen := FullScreenContentCallback.new()
var _reward_listener := OnUserEarnedRewardListener.new()
var _interstitial_load := InterstitialAdLoadCallback.new()
var _interstitial_screen := FullScreenContentCallback.new()
var _init_listener := OnInitializationCompleteListener.new()


func setup(units: Dictionary) -> void:
	_units = units
	_rewarded_load.on_ad_loaded = _on_rewarded_loaded
	_rewarded_load.on_ad_failed_to_load = _on_rewarded_failed
	_rewarded_screen.on_ad_dismissed_full_screen_content = _rewarded_done
	_rewarded_screen.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		_earned = false
		_rewarded_done()
	_reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned = true
	_interstitial_load.on_ad_loaded = _on_interstitial_loaded
	_interstitial_load.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading_interstitial = false
		get_tree().create_timer(RETRY_SECONDS).timeout.connect(_load_interstitial)
	_interstitial_screen.on_ad_dismissed_full_screen_content = _interstitial_done
	_interstitial_screen.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _interstitial_done()
	_init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_load_rewarded()
		_load_interstitial()
	_gather_consent()


# -- consent ----------------------------------------------------------------
# Google's User Messaging Platform: where a privacy law asks for it (the EEA,
# the UK, Switzerland, some US states), the AdMob app's published message is
# shown once, before any ad is requested. Ads start either way once that is
# settled -- or if the check can't be made (offline), as AdMob then serves
# only what the stored answer allows.

var _ads_started := false


func _gather_consent() -> void:
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(), _on_consent_info, func(_e: FormError) -> void: _start_ads())


func _on_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(
			func(form: ConsentForm) -> void: form.show(func(_e: FormError) -> void: _start_ads()),
			func(_e: FormError) -> void: _start_ads())
	else:
		_start_ads()


func _start_ads() -> void:
	if _ads_started:
		return
	_ads_started = true
	MobileAds.initialize(_init_listener)


## True where the player must be able to change their ad privacy choices
## (Settings then shows a button for it).
func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: pass)


# -- rewarded ---------------------------------------------------------------

func show_rewarded() -> void:
	if _rewarded != null:
		_show_rewarded_now()
		return
	_waiting = true
	_load_rewarded()
	get_tree().create_timer(WAIT_SECONDS).timeout.connect(func() -> void:
		if _waiting:
			_waiting = false
			rewarded_result.emit(false))


func _load_rewarded() -> void:
	if _loading_rewarded or _rewarded != null:
		return
	_loading_rewarded = true
	RewardedAdLoader.new().load(str(_units.get("rewarded", "")), AdRequest.new(), _rewarded_load)


func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_loading_rewarded = false
	_rewarded = ad
	ad.full_screen_content_callback = _rewarded_screen
	if _waiting:
		_waiting = false
		_show_rewarded_now()


func _on_rewarded_failed(_error: LoadAdError) -> void:
	_loading_rewarded = false
	if _waiting:
		_waiting = false
		rewarded_result.emit(false)
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(_load_rewarded)


func _show_rewarded_now() -> void:
	_earned = false
	_rewarded.show(_reward_listener)


func _rewarded_done() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	rewarded_result.emit(_earned)
	_load_rewarded()


# -- interstitial -----------------------------------------------------------

func interstitial_loaded() -> bool:
	return _interstitial != null


func show_interstitial() -> void:
	if _interstitial == null:
		interstitial_closed.emit()
		return
	_interstitial.show()


func _load_interstitial() -> void:
	if _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	InterstitialAdLoader.new().load(str(_units.get("interstitial", "")), AdRequest.new(), _interstitial_load)


func _on_interstitial_loaded(ad: InterstitialAd) -> void:
	_loading_interstitial = false
	_interstitial = ad
	ad.full_screen_content_callback = _interstitial_screen


func _interstitial_done() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	interstitial_closed.emit()
	_load_interstitial()
