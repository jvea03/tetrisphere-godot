extends TSScreen

## The Shop (Duckdoku's ShopScreen): a featured sale that rotates weekly, the
## No Ads pass, three bundles, booster packs bought with coins, and coin packs --
## the first of which is a free daily pack (one free claim, then two for an ad
## each). Every real-money item goes through Billing, simulated until the
## store plugins and product ids exist.

const FEATURED_SALES := [
	{"name": "Hatcher's Hoard", "coins": 130000, "bomb": 15, "price": "$4.99", "orig_price": "$9.99", "product_id": "featured_hatchers_hoard"},
]
const BUNDLES := [
	{"name": "Starter", "coins": 10000, "bomb": 4, "price": "$0.99", "product_id": "bundle_starter", "chest": "common"},
	{"name": "Value", "coins": 50000, "bomb": 11, "price": "$2.99", "product_id": "bundle_value", "chest": "rare"},
	{"name": "Mega", "coins": 150000, "bomb": 26, "price": "$6.99", "product_id": "bundle_mega", "chest": "legendary"},
]
const COIN_PACKS := [
	{"coins": 1000, "price": "Free", "starter": true},
	{"coins": 5000, "price": "$0.99", "product_id": "coins_5000"},
	{"coins": 16000, "price": "$2.99", "product_id": "coins_16000"},
	{"coins": 50000, "price": "$6.99", "product_id": "coins_50000"},
	{"coins": 120000, "price": "$12.99", "product_id": "coins_120000"},
	{"coins": 320000, "price": "$29.99", "product_id": "coins_320000"},
]
const STARTER_PACK_LIMIT := 3 # per day: 1 free + 2 ads
const NO_ADS_PRICE := "$4.99"

var _list: VBoxContainer
var _last_coins := -1
var _last_btn: Control
var _ad: Dictionary
var _ad_pack: Dictionary
var _ad_watching := false


func tab_id() -> String:
	return "shop"


func build() -> void:
	add_header("Shop", false)
	_list = TSUI.vbox(18)
	content.add_child(TSUI.scroll(_list))
	_ad = TSUI.dialog(self, 560)
	Billing.purchase_result.connect(_on_purchase_result)
	Billing.prices_updated.connect(_refresh)
	_refresh()


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
	var sale: Dictionary = FEATURED_SALES[(int(Time.get_unix_time_from_system() + 3 * 86400) / (7 * 86400)) % FEATURED_SALES.size()]
	_list.add_child(_header("Featured Sale", TSUI.CORAL, "%s left" % TSUI.fmt_duration(TSProfile.seconds_until_weekly_reset())))
	_list.add_child(_featured_card(sale))
	_list.add_child(_header("Remove Ads", TSUI.SKY, ""))
	_list.add_child(_no_ads_card())
	_list.add_child(_header("Bundles", TSUI.SKY, ""))
	var bundles := TSUI.hbox(12)
	for b in BUNDLES:
		bundles.add_child(_bundle_card(b))
	_list.add_child(bundles)
	_list.add_child(_header("Boosters", TSUI.SKY, ""))
	for id in TSProfile.BOOSTERS:
		_list.add_child(_booster_card(id))
	_list.add_child(_header("Coins", TSUI.SKY, ""))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for p in COIN_PACKS:
		grid.add_child(_coin_card(p))
	_list.add_child(grid)
	_list.add_child(TSUI.spacer(12))
	TSUI.juice(_list)


func _header(text: String, color: Color, trailing: String) -> Control:
	var bar := TSUI.card(color, 20, 10, 3)
	var row := TSUI.hbox(8)
	bar.add_child(row)
	row.add_child(TSUI.expand(TSUI.outlined(TSUI.label(text, 30, Color.WHITE), TSUI.INK, 8)))
	if trailing != "":
		row.add_child(TSIcon.make("clock", 32))
		row.add_child(TSUI.outlined(TSUI.label(trailing, 22, Color.WHITE), TSUI.INK, 6))
	return bar


func _price(item: Dictionary) -> String:
	var live := Billing.price_of(str(item.get("product_id", "")))
	return live if live != "" else str(item["price"])


func _buy_button(text: String, on_press: Callable) -> Button:
	var b := TSUI.button(text, TSUI.GREEN, 24, Vector2(0, 62), 5)
	b.pressed.connect(func():
		_last_btn = b
		on_press.call())
	return b


