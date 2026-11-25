# Privacy wording for the Meta (Facebook) SDK -- DRAFT, not published

For the Meta SDK in the next Android release (code 15; addons/EggMeta). It goes
into `store/privacy.html` (then published as egg-escape.html in the
duckdoku-privacy repo) and the Play Data safety form, **before** that release
ships. Do not publish it until the consent gate below is built, because the
policy text promises it.

## Consent gate (built 2026-11-25; needs a phone test before release)

`addons/EggMeta` used to let the Meta SDK start on its own at launch. Now the
manifest turns auto-init and auto-logging off, and the EggAnalytics plugin's
`setMeta(on)` starts it (and stops it logging) from `TSAnalytics.sync_meta()`,
using the same `_allowed()` rule as Firebase, on every change and every event. Firebase and GameAnalytics do not: they wait for
`TSPrivacyRegion.analytics_allowed()` (a "yes" on Home's card in the UK, EEA and
Switzerland; the Settings > Share usage data switch everywhere). The Meta SDK
must follow the same rule, or a player in the UK would be tracked by Meta
before saying yes, and the Settings switch would not stop it.

Still to do: test on a phone in a regulated region (UK locale or UTC+0..3 time
zone): nothing reaches Meta (Events Manager) before Allow, and the Settings
switch stops it. Do not publish the policy before that.

## 1. Policy text (store/privacy.html -- applied 2026-11-25, dated 25 November 2026; change the date to the publish day)

**Date line:** `Last updated: <the day it ships>`.

**Intro paragraph:** after "what Google's advertising and analytics services" add
"and Meta's advertising measurement", so it reads "...what Google's advertising
and analytics services, Meta's ad measurement (on Android) and the app stores'
purchase services need to work."

**New section, after "Analytics (Google Analytics for Firebase)":**

```html
<h2>Ad measurement (Meta)</h2>
<p>On Android, the game includes the Meta (Facebook) SDK so that we can tell whether people who saw our ads on Facebook or Instagram went on to install and open the game. While it is running, the SDK sends Meta that the game was installed or opened, the game version, your device's advertising ID, your IP address and a coarse location derived from it, device and operating system details, and, for in-app purchases made on Android, the product and price. You do not need a Facebook or Instagram account, and the game never sends Meta your leaderboard name, anything you type, or your contacts. Meta may use this data to measure and improve our ads and, under its own policies, for its own purposes, including showing you ads. It processes the data under <a href="https://www.facebook.com/privacy/policy/">Meta's Privacy Policy</a>.</p>
<p>In the United Kingdom, the European Economic Area and Switzerland the SDK does not start, and nothing is sent to Meta, unless you tap Allow on the consent card. Everywhere else it runs by default. Wherever you are, you can turn it off at any time in the game's Settings &rarr; Share usage data, and you can reset or limit your advertising ID in your device's Settings. The iPhone and iPad version does not include the Meta SDK.</p>
```

**Your choices**, edit the first two bullets:
- "Reset or limit ad personalisation: ..." keep, and add "Meta's ad data: facebook.com/off-facebook-activity or Meta's ad preferences."
- "Stop gameplay analytics: the game's Settings → Share usage data." becomes
  "Stop gameplay analytics and Meta ad measurement: the game's Settings → Share usage data."

**Advertising (Google AdMob)** needs no change.

## 2. Google Play Data safety (the user sends it for review)

Change these, all "Collected" **and "Shared"** (with Meta), optional left as is:

| Data type | Shared with Meta | Purpose to add |
|---|---|---|
| Device or other IDs (advertising ID) | yes | Advertising or marketing; Analytics |
| App activity > App interactions (installs, opens) | yes | Advertising or marketing; Analytics |
| Approximate location (from IP) | yes | Advertising or marketing |
| Purchase history (only if "Log In-App Purchases Automatically" stays on in the Meta app) | yes | Advertising or marketing |

Everything else stays as it is. "Data is encrypted in transit": yes. "Users can
request deletion": unchanged. To keep purchase history out of what is shared,
switch off "Log In-App Purchases Automatically" in the Meta app (Settings >
Basic > Android) and drop that row and the purchase wording above.

## 3. Meta app side

- Privacy policy URL: set (jvea03.github.io/duckdoku-privacy/egg-escape.html).
- Data deletion: Meta wants a data deletion instructions URL or callback to go
  live; point it at the policy's "Your choices" section, or add a short
  "Deleting your data" anchor to the policy.
- Publish the app (icon and category first) only once the release is out.

## 4. iOS

The iPhone and iPad app has no Meta SDK, so nothing changes there until it does
(then: App Privacy labels, the tracking prompt text and domains; see docs/ios.md).
