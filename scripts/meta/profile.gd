class_name TSProfile
extends RefCounted

## The player, persisted to user://profile.cfg: identity, coins, boosters, the
## critter and shell collection, clubs, streaks, the simulated leaderboards,
## the Battle Pass and its quests. Everything the menus show and spend comes
## from here. Ported from Duckdoku's PlayerProfile and re-themed: ducks are
## critters (the little creatures sealed in the egg), ships are shells (egg
## skins), anchors are stars, crews are clubs, and Duckdoku's three boosters
## are Tetrisphere's three: the bomb, the Swap and Rocks.
##
## No backend: the leaderboards, clubs and club chat are simulated locally,
## the same deterministic way Duckdoku does it -- see those sections.

const SAVE_PATH := "user://profile.cfg"
const SAVE_VERSION := 1
## The save is written encrypted. Obfuscation, not security -- the key ships
## in the binary -- but it stops casual coin editing.
const SAVE_KEY := "tetrisphere-profile-v1-2c9e"
const DEFAULT_NAME := "Hatchling"

## False for tests, so they never touch the player's real save.
static var persist: bool = true


## Tests and demo captures: a throwaway profile that never reads or writes the
## save, with the walkthroughs already seen and every booster in hand.
static func use_test_profile(level := 1) -> void:
	persist = false
	ensure_loaded()
	tutorial_seen = true
	bomb_tutorial_seen = true
	bombs_unlocked = true
	bomb_count = 5
	swap_tutorial_seen = true
	rocks_tutorial_seen = true
	swaps_unlocked = true
	swap_count = 3
	rocks_unlocked = true
	rock_count = 2
	last_level = level

## Preset avatar ring colours to choose from on the Profile card.
const AVATAR_COLORS := [
	Color(1.00, 0.55, 0.70), # strawberry
	Color(1.00, 0.80, 0.36), # butter
	Color(0.50, 0.84, 0.62), # mint
	Color(0.52, 0.76, 0.98), # sky
	Color(0.74, 0.60, 0.95), # lilac
	Color(1.00, 0.66, 0.44), # peach
]

static var player_name: String = DEFAULT_NAME
static var avatar_index: int = 0
static var avatar_critter: int = 0 # the critter on the Home card, the Profile, and sealed in the egg
static var last_level: int = 1
static var coin_count: int = 0
## The Shop's daily 1,000-coin pack: claims taken today (free first, then
## ads -- see the Shop's STARTER_PACK_LIMIT) and the date they belong to.
static var starter_coin_claims: int = 0
static var starter_coin_claims_date: String = ""


## Zeroes the daily pack's claims on the first look each day.
static func roll_starter_claims() -> void:
	var today := Time.get_date_string_from_system()
	if starter_coin_claims_date != today:
		starter_coin_claims_date = today
		if starter_coin_claims != 0:
			starter_coin_claims = 0
			save()


## The Shop's No Ads pass: every "watch an ad" step is skipped and its reward
## granted outright, and earned coins get a bonus on top (boost_earned_coins).
static var no_ads: bool = false
const NO_ADS_PASS_COINS := 40000 # bundled into the pass
## True once any real-money purchase has gone through. Payers are never
## offered an ad and see fewer interstitials.
static var is_payer: bool = false
## Set when a non-payer closes the win card past the interstitial gate
## instead of pressing Next Level: Home's PLAY shows that ad first.
static var interstitial_owed: bool = false
static var interstitial_win_count: int = 0


static func no_ads_coin_bonus_percent() -> int:
	return TSTunables.get_int("no_ads_coin_bonus_percent")


static func record_purchase() -> void:
	is_payer = true


## Grants the No Ads pass and its coin bundle (bought, not earned, so no bonus).
static func buy_no_ads_pass() -> void:
	if no_ads:
		return
	no_ads = true
	is_payer = true
	coin_count += NO_ADS_PASS_COINS
	save()


# -- bombs -----------------------------------------------------------------
# The first booster. Bombs are kept between balls; a chain reaction or
# a big clear earns one in play, the Shop sells packs, and an empty bomb
# button offers an ad or a coin buy.

const BOMB_PACK_AMOUNT := 5
const BOMB_UNLOCK_LEVEL := 2
const BOMB_UNLOCK_GRANT := 3

static var bomb_count: int = 0
static var bombs_unlocked: bool = false


static func bomb_pack_cost() -> int:
	return TSTunables.get_int("bomb_pack_cost")


static func bomb_buy_count() -> int:
	return TSTunables.get_int("bomb_buy_count")


## The mid-game buy is the Shop's five-pack pro rata.
static func bomb_buy_cost() -> int:
	return booster_buy_cost("bomb")


## Grants each booster's starting stock once the level that brings it is
## reached: bombs, then the Swap, then Rocks.
static func note_level_started(level: int) -> void:
	var changed := false
	for id in BOOSTERS:
		if level >= booster_unlock_level(id) and not booster_unlocked(id):
			add_boosters(id, booster_unlock_grant(id))
			changed = true
	if changed:
		save()


# -- the Swap and Rocks ----------------------------------------------------
# Two more boosters, kept, earned and bought like bombs. The Swap trades the
# piece you hold for the one with the biggest match on the ball, aimed at it;
# Rocks fire two rocks, each finishing a match on the biggest near-match
# showing (see TSBoard.best_piece and rock_targets). Each has its own count,
# unlock level and walkthrough. BOOSTERS lists all three by id, for the code
# that treats them alike (the empty-booster card, unlocks, the Shop).

const BOOSTERS := ["bomb", "swap", "rocks"]
const BOOSTER_NAMES := {   # title, one, many
	"bomb": ["Bomb", "bomb", "bombs"],
	"swap": ["Swap", "swap", "swaps"],
	"rocks": ["Rocks", "rock shot", "rock shots"],
}
const SWAP_UNLOCK_LEVEL := 4
const SWAP_UNLOCK_GRANT := 3
const ROCKS_UNLOCK_LEVEL := 8
const ROCKS_UNLOCK_GRANT := 2

static var swap_count: int = 0
static var swaps_unlocked: bool = false
static var swap_tutorial_seen: bool = false
static var rock_count: int = 0          # rock shots: each fires two rocks
static var rocks_unlocked: bool = false
static var rocks_tutorial_seen: bool = false


static func booster_count(id: String) -> int:
	match id:
		"swap": return swap_count
		"rocks": return rock_count
	return bomb_count


static func booster_unlocked(id: String) -> bool:
	match id:
		"swap": return swaps_unlocked
		"rocks": return rocks_unlocked
	return bombs_unlocked


static func booster_unlock_level(id: String) -> int:
	match id:
		"swap": return SWAP_UNLOCK_LEVEL
		"rocks": return ROCKS_UNLOCK_LEVEL
	return BOMB_UNLOCK_LEVEL


static func booster_unlock_grant(id: String) -> int:
	match id:
		"swap": return SWAP_UNLOCK_GRANT
		"rocks": return ROCKS_UNLOCK_GRANT
	return BOMB_UNLOCK_GRANT


## Adds (or, with a negative n, spends) boosters; having any unlocks them.
static func add_boosters(id: String, n: int) -> void:
	match id:
		"swap":
			swap_count = maxi(0, swap_count + n)
			swaps_unlocked = true
		"rocks":
			rock_count = maxi(0, rock_count + n)
			rocks_unlocked = true
		_:
			bomb_count = maxi(0, bomb_count + n)
			bombs_unlocked = true


static func booster_pack_cost(id: String) -> int:
	return TSTunables.get_int(id + "_pack_cost")


static func booster_buy_count(id: String) -> int:
	return TSTunables.get_int(id + "_buy_count")


## The mid-game buy is the Shop's five-pack pro rata, for every booster.
static func booster_buy_cost(id: String) -> int:
	@warning_ignore("integer_division")
	return booster_pack_cost(id) * booster_buy_count(id) / BOMB_PACK_AMOUNT


static var tutorial_seen: bool = false # the Level 1 walkthrough, once ever
static var bomb_tutorial_seen: bool = false # the bomb walkthrough, once, when bombs arrive
static var club_intro_seen: bool = false
static var collection_tutorial_seen: bool = false
static var daily_callout_seen: bool = false
static var home_tutorial_seen: bool = false
static var collection_gift_claimed: bool = false
static var _loaded: bool = false

# -- audio/haptics toggles (Settings) ---------------------------------------
static var music_enabled: bool = true
static var sfx_enabled: bool = true
static var haptics_enabled: bool = true


## Settings toggles by name ("music_enabled", "sfx_enabled", "haptics_enabled").
static func get_toggle(name: String) -> bool:
	match name:
		"music_enabled": return music_enabled
		"sfx_enabled": return sfx_enabled
		"haptics_enabled": return haptics_enabled
	return false


static func set_toggle(name: String, on: bool) -> void:
	match name:
		"music_enabled": music_enabled = on
		"sfx_enabled": sfx_enabled = on
		"haptics_enabled": haptics_enabled = on
	save()

# -- critters (Collection) ---------------------------------------------------
# Each critter is drawn by TSIcon from its colour and accessory, so there are
# no art files. Rarity sets its price, its level-up base and how many
# collection points each level is worth. Critter 0, Milky -- the creature
# from the first ball -- starts owned.
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const CRITTER_RARITY_COST := [5000, 15000, 40000, 100000]
const CRITTER_RARITY_POINTS := [5, 8, 12, 20]
const CRITTER_UNLOCK_COST := 5000

