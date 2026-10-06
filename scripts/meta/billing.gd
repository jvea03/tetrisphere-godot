extends Node

## In-app purchase service (autoload "Billing"), ported from Duckdoku. The
## Shop asks to buy a product id and gets a result signal; the store SDK
## behind it is this script's business.
##
## Backends:
##  - simulated: purchases succeed instantly. Editor, desktop and debug
##    builds without a billing plugin (a release build without one has no
##    store at all, unless tetrisphere/simulate_store is set for testing).
##  - Google Play Billing (Android): the official plugin (v3.x) at
##    res://addons/GodotGooglePlayBilling, used only when its Engine
##    singleton exists on a device build.
##  - StoreKit (iOS): Godot's InAppStore iOS plugin, when its singleton exists.
##
## Product ids are the single source of truth for what must exist in Play
## Console and App Store Connect -- none of them exist yet for Tetrisphere.
## Consumables are consumed on grant; NO_ADS is a non-consumable that is
## acknowledged and restored. Grants happen in exactly one place -- _grant().

signal purchase_result(product_id: String, success: bool)
signal prices_updated() # localized price strings are available via price_of()
signal restore_finished(restored: Array) # product ids that were restored

const NO_ADS := "no_ads_pass"
const PRODUCTS := {
	"coins_5000": {"coins": 5000, "consumable": true},
	"coins_16000": {"coins": 16000, "consumable": true},
	"coins_50000": {"coins": 50000, "consumable": true},
	"coins_120000": {"coins": 120000, "consumable": true},
	"coins_320000": {"coins": 320000, "consumable": true},
	"materials_500": {"materials": 500, "consumable": true},
	"materials_1600": {"materials": 1600, "consumable": true},
	"materials_5000": {"materials": 5000, "consumable": true},
	"materials_12000": {"materials": 12000, "consumable": true},
	"materials_32000": {"materials": 32000, "consumable": true},
	"bundle_starter": {"coins": 10000, "bomb": 4, "consumable": true},
	"bundle_value": {"coins": 50000, "bomb": 11, "materials": 1500, "consumable": true},
	"bundle_mega": {"coins": 150000, "bomb": 26, "materials": 5000, "consumable": true},
	"featured_hatchers_hoard": {"coins": 130000, "bomb": 15, "materials": 2000, "consumable": true},
	NO_ADS: {"no_ads": true, "consumable": false},
	"battle_pass": {"battle_pass": true, "consumable": true}, # one season; consumed so next season can buy again
	# Pop-up sales (TSSales.OFFERS) -- Home only, never in the Shop.
	"popup_hatch_day_2026": {"coins": 130000, "bomb": 30, "consumable": true},
	"popup_starter_sprinkle": {"coins": 25000, "bomb": 9, "consumable": true},
	"popup_flash_sale": {"coins": 75000, "bomb": 15, "consumable": true},
}

const SINGLETON := "GodotGooglePlayBilling"
const IOS_SINGLETON := "InAppStore"
const CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

# BillingClient enum values, mirrored so this file does not reference the
# addon's class at parse time (it may be absent from a desktop checkout).
const RESPONSE_OK := 0
const PRODUCT_TYPE_INAPP := 0
const PURCHASE_STATE_PURCHASED := 1

var simulated: bool = true
var _client: Node = null # BillingClient from the addon (Android)
var _store: Object = null # InAppStore singleton (iOS)
var _connected: bool = false
var _details_known: bool = false # purchase() needs a completed product query first
var _prices: Dictionary = {} # product id -> localized price string
var _pending: String = "" # product id of the purchase in flight
var _restoring: bool = false
var _restored_ios: Array = [] # product ids StoreKit has restored so far this pass


