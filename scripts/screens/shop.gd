extends TSScreen

## The Shop (Duckdoku's ShopScreen), in colour-coded sections that chips along
## the top jump to: the weekly featured sale, the No Ads pass, three bundles,
## coin packs and building-materials packs -- each led by a free daily pack
## (one free claim, then two more for an ad each, no ad with No Ads), the rest
## showing how much more each gives for the money, the popular one and the
## best value flagged -- and booster packs bought with coins. Every
## real-money item goes through Billing, simulated until the store plugins
## and product ids exist.

const FEATURED_SALES := [
	{"name": "Hatcher's Hoard", "coins": 130000, "bomb": 15, "materials": 2000, "price": "$4.99", "orig_price": "$9.99", "product_id": "featured_hatchers_hoard"},
]
const BUNDLES := [
	{"name": "Starter", "coins": 10000, "bomb": 4, "price": "$0.99", "product_id": "bundle_starter", "chest": "common"},
	{"name": "Value", "coins": 50000, "bomb": 11, "materials": 1500, "price": "$2.99", "product_id": "bundle_value", "chest": "rare"},
	{"name": "Mega", "coins": 150000, "bomb": 26, "materials": 5000, "price": "$6.99", "product_id": "bundle_mega", "chest": "legendary"},
]
const COIN_PACKS := [
	{"coins": 1000, "price": "Free", "starter": true},
	{"coins": 5000, "price": "$0.99", "product_id": "coins_5000"},
	{"coins": 16000, "price": "$2.99", "product_id": "coins_16000"},
	{"coins": 50000, "price": "$6.99", "product_id": "coins_50000"},
	{"coins": 120000, "price": "$12.99", "product_id": "coins_120000"},
	{"coins": 320000, "price": "$29.99", "product_id": "coins_320000"},
]
## Building materials for the camp and the ship, packed like the coins: a free
## daily pack, then five for real money.
const MATERIAL_PACKS := [
	{"materials": 100, "price": "Free", "starter": true},
	{"materials": 500, "price": "$0.99", "product_id": "materials_500"},
	{"materials": 1600, "price": "$2.99", "product_id": "materials_1600"},
	{"materials": 5000, "price": "$6.99", "product_id": "materials_5000"},
	{"materials": 12000, "price": "$12.99", "product_id": "materials_12000"},
	{"materials": 32000, "price": "$29.99", "product_id": "materials_32000"},
]
const STARTER_PACK_LIMIT := 3 # per day: 1 free + 2 ads
const NO_ADS_PRICE := "$4.99"

var _list: VBoxContainer
var _scroll: ScrollContainer
var _chips: HBoxContainer
var _sections := {}   # section id -> its heading, for the chips
var _last_coins := -1
var _last_btn: Control
var _ad: Dictionary
var _ad_pack: Dictionary
var _ad_watching := false


func tab_id() -> String:
	return "shop"


func build() -> void:
	add_header("Shop", false)
	# Chips that jump the list to each section, the free one flagged while a
	# free claim is waiting.
	_chips = TSUI.hbox(8)
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_chips)
	_list = TSUI.vbox(16)
	_scroll = TSUI.scroll(_list)
	content.add_child(_scroll)
	_ad = TSUI.dialog(self, 560)
	Billing.purchase_result.connect(_on_purchase_result)
	Billing.prices_updated.connect(_refresh)
	_refresh()


## The sections, top to bottom: [id, title, colour, icon].
const SECTIONS := [
	["deals", "Featured Sale", Color(1.0, 0.54, 0.58), "tag"],
	["noads", "Remove Ads", Color(0.74, 0.62, 0.98), "noads"],
	["bundles", "Bundles", Color(0.56, 0.74, 1.0), "chest"],
	["coins", "Coins", Color(1.0, 0.76, 0.3), "coin"],
	["materials", "Materials", Color(0.86, 0.64, 0.44), "materials"],
	["boosters", "Boosters", Color(1.0, 0.6, 0.72), "bomb"],
]
const CHIPS := [["deals", "Deals"], ["coins", "Coins"], ["materials", "Materials"], ["boosters", "Boosters"]]