## {name, color, accessory, rarity}. Accessories are TSIcon's: "", "sprout",
## "freckles", "bow", "flower", "bear", "cat", "bunny", "frog", "bee", "dino",
## "horns", "halo", "crown", "party", "ghost", "glasses", "star", "cloud",
## "pumpkin", "beanie", "rainbow".
const CRITTERS := [
	{"name": "Milky", "color": Color(1.00, 0.97, 0.93), "acc": "", "rarity": Rarity.COMMON},
	{"name": "Peachy", "color": Color(1.00, 0.78, 0.66), "acc": "", "rarity": Rarity.COMMON},
	{"name": "Minty", "color": Color(0.66, 0.92, 0.76), "acc": "sprout", "rarity": Rarity.COMMON},
	{"name": "Lemon", "color": Color(1.00, 0.92, 0.52), "acc": "freckles", "rarity": Rarity.COMMON},
	{"name": "Bubblegum", "color": Color(1.00, 0.72, 0.84), "acc": "bow", "rarity": Rarity.RARE},
	{"name": "Blueberry", "color": Color(0.64, 0.76, 1.00), "acc": "", "rarity": Rarity.COMMON},
	{"name": "Lilac", "color": Color(0.82, 0.72, 0.98), "acc": "flower", "rarity": Rarity.RARE},
	{"name": "Mocha", "color": Color(0.80, 0.64, 0.52), "acc": "bear", "rarity": Rarity.COMMON},
	{"name": "Kitty", "color": Color(0.82, 0.82, 0.86), "acc": "cat", "rarity": Rarity.RARE},
	{"name": "Bunbun", "color": Color(1.00, 0.93, 0.95), "acc": "bunny", "rarity": Rarity.RARE},
	{"name": "Froggy", "color": Color(0.58, 0.86, 0.50), "acc": "frog", "rarity": Rarity.RARE},
	{"name": "Buzzy", "color": Color(1.00, 0.84, 0.30), "acc": "bee", "rarity": Rarity.EPIC},
	{"name": "Dino", "color": Color(0.54, 0.82, 0.64), "acc": "dino", "rarity": Rarity.EPIC},
	{"name": "Imp", "color": Color(1.00, 0.56, 0.56), "acc": "horns", "rarity": Rarity.EPIC},
	{"name": "Angel", "color": Color(1.00, 1.00, 0.98), "acc": "halo", "rarity": Rarity.EPIC},
	{"name": "Royal", "color": Color(1.00, 0.86, 0.48), "acc": "crown", "rarity": Rarity.LEGENDARY},
	{"name": "Party", "color": Color(1.00, 0.66, 0.80), "acc": "party", "rarity": Rarity.RARE},
	{"name": "Ghosty", "color": Color(0.88, 0.92, 1.00), "acc": "ghost", "rarity": Rarity.EPIC},
	{"name": "Nerdy", "color": Color(1.00, 0.74, 0.50), "acc": "glasses", "rarity": Rarity.COMMON},
	{"name": "Starry", "color": Color(0.44, 0.46, 0.80), "acc": "star", "rarity": Rarity.LEGENDARY},
	{"name": "Cloudy", "color": Color(0.84, 0.94, 1.00), "acc": "cloud", "rarity": Rarity.RARE},
	{"name": "Pumpkin", "color": Color(1.00, 0.66, 0.34), "acc": "pumpkin", "rarity": Rarity.EPIC},
	{"name": "Snowy", "color": Color(0.90, 0.96, 1.00), "acc": "beanie", "rarity": Rarity.EPIC},
	{"name": "Rainbow", "color": Color(1.00, 0.80, 0.90), "acc": "rainbow", "rarity": Rarity.LEGENDARY},
]
const CRITTER_COUNT := 24

## Once bought, a critter can be levelled up to CRITTER_MAX_LEVEL.
const CRITTER_MAX_LEVEL := 10
## Four tiers across a critter's (or shell's) levels, each with a title in
## front of the name ("Veteran Minty"), plus star pips on the tile.
const PROGRESS_TITLES := ["", "Seasoned", "Veteran", "Master"]
const CRITTER_LEVEL_UP_BASE := [5000, 7500, 10000, 12500] # by rarity, for level 1 -> 2
const CRITTER_LEVEL_UP_STEP := 2000

static var critter_unlocked: Array = []
static var critter_level: Array = [] # 0 while locked, 1..CRITTER_MAX_LEVEL once owned
## Critters handed over elsewhere (a Battle Pass reward), not yet seen in the
## Collection: their tiles wear a "NEW" badge.
static var new_critters: Array = []

# -- shells (Collection's second tab) -------------------------------------------
# Egg skins: the equipped one colours the egg's caps in play. Purely cosmetic,
# but every level counts toward the collection level.
const SHELLS := [
	{"name": "Strawberry Milk", "cap": Color(1.00, 0.74, 0.82), "trim": Color(1.00, 0.97, 0.90), "rarity": Rarity.COMMON, "cost": 0},
	{"name": "Vanilla Cream", "cap": Color(1.00, 0.95, 0.80), "trim": Color(1.00, 0.72, 0.80), "rarity": Rarity.COMMON, "cost": 10000},
	{"name": "Mint Chip", "cap": Color(0.66, 0.92, 0.78), "trim": Color(0.52, 0.38, 0.30), "rarity": Rarity.COMMON, "cost": 20000},
	{"name": "Blueberry Swirl", "cap": Color(0.62, 0.74, 0.98), "trim": Color(1.00, 0.97, 0.90), "rarity": Rarity.RARE, "cost": 35000},
	{"name": "Lemon Drop", "cap": Color(1.00, 0.90, 0.50), "trim": Color(1.00, 1.00, 1.00), "rarity": Rarity.COMMON, "cost": 15000},
	{"name": "Lavender Dream", "cap": Color(0.80, 0.70, 0.98), "trim": Color(1.00, 0.90, 0.96), "rarity": Rarity.RARE, "cost": 50000},
	{"name": "Peach Fuzz", "cap": Color(1.00, 0.78, 0.64), "trim": Color(1.00, 0.97, 0.90), "rarity": Rarity.COMMON, "cost": 20000},
	{"name": "Chocolate Dip", "cap": Color(0.62, 0.44, 0.34), "trim": Color(1.00, 0.84, 0.88), "rarity": Rarity.EPIC, "cost": 75000},
	{"name": "Robin Egg", "cap": Color(0.62, 0.88, 0.88), "trim": Color(0.36, 0.28, 0.26), "rarity": Rarity.RARE, "cost": 40000},
	{"name": "Galaxy", "cap": Color(0.30, 0.26, 0.52), "trim": Color(1.00, 0.86, 0.40), "rarity": Rarity.LEGENDARY, "cost": 200000},
	{"name": "Golden Yolk", "cap": Color(1.00, 0.80, 0.30), "trim": Color(1.00, 1.00, 0.95), "rarity": Rarity.LEGENDARY, "cost": 150000},
	{"name": "Rainbow Sherbet", "cap": Color(1.00, 0.62, 0.72), "trim": Color(1.00, 0.92, 0.50), "rarity": Rarity.EPIC, "cost": 100000},
]
const SHELL_COUNT := 12
const SHELL_MAX_LEVEL := 6
const SHELL_LEVEL_UP_STEP := 5000

static var shell_unlocked: Array = []
static var shell_level: Array = []
static var equipped_shell: int = 0


static func _blank_collection() -> void:
	critter_unlocked = []
	critter_level = []
	for i in CRITTER_COUNT:
		critter_unlocked.append(i == 0)
		critter_level.append(1 if i == 0 else 0)
	shell_unlocked = []
	shell_level = []
	for i in SHELL_COUNT:
		shell_unlocked.append(i == 0)
		shell_level.append(1 if i == 0 else 0)


static func _static_init() -> void:
	_blank_collection()


static func progress_tier(level: int, max_level: int) -> int:
	if level >= max_level:
		return 3
	var t := float(level - 1) / float(max_level - 1)
	if t < 0.33:
		return 0
	return 1 if t < 0.66 else 2


static func progress_title(level: int, max_level: int, name: String) -> String:
	var prefix: String = PROGRESS_TITLES[progress_tier(level, max_level)]
	return name if prefix == "" else "%s %s" % [prefix, name]


static func critter_name(i: int) -> String:
	return str(CRITTERS[i]["name"])


static func critter_color(i: int) -> Color:
	return CRITTERS[i]["color"]


static func critter_accessory(i: int) -> String:
	return str(CRITTERS[i]["acc"])


static func critter_rarity(i: int) -> int:
	return int(CRITTERS[i]["rarity"])


static func shell_name(i: int) -> String:
	return str(SHELLS[i]["name"])


static func shell_rarity(i: int) -> int:
	return int(SHELLS[i]["rarity"])


static func shell_cost(i: int) -> int:
	return int(SHELLS[i]["cost"])


static func is_critter_unlocked(i: int) -> bool:
	return i >= 0 and i < critter_unlocked.size() and bool(critter_unlocked[i])


static func is_shell_unlocked(i: int) -> bool:
	return i >= 0 and i < shell_unlocked.size() and bool(shell_unlocked[i])


static func critter_level_of(i: int) -> int:
	return int(critter_level[i]) if i >= 0 and i < critter_level.size() else 0


static func shell_level_of(i: int) -> int:
	return int(shell_level[i]) if i >= 0 and i < shell_level.size() else 0


static func is_critter_max_level(i: int) -> bool:
	return critter_level_of(i) >= CRITTER_MAX_LEVEL


static func is_shell_max_level(i: int) -> bool:
	return shell_level_of(i) >= SHELL_MAX_LEVEL


static func critter_unlock_cost(i: int) -> int:
	return int(CRITTER_RARITY_COST[critter_rarity(i)])


