class_name TSSnowball
extends RefCounted

## The Snowball Fight: a weekend team event in the Christmas season. Every
## weekend (Friday to Sunday, local time) while the Christmas Battle Pass
## season runs, the player joins Team Gingerbread (id "red") or Team Snowman ("green"); every piece they pop
## in a level throws a snowball for their team. The two teams' totals race on
## a tug-of-war bar. The player's own throws pay milestone prizes along the
## way, and when the weekend ends everyone who threw at least MIN_TO_PLACE
## gets the team prize -- more for the winning side.
##
## The other players' throws are simulated for now (a steady, seeded climb
## per weekend, each team surging at its own moments, so the lead changes
## hands); the player's own throws are added to their team's.
##
## Snowballs come from every piece popped in a level, and from the Giant
## Snowball the event screen offers every six hours (blast).

const LENGTH_DAYS := 3                   # Friday, Saturday, Sunday
const FRIDAY := 4                        # Monday is 0
const TEAMS := ["red", "green"]
const TEAM_NAMES := {"red": "Team Gingerbread", "green": "Team Snowman"}
const TEAM_COLORS := {"red": Color(1.0, 0.46, 0.48), "green": Color(0.42, 0.8, 0.5)}
const CROWD := 1_200_000                 # roughly what each team throws in a weekend, without the player
## The player's own milestones: {at, coins} or {at, bombs}.
const MILESTONES := [
	{"at": 150, "coins": 500},
	{"at": 400, "bombs": 1},
	{"at": 800, "coins": 1000},
	{"at": 1500, "bombs": 2},
	{"at": 2500, "coins": 2500},
]
const MIN_TO_PLACE := 100                # throws to share in the team prize
const WIN_COINS := 3000
const LOSE_COINS := 1000
## The Giant Snowball: once every BLAST_COOLDOWN seconds the player mashes a
## button for BLAST_SECONDS; it throws BLAST_MIN to BLAST_MAX snowballs for
## their team, more the faster they tap (BLAST_TAPS taps for the most).
const BLAST_COOLDOWN := 6 * 3600
const BLAST_SECONDS := 5.0
const BLAST_MIN := 5
const BLAST_MAX := 15
const BLAST_TAPS := 30

static var week := -1                    # the weekend joined (TSProfile's week index); -1 none
static var team := ""
static var thrown := 0
static var claimed: Array = []           # milestone indexes claimed
## A finished weekend's result, waiting to be shown and paid:
## {"team", "won", "coins", "bombs", "mine", "theirs"}; empty when none.
static var result := {}
## Set to force the event on (captures, tests), whatever the date.
static var force_live := false
## When the last Giant Snowball was thrown (TSClock seconds); 0 never.
static var blast_at := 0.0


static func to_save() -> Dictionary:
	return {"week": week, "team": team, "thrown": thrown, "claimed": claimed.duplicate(), "result": result.duplicate(), "blast_at": blast_at}


static func from_save(data: Dictionary) -> void:
	week = int(data.get("week", -1))
	team = str(data.get("team", ""))
	thrown = int(data.get("thrown", 0))
	claimed = (data.get("claimed", []) as Array).duplicate()
	result = (data.get("result", {}) as Dictionary).duplicate()
	blast_at = float(data.get("blast_at", 0.0))


# -- the calendar ------------------------------------------------------------------

static func _day() -> int:
	@warning_ignore("integer_division")
	return TSClock.local_unix() / 86400


static func _weekday() -> int:
	return (_day() + 3) % 7


static func _week_now() -> int:
	@warning_ignore("integer_division")
	return (_day() + 3) / 7


## Whether a fight is on now: a weekend in the Christmas season.
static func is_live() -> bool:
	if force_live:
		return true
	return TSNav.features_unlocked() and TSProfile.season_theme() == "christmas" and _weekday() >= FRIDAY


## Seconds into this weekend's fight (from Friday's local midnight).
static func elapsed() -> int:
	return TSClock.local_unix() - (_day() - (_weekday() - FRIDAY)) * 86400 if _weekday() >= FRIDAY else 0