func _refresh() -> void:
	var now := TSProfile.coin_count
	if _last_coins >= 0 and now > _last_coins:
		var from := _last_btn.get_global_rect() if is_instance_valid(_last_btn) else wallet.get_global_rect()
		wallet.receive(from, _last_coins, now)
	elif _last_coins >= 0 and now < _last_coins:
		wallet.spend(_last_coins, now)
	else:
		wallet.sync()
	_last_coins = now
	for c in _list.get_children():
		c.queue_free()
	_sections.clear()
	for sec in SECTIONS:
		var id: String = sec[0]
		var trailing := ""
		if id == "deals":
			trailing = "%s left" % TSUI.fmt_duration(TSProfile.seconds_until_weekly_reset())
		_sections[id] = _header(sec[1], sec[2], sec[3], trailing, id)
		_list.add_child(_sections[id])
		match id:
			"deals":
				var sale: Dictionary = FEATURED_SALES[(int(Time.get_unix_time_from_system() + 3 * 86400) / (7 * 86400)) % FEATURED_SALES.size()]
				_list.add_child(_featured_card(sale))
			"noads":
				_list.add_child(_no_ads_card())
			"bundles":
				var bundles := TSUI.hbox(12)
				for b in BUNDLES:
					bundles.add_child(_bundle_card(b))
				_list.add_child(bundles)
			"coins":
				_pack_rows(COIN_PACKS, "coins")
			"materials":
				_pack_rows(MATERIAL_PACKS, "materials")
			"boosters":
				for bid in TSProfile.BOOSTERS:
					_list.add_child(_booster_card(bid))
	_list.add_child(TSUI.spacer(12))
	_build_chips()
	TSUI.juice(_list)


func _build_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	for chip in CHIPS:
		var id: String = chip[0]
		var b := Button.new()
		b.text = chip[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", TSUI.INK)
		b.add_theme_color_override("font_pressed_color", TSUI.INK)
		b.add_theme_color_override("font_hover_color", TSUI.INK)
		var colour: Color = Color.WHITE
		for sec in SECTIONS:
			if sec[0] == id:
				colour = (sec[2] as Color).lerp(Color.WHITE, 0.45)
		var face := TSUI.sb(colour, 99, 2, 3, 14)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, face)
		b.pressed.connect(_jump_to.bind(id))
		_chips.add_child(b)
		if _free_waiting(id):
			TSUI.dot(b, 18.0).visible = true
	TSUI.juice(_chips)