static func critter_level_up_cost(i: int) -> int:
	return int(CRITTER_LEVEL_UP_BASE[critter_rarity(i)]) + CRITTER_LEVEL_UP_STEP * (critter_level_of(i) - 1)


static func shell_level_up_cost(i: int) -> int:
	var base_cost: int = maxi(shell_cost(i), CRITTER_UNLOCK_COST)
	return base_cost + SHELL_LEVEL_UP_STEP * (shell_level_of(i) - 1)


static func unlock_critter(i: int) -> bool:
	if is_critter_unlocked(i) or coin_count < critter_unlock_cost(i):
		return false
	coin_count -= critter_unlock_cost(i)
	var level_before := collection_level()
	critter_unlocked[i] = true
	critter_level[i] = 1
	save()
	record_quest_event("critter_spend")
	_note_collection_level(level_before)
	return true


## Hands a critter over for free (a pass reward). False if already owned.
static func grant_critter(i: int) -> bool:
	if i < 0 or i >= CRITTER_COUNT or is_critter_unlocked(i):
		return false
	var level_before := collection_level()
	critter_unlocked[i] = true
	critter_level[i] = 1
	if not new_critters.has(i):
		new_critters.append(i)
	_note_collection_level(level_before)
	return true


static func level_up_critter(i: int) -> bool:
	if not is_critter_unlocked(i) or is_critter_max_level(i):
		return false
	var cost := critter_level_up_cost(i)
	if coin_count < cost:
		return false
	coin_count -= cost
	var level_before := collection_level()
	critter_level[i] += 1
	save()
	record_quest_event("critter_spend")
	_note_collection_level(level_before)
	return true


static func unlock_shell(i: int) -> bool:
	if is_shell_unlocked(i) or coin_count < shell_cost(i):
		return false
	coin_count -= shell_cost(i)
	var level_before := collection_level()
	shell_unlocked[i] = true
	shell_level[i] = 1
	save()
	_note_collection_level(level_before)
	return true


static func grant_shell(i: int) -> bool:
	if i < 0 or i >= SHELL_COUNT or is_shell_unlocked(i):
		return false
	var level_before := collection_level()
	shell_unlocked[i] = true
	shell_level[i] = 1
	_note_collection_level(level_before)
	return true


static func level_up_shell(i: int) -> bool:
	if not is_shell_unlocked(i) or is_shell_max_level(i):
		return false
	var cost := shell_level_up_cost(i)
	if coin_count < cost:
		return false
	coin_count -= cost
	var level_before := collection_level()
	shell_level[i] += 1
	save()
	_note_collection_level(level_before)
	return true


static func equip_shell(i: int) -> bool:
	if not is_shell_unlocked(i) or i == equipped_shell:
		return false
	equipped_shell = i
	save()
	return true


static func is_critter_new(i: int) -> bool:
	return new_critters.has(i)


static func clear_new_critters(indices: Array = []) -> void:
	var before := new_critters.size()
	if indices.is_empty():
		new_critters.clear()
	else:
		for i in indices:
			new_critters.erase(i)
	if new_critters.size() != before:
		save()


## Makes an owned critter the avatar (and the one sealed in the egg).
static func set_avatar_critter(i: int) -> void:
	if not is_critter_unlocked(i) or avatar_critter == i:
		return
	avatar_critter = i
	save()


static func avatar_color() -> Color:
	return AVATAR_COLORS[avatar_index]


## The avatar critter, falling back to Milky if the pick is not owned.
static func avatar() -> int:
	return avatar_critter if is_critter_unlocked(avatar_critter) else 0


## A critter portrait for someone else -- a club mate, a rival -- picked by seed.
static func npc_critter(seed_value: int) -> int:
	return posmod(seed_value, CRITTER_COUNT)


## The Collection walkthrough hands over one Common critter's worth of coins.
const COLLECTION_GIFT_COINS := CRITTER_UNLOCK_COST

static func claim_collection_gift() -> int:
	if collection_gift_claimed:
		return 0
	collection_gift_claimed = true
	coin_count += COLLECTION_GIFT_COINS
	save()
	return COLLECTION_GIFT_COINS


## Collection level: every level across every owned critter and shell counts
## (a shell level is worth 10 points, a critter level 5-20 by rarity); each
## collection level past the first adds 1% to the coins a win pays.
const COLLECTION_POINTS_PER_SHELL_LEVEL := 10
const COLLECTION_POINTS_FIRST_LEVEL := 50
const COLLECTION_POINTS_LEVEL_STEP := 5
const COLLECTION_COIN_BONUS_PERCENT := 1


static func collection_points() -> int:
	var total := 0
	for i in CRITTER_COUNT:
		total += critter_level_of(i) * int(CRITTER_RARITY_POINTS[critter_rarity(i)])
	for lvl in shell_level:
		total += int(lvl) * COLLECTION_POINTS_PER_SHELL_LEVEL
	return total


static func collection_coin_bonus_percent() -> int:
	return (collection_level() - 1) * COLLECTION_COIN_BONUS_PERCENT


static func collection_points_for_level(level: int) -> int:
	return COLLECTION_POINTS_FIRST_LEVEL + (level - 1) * COLLECTION_POINTS_LEVEL_STEP


static func _note_collection_level(level_before: int) -> void:
	var gained := collection_level() - level_before
	if gained > 0:
		record_quest_event("collection_level", gained)


static func collection_level() -> int:
	var remaining := collection_points()
	var level := 1
	while remaining >= collection_points_for_level(level):
		remaining -= collection_points_for_level(level)
		level += 1
	return level


static func collection_level_progress() -> int:
	var remaining := collection_points()
	var level := 1
	while remaining >= collection_points_for_level(level):
		remaining -= collection_points_for_level(level)
		level += 1
	return remaining


# -- clubs (Clubs tab) --------------------------------------------------------
# No backend: CLUB_LIST is a fixed set of fictional clubs to join or search;
# joining or founding one is local state only.
const CLUB_LIST := [
	{"name": "Sunny Side Up", "members": 14, "capacity": 20},
	{"name": "Egg-cellent Friends", "members": 20, "capacity": 20},
	{"name": "The Shell Squad", "members": 7, "capacity": 15},
	{"name": "Hatch Patch", "members": 18, "capacity": 25},
	{"name": "Yolk Folk", "members": 5, "capacity": 10},
	{"name": "Cozy Nest", "members": 22, "capacity": 30},
	{"name": "Pastel Posse", "members": 9, "capacity": 12},
	{"name": "The Wobble Club", "members": 16, "capacity": 20},
]
const CLUB_CREATE_COST := 10000
const CLUB_DEFAULT_CAPACITY := 20

const RANK_LEADER := "Leader"
const RANK_OFFICER := "Officer"
const RANK_MEMBER := "Member"
const RANK_ORDER := [RANK_LEADER, RANK_OFFICER, RANK_MEMBER]

const CLUB_MEMBER_NAMES := [
	"Pudding", "Biscuit", "Noodle", "Waffles", "Sprinkles", "Toffee",
	"Dumpling", "Marshmallow", "Pickles", "Button", "Jellybean", "Peanut",
	"Muffin", "Pebble", "Taffy", "Cupcake", "Bubbles", "Nugget", "Clover", "Poppy",
]

static var has_club: bool = false
static var club_name: String = ""
static var club_is_owner: bool = false
static var club_joined_date: String = ""
static var club_joined_unix: int = 0
static var club_icon: int = 0
static var club_message: String = ""

const CLUB_ICON_COUNT := 10 # drawn by TSIcon ("badge" 0..9)
const CLUB_MESSAGE_MAX := 120

## Club chat, local like the rest: the player's own lines are kept, and
## simulated club mates chip in -- a few seeded lines when the club is joined
## and a reply now and then. Each line is {name, text, unix, is_player}.
const CLUB_CHAT_KEEP := 60
const CLUB_CHAT_LINE_MAX := 140
const CLUB_CHAT_OPENERS := [
	"Welcome to the club!", "Hi hi, new friend!", "Glad you're here!",
	"Stars up, everyone -- big week ahead.", "Anyone else stuck on an Extreme egg?",
	"Bombs are a lifesaver on the big holes.", "Nice run yesterday, club!",
]
const CLUB_CHAT_REPLIES := [
	"Yay!", "Nice one!", "On it.", "Same here.", "Let's climb!",
	"Good luck out there.", "Hehe, love it.", "Eggs-cellent!", "See you on the leaderboard.",
]
static var club_chat: Array = []


static func _is_known_club_name(name: String) -> bool:
	for club in CLUB_LIST:
		if club["name"] == name:
			return true
	return false


static func _push_chat(name: String, text: String, is_player: bool, unix: int = 0) -> void:
	club_chat.append({"name": name, "text": text, "unix": unix if unix > 0 else int(Time.get_unix_time_from_system()), "is_player": is_player})
	while club_chat.size() > CLUB_CHAT_KEEP:
		club_chat.pop_front()


static func _seed_club_chat() -> void:
	club_chat = []
	if club_is_owner:
		return
	var now := int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("club_chat_" + club_name)
	var mates := club_roster().filter(func(m): return not m["is_player"])
	if mates.is_empty():
		return
	for i in 3:
		var mate: Dictionary = mates[rng.randi_range(0, mates.size() - 1)]
		_push_chat(str(mate["name"]), CLUB_CHAT_OPENERS[rng.randi_range(0, CLUB_CHAT_OPENERS.size() - 1)], false, now - rng.randi_range(600, 6 * 3600))
	club_chat.sort_custom(func(a, b): return int(a["unix"]) < int(b["unix"]))


