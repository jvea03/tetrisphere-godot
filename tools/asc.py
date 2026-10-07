#!/usr/bin/env python3
"""App Store Connect API helper for the bits the web UI makes tedious.

Auth: an App Store Connect API key (App Manager role) described by
~/.appstoreconnect/config.env (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH).
Run with ~/.appstoreconnect/venv/bin/python (pyjwt, cryptography, requests).

  tools/asc.py screenshots <version-localization-id> <dir> <display-type>
      Upload every *.png in <dir> (sorted) as the screenshot set for that
      display type, e.g. APP_IPHONE_65 or APP_IPAD_PRO_3GEN_129, replacing
      any existing set of that type.
  tools/asc.py version-localizations <app-id>
      Print the localization ids of the app's editable version.
  tools/asc.py iap-availability <app-id>
      Make every in-app purchase available in all territories.
  tools/asc.py iap-review-screenshot <app-id> <png>
      Attach <png> as the review screenshot of every in-app purchase that
      does not have one yet.
  tools/asc.py builds <app-id>
      List uploaded builds and their processing state.
  tools/asc.py attach-build <app-id> <build-id>
      Attach a processed build to the editable App Store version.
"""
import hashlib
import os
import sys
import time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com/v1"


def _token() -> str:
    env = {}
    with open(os.path.expanduser("~/.appstoreconnect/config.env")) as f:
        for line in f:
            if "=" in line and not line.startswith("#"):
                k, v = line.strip().split("=", 1)
                env[k] = os.path.expandvars(v)
    with open(os.path.expanduser(env["ASC_KEY_PATH"])) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": env["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": env["ASC_KEY_ID"]})


_session = requests.Session()
_session.headers["Authorization"] = "Bearer " + _token()


def call(method: str, path: str, **kw):
    url = path if path.startswith("http") else API + path
    r = _session.request(method, url, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} -> {r.status_code}\n{r.text[:800]}")
    return r.json() if r.text else {}


def upload_asset(reserve_path: str, relationships: dict, png: str, asset_type: str) -> str:
    """The three-step asset upload every ASC image endpoint uses."""
    data = open(png, "rb").read()
    res = call("POST", reserve_path, json={"data": {
        "type": asset_type,
        "attributes": {"fileName": os.path.basename(png), "fileSize": len(data)},
        "relationships": relationships}})["data"]
    for op in res["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        r = requests.request(op["method"], op["url"], headers=headers, data=chunk)
        r.raise_for_status()
    call("PATCH", f"/{asset_type}/{res['id']}", json={"data": {
        "type": asset_type, "id": res["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return res["id"]


def cmd_version_localizations(app_id: str) -> None:
    vers = call("GET", f"/apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,WAITING_FOR_REVIEW")["data"]
    for v in vers:
        locs = call("GET", f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]
        for loc in locs:
            print(v["attributes"]["versionString"], loc["attributes"]["locale"], loc["id"])


def cmd_screenshots(loc_id: str, folder: str, display_type: str) -> None:
    sets = call("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]
    for s in sets:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            call("DELETE", f"/appScreenshotSets/{s['id']}")
            print("removed existing", display_type, "set")
    sset = call("POST", "/appScreenshotSets", json={"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": display_type},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".png"):
            continue
        sid = upload_asset("/appScreenshots",
                           {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}},
                           os.path.join(folder, name), "appScreenshots")
        print("uploaded", display_type, name, sid)


def _iaps(app_id: str):
    return call("GET", f"/apps/{app_id}/inAppPurchasesV2?limit=50")["data"]


def cmd_iap_availability(app_id: str) -> None:
    for iap in _iaps(app_id):
        pid = iap["attributes"]["productId"]
        r = _session.get(f"{API}/inAppPurchasesV2/{iap['id']}/inAppPurchaseAvailability")
        if r.status_code == 200 and r.json().get("data"):
            print("already set", pid)
            continue
        call("POST", "/inAppPurchaseAvailabilities", json={"data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                "availableTerritories": {"data": [{"type": "territories", "id": t["id"]} for t in _all_territories()]}}}})
        print("all territories", pid)


_territories_cache = None


def _all_territories():
    global _territories_cache
    if _territories_cache is None:
        _territories_cache = call("GET", "/territories?limit=200")["data"]
    return _territories_cache


def cmd_iap_review_screenshot(app_id: str, png: str) -> None:
    for iap in _iaps(app_id):
        pid = iap["attributes"]["productId"]
        r = _session.get(f"{API}/inAppPurchasesV2/{iap['id']}/appStoreReviewScreenshot")
        if r.status_code == 200 and r.json().get("data"):
            print("has screenshot", pid)
            continue
        upload_asset("/inAppPurchaseAppStoreReviewScreenshots",
                     {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap["id"]}}},
                     png, "inAppPurchaseAppStoreReviewScreenshots")
        print("uploaded review screenshot", pid)


def cmd_builds(app_id: str) -> None:
    for b in call("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10")["data"]:
        a = b["attributes"]
        print(b["id"], a["version"], a["processingState"], a["uploadedDate"])


def cmd_attach_build(app_id: str, build_id: str) -> None:
    v = call("GET", f"/apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED")["data"][0]
    call("PATCH", f"/appStoreVersions/{v['id']}/relationships/build",
         json={"data": {"type": "builds", "id": build_id}})
    print("attached", build_id, "to version", v["attributes"]["versionString"])


if __name__ == "__main__":
    cmds = {
        "builds": cmd_builds,
        "attach-build": cmd_attach_build,
        "version-localizations": cmd_version_localizations,
        "screenshots": cmd_screenshots,
        "iap-availability": cmd_iap_availability,
        "iap-review-screenshot": cmd_iap_review_screenshot,
    }
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        sys.exit(__doc__)
    cmds[sys.argv[1]](*sys.argv[2:])