## Glides the list so a section's heading sits at the top.
func _jump_to(id: String) -> void:
	var head: Control = _sections.get(id)
	if head == null:
		return
	TSSfx.play("tap")
	var to := mini(int(head.position.y), int(_scroll.get_v_scroll_bar().max_value - _scroll.size.y))
	create_tween().tween_property(_scroll, "scroll_vertical", maxi(0, to), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## True while a section's daily pack (coins or materials) still has its
## free claim today.
func _free_waiting(id: String) -> bool:
	TSProfile.roll_starter_claims()
	if id == "coins":
		return TSProfile.starter_coin_claims == 0
	if id == "materials":
		return TSProfile.starter_material_claims == 0
	return false


## A section's heading: its icon, its name in white, and on the right what
## matters there (the sale's time left, the materials you have).
func _header(text: String, color: Color, icon: String, trailing: String, id: String) -> Control:
	var bar := TSUI.card(color, 20, 10, 3)
	var row := TSUI.hbox(8)
	bar.add_child(row)
	row.add_child(TSIcon.make(icon, 38))
	row.add_child(TSUI.expand(TSUI.outlined(TSUI.label(text, 30, Color.WHITE), TSUI.INK, 8)))
	if id == "materials":
		row.add_child(TSIcon.make("materials", 34))
		row.add_child(TSUI.outlined(TSUI.label(TSProfile.fmt_coins(TSProfile.materials), 24, Color.WHITE), TSUI.INK, 6))
	if trailing != "":
		row.add_child(TSIcon.make("clock", 32))
		row.add_child(TSUI.outlined(TSUI.label(trailing, 22, Color.WHITE), TSUI.INK, 6))
	return bar


## A section's packs three to a row -- its free daily pack first, as it
## always was -- the last row's cards widening to fill it.
func _pack_rows(packs: Array, kind: String) -> void:
	var base := _per_dollar(packs[1], kind)   # the smallest paid pack
	for start in range(0, packs.size(), 3):
		var row := TSUI.hbox(12)
		for p in packs.slice(start, start + 3):
			row.add_child(_free_card(p) if p.get("starter", false) else _pack_card(p, kind, base))
		_list.add_child(row)


## What a pack gives per dollar at its listed price, for the "+% more" tags.
static func _per_dollar(p: Dictionary, kind: String) -> float:
	var dollars := str(p["price"]).trim_prefix("$").to_float()
	return float(p[kind]) / dollars if dollars > 0.0 else 0.0


func _price(item: Dictionary) -> String:
	var live := Billing.price_of(str(item.get("product_id", "")))
	return live if live != "" else str(item["price"])


func _buy_button(text: String, on_press: Callable) -> Button:
	var b := TSUI.button(text, TSUI.GREEN, 24, Vector2(0, 62), 5)
	b.pressed.connect(func():
		_last_btn = b
		on_press.call())
	return b


## The week's sale: its haul piled up -- chest, bomb and materials -- under a
## percent-off sticker, what's in it as a list, and the old price struck
## through beside the new.
func _featured_card(item: Dictionary) -> Control:
	var card := TSUI.card(Color(1.0, 0.9, 0.78), 28, 14, 4)
	var row := TSUI.hbox(10)
	card.add_child(row)
	var art := Control.new()
	art.custom_minimum_size = Vector2(220, 210)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pieces := [["chest", 160, Vector2(0, 34), "legendary"], ["materials", 84, Vector2(4, 126), ""], ["bomb", 100, Vector2(118, 104), ""]]
	for pc in pieces:
		var ic := TSIcon.make(pc[0], pc[1], 0, pc[3])
		ic.position = pc[2]
		ic.size = Vector2(pc[1], pc[1])
		art.add_child(ic)
	var dollars := str(item["price"]).trim_prefix("$").to_float()
	var was := str(item["orig_price"]).trim_prefix("$").to_float()
	if was > dollars and dollars > 0.0:
		var off := TSUI.pill("%d%% OFF" % roundi((1.0 - dollars / was) * 100.0), TSUI.RED_DOT, 22, Color.WHITE)
		off.position = Vector2(108, 8)
		off.rotation = 0.18
		art.add_child(off)
	row.add_child(art)
	var v := TSUI.vbox(6)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	v.add_child(TSUI.title(item["name"], 34))
	var lines := [["coin", "%s coins" % TSProfile.fmt_coins(int(item["coins"]))], ["bomb", "%d bombs" % int(item["bomb"])]]
	if item.has("materials"):
		lines.append(["materials", "%s materials" % TSProfile.fmt_coins(int(item["materials"]))])
	for l in lines:
		var line := TSUI.hbox(6)
		line.add_child(TSIcon.make(l[0], 28))
		line.add_child(TSUI.label(l[1], 22))
		v.add_child(line)
	var buy_row := TSUI.hbox(8)
	var struck := RichTextLabel.new()
	struck.bbcode_enabled = true
	struck.fit_content = true
	struck.autowrap_mode = TextServer.AUTOWRAP_OFF
	struck.custom_minimum_size = Vector2(80, 0)
	struck.add_theme_font_override("normal_font", TSToon.hand_font())
	struck.add_theme_font_size_override("normal_font_size", 22)
	struck.add_theme_color_override("default_color", TSUI.MUTED)
	struck.text = "[s]%s[/s]" % item["orig_price"]
	struck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(struck)
	buy_row.add_child(TSUI.expand(_buy_button(_price(item), func(): Billing.purchase(item["product_id"]))))
	v.add_child(buy_row)
	return card


func _no_ads_card() -> Control:
	var card := TSUI.card(TSUI.CARD, 26, 14, 3)
	var row := TSUI.hbox(14)
	card.add_child(row)
	row.add_child(TSIcon.make("noads", 110))
	var v := TSUI.vbox(4)
	TSUI.expand(v)
	row.add_child(v)
	v.add_child(TSUI.label("No Ads Pass", 28))
	var perks := ["Never watch an ad again", "+%d%% on every coin you earn" % TSProfile.no_ads_coin_bonus_percent(), "Chests unlock %d%% faster" % TSChests.TIMER_DISCOUNT_PERCENT]
	if not TSProfile.no_ads:
		perks.push_front("%s coins" % TSProfile.fmt_coins(TSProfile.NO_ADS_PASS_COINS))
	for perk in perks:
		var line := TSUI.hbox(6)
		line.add_child(TSIcon.make("check", 24))
		line.add_child(TSUI.label(perk, 19))
		v.add_child(line)
	if TSProfile.no_ads:
		row.add_child(TSUI.label("Active", 26, Color(0.3, 0.64, 0.3)))
	else:
		var nb := _buy_button(_price({"product_id": Billing.NO_ADS, "price": NO_ADS_PRICE}), func(): Billing.purchase(Billing.NO_ADS))
		nb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nb)
	return card