static func seconds_left() -> int:
	return maxi(LENGTH_DAYS * 86400 - elapsed(), 0)


## How far through the weekend, 0..1.
static func fraction() -> float:
	return clampf(float(elapsed()) / float(LENGTH_DAYS * 86400), 0.0, 1.0)


# -- joining and throwing ------------------------------------------------------------

## Settles a finished weekend (its result waits to be shown) and joins this
## one -- on a team picked at random, kept all weekend.
static func roll() -> void:
	var now_week := _week_now()
	if week >= 0 and week != now_week:
		_settle()
	if is_live() and week != now_week:
		week = now_week
		team = TEAMS[randi() % 2]
		thrown = 0
		claimed = []
		TSProfile.save()


## Each piece popped in a level throws a snowball.
static func note_pieces(n: int) -> void:
	if n <= 0 or not is_live():
		return
	roll()
	thrown += n
	push_board()


# -- top throwers ------------------------------------------------------------------
# Each team has its own online board each weekend, "snowball_W<week>_<team>",
# on Online's boards (a row's "stars" are the snowballs thrown; firestore.rules
# takes any board, up to 100,000), so the Top Throwers tab can show either
# team's best without a team field on the row.

const PUSH_EVERY := 60.0                 # seconds between row writes while playing
## Coins for each team's top three throwers, paid once the weekend's over
## (through TSProfile's board results: placed online, on a board of at least
## TSProfile.BOARD_MIN_FOR_PRIZES players, collected on Home).
const TOP_COINS := [5000, 3000, 2000]
static var _pushed_at := -1.0e9


static func board(t: String) -> String:
	return Online.board_id("snowball", "W%d_%s" % [week, t])


## Writes the player's row on their team's board: at most once a minute
## while they pop pieces, or now (`now`).
static func push_board(now := false) -> void:
	if team == "" or thrown <= 0 or week < 0:
		return
	var t := Time.get_unix_time_from_system()
	if not now and t - _pushed_at < PUSH_EVERY:
		return
	_pushed_at = t
	Online.push(board(team), mini(thrown, 100000))


## A team's top throwers this weekend, best first: the board's rows (minus
## anyone the player blocked), with the player's own row on their team.
static func standings(t: String) -> Array:
	var rows: Array = Online.entries(board(t)).filter(func(e: Dictionary) -> bool: return not e.get("is_player", false) and not TSProfile.blocked_players.has(e.get("uid", "")))
	if t == team:
		rows.append({"uid": Online.uid, "name": TSProfile.player_name, "avatar": TSProfile.avatar(), "stars": thrown, "is_player": true})
	rows.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]) or (int(a["stars"]) == int(b["stars"]) and a.get("is_player", false) and not b.get("is_player", false)))
	return rows


## Whether the Giant Snowball is ready to throw.
static func blast_ready() -> bool:
	return is_live() and blast_wait() <= 0


## Seconds until the Giant Snowball is ready again.
static func blast_wait() -> int:
	return maxi(int(blast_at + BLAST_COOLDOWN - TSClock.now()), 0)


## How many snowballs a Giant Snowball mashed `taps` times throws.
static func blast_amount(taps: int) -> int:
	return clampi(BLAST_MIN + roundi(float(taps) * float(BLAST_MAX - BLAST_MIN) / float(BLAST_TAPS)), BLAST_MIN, BLAST_MAX)


## Throws the Giant Snowball: its snowballs go to the player's team and the
## cooldown starts. Returns how many it threw (0 if it wasn't ready).
static func blast(taps: int) -> int:
	if not blast_ready():
		return 0
	roll()
	var n := blast_amount(taps)
	thrown += n
	blast_at = TSClock.now()
	TSProfile.save()
	push_board(true)
	return n