static func post_club_chat(text: String) -> bool:
	var line := TSFilter.clean(text.strip_edges().left(CLUB_CHAT_LINE_MAX))
	if not has_club or line == "":
		return false
	_push_chat(player_name, line, true)
	save()
	return true


## A simulated mate answers the player's last line (about half the time).
static func club_chat_reply() -> Dictionary:
	if not has_club:
		return {}
	var mates := club_roster().filter(func(m): return not m["is_player"])
	if mates.is_empty() or randf() < 0.45:
		return {}
	var mate: Dictionary = mates[randi() % mates.size()]
	_push_chat(str(mate["name"]), CLUB_CHAT_REPLIES[randi() % CLUB_CHAT_REPLIES.size()], false)
	save()
	return club_chat.back()


const CLUB_MESSAGES := [
	"Welcome! Dig holes, earn stars, have fun.",
	"Every star counts -- play a level a day and we climb.",
	"Cozy club, no pressure. Say hi!",
	"Top 3 this week, let's go!",
	"Bombs ready, lives full, hearts happy.",
]


static func club_icon_for(name: String) -> int:
	if has_club and name == club_name and club_is_owner:
		return club_icon
	return abs(hash("club_icon_" + name)) % CLUB_ICON_COUNT


static func club_message_for(name: String) -> String:
	if has_club and name == club_name and club_is_owner:
		return club_message
	return CLUB_MESSAGES[abs(hash("club_msg_" + name)) % CLUB_MESSAGES.size()]


static func set_club_message(text: String) -> bool:
	if not has_club or not club_is_owner:
		return false
	club_message = TSFilter.clean(text.strip_edges().left(CLUB_MESSAGE_MAX))
	save()
	return true


static func set_club_icon(icon: int) -> bool:
	if not has_club or not club_is_owner:
		return false
	club_icon = clampi(icon, 0, CLUB_ICON_COUNT - 1)
	save()
	return true


## 3-24 characters: letters, digits, spaces, apostrophes and hyphens,
## starting with a letter or digit, and clean.
const CLUB_NAME_MIN := 3
const CLUB_NAME_MAX := 24

