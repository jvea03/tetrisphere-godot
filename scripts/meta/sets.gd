class_name TSSets
extends RefCounted

## Collection sets: themed groups of critters. Owning every critter in a set
## lets the player claim its coins, once (TSProfile.sets_claimed). Only
## critters anyone can buy are in sets (none held back for a later release,
## none only in the Battle Pass), and each critter is in one set at most.
## Each has its own colour for its card. The reward is a quarter of what
## the set's critters cost to buy, rounded to 500.

const SETS := [
	{"id": "snacks", "color": Color(1.0, 0.72, 0.5), "name": "Snack Time", "critters": [18, 27, 36, 37, 38, 68]},     # Popcorn, Donut, Choco, Cocoa, Cinnamon, S'more
	{"id": "pets", "color": Color(1.0, 0.8, 0.45), "name": "Pet Pals", "critters": [25, 34, 33, 41, 94, 26, 35]},       # Puppy, Kitty, Capy, Moo, Piggy, Donkey, Chick
	{"id": "garden", "color": Color(0.6, 0.86, 0.56), "name": "In the Garden", "critters": [1, 8, 73, 87, 77]},          # Gardy, Sprout, Berry, Rosie, Violet
	{"id": "family", "color": Color(1.0, 0.68, 0.76), "name": "Family Tree", "critters": [6, 7, 16, 45]},                # Granny, Grandpa, Mama, Baby
	{"id": "crew", "color": Color(0.95, 0.74, 0.52), "name": "Camp Crew", "critters": [40, 59, 39, 48, 14]},             # Builder, Wrench, Scrubby, Explorer, Postie
	{"id": "clinic", "color": Color(0.62, 0.86, 0.9), "name": "Doctor's Office", "critters": [19, 24, 62, 63, 92]},     # Nurse, Doc, Dentist, Medic, Labby
	{"id": "outdoors", "color": Color(0.66, 0.84, 0.98), "name": "Out & About", "critters": [47, 89, 81, 74, 75]},        # Biker, Jogger, Tourist, Sunny, Shades
	{"id": "splash", "color": Color(0.52, 0.76, 1.0), "name": "Splash Zone", "critters": [64, 65, 93, 90, 84, 83]},     # Sharky, Pearl, Diver, Sailor, Puddles, Drizzle
	{"id": "snow", "color": Color(0.78, 0.88, 1.0), "name": "Snow Day", "critters": [66, 69, 56, 88]},                   # Skier, Boarder, Flurry, Rudy
	{"id": "show", "color": Color(0.88, 0.7, 1.0), "name": "Showtime", "critters": [23, 44, 49, 98, 9]},               # Director, Artist, Party, Groovy, Skater
	{"id": "royal", "color": Color(1.0, 0.82, 0.32), "name": "Royal Court", "critters": [10, 12, 43, 60, 61]},          # King, Knight, Gent, Mayor, Boss
	{"id": "magic", "color": Color(0.76, 0.64, 1.0), "name": "Magic & Myth", "critters": [28, 30, 57, 17, 22, 103]},    # Dragon, Fairy, Witch, Rawr, Dino, Rainbow
]


static func reward(s: Dictionary) -> int:
	var cost := 0
	for i: int in s["critters"]:
		cost += TSProfile.critter_unlock_cost(i)
	return maxi(500, roundi(cost * 0.25 / 500.0) * 500)


static func owned_in(s: Dictionary) -> int:
	var n := 0
	for i: int in s["critters"]:
		n += int(TSProfile.is_critter_unlocked(i))
	return n


static func is_complete(s: Dictionary) -> bool:
	return owned_in(s) == (s["critters"] as Array).size()


static func is_claimed(s: Dictionary) -> bool:
	return TSProfile.sets_claimed.has(s["id"])


static func can_claim(s: Dictionary) -> bool:
	return is_complete(s) and not is_claimed(s)


## How many finished sets wait to be claimed (the Sets tab's count).
static func claimable_count() -> int:
	var n := 0
	for s: Dictionary in SETS:
		n += int(can_claim(s))
	return n


## Pays a finished set's coins, once. Returns the coins (0 if it can't).
static func claim(s: Dictionary) -> int:
	if not can_claim(s):
		return 0
	var coins := TSProfile.boost_earned_coins(reward(s))
	TSProfile.coin_count += coins
	TSProfile.sets_claimed.append(s["id"])
	TSProfile.save()
	return coins


## The sets in the order the tab shows them: ready to claim, then by how
## near they are, then the ones already claimed.
static func ordered() -> Array:
	var out: Array = SETS.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := [0 if can_claim(a) else (2 if is_claimed(a) else 1), -float(owned_in(a)) / float((a["critters"] as Array).size())]
		var kb := [0 if can_claim(b) else (2 if is_claimed(b) else 1), -float(owned_in(b)) / float((b["critters"] as Array).size())]
		return ka < kb)
	return out