func _featured_card(item: Dictionary) -> Control:
	var card := TSUI.card(Color(1.0, 0.9, 0.78), 28, 14, 4)
	var row := TSUI.hbox(14)
	card.add_child(row)
	var art := Control.new()
	art.custom_minimum_size = Vector2(230, 200)
	var chest := TSIcon.make("chest", 170, 0, "legendary")
	chest.position = Vector2(0, 20)
	chest.size = Vector2(170, 170)
	art.add_child(chest)
	var bomb := TSIcon.make("bomb", 110)
	bomb.position = Vector2(120, 80)
	bomb.size = Vector2(110, 110)
	art.add_child(bomb)
	row.add_child(art)
	var v := TSUI.vbox(8)
	TSUI.expand(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	v.add_child(TSUI.title(item["name"], 34))
	v.add_child(TSUI.wrap(TSUI.label("%s coins + %d bombs!" % [TSProfile.fmt_coins(int(item["coins"])), int(item["bomb"])], 22)))
	var buy_row := TSUI.hbox(8)
	var was := RichTextLabel.new()
	was.bbcode_enabled = true
	was.fit_content = true
	was.autowrap_mode = TextServer.AUTOWRAP_OFF
	was.custom_minimum_size = Vector2(80, 0)
	was.add_theme_font_override("normal_font", TSToon.hand_font())
	was.add_theme_font_size_override("normal_font_size", 22)
	was.add_theme_color_override("default_color", TSUI.MUTED)
	was.text = "[s]%s[/s]" % item["orig_price"]
	was.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(was)
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


func _bundle_card(b: Dictionary) -> Control:
	var card := TSUI.card(TSUI.CARD, 24, 10, 3)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(6)
	card.add_child(v)
	v.add_child(TSUI.label("%s Bundle" % b["name"], 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var art := TSIcon.make("chest", 96, 0, b["chest"])
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	for text in ["%s coins" % TSProfile.fmt_coins(int(b["coins"])), "%d bombs" % int(b["bomb"])]:
		var line := TSUI.hbox(4)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(TSIcon.make("check", 20))
		line.add_child(TSUI.label(text, 18))
		v.add_child(line)
	v.add_child(_buy_button(_price(b), func(): Billing.purchase(b["product_id"])))
	return card


## A five-pack of one booster ("bomb", "swap" or "rocks") for coins. Buying
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


func _coin_card(p: Dictionary) -> Control:
	var card := TSUI.card(TSUI.CARD, 24, 10, 3)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := TSUI.vbox(4)
	card.add_child(v)
	var coins := int(p["coins"])
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 90)
	var n := clampi(int(log(float(coins) / 1000.0) / log(2.5)) + 1, 1, 5)
	for k in n:
		var c := TSIcon.make("coin", 56)
		c.position = Vector2(40 + (k % 3) * 22 - (n - 1) * 6, 30 - (k / 3) * 22 - k * 3)
		c.size = Vector2(56, 56)
		stack.add_child(c)
	v.add_child(stack)
	v.add_child(TSUI.label("%s coins" % TSProfile.fmt_coins(coins), 22, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if p.get("starter", false):
		TSProfile.roll_starter_claims()
		var left := _starter_left()
		var claims := TSProfile.starter_coin_claims
		v.add_child(TSUI.label("Back tomorrow" if left <= 0 else ("Free today" if claims == 0 else "%d ad%s left" % [left, "" if left == 1 else "s"]), 16, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var b := _buy_button("Free" if claims == 0 else ("Watch Ad" if left > 0 else "Claimed"), _on_starter.bind(p))
		b.disabled = left <= 0
		v.add_child(b)
		return card
	v.add_child(_buy_button(_price(p), func(): Billing.purchase(p["product_id"])))
	return card


## Payers are never shown ads, so for them the daily pack is its one free claim.
func _starter_left() -> int:
	TSProfile.roll_starter_claims()
	var limit := 1 if TSProfile.is_payer else STARTER_PACK_LIMIT
	return maxi(limit - TSProfile.starter_coin_claims, 0)


func _on_starter(p: Dictionary) -> void:
	if _starter_left() <= 0:
		return
	if TSProfile.starter_coin_claims == 0:
		TSProfile.starter_coin_claims = 1
		TSProfile.coin_count += int(p["coins"])
		TSProfile.save()
		_celebrate()
		_refresh()
		return
	_open_ad(p)


func _celebrate() -> void:
	TSSfx.play("upgrade")
	if is_instance_valid(_last_btn) and TSProfile.coin_count <= _last_coins:
		TSFX.sparkle_burst(self, _last_btn)


func _on_purchase_result(_id: String, success: bool) -> void:
	if not is_inside_tree():
		return
	if success:
		_celebrate()
	_refresh()


# -- the daily pack's ad claims -------------------------------------------------------

func _open_ad(pack: Dictionary) -> void:
	_ad_pack = pack
	_ad_watching = false
	var box: VBoxContainer = _ad["box"]
	for c in box.get_children():
		c.queue_free()
	box.add_child(TSUI.title("Free Coins", 44))
	var ic := TSIcon.make("ad", 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var status := TSUI.wrap(TSUI.label("Watch a short ad to earn %s coins." % TSProfile.fmt_coins(int(pack["coins"])), 24, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
				status.text = "The ad didn't finish -- no coins this time."
				return
			TSProfile.starter_coin_claims += 1
			TSProfile.coin_count += int(_ad_pack["coins"])
			TSProfile.save()
			status.text = "You earned %s coins!" % TSProfile.fmt_coins(int(_ad_pack["coins"]))
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