static func is_valid_club_name(candidate: String) -> bool:
	var name := candidate.strip_edges()
	if name.length() < CLUB_NAME_MIN or name.length() > CLUB_NAME_MAX:
		return false
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9][A-Za-z0-9 '-]*$")
	return re.search(name) != null and TSFilter.is_clean(name)


static func create_club(new_name: String, icon: int = 0) -> bool:
	var trimmed := new_name.strip_edges()
	if has_club or not is_valid_club_name(trimmed) or coin_count < CLUB_CREATE_COST:
		return false
	coin_count -= CLUB_CREATE_COST
	has_club = true
	club_name = trimmed
	club_is_owner = true
	club_icon = clampi(icon, 0, CLUB_ICON_COUNT - 1)
	club_message = ""
	club_chat = []
	club_joined_date = Time.get_date_string_from_system()
	club_joined_unix = int(Time.get_unix_time_from_system())
	save()
	return true


static func join_club(target_name: String) -> bool:
	if has_club:
		return false
	has_club = true
	club_name = target_name
	club_is_owner = false
	club_joined_date = Time.get_date_string_from_system()
	club_joined_unix = int(Time.get_unix_time_from_system())
	_seed_club_chat()
	save()
	return true


static func leave_club() -> void:
	has_club = false
	club_name = ""
	club_is_owner = false
	club_icon = 0
	club_message = ""
	club_chat = []
	club_joined_date = ""
	club_joined_unix = 0
	save()


## Simulated roster -- deterministic per club name and week. The player is
## always in it: Leader of a club they founded, a new Member of one they joined.
static func club_roster() -> Array:
	if not has_club:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("club_roster_" + club_name + "_" + _period_key("weekly"))
	var npc_count := 0
	if not club_is_owner:
		for club in CLUB_LIST:
			if club["name"] == club_name:
				npc_count = maxi(int(club["members"]) - 1, 0)
				break
	var roster: Array = []
	for i in range(npc_count):
		@warning_ignore("integer_division")
		var rank: String = RANK_LEADER if i == 0 else (RANK_OFFICER if i <= maxi(npc_count / 5, 1) else RANK_MEMBER)
		roster.append({
			"name": CLUB_MEMBER_NAMES[i % CLUB_MEMBER_NAMES.size()],
			"rank": rank,
			"stars": rng.randi_range(0, 60),
			"tenure_seconds": rng.randi_range(3600, 200 * 86400),
			"critter": npc_critter(hash(str(CLUB_MEMBER_NAMES[i % CLUB_MEMBER_NAMES.size()]))),
			"is_player": false,
		})
	roster.append({
		"name": player_name,
		"rank": RANK_LEADER if club_is_owner else RANK_MEMBER,
		"stars": club_score(),
		"tenure_seconds": club_tenure_seconds(),
		"critter": avatar(),
		"is_player": true,
	})
	roster.sort_custom(func(a, b):
		var ra: int = RANK_ORDER.find(a["rank"])
		var rb: int = RANK_ORDER.find(b["rank"])
		if ra != rb:
			return ra < rb
		return int(a["stars"]) > int(b["stars"]))
	return roster


static func club_tenure_seconds() -> int:
	if club_joined_unix <= 0:
		return 0
	return maxi(int(Time.get_unix_time_from_system()) - club_joined_unix, 0)


## Weekly club-vs-club board: the player is their club's only real
## contributor, so the club's score is their weekly star total; rival clubs
## are simulated from the week key.
const CLUB_LEADERBOARD_REWARDS := [10000, 5000, 2500]
static var club_leaderboard_key: String = ""
static var club_leaderboard_reward_message: String = ""


static func club_score() -> int:
	return int(period_star_total["weekly"])


static func simulated_club_rivals_for(week_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("club_leaderboard_" + week_key)
	var rivals := []
	for club in CLUB_LIST:
		var score := rng.randi_range(10, 120) # drawn even when skipped, so the seed stays stable
		if has_club and club["name"] == club_name:
			continue
		rivals.append({"name": club["name"], "score": score, "is_player": false})
	rivals.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return rivals


## Must run BEFORE _roll_period("weekly") resets the total it reads.
static func _roll_club_leaderboard() -> void:
	if not has_club:
		return
	var week_key := _period_key("weekly")
	if club_leaderboard_key == week_key:
		return
	if club_leaderboard_key != "":
		_resolve_club_leaderboard(club_leaderboard_key, club_score())
	club_leaderboard_key = week_key


static func _resolve_club_leaderboard(week_key: String, club_total: int) -> void:
	var better := 0
	for rival in simulated_club_rivals_for(week_key):
		if int(rival["score"]) > club_total:
			better += 1
	if better < CLUB_LEADERBOARD_REWARDS.size():
		var reward: int = boost_earned_coins(CLUB_LEADERBOARD_REWARDS[better])
		_queue_board_prize("Club Leaderboard", better + 1, "%d stars" % club_total, reward)
		club_leaderboard_reward_message = "%s placed #%d (%d stars)! Collect +%s coins on Home." % [club_name, better + 1, club_total, fmt_coins(reward)]


static func club_standings() -> Array:
	_roll_club_leaderboard()
	_roll_period("weekly")
	var entries := simulated_club_rivals_for(_period_key("weekly"))
	if has_club:
		entries.append({"name": club_name, "score": club_score(), "is_player": true})
	entries.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return entries


## Seconds to the coming Monday 00:00 local.
static func seconds_until_weekly_reset() -> int:
	var dt := Time.get_datetime_dict_from_system()
	var days_left: int = (8 - int(dt["weekday"])) % 7
	if days_left == 0:
		days_left = 7
	var today_secs: int = int(dt["hour"]) * 3600 + int(dt["minute"]) * 60 + int(dt["second"])
	return days_left * 86400 - today_secs


# -- daily streaks --------------------------------------------------------------
# Two independent streaks: showing up at all (login) and playing the Daily
# Egg. Every 7th day of either pays bombs; each day also has a coin claim.
const STREAK_REWARD_INTERVAL := 7
const STREAK_REWARD_BOMBS := 5
const DAILY_LOGIN_REWARD_COINS := 100
const STREAK_MILESTONE_REWARD_COINS := 500

static var login_streak_count: int = 0
static var login_streak_last_date: String = ""
static var daily_streak_count: int = 0
static var daily_streak_last_date: String = ""
static var daily_completed_date: String = ""
static var login_reward_claimed_date: String = ""
static var daily_reward_claimed_date: String = ""
## Not saved: a just-happened notice for the Streak screen.
static var streak_reward_message: String = ""


static func _yesterday_of(date_str: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date_str + "T00:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)


static func _append_streak_message(msg: String) -> void:
	streak_reward_message = msg if streak_reward_message == "" else "%s\n%s" % [streak_reward_message, msg]


## Once per real day the app is opened (Home calls it).
static func record_login() -> void:
	var today := Time.get_date_string_from_system()
	if login_streak_last_date == today:
		return
	if login_streak_last_date != "" and login_streak_last_date == _yesterday_of(today):
		login_streak_count += 1
	else:
		login_streak_count = 1
	login_streak_last_date = today
	record_quest_event("login")
	if login_streak_count % STREAK_REWARD_INTERVAL == 0:
		bomb_count += STREAK_REWARD_BOMBS
		bombs_unlocked = true
		_append_streak_message("Login streak: %d days! +%d bombs" % [login_streak_count, STREAK_REWARD_BOMBS])
	save()


## Once when the player starts the day's Daily Egg.
static func record_daily_play() -> void:
	var today := Time.get_date_string_from_system()
	if daily_streak_last_date == today:
		return
	if daily_streak_last_date != "" and daily_streak_last_date == _yesterday_of(today):
		daily_streak_count += 1
	else:
		daily_streak_count = 1
	daily_streak_last_date = today
	if daily_streak_count % STREAK_REWARD_INTERVAL == 0:
		bomb_count += STREAK_REWARD_BOMBS
		bombs_unlocked = true
		_append_streak_message("Daily Egg streak: %d days! +%d bombs" % [daily_streak_count, STREAK_REWARD_BOMBS])
	save()


static func can_claim_login_reward() -> bool:
	var today := Time.get_date_string_from_system()
	return login_streak_last_date == today and login_reward_claimed_date != today


static func login_reward_amount() -> int:
	return boost_earned_coins(STREAK_MILESTONE_REWARD_COINS if login_streak_count % STREAK_REWARD_INTERVAL == 0 else DAILY_LOGIN_REWARD_COINS)


static func claim_login_reward() -> int:
	if not can_claim_login_reward():
		return 0
	var reward := login_reward_amount()
	coin_count += reward
	login_reward_claimed_date = login_streak_last_date
	save()
	return reward


static func can_claim_daily_reward() -> bool:
	var today := Time.get_date_string_from_system()
	return daily_streak_last_date == today and daily_reward_claimed_date != today


static func daily_reward_amount() -> int:
	return boost_earned_coins(STREAK_MILESTONE_REWARD_COINS if daily_streak_count % STREAK_REWARD_INTERVAL == 0 else DAILY_LOGIN_REWARD_COINS)


static func claim_daily_reward() -> int:
	if not can_claim_daily_reward():
		return 0
	var reward := daily_reward_amount()
	coin_count += reward
	daily_reward_claimed_date = daily_streak_last_date
	save()
	return reward


static func has_claimed_all_streak_rewards_today() -> bool:
	var today := Time.get_date_string_from_system()
	return login_reward_claimed_date == today and daily_reward_claimed_date == today


static func mark_daily_completed() -> void:
	daily_completed_date = Time.get_date_string_from_system()
	save()


static func is_daily_completed_today() -> bool:
	return daily_completed_date == Time.get_date_string_from_system()


# -- leaderboards ("stars") ---------------------------------------------------------
# A local placeholder, not a real cross-player board: rivals are fictional,
# their scores seeded from the date, so they are the same for everyone on a
# given day. Swap in a real backend if one is ever set up.
const LEADERBOARD_RIVAL_NAMES := [
	"Sir Wobbles", "Lady Yolk", "Captain Crumble",
	"Mochi Mae", "Professor Peep", "Duchess Doodle",
]
const LEADERBOARD_DAILY_COIN_REWARDS := [2000, 1500, 1000]
const LEADERBOARD_WEEKLY_COIN_REWARDS := [5000, 4000, 3000]
const LEADERBOARD_SEASON_COIN_REWARDS := [10000, 7500, 5000]

static var daily_star_total: int = 0
static var daily_star_date: String = ""
static var period_star_total: Dictionary = {"weekly": 0, "season": 0}
static var period_star_key: Dictionary = {"weekly": "", "season": ""}
static var leaderboard_reward_message: String = ""
## Board prizes are paid for a board's FINAL standing, once it has reset:
## settling queues the prize here, and Home's results card pays it.
static var pending_board_prizes: Array = []


static func _queue_board_prize(board: String, place: int, score: String, coins: int) -> void:
	pending_board_prizes.append({"board": board, "place": place, "score": score, "coins": coins})


static func claim_board_prizes() -> int:
	var total := 0
	for p in pending_board_prizes:
		total += int(p["coins"])
	pending_board_prizes = []
	coin_count += total
	if total > 0:
		save()
	return total


static func _append_leaderboard_message(msg: String) -> void:
	leaderboard_reward_message = msg if leaderboard_reward_message == "" else "%s\n%s" % [leaderboard_reward_message, msg]


static func simulated_rivals_for(date_str: String, days: float = 1.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("leaderboard_" + date_str)
	var rivals := []
	for rival_name in LEADERBOARD_RIVAL_NAMES:
		rivals.append({"name": rival_name, "stars": roundi(rng.randi_range(2, 22) * maxf(days, 1.0)), "is_player": false})
	rivals.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]))
	return rivals


static func _roll_leaderboard_day() -> void:
	var today := Time.get_date_string_from_system()
	if daily_star_date == today:
		return
	if daily_star_date != "" and daily_star_total > 0:
		_resolve_leaderboard_day(daily_star_date, daily_star_total)
	daily_star_date = today
	daily_star_total = 0


static func _resolve_leaderboard_day(date_str: String, player_total: int) -> void:
	if not TSNav.social_enabled():
		return
	var better := 0
	for rival in simulated_rivals_for(date_str):
		if int(rival["stars"]) > player_total:
			better += 1
	if better < LEADERBOARD_DAILY_COIN_REWARDS.size():
		var reward: int = boost_earned_coins(LEADERBOARD_DAILY_COIN_REWARDS[better])
		_queue_board_prize("Daily Leaderboard", better + 1, "%d stars" % player_total, reward)
		_append_leaderboard_message("Daily leaderboard: #%d place (%d stars)! Collect +%s coins on Home." % [better + 1, player_total, fmt_coins(reward)])


## Coins per star on a win. Live-tunable.
static func coins_per_star() -> int:
	return TSTunables.get_int("coins_per_star")


## Every difficulty pays the base; Extreme pays double.
const DIFFICULTY_COIN_MULTIPLIER := [1.0, 1.0, 1.0, 1.0, 2.0] # Beginner .. Extreme, as in Duckdoku

static func difficulty_coin_multiplier(difficulty: int) -> float:
	if difficulty < 0 or difficulty >= DIFFICULTY_COIN_MULTIPLIER.size():
		return 1.0
	return float(DIFFICULTY_COIN_MULTIPLIER[difficulty])


## The coins a win pays for `stars_earned` stars, collection bonus included.
static func win_coin_payout(stars_earned: int, difficulty: int = 0) -> int:
	var base := stars_earned * coins_per_star() * (1.0 + collection_coin_bonus_percent() / 100.0)
	return boost_earned_coins(roundi(base * difficulty_coin_multiplier(difficulty)))


## "180,030" -- every coin figure the player reads goes through this.
static func fmt_coins(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## The No Ads pass and an active Battle Pass each add their bonus to every
## coin EARNED (wins, streaks, prizes, pass tiers -- not purchases).
const BATTLE_PASS_COIN_BONUS_PERCENT := 5

static func battle_pass_active() -> bool:
	return battle_pass_purchased and battle_pass_seconds_remaining() > 0


static func earned_coin_bonus_percent() -> int:
	var pct := 0
	if no_ads:
		pct += no_ads_coin_bonus_percent()
	if battle_pass_active():
		pct += BATTLE_PASS_COIN_BONUS_PERCENT
	return pct


static func boost_earned_coins(base: int) -> int:
	var pct := earned_coin_bonus_percent()
	if pct <= 0:
		return base
	return roundi(base * (1.0 + pct / 100.0))


## Stars only start counting once the Battle Pass exists (the level-7 features).
static func stars_open() -> bool:
	return TSNav.features_unlocked()


## Coins paid by something other than the level just played (an Egg Hunt day
## finishing): logged here so the win card can list them.
static var coin_notices: Array[Dictionary] = []

static func note_coins(label: String, coins: int) -> void:
	if coins > 0:
		coin_notices.append({"label": label, "coins": coins})


## Settles every board whose day, week or season has rolled over.
static func settle_boards() -> void:
	if not TSNav.social_enabled():
		return
	_roll_leaderboard_day()
	_roll_club_leaderboard()
	_roll_period("weekly")
	_roll_period("season")


## A win: stars = lives left + bonus (the first-attempt bonus). Pays coins
## per star, climbs the Battle Pass, and adds to every board. Returns the
## stars awarded (0 before the pass opens -- the coins are still paid).
static func add_stars(lives_remaining: int, bonus: int = 0, difficulty: int = 0) -> int:
	var earned: int = maxi(lives_remaining, 0) + maxi(bonus, 0)
	coin_count += win_coin_payout(earned, difficulty)
	if not stars_open():
		save()
		return 0
	add_battle_pass_xp(earned)
	if TSNav.social_enabled():
		settle_boards()
		daily_star_total += earned
		period_star_total["weekly"] += earned
		period_star_total["season"] += earned
	save()
	return earned


static func todays_standings() -> Array:
	_roll_leaderboard_day()
	var entries := simulated_rivals_for(Time.get_date_string_from_system())
	entries.append({"name": player_name, "stars": daily_star_total, "is_player": true})
	entries.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]))
	return entries


static func _period_key(period: String) -> String:
	if period == "season":
		var dt := Time.get_datetime_dict_from_system()
		return "%04d-%02d" % [dt["year"], dt["month"]]
	return "W%d" % _local_week_index()


static func period_length_days(period: String) -> int:
	return 7 if period == "weekly" else 30


static func period_days_elapsed(period: String) -> int:
	if period == "weekly":
		return (_local_day_index() + 3) % 7 + 1
	return int(Time.get_datetime_dict_from_system()["day"])


## Days since the epoch in local time (1970-01-01 was a Thursday, so +3 makes
## Monday the start of each week).
static func _local_day_index() -> int:
	var date := Time.get_date_string_from_system()
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / 86400)


static func _local_week_index() -> int:
	@warning_ignore("integer_division")
	return (_local_day_index() + 3) / 7


