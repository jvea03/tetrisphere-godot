#!/usr/bin/env python3
"""Fills Egg Escape's App Store listing from this file (text from
store/listing.md, categories, age rating, price, screenshots). Re-runnable.

  ~/.appstoreconnect/venv/bin/python tools/asc_listing.py <app-id>

Not done here (the API can't, or it is the owner's call): App Privacy answers,
availability by country, App Review contact details, the content-rights
answer, and the build. See docs/ios.md.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import asc  # noqa: E402

B = "https://api.appstoreconnect.apple.com/v1"
PRIVACY_URL = "https://jvea03.github.io/duckdoku-privacy/egg-escape.html"
SUPPORT_URL = os.environ.get("SUPPORT_URL", "https://jvea03.github.io/duckdoku-privacy/egg-escape-support/")
SHOTS = "build/store/ios"

SUBTITLE = "Spin the egg, free critters"            # <= 30
KEYWORDS = "match,3d,casual,critters,blocks,brain,relax,cute,spin,rotate,pastel,logic,daily,collect,sphere"  # <= 100
PROMO = ("Crack open giant eggs, free the critters and rebuild the crashed spaceship. "
         "A new Daily Egg every day and the 7-Day Eggsperience are waiting!")  # <= 170
DESCRIPTION = """Crash-landed on a strange planet, the critters are stuck inside giant eggs – and only you can crack them open!

Spin the egg in any direction, aim your falling block, and drop it to match three or more of the same piece. Clear a path down through the shell and dig out the escape hole to set each critter free.

• A fresh puzzle on every turn of the egg – swipe to spin it all the way round
• Slide pieces into place, set off chains, and dig deeper with every match
• Tough blockers: armoured stones, tie-downs holding the critter in place, and geodes that fire a rock when they finally crack
• Boosters when you're stuck: Bombs, Any Piece and Rocks
• A day-and-night sky that changes as you climb through the levels
• Rebuild the crashed spaceship at your camp, collect critters, open chests and play the Daily Egg
• Hand-drawn pastel art and relaxing music

Can you get every critter off the planet?

Egg Escape: Puzzle Break is free to play, with optional in-app purchases and ads. You can remove the ads with the No Ads Pass."""
COPYRIGHT = "2026 Jeffrey Vea"

# Same answers as Duckdoku Blast (4+): ads are the only "yes". Chests are earned
# in play and nothing bought is random (a bundle's chest is only its picture).
AGE = {"advertising": True, "alcoholTobaccoOrDrugUseOrReferences": "NONE", "contests": "NONE",
       "gambling": False, "gamblingSimulated": "NONE", "gunsOrOtherWeapons": "NONE",
       "healthOrWellnessTopics": False, "lootBox": False, "medicalOrTreatmentInformation": "NONE",
       "messagingAndChat": False, "parentalControls": False, "profanityOrCrudeHumor": "NONE",
       "ageAssurance": False, "sexualContentGraphicAndNudity": "NONE", "sexualContentOrNudity": "NONE",
       "socialMedia": False, "socialMediaAgeRestricted": False, "horrorOrFearThemes": "NONE",
       "matureOrSuggestiveThemes": "NONE", "unrestrictedWebAccess": False, "userGeneratedContent": False,
       "violenceCartoonOrFantasy": "NONE", "violenceRealisticProlongedGraphicOrSadistic": "NONE",
       "violenceRealistic": "NONE"}


def main(app_id: str) -> None:
    ver = asc.call("GET", f"{B}/apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION")["data"][0]
    asc.call("PATCH", f"{B}/appStoreVersions/{ver['id']}", json={"data": {
        "type": "appStoreVersions", "id": ver["id"],
        "attributes": {"copyright": COPYRIGHT, "releaseType": "MANUAL"}}})
    print("version", ver["attributes"]["versionString"], "copyright + manual release")

    loc = asc.call("GET", f"{B}/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"][0]
    attrs = {"description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO}
    if SUPPORT_URL:
        attrs["supportUrl"] = SUPPORT_URL
    asc.call("PATCH", f"{B}/appStoreVersionLocalizations/{loc['id']}", json={"data": {
        "type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}})
    print("description, keywords, promo text" + (", support url" if SUPPORT_URL else " (no support url yet)"))

    info = asc.call("GET", f"{B}/apps/{app_id}/appInfos")["data"][0]
    asc.call("PATCH", f"{B}/appInfos/{info['id']}", json={"data": {
        "type": "appInfos", "id": info["id"], "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
            "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_PUZZLE"}},
            "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": "GAMES_CASUAL"}}}}})
    print("categories: Games > Puzzle, Casual")
    il = asc.call("GET", f"{B}/appInfos/{info['id']}/appInfoLocalizations")["data"][0]
    asc.call("PATCH", f"{B}/appInfoLocalizations/{il['id']}", json={"data": {
        "type": "appInfoLocalizations", "id": il["id"],
        "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": PRIVACY_URL}}})
    print("subtitle + privacy policy url")

    age = asc.call("GET", f"{B}/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    asc.call("PATCH", f"{B}/ageRatingDeclarations/{age['id']}", json={"data": {
        "type": "ageRatingDeclarations", "id": age["id"], "attributes": AGE}})
    print("age rating answers")

    # (the schedule resource always exists; it has a price only once manualPrices answers)
    if asc._session.get(f"{B}/appPriceSchedules/{app_id}/manualPrices").status_code != 200:
        pts = asc.call("GET", f"{B}/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")["data"]
        free = next(p for p in pts if float(p["attributes"]["customerPrice"] or 0) == 0)
        asc.call("POST", f"{B}/appPriceSchedules", json={
            "data": {"type": "appPriceSchedules", "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${p}"}]}}},
            "included": [{"type": "appPrices", "id": "${p}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
        print("price: Free")

    for size, display in (("1290x2796", "APP_IPHONE_67"), ("1284x2778", "APP_IPHONE_65"),
                          ("2048x2732", "APP_IPAD_PRO_3GEN_129")):
        asc.cmd_screenshots(loc["id"], os.path.join(SHOTS, size), display)


if __name__ == "__main__":
    main(sys.argv[1])
