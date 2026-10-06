extends Node

## Ad service (autoload "Ads"), ported from Duckdoku. The game asks for a
## rewarded or an interstitial ad and gets a callback; which SDK -- if any --
## sits behind that is this script's business.
##
## Backends:
##  - simulated (default): a fake ad that "plays" for SIMULATED_SECONDS and
##    always rewards. Editor, desktop, and any device build without the AdMob
##    plugin. Callers show their own progress bar while `simulated` is true.
##  - AdMob (Android/iOS): used only when an AdMob plugin is installed at
##    res://addons/admob and a backend script exists at ADMOB_BACKEND_PATH
##    (Duckdoku's scripts/ads/AdmobBackend.gd can be copied across). Loaded
##    with load() at runtime so the project parses without the addon.
##
## Only Google's public TEST ad units are here. Tetrisphere needs its own
## AdMob app and ad units before a release build; Duckdoku's belong to
## Duckdoku's store listing and must not be reused.

signal rewarded_result(earned: bool)
signal interstitial_closed()

const SIMULATED_SECONDS := 2.5

const AD_UNITS_TEST := {
	"android": {
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
	},
	"ios": {
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
	},
}

## Tetrisphere's own ad units, from its AdMob app -- fill these in (and the
## app ids under Project Settings > admob/general) once they exist. Release
## builds use them when set; debug builds always use the test units above.
const AD_UNITS_LIVE := {
	"android": {"rewarded": "", "interstitial": ""},
	"ios": {"rewarded": "", "interstitial": ""},
}

const ADMOB_BACKEND_PATH := "res://scripts/ads/AdmobBackend.gd"
const ADMOB_ADDON_MARKER := "res://addons/admob/plugin.cfg"

var simulated: bool = true
var _backend: Node = null
var _busy: bool = false


func _ready() -> void:
	if (OS.has_feature("android") or OS.has_feature("ios")) \
			and FileAccess.file_exists(ADMOB_ADDON_MARKER) and ResourceLoader.exists(ADMOB_BACKEND_PATH):
		var script: GDScript = load(ADMOB_BACKEND_PATH)
		if script != null:
			_backend = script.new()
			add_child(_backend)
			_backend.rewarded_result.connect(_finish_rewarded)
			_backend.interstitial_closed.connect(_finish_interstitial)
			_backend.setup(_units())
			simulated = false


## The ad units to use: the live ones in a release build once they are set,
## Google's test units otherwise.
func _units() -> Dictionary:
	var os := "ios" if OS.has_feature("ios") else "android"
	var live: Dictionary = AD_UNITS_LIVE[os]
	if not OS.is_debug_build() and str(live["rewarded"]) != "" and str(live["interstitial"]) != "":
		return live
	return AD_UNITS_TEST[os]


func is_busy() -> bool:
	return _busy


## Emits rewarded_result(true) once the reward is earned, false if closed
## early or failed. Exactly one signal per call.
func show_rewarded() -> void:
	if _busy:
		return
	_busy = true
	if simulated:
		get_tree().create_timer(SIMULATED_SECONDS).timeout.connect(func(): _finish_rewarded(true))
		return
	_backend.show_rewarded()


## Emits interstitial_closed() when it is gone -- at once if none loaded.
func show_interstitial() -> void:
	if _busy:
		return
	_busy = true
	if simulated:
		get_tree().create_timer(SIMULATED_SECONDS).timeout.connect(_finish_interstitial)
		return
	if not _backend.interstitial_loaded():
		_finish_interstitial()
		return
	_backend.show_interstitial()


func _finish_rewarded(earned: bool) -> void:
	_busy = false
	rewarded_result.emit(earned)


func _finish_interstitial() -> void:
	_busy = false
	interstitial_closed.emit()