static func _roll_period(period: String) -> void:
	var key := _period_key(period)
	if period_star_key[period] == key:
		return
	var prev_key: String = period_star_key[period]
	var prev_total: int = period_star_total[period]
	if prev_key != "" and prev_total > 0:
		_resolve_period(period, prev_key, prev_total)
	period_star_key[period] = key
	period_star_total[period] = 0


static func _resolve_period(period: String, key: String, player_total: int) -> void:
	if not TSNav.social_enabled():
		return
	var better := 0
	for rival in simulated_rivals_for(period + "_" + key, period_length_days(period)):
		if int(rival["stars"]) > player_total:
			better += 1
	var table: Array = LEADERBOARD_WEEKLY_COIN_REWARDS if period == "weekly" else LEADERBOARD_SEASON_COIN_REWARDS
	if better < table.size():
		var coins: int = boost_earned_coins(table[better])
		_queue_board_prize("%s Leaderboard" % period.capitalize(), better + 1, "%d stars" % player_total, coins)
		_append_leaderboard_message("%s leaderboard: #%d place (%d stars)! Collect +%s coins on Home." % [period.capitalize(), better + 1, player_total, fmt_coins(coins)])


static func period_standings(period: String) -> Array:
	_roll_period(period)
	var entries := simulated_rivals_for(period + "_" + _period_key(period), period_days_elapsed(period))
	entries.append({"name": player_name, "stars": period_star_total[period], "is_player": true})
	entries.sort_custom(func(a, b): return int(a["stars"]) > int(b["stars"]))
	return entries


static func standings_for(period: String) -> Array:
	if period == "daily":
		return todays_standings()
	return period_standings(period)


# -- Battle Pass ------------------------------------------------------------------
# A season is a rolling BATTLE_PASS_DAYS bucket; the season state resets on
# its own the next time anything touches the pass after a boundary.
const BATTLE_PASS_DAYS := 28
const BATTLE_PASS_TIER_COUNT := 30
const BATTLE_PASS_TIER_BASE := 30
const BATTLE_PASS_TIER_STEP := 1
const BATTLE_PASS_PRICE_LABEL := "$4.99"
const TIER_BUY_COINS_PER_STAR := 250

static var battle_pass_key: String = ""
static var battle_pass_xp: int = 0 # stars banked this season
static var battle_pass_purchased: bool = false
static var battle_pass_free_claimed: Array = []
static var battle_pass_paid_claimed: Array = []


static func battle_pass_tier_cost(tier: int) -> int:
	if tier <= 1:
		return 0
	return BATTLE_PASS_TIER_BASE + (tier - 2) * BATTLE_PASS_TIER_STEP


static func battle_pass_stars_for_tier(tier: int) -> int:
	var total := 0
	for t in range(1, tier + 1):
		total += battle_pass_tier_cost(t)
	return total


static func _battle_pass_key() -> String:
	@warning_ignore("integer_division")
	var epoch_day: int = int(Time.get_unix_time_from_system()) / 86400
	@warning_ignore("integer_division")
	return "BP%d" % (epoch_day / BATTLE_PASS_DAYS)


static func _sized_claim_array(arr: Array) -> Array:
	var result: Array = arr.duplicate()
	while result.size() < BATTLE_PASS_TIER_COUNT:
		result.append(false)
	if result.size() > BATTLE_PASS_TIER_COUNT:
		result.resize(BATTLE_PASS_TIER_COUNT)
	return result


static func _roll_battle_pass() -> void:
	battle_pass_free_claimed = _sized_claim_array(battle_pass_free_claimed)
	battle_pass_paid_claimed = _sized_claim_array(battle_pass_paid_claimed)
	var key := _battle_pass_key()
	if battle_pass_key == key:
		return
	battle_pass_key = key
	battle_pass_xp = 0
	battle_pass_purchased = false
	battle_pass_free_claimed.fill(false)
	battle_pass_paid_claimed.fill(false)
	save()


static func battle_pass_seconds_remaining() -> int:
	_roll_battle_pass()
	var now := int(Time.get_unix_time_from_system())
	@warning_ignore("integer_division")
	var season_index: int = (now / 86400) / BATTLE_PASS_DAYS
	return maxi((season_index + 1) * BATTLE_PASS_DAYS * 86400 - now, 0)


static func battle_pass_tier() -> int:
	_roll_battle_pass()
	var tier := 0
	while tier < BATTLE_PASS_TIER_COUNT and battle_pass_xp >= battle_pass_stars_for_tier(tier + 1):
		tier += 1
	return tier


static func battle_pass_tier_progress() -> int:
	var tier := battle_pass_tier()
	if tier >= BATTLE_PASS_TIER_COUNT:
		return 0
	return battle_pass_xp - battle_pass_stars_for_tier(tier)


static func battle_pass_open() -> bool:
	return TSNav.features_unlocked() and battle_pass_seconds_remaining() > 0


static func add_battle_pass_xp(amount: int) -> int:
	if not battle_pass_open():
		return 0
	_roll_battle_pass()
	var credited: int = maxi(amount, 0)
	battle_pass_xp += credited
	return credited


static func battle_pass_tier_buy_cost() -> int:
	var tier := battle_pass_tier()
	if tier >= BATTLE_PASS_TIER_COUNT:
		return 0
	var needed: int = battle_pass_stars_for_tier(tier + 1) - battle_pass_xp
	return maxi(needed, 1) * TIER_BUY_COINS_PER_STAR


static func purchase_battle_pass_tier() -> bool:
	if not battle_pass_open():
		return false
	var cost := battle_pass_tier_buy_cost()
	if cost <= 0 or coin_count < cost:
		return false
	var tier := battle_pass_tier()
	coin_count -= cost
	battle_pass_xp = battle_pass_stars_for_tier(tier + 1)
	save()
	return true


static func purchase_battle_pass() -> bool:
	_roll_battle_pass()
	if battle_pass_purchased:
		return false
	battle_pass_purchased = true
	save()
	return true


## Collectibles per season -- {tier: critter} and {tier: shell} per track;
## coins and bombs are the same every season. Later seasons walk the list
## and wrap. Each season's paid tier-1 critter is pass-only.
const BATTLE_PASS_SEASON_ONE := 739 # epoch_day / BATTLE_PASS_DAYS for the first season
const BATTLE_PASS_SEASON_REWARDS := [
	{"free_critters": {15: 16, 30: 11}, "paid_critters": {1: 19}, "paid_shells": {30: 9}}, # Party, Buzzy; Starry; Galaxy
	{"free_critters": {15: 21, 30: 22}, "paid_critters": {1: 23}, "paid_shells": {30: 10}}, # Pumpkin, Snowy; Rainbow; Golden Yolk
]
const BATTLE_PASS_EXCLUSIVE_CRITTERS := [19, 23]


static func battle_pass_season_number() -> int:
	@warning_ignore("integer_division")
	var idx: int = (int(Time.get_unix_time_from_system()) / 86400) / BATTLE_PASS_DAYS
	return maxi(idx - BATTLE_PASS_SEASON_ONE, 0) + 1


static func season_rewards() -> Dictionary:
	return BATTLE_PASS_SEASON_REWARDS[(battle_pass_season_number() - 1) % BATTLE_PASS_SEASON_REWARDS.size()]


static func is_critter_pass_exclusive(i: int) -> bool:
	return BATTLE_PASS_EXCLUSIVE_CRITTERS.has(i)


## Free track: 500 coins at tier 1, +100 a tier, 2 bombs every 5th tier
## (unless that tier hands out a critter).
const BATTLE_PASS_FREE_COINS_BASE := 500
const BATTLE_PASS_PAID_COINS_BASE := 1000
const BATTLE_PASS_COINS_STEP := 100

static func battle_pass_free_reward(tier: int) -> Dictionary:
	var r := {"coins": BATTLE_PASS_FREE_COINS_BASE + BATTLE_PASS_COINS_STEP * (tier - 1)}
	var critters: Dictionary = season_rewards()["free_critters"]
	if critters.has(tier):
		r["critter"] = critters[tier]
	elif tier % 5 == 0:
		r["bomb"] = 2
	return r


## Premium track: 1000 coins at tier 1, +100 a tier, and bombs every tier --
## 1 a tier, 3 on every 5th, 5 on the 10th and 20th -- unless the tier hands
## out a critter or shell.
static func battle_pass_paid_reward(tier: int) -> Dictionary:
	var r := {"coins": BATTLE_PASS_PAID_COINS_BASE + BATTLE_PASS_COINS_STEP * (tier - 1)}
	var season := season_rewards()
	if season["paid_critters"].has(tier):
		r["critter"] = season["paid_critters"][tier]
	elif season["paid_shells"].has(tier):
		r["shell"] = season["paid_shells"][tier]
	elif tier % 10 == 0:
		r["bomb"] = 5
	elif tier % 5 == 0:
		r["bomb"] = 3
	else:
		r["bomb"] = 1
	return r


static func _apply_reward(reward: Dictionary) -> void:
	coin_count += boost_earned_coins(int(reward.get("coins", 0)))
	if reward.has("critter"):
		grant_critter(int(reward["critter"]))
	if reward.has("shell"):
		grant_shell(int(reward["shell"]))
	if int(reward.get("bomb", 0)) > 0:
		bomb_count += int(reward["bomb"])
		bombs_unlocked = true


static func has_claimable_battle_pass_reward() -> bool:
	_roll_battle_pass()
	var reached := battle_pass_tier()
	for i in range(reached):
		if not bool(battle_pass_free_claimed[i]):
			return true
		if battle_pass_purchased and not bool(battle_pass_paid_claimed[i]):
			return true
	return false


