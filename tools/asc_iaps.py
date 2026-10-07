#!/usr/bin/env python3
"""Creates Egg Escape's in-app purchases in App Store Connect from the table
below (ids and prices match scripts/meta/billing.gd and the Shop; the egg_ prefix is
because Apple product ids are unique across the whole developer account). Idempotent:
a product that exists is not re-created; each step skips what is already set.

  ~/.appstoreconnect/venv/bin/python tools/asc_iaps.py <app-id>

Per product: the product, its en-US name and description, the USD price (base
territory USA, Apple derives the other territories), all territories, and a
review screenshot (the Shop for Shop products, Home for the Home-only pop-up
sales; from build/store/ios, see tools/ios-screenshots.sh).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import asc  # noqa: E402  (its API key session)

V2 = "https://api.appstoreconnect.apple.com/v2"
SHOP = "build/store/ios/1290x2796/4_shop.png"
HOME = "build/store/ios/1290x2796/1_home.png"

C, N = "CONSUMABLE", "NON_CONSUMABLE"
# product id, type, USD, name (<= 30), description (<= 45), review screenshot
PRODUCTS = [
    ("egg_coins_5000", C, "0.99", "5,000 Coins", "5,000 coins for critters and upgrades.", SHOP),
    ("egg_coins_16000", C, "2.99", "16,000 Coins", "16,000 coins for critters and upgrades.", SHOP),
    ("egg_coins_50000", C, "6.99", "50,000 Coins", "50,000 coins for critters and upgrades.", SHOP),
    ("egg_coins_120000", C, "12.99", "120,000 Coins", "120,000 coins for critters and upgrades.", SHOP),
    ("egg_coins_320000", C, "29.99", "320,000 Coins", "320,000 coins for critters and upgrades.", SHOP),
    ("egg_materials_500", C, "0.99", "500 Materials", "500 materials to build your camp and ship.", SHOP),
    ("egg_materials_1600", C, "2.99", "1,600 Materials", "1,600 materials to build your camp and ship.", SHOP),
    ("egg_materials_5000", C, "6.99", "5,000 Materials", "5,000 materials to build your camp and ship.", SHOP),
    ("egg_materials_12000", C, "12.99", "12,000 Materials", "12,000 materials to build your camp and ship.", SHOP),
    ("egg_materials_32000", C, "29.99", "32,000 Materials", "32,000 materials to build your camp and ship.", SHOP),
    ("egg_bundle_starter", C, "0.99", "Starter Bundle", "10,000 coins and 4 bombs.", SHOP),
    ("egg_bundle_value", C, "2.99", "Value Bundle", "50,000 coins, 11 bombs, 1,500 materials.", SHOP),
    ("egg_bundle_mega", C, "6.99", "Mega Bundle", "150,000 coins, 26 bombs, 5,000 materials.", SHOP),
    ("egg_featured_hatchers_hoard", C, "4.99", "Hatcher's Hoard", "130,000 coins, 15 bombs, 2,000 materials.", SHOP),
    ("egg_no_ads_pass", N, "4.99", "No Ads Pass", "No ads, 40,000 coins and bonuses.", SHOP),
    ("egg_battle_pass", C, "4.99", "Battle Pass", "Unlock this season's premium rewards.", SHOP),
    ("egg_popup_hatch_day_2026", C, "4.99", "Hatch Day Feast", "130,000 coins and 30 bombs.", HOME),
    ("egg_popup_starter_sprinkle", C, "0.99", "Starter Sprinkle", "25,000 coins and 9 bombs.", HOME),
    ("egg_popup_flash_sale", C, "4.99", "Flash Sale", "75,000 coins and 15 bombs.", HOME),
]
NOTE = "No account needed. Purchases grant in-game items; the Shop is on the bottom tab bar."


def price_points(iap_id: str) -> dict:
    out, url = {}, f"{V2}/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
    while url:
        r = asc.call("GET", url)
        for p in r["data"]:
            out[p["attributes"]["customerPrice"]] = p["id"]
        url = r.get("links", {}).get("next")
    return out


def main(app_id: str) -> None:
    existing = {i["attributes"]["productId"]: i["id"] for i in asc._iaps(app_id)}
    for pid, typ, usd, name, desc, shot in PRODUCTS:
        if pid in existing:
            iap_id = existing[pid]
            print("have   ", pid)
        else:
            iap_id = asc.call("POST", f"{V2}/inAppPurchases", json={"data": {
                "type": "inAppPurchases",
                "attributes": {"name": name, "productId": pid, "inAppPurchaseType": typ,
                               "reviewNote": NOTE, "familySharable": False},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]["id"]
            print("created", pid)
        locs = asc.call("GET", f"{V2}/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")["data"]
        if not locs:
            asc.call("POST", "/inAppPurchaseLocalizations", json={"data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {"locale": "en-US", "name": name, "description": desc},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})
        sched = asc._session.get(f"{V2}/inAppPurchases/{iap_id}/iapPriceSchedule")
        if not (sched.status_code == 200 and sched.json().get("data")):
            pp = price_points(iap_id)
            if usd not in pp:
                sys.exit(f"no USD {usd} price point for {pid}")
            asc.call("POST", "/inAppPurchasePriceSchedules", json={
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${p}", "attributes": {"startDate": None},
                              "relationships": {"inAppPurchasePricePoint": {
                                  "data": {"type": "inAppPurchasePricePoints", "id": pp[usd]}}}}]})
        r = asc._session.get(f"{V2}/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
        if not (r.status_code == 200 and r.json().get("data")):
            asc.upload_asset("/inAppPurchaseAppStoreReviewScreenshots",
                             {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}},
                             shot, "inAppPurchaseAppStoreReviewScreenshots")
        print("  set up", pid, "$" + usd)
    for iap in asc._iaps(app_id):   # all territories (asc.py's own check uses a path Apple 404s)
        r = asc._session.get(f"{V2}/inAppPurchases/{iap['id']}/inAppPurchaseAvailability")
        if r.status_code == 200 and r.json().get("data"):
            continue
        asc.call("POST", "/inAppPurchaseAvailabilities", json={"data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                "availableTerritories": {"data": [{"type": "territories", "id": t["id"]}
                                                  for t in asc._all_territories()]}}}})
        print("all territories", iap["attributes"]["productId"])


if __name__ == "__main__":
    main(sys.argv[1])
