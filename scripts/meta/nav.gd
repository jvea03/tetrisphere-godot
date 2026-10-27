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
## switch (Tunables "social_enabled") turns both on early (the editor has it on).
static var as_released := false   # true: the editor too sees what players do (tools/store_shot --release)


static func social_enabled() -> bool:
	return (OS.has_feature("editor") and not as_released) or TSTunables.get_bool("social_enabled")


## The leaderboards (Ranks) and Clubs (teams) open on these local dates; until
## then their tabs say so.
const LEADERBOARDS_OPEN_DATE := "2026-11-11"
const LEADERBOARDS_SOON := "Leaderboards open November 11!"
const CLUBS_OPEN_DATE := "2026-12-09"
const CLUBS_SOON := "Teams open December 9!"


static func leaderboards_open() -> bool:
	return social_enabled() or leaderboards_open_on(TSClock.date_string())


static func leaderboards_open_on(date: String) -> bool:   # a "YYYY-MM-DD" local date
	return date >= LEADERBOARDS_OPEN_DATE


## Clubs (teams) open on their own date.
static func clubs_open() -> bool:
	return social_enabled() or clubs_open_on(TSClock.date_string())


static func clubs_open_on(date: String) -> bool:
	return date >= CLUBS_OPEN_DATE


## The win streak starts on its own local date (from level 7 on): before it,
## no streak is counted, shown or rewarded. The editor sees it at once, unless
## as_released.
const WIN_STREAK_OPEN_DATE := "2026-11-04"

static func win_streak_open() -> bool:
	return (OS.has_feature("editor") and not as_released) or win_streak_open_on(TSClock.date_string())


static func win_streak_open_on(date: String) -> bool:   # a "YYYY-MM-DD" local date
	return date >= WIN_STREAK_OPEN_DATE


## Wires one nav tab: `go` runs once unlocked; otherwise a note says when.
static func gate(btn: BaseButton, unlocked: bool, unlock_level: int, screen: Control, go: Callable) -> void:
	btn.modulate = Color(1, 1, 1, 1.0 if unlocked else LOCKED_ALPHA)
	if unlocked:
		btn.pressed.connect(go)
	else:
		btn.pressed.connect(func(): TSUI.note(screen, btn, "Unlocks at level %d" % unlock_level))


## As gate, for a feature not open yet: the tab dimmed under a `tag_text` tag
## ("SOON", or the date), and a tap says `soon`.
static func gate_soon(btn: BaseButton, open: bool, unlocked: bool, unlock_level: int, soon: String, tag_text: String, screen: Control, go: Callable) -> void:
	if open:
		gate(btn, unlocked, unlock_level, screen, go)
		return
	for c in btn.get_children():   # its icon and label dimmed, the tag bright
		(c as CanvasItem).modulate = Color(1, 1, 1, LOCKED_ALPHA)
	var tag := TSUI.pill(tag_text, TSUI.CORAL, 15, Color.WHITE)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -64.0
	tag.offset_right = -2.0
	tag.offset_top = -8.0
	tag.rotation = 0.12
	btn.add_child(tag)
	btn.pressed.connect(func(): TSUI.note(screen, btn, soon))
