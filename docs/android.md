# Android (Google Play)

State on 7 Oct 2026. App **Egg Escape: Puzzle Break**, `com.jvea.eggescape`, Play
app id `4973493136794668328`, developer account "The Little Guy Games".

## Done
- App exists in Play Console, on **closed testing** (0 installs yet), update "not
  yet sent for review"; Production is inactive (the closed-test requirement).
- The project is ready for the next upload: AAB preset at **version code 3**,
  version name **1.0** (Play refuses a code it has seen). `tetrisphere/test_ads`
  is still on, so Android release builds show Google's test ads (iOS is live).
- AdMob Android app and units are set (`Ads.AD_UNITS_LIVE["android"]`).

## Left (needs you or a Windows machine)
1. **Build the AAB** on the Windows PC that has the upload key:
   `powershell -ExecutionPolicy Bypass -File tools\release_aab.ps1` (it asks for the
   key's password; Godot 4.7.1 on that machine). This Mac has no Android SDK, no
   JDK and no upload key, and the script is PowerShell.
2. **Create the 19 one-time products** in Play Console (Monetize with Play >
   Products > One-time products). Ids must match exactly (the egg_ prefix is the
   same as the App Store ones); one purchase option each with id `buy`, default
   price in USD, available in every country, then **Activate**:

| Product ID | Type | USD | Name | Description |
|---|---|---|---|---|
| `egg_coins_5000` | one-time, consumable | $0.99 | 5,000 Coins | 5,000 coins for critters and upgrades. |
| `egg_coins_16000` | one-time, consumable | $2.99 | 16,000 Coins | 16,000 coins for critters and upgrades. |
| `egg_coins_50000` | one-time, consumable | $6.99 | 50,000 Coins | 50,000 coins for critters and upgrades. |
| `egg_coins_120000` | one-time, consumable | $12.99 | 120,000 Coins | 120,000 coins for critters and upgrades. |
| `egg_coins_320000` | one-time, consumable | $29.99 | 320,000 Coins | 320,000 coins for critters and upgrades. |
| `egg_materials_500` | one-time, consumable | $0.99 | 500 Materials | 500 materials to build your camp and ship. |
| `egg_materials_1600` | one-time, consumable | $2.99 | 1,600 Materials | 1,600 materials to build your camp and ship. |
| `egg_materials_5000` | one-time, consumable | $6.99 | 5,000 Materials | 5,000 materials to build your camp and ship. |
| `egg_materials_12000` | one-time, consumable | $12.99 | 12,000 Materials | 12,000 materials to build your camp and ship. |
| `egg_materials_32000` | one-time, consumable | $29.99 | 32,000 Materials | 32,000 materials to build your camp and ship. |
| `egg_bundle_starter` | one-time, consumable | $0.99 | Starter Bundle | 10,000 coins and 4 bombs. |
| `egg_bundle_value` | one-time, consumable | $2.99 | Value Bundle | 50,000 coins, 11 bombs, 1,500 materials. |
| `egg_bundle_mega` | one-time, consumable | $6.99 | Mega Bundle | 150,000 coins, 26 bombs, 5,000 materials. |
| `egg_featured_hatchers_hoard` | one-time, consumable | $4.99 | Hatcher's Hoard | 130,000 coins, 15 bombs, 2,000 materials. |
| `egg_no_ads_pass` | one-time, non-consumable | $4.99 | No Ads Pass | No ads, 40,000 coins and bonuses. |
| `egg_battle_pass` | one-time, consumable | $4.99 | Battle Pass | Unlock this season's premium rewards. |
| `egg_popup_hatch_day_2026` | one-time, consumable | $4.99 | Hatch Day Feast | 130,000 coins and 30 bombs. |
| `egg_popup_starter_sprinkle` | one-time, consumable | $0.99 | Starter Sprinkle | 25,000 coins and 9 bombs. |
| `egg_popup_flash_sale` | one-time, consumable | $4.99 | Flash Sale | 75,000 coins and 15 bombs. |

   `egg_no_ads_pass` is the only non-consumable on the iOS side; Play treats it
   as a one-time product the game acknowledges instead of consuming
   (`scripts/meta/billing.gd` decides that from the product table).
3. **Upload the AAB** to Closed testing, wait for the pre-launch report, keep 12
   testers opted in for 14 days in a row, then apply for production access.
4. Re-check the Play **App content** answers (Ads: yes; Data safety to match the
   App Privacy answers in `docs/ios.md`) and the store listing against
   `store/listing.md`, which still says "no ads" / "no digital purchases".
5. Link the AdMob Android app to the Play listing once it is published.