## A bundle on a card tinted like its chest, the biggest flagged best value:
## its chest, then what's in it, each with its own icon.
func _bundle_card(b: Dictionary) -> Control:
	var tint: Color = {"common": TSUI.PEACH, "rare": TSUI.SKY, "legendary": TSUI.LILAC}.get(b["chest"], TSUI.CARD)
	var card := TSUI.card(tint.lerp(Color.WHITE, 0.72), 24, 10, 3)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(5)
	card.add_child(v)
	v.add_child(_ribbon("BEST VALUE" if b == BUNDLES[-1] else "", TSUI.GOLD_DARK))
	v.add_child(TSUI.label("%s Bundle" % b["name"], 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var art := TSIcon.make("chest", 92, 0, b["chest"])
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var lines := [["coin", TSProfile.fmt_coins(int(b["coins"]))], ["bomb", "%d" % int(b["bomb"])]]
	if b.has("materials"):
		lines.append(["materials", TSProfile.fmt_coins(int(b["materials"]))])
	for l in lines:
		var line := TSUI.hbox(4)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(TSIcon.make(l[0], 26))
		line.add_child(TSUI.label(l[1], 20))
		v.add_child(line)
	v.add_child(TSUI.spacer(0, true))   # every bundle's button along the bottom
	v.add_child(_buy_button(_price(b), func(): Billing.purchase(b["product_id"])))
	return card


## A five-pack of one booster ("bomb", "swap" -- the Any Piece -- or "rocks") for coins. Buying
## one before its unlock level unlocks it early.
func _booster_card(id: String) -> Control:
	var card := TSUI.card(TSUI.CARD, 26, 14, 3)
	var row := TSUI.hbox(14)
	card.add_child(row)
	row.add_child(TSIcon.make(id, 90))
	var v := TSUI.vbox(2)
	TSUI.expand(v)
	row.add_child(v)
	v.add_child(TSUI.label("%s x%d" % [TSProfile.BOOSTER_NAMES[id][0], TSProfile.BOMB_PACK_AMOUNT], 28))
	v.add_child(TSUI.label("You have %d" % TSProfile.booster_count(id), 20, TSUI.MUTED))
	var cost := TSProfile.booster_pack_cost(id)
	var b := _buy_button("%s coins" % TSProfile.fmt_coins(cost), func():
		if TSProfile.coin_count < cost:
			return
		TSProfile.coin_count -= cost
		TSProfile.add_boosters(id, TSProfile.BOMB_PACK_AMOUNT)
		TSProfile.save()
		_celebrate()
		_refresh())
	b.custom_minimum_size.x = 200
	b.disabled = TSProfile.coin_count < cost
	row.add_child(b)
	return card


## A pack's picture (TSIcon's coin_pack or material_pack, by its size: 0 the
## free one, 5 the biggest), centred in its card.
func _pack_art(icon: String, tier: int) -> Control:
	var art := TSIcon.make(icon, 118, tier)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return art


## A ribbon over a card's art ("MOST POPULAR", "BEST VALUE"), or a blank of
## the same height so a row's cards line up.
func _ribbon(text: String, colour: Color) -> Control:
	if text == "":
		return TSUI.spacer(26)
	var pill := TSUI.pill(text, colour, 15, Color.WHITE)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pill


## A daily pack, free: on mint, its heap, its amount large, what's left today
## and a pink Claim (or Watch Ad) button.
func _free_card(p: Dictionary) -> Control:
	var mats := p.has("materials")
	var card := TSUI.card(Color(0.86, 0.97, 0.88), 24, 10, 4)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(4)
	card.add_child(v)
	TSProfile.roll_starter_claims()
	var left := _starter_left(mats)
	var claims := TSProfile.starter_material_claims if mats else TSProfile.starter_coin_claims
	v.add_child(_ribbon("FREE" if claims == 0 else "", TSUI.RED_DOT))
	v.add_child(_pack_art("material_pack" if mats else "coin_pack", 0))
	v.add_child(TSUI.label(TSProfile.fmt_coins(int(p["materials" if mats else "coins"])), 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(TSUI.label("materials" if mats else "coins", 18, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(TSUI.label("Back tomorrow" if left <= 0 else ("Free now, %d more later" % (left - 1) if claims == 0 else ("%d more today" % left if TSProfile.no_ads else "%d ad%s left today" % [left, "" if left == 1 else "s"])), 16, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(TSUI.spacer(0, true))
	var b := TSUI.button(_starter_button_text(claims, left), TSUI.PINK if left > 0 else TSUI.GREY, 24, Vector2(0, 62), 5)
	b.pressed.connect(func():
		_last_btn = b
		_on_starter(p))
	b.disabled = left <= 0
	v.add_child(b)
	return card


## A paid coins or materials pack: its heap, its amount, how much more it
## gives for the money than the smallest pack, and its price. The middle
## pack is the popular one; the biggest, the best value.
func _pack_card(p: Dictionary, kind: String, base: float) -> Control:
	var card := TSUI.card(TSUI.CARD, 24, 10, 3)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(4)
	card.add_child(v)
	var amount := int(p[kind])
	var packs: Array = COIN_PACKS if kind == "coins" else MATERIAL_PACKS
	var at := packs.find(p)
	var ribbon := ""
	if at == 3:
		ribbon = "MOST POPULAR"
	elif at == packs.size() - 1:
		ribbon = "BEST VALUE"
	v.add_child(_ribbon(ribbon, TSUI.CORAL if at == 3 else TSUI.GOLD_DARK))
	v.add_child(_pack_art("coin_pack" if kind == "coins" else "material_pack", at))
	v.add_child(TSUI.label(TSProfile.fmt_coins(amount), 28, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var more := roundi((_per_dollar(p, kind) / base - 1.0) * 100.0) if base > 0.0 else 0
	v.add_child(TSUI.label("+%d%% more" % more if more >= 5 else kind, 17, TSFX.COL_GAIN if more >= 5 else TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(TSUI.spacer(0, true))
	v.add_child(_buy_button(_price(p), func(): Billing.purchase(p["product_id"])))
	return card


## Claims of a daily pack left today. Everyone gets the ad claims -- they're
## asked for, never pushed, so payers too -- and the No Ads pass skips the ads.
func _starter_left(materials := false) -> int:
	TSProfile.roll_starter_claims()
	return maxi(STARTER_PACK_LIMIT - (TSProfile.starter_material_claims if materials else TSProfile.starter_coin_claims), 0)


## A daily pack's button: Free first, then Watch Ad (or Claim, with No Ads).
static func _starter_button_text(claims: int, left: int) -> String:
	if claims == 0:
		return "Free"
	if left <= 0:
		return "Claimed"
	return "Claim" if TSProfile.no_ads else "Watch Ad"


## A daily pack (coins or materials): the first claim is free, the rest an ad
## each (no ad with the No Ads pass).
func _on_starter(p: Dictionary) -> void:
	var mats := p.has("materials")
	if _starter_left(mats) <= 0:
		return
	if (TSProfile.starter_material_claims if mats else TSProfile.starter_coin_claims) == 0 or TSProfile.no_ads:
		_grant_starter(p)
		_celebrate()
		_refresh()
		return
	_open_ad(p)


## One claim of a daily pack, counted against today's.
func _grant_starter(p: Dictionary) -> void:
	if p.has("materials"):
		TSProfile.starter_material_claims += 1
		TSProfile.add_materials(int(p["materials"]))
	else:
		TSProfile.starter_coin_claims += 1
		TSProfile.coin_count += int(p["coins"])
	TSProfile.save()


## "1,000 coins" or "100 materials": what a daily pack gives.
static func _pack_text(p: Dictionary) -> String:
	if p.has("materials"):
		return "%s materials" % TSProfile.fmt_coins(int(p["materials"]))
	return "%s coins" % TSProfile.fmt_coins(int(p["coins"]))


func _celebrate() -> void:
	TSSfx.play("upgrade")
	if is_instance_valid(_last_btn) and TSProfile.coin_count <= _last_coins:
		TSFX.sparkle_burst(self, _last_btn)


func _on_purchase_result(_id: String, success: bool) -> void:
	if not is_inside_tree():
		return
	if success:
		_celebrate()
	elif not Billing.available() and is_instance_valid(_last_btn):
		TSUI.note(self, _last_btn, "The store isn't available yet -- check back soon!")
	_refresh()


# -- the daily pack's ad claims -------------------------------------------------------

func _open_ad(pack: Dictionary) -> void:
	_ad_pack = pack
	_ad_watching = false
	var box: VBoxContainer = _ad["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Free Materials" if pack.has("materials") else "Free Coins", 44))
	var ic := TSIcon.make("ad", 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var status := TSUI.wrap(TSUI.label("Watch a short ad to earn %s." % _pack_text(pack), 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(status)
	var progress := TSUI.bar(TSUI.SKY, 26)
	progress.visible = false
	box.add_child(progress)
	var watch := TSUI.button("Watch Ad", TSUI.SKY, 28)
	var close := TSUI.button("Not now", TSUI.GREY, 24, Vector2(0, 60))
	watch.pressed.connect(func():
		if _ad_watching or Ads.is_busy():
			return
		_ad_watching = true
		watch.visible = false
		close.visible = false
		progress.visible = Ads.simulated
		status.text = "Ad playing..." if Ads.simulated else "Loading ad..."
		if Ads.simulated:
			create_tween().tween_property(progress, "value", 100.0, Ads.SIMULATED_SECONDS)
		Ads.rewarded_result.connect(func(earned: bool):
			if not is_inside_tree():
				return
			_ad_watching = false
			progress.visible = false
			close.visible = true
			if not earned:
				watch.visible = true
				status.text = "The ad didn't finish -- nothing this time."
				return
			_grant_starter(_ad_pack)
			status.text = "You earned %s!" % _pack_text(_ad_pack)
			close.text = "Done"
			_refresh(), CONNECT_ONE_SHOT)
		Ads.show_rewarded())
	close.pressed.connect(func():
		if not _ad_watching:
			TSUI.conceal(_ad["root"]))
	box.add_child(watch)
	box.add_child(close)
	TSUI.juice(box)
	TSUI.reveal(_ad["root"], _ad["panel"])


func on_back_requested() -> bool:
	if _ad["root"].visible:
		if not _ad_watching:
			TSUI.conceal(_ad["root"])
		return true
	return false
