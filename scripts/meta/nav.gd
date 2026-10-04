class_name TSNav
extends RefCounted

## Level gates on the bottom nav and Home (Duckdoku's NavLock). A locked tab
## stays in the bar, dimmed, and tapping it says when it unlocks.

const COLLECTION_UNLOCK_LEVEL := 5
const CLUBS_UNLOCK_LEVEL := 25
const FEATURES_UNLOCK_LEVEL := 7 # chest tray + Battle Pass + Eggsperience (with their Home walkthrough)
const DAILY_UNLOCK_LEVEL := 10 # the Daily Egg tile on Home

const LOCKED_ALPHA := 0.45


static func collection_unlocked() -> bool:
	return TSProfile.last_level >= COLLECTION_UNLOCK_LEVEL


static func clubs_unlocked() -> bool:
	return TSProfile.last_level >= CLUBS_UNLOCK_LEVEL


static func features_unlocked() -> bool:
	return TSProfile.last_level >= FEATURES_UNLOCK_LEVEL


static func daily_unlocked() -> bool:
	return TSProfile.last_level >= DAILY_UNLOCK_LEVEL


## Leaderboards and Clubs run on locally simulated rivals (no backend). One
## switch (Tunables "social_enabled") can hide both behind "Coming soon".
static func social_enabled() -> bool:
	return OS.has_feature("editor") or TSTunables.get_bool("social_enabled")


## Wires one nav tab: `go` runs once unlocked; otherwise a note says when.
static func gate(btn: BaseButton, unlocked: bool, unlock_level: int, screen: Control, go: Callable) -> void:
	btn.modulate = Color(1, 1, 1, 1.0 if unlocked else LOCKED_ALPHA)
	if unlocked:
		btn.pressed.connect(go)
	else:
		btn.pressed.connect(func(): TSUI.note(screen, btn, "Unlocks at level %d" % unlock_level))


## As gate, but "Coming soon" when the social features are switched off.
static func gate_social(btn: BaseButton, unlocked: bool, unlock_level: int, screen: Control, go: Callable) -> void:
	if social_enabled():
		gate(btn, unlocked, unlock_level, screen, go)
		return
	btn.modulate = Color(1, 1, 1, LOCKED_ALPHA)
	if unlocked:
		btn.pressed.connect(func(): TSUI.note(screen, btn, "Coming soon"))
	else:
		btn.pressed.connect(func(): TSUI.note(screen, btn, "Unlocks at level %d" % unlock_level))
