class_name TSSets
extends RefCounted

## Collection sets: themed groups of critters, each with ranks 1 to MAX_RANK.
## Rank N is claimed once every critter in the set is at least level N:
## rank 1 by owning them all (a critter starts at level 1), rank 2 once every
## one is level 2, and so on to the critters' top level. Each rank pays once
## (TSProfile.sets_rank; sets claimed before ranks are rank 1 through
## TSProfile.sets_claimed). Rank 1 pays the set's full coins, every rank
## after it RANK_UP_SHARE of them. Only
## critters anyone can buy are in sets (none held back for a later release,
## none only in the Battle Pass), and each critter is in one set at most.
## Each has its own colour for its card. The reward is a quarter of what
## the set's critters cost to buy, rounded to 500. A set with a "season" is
## featured while that Battle Pass season runs (Snow Day at Christmas): first
## on the tab, dressed for it, and worth FEATURED_BONUS times its coins.

const FEATURED_BONUS := 2

const SETS := [
	{"id": "snacks", "color": Color(1.0, 0.72, 0.5), "name": "Snack Time", "critters": [18, 27, 36, 37, 38, 68]},     # Popcorn, Donut, Choco, Cocoa, Cinnamon, S'more
	{"id": "pets", "color": Color(1.0, 0.8, 0.45), "name": "Pet Pals", "critters": [25, 34, 33, 41, 94, 26, 35]},       # Puppy, Kitty, Capy, Moo, Piggy, Donkey, Chick
	{"id": "garden", "color": Color(0.6, 0.86, 0.56), "name": "In the Garden", "critters": [1, 8, 73, 87, 77]},          # Gardy, Sprout, Berry, Rosie, Violet
	{"id": "family", "color": Color(1.0, 0.68, 0.76), "name": "Family Tree", "critters": [6, 7, 16, 45]},                # Granny, Grandpa, Mama, Baby
	{"id": "crew", "color": Color(0.95, 0.74, 0.52), "name": "Camp Crew", "critters": [40, 59, 39, 48, 14]},             # Builder, Wrench, Scrubby, Explorer, Postie
	{"id": "clinic", "color": Color(0.62, 0.86, 0.9), "name": "Doctor's Office", "critters": [19, 24, 62, 63, 92]},     # Nurse, Doc, Dentist, Medic, Labby
	{"id": "outdoors", "color": Color(0.66, 0.84, 0.98), "name": "Out & About", "critters": [47, 89, 81, 74, 75]},        # Biker, Jogger, Tourist, Sunny, Shades
	{"id": "splash", "color": Color(0.52, 0.76, 1.0), "name": "Splash Zone", "critters": [64, 65, 93, 90, 84, 83]},     # Sharky, Pearl, Diver, Sailor, Puddles, Drizzle
	{"id": "snow", "color": Color(0.78, 0.88, 1.0), "name": "Snow Day", "critters": [66, 69, 56, 88], "season": "christmas"},                   # Skier, Boarder, Flurry, Rudy
	{"id": "show", "color": Color(0.88, 0.7, 1.0), "name": "Showtime", "critters": [23, 44, 49, 98, 9]},               # Director, Artist, Party, Groovy, Skater
	{"id": "royal", "color": Color(1.0, 0.82, 0.32), "name": "Royal Court", "critters": [10, 12, 43, 60, 61]},          # King, Knight, Gent, Mayor, Boss
	{"id": "magic", "color": Color(0.76, 0.64, 1.0), "name": "Magic & Myth", "critters": [28, 30, 57, 17, 22, 103]},    # Dragon, Fairy, Witch, Rawr, Dino, Rainbow
]


## A set's top rank: the critters' top level.
const MAX_RANK := TSProfile.CRITTER_MAX_LEVEL
## What each rank after the first pays, as a share of the set's coins.
const RANK_UP_SHARE := 0.5


## What the next rank pays now: rank 1 the set's base_reward, a later rank
## RANK_UP_SHARE of it (to the nearest 500); times FEATURED_BONUS while featured.
static func reward(s: Dictionary) -> int:
	return reward_for(s, mini(rank(s) + 1, MAX_RANK))


static func reward_for(s: Dictionary, r: int) -> int:
	var base := base_reward(s)
	var pay := base if r <= 1 else maxi(500, roundi(base * RANK_UP_SHARE / 500.0) * 500)
	return pay * (FEATURED_BONUS if is_featured(s) else 1)


## Whether this is the season's featured set (its "season" is the one running).
static func is_featured(s: Dictionary) -> bool:
	return s.has("season") and str(s["season"]) == TSProfile.season_theme()


static func base_reward(s: Dictionary) -> int:
	var cost := 0
	for i: int in s["critters"]:
		cost += TSProfile.critter_unlock_cost(i)
	return maxi(500, roundi(cost * 0.25 / 500.0) * 500)


## The rank claimed so far: 0 none, 1..MAX_RANK.
static func rank(s: Dictionary) -> int:
	var id := str(s["id"])
	return int(TSProfile.sets_rank.get(id, 1 if TSProfile.sets_claimed.has(id) else 0))


## The rank being worked toward (MAX_RANK once it's all claimed).
static func next_rank(s: Dictionary) -> int:
	return mini(rank(s) + 1, MAX_RANK)


## How many of a set's critters are at level `at` or above (1: owned).
static func at_level(s: Dictionary, at: int) -> int:
	var n := 0
	for i: int in s["critters"]:
		n += int(TSProfile.is_critter_unlocked(i) and maxi(TSProfile.critter_level_of(i), 1) >= at)   # owned is level 1 at least
	return n


## Owned critters in the set.
static func owned_in(s: Dictionary) -> int:
	return at_level(s, 1)


## Every critter owned (rank 1 within reach).
static func is_complete(s: Dictionary) -> bool:
	return owned_in(s) == (s["critters"] as Array).size()


## Rank 1 claimed -- the set counts as complete.
static func is_claimed(s: Dictionary) -> bool:
	return rank(s) >= 1


## Every rank claimed.
static func is_maxed(s: Dictionary) -> bool:
	return rank(s) >= MAX_RANK


## The next rank is ready: every critter at its level.
static func can_claim(s: Dictionary) -> bool:
	return not is_maxed(s) and at_level(s, next_rank(s)) == (s["critters"] as Array).size()


## How many sets have a rank waiting to be claimed (the Sets tab's count).
static func claimable_count() -> int:
	var n := 0
	for s: Dictionary in SETS:
		n += int(can_claim(s))
	return n


## Claims the next rank and pays it. Returns the coins (0 if it can't).
static func claim(s: Dictionary) -> int:
	if not can_claim(s):
		return 0
	var r := next_rank(s)
	var coins := TSProfile.boost_earned_coins(reward_for(s, r))
	TSProfile.coin_count += coins
	TSAnalytics.earned("Collection", "Set", coins)
	var id := str(s["id"])
	TSProfile.sets_rank[id] = r
	if not TSProfile.sets_claimed.has(id):
		TSProfile.sets_claimed.append(id)   # older builds read this
	TSProfile.save()
	return coins


## The sets in the order the tab shows them: the season's featured set (till
## its first rank is claimed), a rank ready to claim, then by how near the next
## rank is, then the ones with every rank claimed.
static func ordered() -> Array:
	var out: Array = SETS.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _order_key(a) < _order_key(b))
	return out


static func _order_key(s: Dictionary) -> Array:
	var key := 0 if can_claim(s) else (2 if is_maxed(s) else 1)
	if key < 2 and is_featured(s) and not is_claimed(s):
		key = -1
	return [key, -float(at_level(s, next_rank(s))) / float((s["critters"] as Array).size())]