func _ready() -> void:
	if Engine.has_singleton(SINGLETON) and ResourceLoader.exists(CLIENT_SCRIPT):
		var script: GDScript = load(CLIENT_SCRIPT)
		_client = script.new()
		add_child(_client)
		simulated = false
		_client.connected.connect(_on_connected)
		_client.disconnected.connect(func(): _connected = false)
		_client.connect_error.connect(func(code, msg): push_warning("[Billing] connect error %s: %s" % [code, msg]))
		_client.query_product_details_response.connect(_on_product_details)
		_client.query_purchases_response.connect(_on_query_purchases)
		_client.on_purchase_updated.connect(_on_purchase_updated)
		_client.consume_purchase_response.connect(_on_consume_response)
		_client.acknowledge_purchase_response.connect(_on_acknowledge_response)
		_client.start_connection()
	elif Engine.has_singleton(IOS_SINGLETON):
		_store = Engine.get_singleton(IOS_SINGLETON)
		simulated = false
		_store.set_auto_finish_transaction(false) # we finish after the grant is saved
		_store.request_product_info({"product_ids": PackedStringArray(PRODUCTS.keys())})
		set_process(true)
	else:
		# No store plugin. Debug builds simulate one (purchases succeed at once);
		# a release build has no store at all -- purchases fail -- unless the
		# project setting tetrisphere/simulate_store is on, for a test build.
		simulated = OS.is_debug_build() or bool(ProjectSettings.get_setting("tetrisphere/simulate_store", false))
		print("[Billing] simulated backend (no store plugin)" if simulated else "[Billing] no store plugin: purchases unavailable")
	if _store == null:
		set_process(false)


## True when purchases can go through: a store plugin, or the simulation.
func available() -> bool:
	return simulated or _store != null or _client != null


## Localized price for a product ("$4.99", "4,99 €"), or "" until the store
## has answered. The Shop falls back to its own price strings meanwhile.
func price_of(product_id: String) -> String:
	return str(_prices.get(product_id, ""))


## Starts a purchase. Exactly one purchase_result(product_id, success)
## follows, after the grant has been applied on success.
func purchase(product_id: String) -> void:
	if not PRODUCTS.has(product_id) or _pending != "":
		purchase_result.emit(product_id, false)
		return
	if product_id == NO_ADS and TSProfile.no_ads:
		purchase_result.emit(product_id, false)
		return
	if product_id == "battle_pass" and TSProfile.battle_pass_purchased:
		purchase_result.emit(product_id, false)
		return
	_pending = product_id
	if simulated:
		_grant(product_id)
		_finish(product_id, true)
		return
	if _store != null:
		if not _details_known:
			_finish(product_id, false)
			return
		var r: int = _store.purchase({"product_id": product_id})
		if r != OK:
			push_warning("[Billing] StoreKit purchase did not start: %d" % r)
			_finish(product_id, false)
		return
	if not _connected or not _details_known:
		_finish(product_id, false)
		return
	var launched: Dictionary = _client.purchase(product_id)
	if int(launched.get("response_code", -1)) != RESPONSE_OK:
		push_warning("[Billing] purchase flow did not launch: %s" % str(launched.get("debug_message", "")))
		_finish(product_id, false)


## Re-grants non-consumables the account already owns (the No Ads pass).
## Apple requires a visible Restore button; on Android it also covers a
## reinstall. Emits restore_finished with what was restored.
func restore_purchases() -> void:
	if _store != null:
		_restoring = true
		_restored_ios.clear()
		_store.restore_purchases()
		return
	if simulated or not _connected:
		restore_finished.emit([])
		return
	_restoring = true
	_client.query_purchases(PRODUCT_TYPE_INAPP)


# -- grants ----------------------------------------------------------------

func _grant(product_id: String) -> void:
	var p: Dictionary = PRODUCTS[product_id]
	TSProfile.record_purchase()
	if p.get("no_ads", false):
		TSProfile.buy_no_ads_pass()
		return
	if p.get("battle_pass", false):
		TSProfile.purchase_battle_pass()
		return
	TSProfile.coin_count += int(p.get("coins", 0))
	TSProfile.add_materials(int(p.get("materials", 0)))
	if int(p.get("bomb", 0)) > 0:
		TSProfile.bomb_count += int(p["bomb"])
		TSProfile.bombs_unlocked = true
	TSSales.complete(product_id) # a bought pop-up offer ends here, whatever screen is up
	TSProfile.save()


func _finish(product_id: String, success: bool) -> void:
	_pending = ""
	purchase_result.emit(product_id, success)


# -- Google Play Billing callbacks (plugin v3.x dictionary shapes) --------------

func _on_connected() -> void:
	_connected = true
	_client.query_product_details(PackedStringArray(PRODUCTS.keys()), PRODUCT_TYPE_INAPP)
	_client.query_purchases(PRODUCT_TYPE_INAPP) # picks up an owned No Ads pass on reinstall


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("[Billing] product query failed: %s" % str(response.get("debug_message", "")))
		return
	for d in response.get("product_details", []):
		var offers: Variant = d.get("one_time_purchase_offer_details_list", null)
		if offers is Array and not offers.is_empty():
			_prices[str(d["product_id"])] = str(offers[0].get("formatted_price", ""))
	_details_known = true
	prices_updated.emit()