static func can_claim_battle_pass_free(tier: int) -> bool:
	_roll_battle_pass()
	if tier < 1 or tier > BATTLE_PASS_TIER_COUNT:
		return false
	return battle_pass_tier() >= tier and not bool(battle_pass_free_claimed[tier - 1])


static func can_claim_battle_pass_paid(tier: int) -> bool:
	_roll_battle_pass()
	if not battle_pass_purchased or tier < 1 or tier > BATTLE_PASS_TIER_COUNT:
		return false
	return battle_pass_tier() >= tier and not bool(battle_pass_paid_claimed[tier - 1])


static func claim_battle_pass_free(tier: int) -> Dictionary:
	if not can_claim_battle_pass_free(tier):
		return {}
	var reward := battle_pass_free_reward(tier)
	_apply_reward(reward)
	battle_pass_free_claimed[tier - 1] = true
	save()
	return reward


static func claim_battle_pass_paid(tier: int) -> Dictionary:
	if not can_claim_battle_pass_paid(tier):
		return {}
	var reward := battle_pass_paid_reward(tier)
	_apply_reward(reward)
	battle_pass_paid_claimed[tier - 1] = true
	save()
	return reward


# -- quests (the Battle Pass screen's Quests tab) ---------------------------------
## Each quest counts one stat toward a target; reaching it completes the
## quest, and Collect pays its stars into the pass. The game reports:
##   "win"          a normal level won
##   "flawless"     a normal level won without losing a life
##   "clear"        pieces destroyed in play (by the count)
##   "match"        a fresh ball started
##   "daily_puzzle" the day's Daily Egg won
##   "booster"      a booster used: a bomb, Swap or Rocks
##   "chest"        a chest opened
##   "login", "collection_level", "critter_spend"
const DAILY_QUESTS := [
	{"name": "Log in", "points": 2, "stat": "login", "target": 1},
	{"name": "Win 1 level", "points": 3, "stat": "win", "target": 1},
	{"name": "Clear 30 pieces", "points": 5, "stat": "clear", "target": 30},
	{"name": "Win 5 levels", "points": 8, "stat": "win", "target": 5},
	{"name": "Complete a Daily Egg", "points": 10, "stat": "daily_puzzle", "target": 1},
	{"name": "Open 5 chests", "points": 10, "stat": "chest", "target": 5},
]
const WEEKLY_QUESTS := [
	{"name": "Log in 5 days", "points": 12, "stat": "login", "target": 5},
	{"name": "Go up a Collection level", "points": 15, "stat": "collection_level", "target": 1},
	{"name": "Win 30 levels", "points": 30, "stat": "win", "target": 30},
	{"name": "Use 10 boosters", "points": 15, "stat": "booster", "target": 10},
	{"name": "Clear 300 pieces", "points": 20, "stat": "clear", "target": 300},
	{"name": "Buy or upgrade 3 critters", "points": 15, "stat": "critter_spend", "target": 3},
	{"name": "Win 7 levels without losing a life", "points": 30, "stat": "flawless", "target": 7},
]
## Each new week ADDS its set; older weeks' quests stay listed for this long.
const QUEST_WEEKS_KEPT := 4

static var quest_daily_date: String = ""
static var quest_daily_progress: Dictionary = {}
static var quest_daily_done: Array = []
static var quest_daily_claimed: Array = []
static var quest_weekly: Dictionary = {}


static func _quest_week_number(key: String) -> int:
	return int(key.substr(1))


static func _roll_quests() -> void:
	var today := Time.get_date_string_from_system()
	if quest_daily_date != today:
		quest_daily_date = today
		quest_daily_progress = {}
		quest_daily_done = []
		quest_daily_claimed = []
	_pad_quest_flags(quest_daily_done, quest_daily_claimed, DAILY_QUESTS.size())
	var week := _period_key("weekly")
	if not quest_weekly.has(week):
		quest_weekly[week] = {"progress": {}, "done": [], "claimed": []}
	var this_week := _quest_week_number(week)
	for key in quest_weekly.keys():
		if this_week - _quest_week_number(key) >= QUEST_WEEKS_KEPT:
			quest_weekly.erase(key)
			continue
		var week_set: Dictionary = quest_weekly[key]
		_pad_quest_flags(week_set["done"], week_set["claimed"], WEEKLY_QUESTS.size())


static func _pad_quest_flags(done: Array, claimed: Array, count: int) -> void:
	while done.size() < count:
		done.append(false)
	while claimed.size() < count:
		claimed.append(false)


static func record_quest_event(stat: String, amount: int = 1) -> Array:
	_roll_quests()
	var completed: Array = []
	quest_daily_progress[stat] = int(quest_daily_progress.get(stat, 0)) + amount
	completed += _complete_quests(DAILY_QUESTS, quest_daily_progress, quest_daily_done)
	for key in quest_weekly:
		var week: Dictionary = quest_weekly[key]
		week["progress"][stat] = int(week["progress"].get(stat, 0)) + amount
		completed += _complete_quests(WEEKLY_QUESTS, week["progress"], week["done"])
	TSHunt.record_event(stat, amount)
	save()
	return completed


static func _complete_quests(defs: Array, progress: Dictionary, done: Array) -> Array:
	var completed: Array = []
	for i in defs.size():
		if done[i]:
			continue
		var q: Dictionary = defs[i]
		if int(progress.get(q["stat"], 0)) >= int(q["target"]):
			done[i] = true
			completed.append(q)
	return completed


## Collect a finished quest: its stars go to the pass (if open). week_key ""
## is today's daily set. Returns the stars credited, or -1 if nothing to collect.
static func claim_quest(week_key: String, index: int) -> int:
	_roll_quests()
	var defs: Array = DAILY_QUESTS if week_key == "" else WEEKLY_QUESTS
	var done: Array = quest_daily_done if week_key == "" else quest_weekly.get(week_key, {}).get("done", [])
	var claimed: Array = quest_daily_claimed if week_key == "" else quest_weekly.get(week_key, {}).get("claimed", [])
	if index < 0 or index >= done.size() or not done[index] or claimed[index]:
		return -1
	claimed[index] = true
	var credited := add_battle_pass_xp(int(defs[index]["points"]))
	save()
	return credited


static func has_unclaimed_quests() -> bool:
	return has_unclaimed_daily_quests() or has_unclaimed_weekly_quests()


static func has_unclaimed_daily_quests() -> bool:
	_roll_quests()
	for i in quest_daily_done.size():
		if quest_daily_done[i] and not quest_daily_claimed[i]:
			return true
	return false


static func has_unclaimed_weekly_quests() -> bool:
	_roll_quests()
	for key in quest_weekly:
		var week_set: Dictionary = quest_weekly[key]
		for i in week_set["done"].size():
			if week_set["done"][i] and not week_set["claimed"][i]:
				return true
	return false


static func daily_quest_rows() -> Array:
	_roll_quests()
	return _quest_rows(DAILY_QUESTS, quest_daily_progress, quest_daily_done, quest_daily_claimed, "")


static func weekly_quest_groups() -> Array:
	_roll_quests()
	var this_week := _quest_week_number(_period_key("weekly"))
	var keys := quest_weekly.keys()
	keys.sort_custom(func(a, b): return _quest_week_number(a) > _quest_week_number(b))
	var groups: Array = []
	for key in keys:
		var week: Dictionary = quest_weekly[key]
		groups.append({
			"week_key": key,
			"weeks_ago": this_week - _quest_week_number(key),
			"rows": _quest_rows(WEEKLY_QUESTS, week["progress"], week["done"], week["claimed"], key),
		})
	return groups


static func _quest_rows(defs: Array, progress: Dictionary, done: Array, claimed: Array, week_key: String) -> Array:
	var rows: Array = []
	for i in defs.size():
		var q: Dictionary = defs[i].duplicate()
		q["progress"] = mini(int(progress.get(q["stat"], 0)), int(q["target"]))
		q["done"] = bool(done[i])
		q["claimed"] = bool(claimed[i])
		q["index"] = i
		q["week_key"] = week_key
		rows.append(q)
	return rows


# -- saving -----------------------------------------------------------------------

