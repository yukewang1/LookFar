# Look Far

**Eye Strain Relief & Breaks**

A native iPhone app for regular distance-looking breaks, with a quiet dark forest design.

## Run locally

1. Open `LookFar.xcodeproj` in Xcode 26.5 or later.
2. Select the **LookFar** scheme and an **iOS 26.5+ iPhone simulator**.
3. Run. Complete the three-screen introduction, then start a rest.

Subscriptions use **RevenueCat iOS SDK 5.90.2**, pinned through Swift Package Manager. The proposed plans are **US$39.99/year** and **US$7.99/month**; connected prices come from the configured offering and store products. Features currently remain open regardless of subscription state. See the subscription setup below before testing purchases.

The command-line tools on this Mac currently point to Command Line Tools. Shell builds should use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; changing the machine-wide setting is unnecessary.

## Flows included

- Onboarding for people with myopia or recurring screen discomfort.
- Classic 20-minute/20-second, frequent 10-minute/20-second, and longer 20-minute/60-second routines.
- Foreground guided rest, completion sound/haptic, interrupted-session recovery, skip, and user-confirmed reset.
- Local history, weekly/monthly charts, timed rests, confirmed breaks, and skips.
- Eye-health education with AOA/NEI links and explicit limits on medical claims.
- RevenueCat offering/package selection, purchase, restore, and customer entitlement updates, validated with its Test Store.
- Individual Screen Time authorization, app selection, active hours, usage thresholds, and three shielding/monitoring extensions.

**Simulator limits:** iOS Simulator cannot validate real Screen Time authorization, app usage, or shielding. Being away from this app never silently counts as being away from the phone.

**Real gaps:** standard Screen Time callbacks do not establish continuous whole-phone inactivity. “I already took a break” resets the cycle and records a confirmation separately. Automatic confirmed-idle reset is not implemented.

The short break timer uses its saved deadline. In the foreground, it completes and releases restrictions automatically. After locking or terminating the app, release is reconciled on return or a shield action; exact background release and notification delivery are not promised. Skipping or turning off monitoring always releases this app's restrictions.

## Physical iPhone and TestFlight

**Bundle identity changed:** the app now uses `dev.local.lookfar` and App Group `group.dev.local.lookfar`. It installs separately from the earlier Stillfar build. Existing Stillfar history stays in that app’s container and is not automatically migrated; retain the earlier app if you need its records.

The project selects **Norvane Systems Ltd.** (team `VRT5976586`). The main bundle identifier `dev.local.lookfar` is registered with App Groups and Family Controls (Development). Real Screen Time behavior still requires a signed physical-device test. Sign into that team in Xcode, finish registering the extension identifiers, and register/configure `group.dev.local.lookfar` for the app and extensions.

Enable Family Controls and the App Group for the app and extensions. Distribution needs Apple's Family Controls entitlement approval for the relevant identifiers. The source project does not include signing credentials.

**App Store Connect is created:** [Look Far: Eye Strain Relief](https://appstoreconnect.apple.com/apps/6813801317/distribution/info), app ID `6813801317`, SKU `lookfar-ios`, English (U.S.), Health & Fitness. Its subtitle is **Eye Strain Relief & Breaks**. The app is a draft in Prepare for Submission; no build has been uploaded or submitted for review. The visible name inside the app remains **Look Far**. The store draft starts at version 1.0; align it with the intended release build before submission.

## RevenueCat subscription setup

The RevenueCat manager replaces the app's direct StoreKit transaction manager. Configure `Config/RevenueCat.xcconfig`; the Xcode project expands these values through `Config/LookFar-Info.plist` into the app bundle:

| Build setting | Info.plist key | Value |
| --- | --- | --- |
| `REVENUECAT_PUBLIC_SDK_KEY` | `RevenueCatPublicSDKKey` | Public SDK key for the selected RevenueCat app/store. |
| `REVENUECAT_ENTITLEMENT_ID` | `RevenueCatEntitlementID` | `plus` by default. |
| `REVENUECAT_OFFERING_ID` | `RevenueCatOfferingID` | Leave empty to use the project's current offering. |

Create annual and monthly products, attach both to the `plus` entitlement, and place them in the offering's annual and monthly packages. Each product must have its matching one-year or one-month period. The app reads packages and access from RevenueCat; an unconfigured service shows an unavailable message without prices or a purchase action.

**Local testing is configured:** [Look Far in RevenueCat](https://app.revenuecat.com/projects/bb457c46/overview) has a Test Store, the `plus` entitlement, and the current `default` offering. Its annual package uses `dev.lookfar.plus.annual` at US$39.99/year; its monthly package uses `dev.lookfar.plus.monthly` at US$7.99/month. The public Test Store key is in the xcconfig. Debug purchases are simulated and do not charge money. `Config/LookFar.storekit` remains available for optional Xcode StoreKit testing, but the shared scheme does **not** enable that file by default. It is not required for RevenueCat Test Store testing.

**App Store / TestFlight:** create the iOS app in RevenueCat and configure its connection to App Store Connect. Create one Apple subscription group containing `dev.lookfar.plus.annual` and `dev.lookfar.plus.monthly`, set the prices/periods, and connect the products to the RevenueCat entitlement and offering. Use the iOS public `appl_` SDK key before archiving; Release builds reject Test Store keys. TestFlight uses Apple's sandbox, not the RevenueCat Test Store or Xcode's local StoreKit file. Purchase, restore, and entitlement checks must be repeated in that environment.

Only public SDK keys belong in this config. Do not put RevenueCat secret API keys or App Store Connect private credentials in the app. Privacy/terms screens are prototype text, not published production policies.

## Data and privacy

Routine preferences and rest history stay on the device. They are not sent to RevenueCat. When configured, RevenueCat receives an anonymous app user identifier and purchase/customer subscription information to manage access. There is no Look Far account or app-owned backend. App Store payments are handled by Apple; the app does not collect payment-card details. See [RevenueCat's privacy policy](https://www.revenuecat.com/privacy/).

## Checks

Pure Swift timer/history tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/lookfar-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/lookfar-swift-cache \
swift test --disable-sandbox --scratch-path /tmp/lookfar-core-build
```

The renamed Look Far app passed **9 core tests and all 4 iOS Simulator UI tests**. RevenueCat Test Store checks passed for the US$39.99 annual / US$7.99 monthly prices, cancellation, simulated purchase failure and success, restoring purchases, and retaining entitlement access after relaunch. **Physical-iPhone Screen Time behavior and Apple sandbox/TestFlight purchases remain unvalidated.**

In Xcode, **Product → Test** runs the app UI tests. UI tests use a two-second timer and isolated in-memory history; normal runs use the full selected duration. Optional launch arguments: `--skip-onboarding` and `--ui-testing` (test-only shortened timer and nonpersistent history). Normal runs use only the user’s saved records; sample history and the Settings testing lab have been removed.

`scripts/generate_project.py` regenerates the checked-in Xcode project using only Python's standard library. Run it after adding/removing source files. Reapply any local signing choices after regeneration.

The current app promises a break habit. It does not claim to correct myopia, slow axial elongation, prevent retinal disease, or verify that users looked into the distance.