## A finished (or pending -> finished) purchase flow. Grants every PURCHASED
## item we recognise, then consumes or acknowledges it so Play does not
## refund it after three days.
func _on_purchase_updated(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("[Billing] purchase error %s: %s" % [response.get("response_code"), response.get("debug_message", "")])
		if _pending != "":
			_finish(_pending, false)
		return
	var settled := false
	for pur in response.get("purchases", []):
		if int(pur.get("purchase_state", 0)) != PURCHASE_STATE_PURCHASED:
			continue # PENDING: Play sends another update when it completes
		for product_id in pur.get("product_ids", []):
			if not PRODUCTS.has(product_id):
				continue
			_grant(product_id)
			_settle(pur, product_id)
			if product_id == _pending:
				settled = true
	if settled:
		_finish(_pending, true)


func _on_query_purchases(response: Dictionary) -> void:
	var restored: Array = []
	if int(response.get("response_code", -1)) == RESPONSE_OK:
		for pur in response.get("purchases", []):
			if int(pur.get("purchase_state", 0)) != PURCHASE_STATE_PURCHASED:
				continue
			for product_id in pur.get("product_ids", []):
				if not PRODUCTS.has(product_id):
					continue
				if PRODUCTS[product_id]["consumable"]:
					# An unconsumed consumable means the app died between
					# purchase and consume: grant it now and consume.
					_grant(product_id)
					_settle(pur, product_id)
				elif product_id == NO_ADS:
					if not TSProfile.no_ads:
						_grant(product_id)
						restored.append(product_id)
					_settle(pur, product_id)
	if _restoring:
		_restoring = false
		restore_finished.emit(restored)


func _settle(pur: Dictionary, product_id: String) -> void:
	if PRODUCTS[product_id]["consumable"]:
		_client.consume_purchase(str(pur["purchase_token"]))
	elif not bool(pur.get("is_acknowledged", false)):
		_client.acknowledge_purchase(str(pur["purchase_token"]))


func _on_consume_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("[Billing] consume failed: %s" % str(response.get("debug_message", "")))


func _on_acknowledge_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		push_warning("[Billing] acknowledge failed: %s" % str(response.get("debug_message", "")))


# -- StoreKit (godot-ios-plugins InAppStore, Godot 4 branch) ----------------------
## The plugin does not use signals: it queues dictionaries that we pop each
## frame. Shapes: {"type": "product_info", "result": "ok", "ids": [...],
## "localized_prices": [...]}, {"type": "purchase", "result": "ok"|"error"|
## "progress"|"unhandled", "product_id": ...}, {"type": "restore",
## "result": "ok", "product_id": ...} per item then {"type": "restore",
## "result": "completed"} (or "error").

func _process(_delta: float) -> void:
	if _store == null:
		return
	while _store.get_pending_event_count() > 0:
		_on_store_event(_store.pop_pending_event())


func _on_store_event(ev: Dictionary) -> void:
	var kind := str(ev.get("type", ""))
	var result := str(ev.get("result", ""))
	match kind:
		"product_info":
			if result != "ok":
				push_warning("[Billing] StoreKit product query failed: %s" % str(ev.get("error", "")))
				return
			var ids: Array = ev.get("ids", [])
			var prices: Array = ev.get("localized_prices", [])
			for i in mini(ids.size(), prices.size()):
				_prices[str(ids[i])] = str(prices[i])
			_details_known = true
			prices_updated.emit()
		"purchase":
			var product_id := str(ev.get("product_id", ""))
			match result:
				"ok":
					if PRODUCTS.has(product_id):
						_grant(product_id)
						_store.finish_transaction(product_id)
					if product_id == _pending:
						_finish(product_id, true)
				"error", "unhandled":
					if product_id != "":
						_store.finish_transaction(product_id)
					if _pending != "":
						_finish(_pending, false)
				_:
					pass # "progress": StoreKit is still working
		"restore":
			match result:
				"ok":
					# Only non-consumables come back. Re-grant the No Ads pass if this
					# device does not have it; finish the transaction either way.
					var product_id := str(ev.get("product_id", ""))
					if product_id == NO_ADS and not TSProfile.no_ads:
						_grant(product_id)
						_restored_ios.append(product_id)
					if product_id != "":
						_store.finish_transaction(product_id)
				"completed", "error":
					if _restoring:
						_restoring = false
						restore_finished.emit(_restored_ios.duplicate())