## Idempotent -- safe to call from every screen's _ready().
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := _read_save() if persist else null
	if cfg == null:
		return
	var g := func(key: String, default: Variant) -> Variant: return cfg.get_value("profile", key, default)
	player_name = str(g.call("name", DEFAULT_NAME))
	if not TSFilter.is_clean(player_name):
		player_name = DEFAULT_NAME
	avatar_index = clampi(int(g.call("avatar_index", 0)), 0, AVATAR_COLORS.size() - 1)
	avatar_critter = clampi(int(g.call("avatar_critter", 0)), 0, CRITTER_COUNT - 1)
	last_level = maxi(int(g.call("last_level", 1)), 1)
	coin_count = int(g.call("coin_count", 0))
	starter_coin_claims = int(g.call("starter_coin_claims", 0))
	starter_coin_claims_date = str(g.call("starter_coin_claims_date", ""))
	no_ads = bool(g.call("no_ads", false))
	is_payer = bool(g.call("is_payer", false)) or no_ads
	interstitial_owed = bool(g.call("interstitial_owed", false))
	interstitial_win_count = int(g.call("interstitial_win_count", 0))
	bomb_count = int(g.call("bomb_count", 0))
	bombs_unlocked = bool(g.call("bombs_unlocked", false))
	swap_count = int(g.call("swap_count", 0))
	swaps_unlocked = bool(g.call("swaps_unlocked", false))
	swap_tutorial_seen = bool(g.call("swap_tutorial_seen", false))
	rock_count = int(g.call("rock_count", 0))
	rocks_unlocked = bool(g.call("rocks_unlocked", false))
	rocks_tutorial_seen = bool(g.call("rocks_tutorial_seen", false))
	tutorial_seen = bool(g.call("tutorial_seen", false))
	bomb_tutorial_seen = bool(g.call("bomb_tutorial_seen", false))
	club_intro_seen = bool(g.call("club_intro_seen", false))
	collection_tutorial_seen = bool(g.call("collection_tutorial_seen", false))
	daily_callout_seen = bool(g.call("daily_callout_seen", false))
	home_tutorial_seen = bool(g.call("home_tutorial_seen", false))
	collection_gift_claimed = bool(g.call("collection_gift_claimed", false))
	music_enabled = bool(g.call("music_enabled", true))
	sfx_enabled = bool(g.call("sfx_enabled", true))
	haptics_enabled = bool(g.call("haptics_enabled", true))
	var cu: Array = g.call("critter_unlocked", [])
	var cl: Array = g.call("critter_level", [])
	var su: Array = g.call("shell_unlocked", [])
	var sl: Array = g.call("shell_level", [])
	_blank_collection()
	for i in CRITTER_COUNT:
		if i < cu.size():
			critter_unlocked[i] = cu[i] == true or i == 0
		if i < cl.size() and cl[i] != null:
			critter_level[i] = maxi(int(cl[i]), 1 if critter_unlocked[i] else 0)
	for i in SHELL_COUNT:
		if i < su.size():
			shell_unlocked[i] = su[i] == true or i == 0
		if i < sl.size() and sl[i] != null:
			shell_level[i] = maxi(int(sl[i]), 1 if shell_unlocked[i] else 0)
	new_critters = []
	for i in g.call("new_critters", []):
		if int(i) >= 0 and int(i) < CRITTER_COUNT:
			new_critters.append(int(i))
	equipped_shell = clampi(int(g.call("equipped_shell", 0)), 0, SHELL_COUNT - 1)
	has_club = bool(g.call("has_club", false))
	club_name = str(g.call("club_name", ""))
	club_is_owner = bool(g.call("club_is_owner", false))
	club_joined_date = str(g.call("club_joined_date", ""))
	club_joined_unix = int(g.call("club_joined_unix", 0))
	club_icon = int(g.call("club_icon", 0))
	club_message = TSFilter.clean(str(g.call("club_message", "")))
	club_chat = g.call("club_chat", [])
	club_leaderboard_key = str(g.call("club_leaderboard_key", ""))
	if has_club and not club_is_owner and not _is_known_club_name(club_name):
		club_is_owner = true
	login_streak_count = int(g.call("login_streak_count", 0))
	login_streak_last_date = str(g.call("login_streak_last_date", ""))
	daily_streak_count = int(g.call("daily_streak_count", 0))
	daily_streak_last_date = str(g.call("daily_streak_last_date", ""))
	daily_completed_date = str(g.call("daily_completed_date", ""))
	login_reward_claimed_date = str(g.call("login_reward_claimed_date", ""))
	daily_reward_claimed_date = str(g.call("daily_reward_claimed_date", ""))
	daily_star_total = int(g.call("daily_star_total", 0))
	daily_star_date = str(g.call("daily_star_date", ""))
	period_star_total = g.call("period_star_total", period_star_total)
	period_star_key = g.call("period_star_key", period_star_key)
	pending_board_prizes = []
	for p in g.call("pending_board_prizes", []):
		if p is Dictionary and p.has("coins"):
			pending_board_prizes.append(p)
	battle_pass_key = str(g.call("battle_pass_key", ""))
	battle_pass_xp = int(g.call("battle_pass_xp", 0))
	battle_pass_purchased = bool(g.call("battle_pass_purchased", false))
	battle_pass_free_claimed = g.call("battle_pass_free_claimed", [])
	battle_pass_paid_claimed = g.call("battle_pass_paid_claimed", [])
	quest_daily_date = str(g.call("quest_daily_date", ""))
	quest_daily_progress = g.call("quest_daily_progress", {})
	quest_daily_done = g.call("quest_daily_done", [])
	quest_daily_claimed = g.call("quest_daily_claimed", [])
	quest_weekly = g.call("quest_weekly", {})
	TSChests.from_save(g.call("chests", {}))
	TSHunt.from_save(g.call("hunt", {}))
	TSSales.from_save(g.call("sales", {}))


static func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	var s := func(key: String, value: Variant) -> void: cfg.set_value("profile", key, value)
	s.call("name", player_name)
	s.call("avatar_index", avatar_index)
	s.call("avatar_critter", avatar_critter)
	s.call("last_level", last_level)
	s.call("coin_count", coin_count)
	s.call("starter_coin_claims", starter_coin_claims)
	s.call("starter_coin_claims_date", starter_coin_claims_date)
	s.call("no_ads", no_ads)
	s.call("is_payer", is_payer)
	s.call("interstitial_owed", interstitial_owed)
	s.call("interstitial_win_count", interstitial_win_count)
	s.call("bomb_count", bomb_count)
	s.call("bombs_unlocked", bombs_unlocked)
	s.call("swap_count", swap_count)
	s.call("swaps_unlocked", swaps_unlocked)
	s.call("swap_tutorial_seen", swap_tutorial_seen)
	s.call("rock_count", rock_count)
	s.call("rocks_unlocked", rocks_unlocked)
	s.call("rocks_tutorial_seen", rocks_tutorial_seen)
	s.call("tutorial_seen", tutorial_seen)
	s.call("bomb_tutorial_seen", bomb_tutorial_seen)
	s.call("club_intro_seen", club_intro_seen)
	s.call("collection_tutorial_seen", collection_tutorial_seen)
	s.call("daily_callout_seen", daily_callout_seen)
	s.call("home_tutorial_seen", home_tutorial_seen)
	s.call("collection_gift_claimed", collection_gift_claimed)
	s.call("music_enabled", music_enabled)
	s.call("sfx_enabled", sfx_enabled)
	s.call("haptics_enabled", haptics_enabled)
	s.call("critter_unlocked", critter_unlocked)
	s.call("critter_level", critter_level)
	s.call("new_critters", new_critters)
	s.call("shell_unlocked", shell_unlocked)
	s.call("shell_level", shell_level)
	s.call("equipped_shell", equipped_shell)
	s.call("has_club", has_club)
	s.call("club_name", club_name)
	s.call("club_is_owner", club_is_owner)
	s.call("club_joined_date", club_joined_date)
	s.call("club_joined_unix", club_joined_unix)
	s.call("club_icon", club_icon)
	s.call("club_message", club_message)
	s.call("club_chat", club_chat)
	s.call("club_leaderboard_key", club_leaderboard_key)
	s.call("login_streak_count", login_streak_count)
	s.call("login_streak_last_date", login_streak_last_date)
	s.call("daily_streak_count", daily_streak_count)
	s.call("daily_streak_last_date", daily_streak_last_date)
	s.call("daily_completed_date", daily_completed_date)
	s.call("login_reward_claimed_date", login_reward_claimed_date)
	s.call("daily_reward_claimed_date", daily_reward_claimed_date)
	s.call("daily_star_total", daily_star_total)
	s.call("daily_star_date", daily_star_date)
	s.call("period_star_total", period_star_total)
	s.call("period_star_key", period_star_key)
	s.call("pending_board_prizes", pending_board_prizes)
	s.call("battle_pass_key", battle_pass_key)
	s.call("battle_pass_xp", battle_pass_xp)
	s.call("battle_pass_purchased", battle_pass_purchased)
	s.call("battle_pass_free_claimed", battle_pass_free_claimed)
	s.call("battle_pass_paid_claimed", battle_pass_paid_claimed)
	s.call("quest_daily_date", quest_daily_date)
	s.call("quest_daily_progress", quest_daily_progress)
	s.call("quest_daily_done", quest_daily_done)
	s.call("quest_daily_claimed", quest_daily_claimed)
	s.call("quest_weekly", quest_weekly)
	s.call("chests", TSChests.to_save())
	s.call("hunt", TSHunt.to_save())
	s.call("sales", TSSales.to_save())
	s.call("save_version", SAVE_VERSION)
	_write_save(cfg)


## Never written over in place: the new save goes to SAVE_TMP first, then the
## old one steps aside to SAVE_BAK and the new one takes its place, so a
## phone killing the app mid-write always leaves one whole save on disk.
const SAVE_TMP := SAVE_PATH + ".tmp"
const SAVE_BAK := SAVE_PATH + ".bak"

static func _write_save(cfg: ConfigFile) -> void:
	if cfg.save_encrypted_pass(SAVE_TMP, SAVE_KEY) != OK:
		return
	var dir := DirAccess.open(SAVE_PATH.get_base_dir())
	if dir == null:
		return
	if dir.file_exists(SAVE_PATH.get_file()):
		if dir.file_exists(SAVE_BAK.get_file()):
			dir.remove(SAVE_BAK.get_file())
		dir.rename(SAVE_PATH.get_file(), SAVE_BAK.get_file())
	dir.rename(SAVE_TMP.get_file(), SAVE_PATH.get_file())


static func _read_save() -> ConfigFile:
	for path in [SAVE_PATH, SAVE_TMP, SAVE_BAK]:
		if not FileAccess.file_exists(path):
			continue
		var cfg := ConfigFile.new()
		if cfg.load_encrypted_pass(path, SAVE_KEY) == OK and cfg.has_section("profile"):
			if path != SAVE_PATH and FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)
			return cfg
	return null