## What a team has thrown so far (the crowd's, plus the player's for theirs).
static func team_total(t: String, at := -1.0) -> int:
	var f := fraction() if at < 0.0 else at
	var seed_v := hash("%d:%s" % [week, t])
	var size := CROWD * (0.92 + 0.16 * float(seed_v % 1000) / 1000.0)
	@warning_ignore("integer_division")
	var phase := float((seed_v / 1000) % 628) / 100.0
	# A steady climb with a surge or two of its own; never goes backwards.
	var curve := f + 0.03 * (sin(f * TAU * 2.0 + phase) - sin(phase))
	return int(size * maxf(curve, 0.0)) + (thrown if t == team else 0)


static func rival() -> String:
	return "green" if team == "red" else "red"


static func winning() -> bool:
	return team_total(team) >= team_total(rival())


## A team's share of all the snowballs thrown, 0..1 (0.5 before any).
static func share(t: String) -> float:
	var a := team_total(t)
	var b := team_total("green" if t == "red" else "red")
	return 0.5 if a + b == 0 else float(a) / float(a + b)


# -- milestones --------------------------------------------------------------------

static func milestone_reached(i: int) -> bool:
	return thrown >= int(MILESTONES[i]["at"])


static func milestone_claimed(i: int) -> bool:
	return claimed.has(i)


static func claimable_count() -> int:
	var n := 0
	for i in MILESTONES.size():
		n += int(milestone_reached(i) and not milestone_claimed(i))
	return n


## Pays a reached milestone, once. Returns what it paid ("+500 coins").
static func claim(i: int) -> String:
	if not milestone_reached(i) or milestone_claimed(i):
		return ""
	claimed.append(i)
	var got := _pay(MILESTONES[i])
	TSProfile.save()
	return got


static func _pay(m: Dictionary) -> String:
	if m.has("bombs"):
		TSProfile.add_boosters("bomb", int(m["bombs"]))
		return "+%d bomb%s" % [int(m["bombs"]), "" if int(m["bombs"]) == 1 else "s"]
	var coins := TSProfile.boost_earned_coins(int(m["coins"]))
	TSProfile.coin_count += coins
	TSProfile.note_coins("Snowball Fight", coins)
	return "+%s coins" % TSProfile.fmt_coins(coins)


## The weekend just over: who won, and what the player gets -- the team prize
## if they threw enough, and any milestones they left unclaimed. Paid now;
## `result` keeps it to show.
static func _settle() -> void:
	var mine := team_total(team, 1.0)
	var theirs := team_total(rival(), 1.0)
	var won := mine >= theirs
	var coins := 0
	var bombs := 0
	if thrown >= MIN_TO_PLACE:
		coins += WIN_COINS if won else LOSE_COINS
	for i in MILESTONES.size():
		if milestone_reached(i) and not milestone_claimed(i):
			coins += int(MILESTONES[i].get("coins", 0))
			bombs += int(MILESTONES[i].get("bombs", 0))
	if coins > 0:
		coins = TSProfile.boost_earned_coins(coins)
		TSProfile.coin_count += coins
		TSProfile.note_coins("Snowball Fight", coins)
	if bombs > 0:
		TSProfile.add_boosters("bomb", bombs)
	result = {"team": team, "won": won, "coins": coins, "bombs": bombs, "mine": mine, "theirs": theirs, "thrown": thrown}
	# Top Throwers: the team's board is placed online like the other boards,
	# and a top-3 place pays TOP_COINS (only if the row was written online).
	if thrown > 0 and TSProfile.boards_joined.has(board(team)):
		TSProfile.pending_board_results.append({"period": "snowball", "board": board(team), "stars": thrown, "team": team})
	week = -1
	team = ""
	thrown = 0
	claimed = []
	TSProfile.save()


## Shown (and cleared) by the screen.
static func take_result() -> Dictionary:
	var r := result
	if not r.is_empty():
		result = {}
		TSProfile.save()
	return r


## Home shows the tile while a fight is on, or a result waits.
static func show_tile() -> bool:
	return is_live() or not result.is_empty()


static func has_alert() -> bool:
	return claimable_count() > 0 or not result.is_empty() or (is_live() and week != _week_now()) or blast_ready()
