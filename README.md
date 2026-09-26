# Look Far

**Eye Strain Relief & Breaks**

A native iPhone app for regular distance-looking breaks, with a quiet dark forest design.

## Run locally

1. Open `LookFar.xcodeproj` in Xcode 26.5 or later.
2. Select the **LookFar** scheme and an **iOS 26.5+ iPhone simulator**.
3. Run to preview the introduction and guided break. Screen Time access is required before the membership preview or main tabs; normal Simulator runs stop at this gate. Use a signed physical iPhone for the complete flow.

The paywall is a **free placeholder**. It does not configure RevenueCat, load products, or offer purchases. The existing RevenueCat SDK/configuration remains in the project for later integration; the setup notes below describe that deferred integration.

The command-line tools on this Mac currently point to Command Line Tools. Shell builds should use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; changing the machine-wide setting is unnecessary.

## Flows included

- Concise onboarding: one introduction opens a 10-second trial rest directly. Completing or skipping the rest leads to required Screen Time access, then the minimal free paywall placeholder.
- Automatic pauses run 24/7, with no active-hours window. The default rhythm is 20 minutes of aggregate use followed by a 20-second break. Customize both values only in Settings → Break timing, using native scrolling wheels (5–120 minutes and 5–120 seconds, in steps of 5). Save applies both together; Back discards edits. Any break can be skipped.
- Guided rest with a “Look far” instruction, brief end cue, quiet horizon, seconds remaining, and elapsed progress. The timer uses its saved deadline, supports interrupted-session recovery, and ends with sound/haptic feedback. Reduce Motion disables the repeating horizon and progress animation.
- Today’s forest starts empty each local day and grows one tree per completed guided rest. Past rests remain in Progress; no history is deleted at the daily reset. Screen time, completed breaks, rest duration, and streak sit alongside the forest.
- Progress with weekly/monthly charts and dated history. Confirmed breaks and skips stay separate and never award trees.
- Eye-health education and practical tips in the third tab, Learn.
- Required individual Screen Time authorization and all eligible apps included by default; optional app selection narrows automatic pauses. Losing access blocks the main UI and closes settings, membership, or an active break. An interrupted break earns no tree; past history is preserved.
- A Device Activity Report extension displays today's aggregate screen time on this iPhone. Its usage data stays inside Apple's report extension.

**Simulator limits:** iOS Simulator cannot provide real Screen Time authorization, usage totals, or shielding. The introduction and demo rest can be previewed, but there is no normal bypass into the app. Explicit DEBUG authorization fixtures let UI tests exercise the dashboard and permission states; they do not validate Screen Time itself. Being away from this app never silently counts as being away from the phone.

**Existing users:** saved history, explicit app selections, usage intervals, and authorized active sessions are preserved. Legacy routine presets no longer apply; the rest duration defaults to 20 seconds until changed in Settings. Enabled active-hours schedules are replaced with 24/7 monitoring on the next app refresh, starting a fresh usage cycle while preserving any pending break and guided deadline. Saving timing in Settings also starts a fresh usage cycle; an in-progress rest retains its original duration. There is no history deletion or service downtime.

**Real gaps:** standard Screen Time callbacks do not establish continuous whole-phone inactivity. “I already took a break” on the break prompt resets the cycle and records a confirmation separately; it is not a Settings preference. Automatic confirmed-idle reset is not implemented.

The short break timer uses its saved deadline. In the foreground, it completes and releases restrictions automatically. After locking or terminating the app, release is reconciled on return or a shield action; exact background release and notification delivery are not promised. Skipping or turning off monitoring always releases this app's restrictions.

## Physical iPhone and TestFlight

**Bundle identity changed:** the app now uses `dev.local.lookfar` and App Group `group.dev.local.lookfar`. It installs separately from the earlier Stillfar build. Existing Stillfar history stays in that app’s container and is not automatically migrated; retain the earlier app if you need its records.

The project selects **Norvane Systems Ltd.** (team `VRT5976586`). The app and all four extension identifiers are registered with Family Controls (Development and Distribution). App Group `group.dev.local.lookfar` is configured for the app and monitoring/shield extensions. Sign into that team in Xcode for signed builds. Real Screen Time behavior still requires a physical-device test.

The report extension, `dev.local.lookfar.screentimereport`, deliberately has no App Group; it renders usage totals within its sandbox. Apple's Family Controls distribution approval is in place, and distribution signing passed for the app and all four extensions. The source project does not include signing credentials.

**App Store Connect:** [Look Far: Eye Strain Relief](https://appstoreconnect.apple.com/apps/6813801317/distribution/info), app ID `6813801317`, SKU `lookfar-ios`, English (U.S.), Health & Fitness. Its subtitle is **Eye Strain Relief & Breaks**. Build **0.1.0 (1)** is available for internal TestFlight testing in **Yuke Automatic**, with the tester invited and automatic distribution enabled for future Xcode builds. The App Store draft remains in Prepare for Submission and has not been submitted for review. The visible name inside the app remains **Look Far**. The store draft starts at version 1.0; align it with the intended release build before submission.

## RevenueCat subscription setup

This integration is retained for later activation and is not used by the current placeholder paywall. Configure `Config/RevenueCat.xcconfig`; the Xcode project expands these values through `Config/LookFar-Info.plist` into the app bundle:

| Build setting | Info.plist key | Value |
| --- | --- | --- |
| `REVENUECAT_PUBLIC_SDK_KEY` | `RevenueCatPublicSDKKey` | Public SDK key for the selected RevenueCat app/store. |
| `REVENUECAT_ENTITLEMENT_ID` | `RevenueCatEntitlementID` | `plus` by default. |
| `REVENUECAT_OFFERING_ID` | `RevenueCatOfferingID` | Leave empty to use the project's current offering. |

Create annual and monthly products, attach both to the `plus` entitlement, and place them in the offering's annual and monthly packages. Each product must have its matching one-year or one-month period. The app reads packages and access from RevenueCat; an unconfigured service shows an unavailable message without prices or a purchase action.

**Local testing is configured:** [Look Far in RevenueCat](https://app.revenuecat.com/projects/bb457c46/overview) has a Test Store, the `plus` entitlement, and the current `default` offering. Its annual package uses `dev.lookfar.plus.annual` at US$39.99/year; its monthly package uses `dev.lookfar.plus.monthly` at US$7.99/month. The public Test Store key is in the xcconfig. Debug purchases are simulated and do not charge money. `Config/LookFar.storekit` remains available for optional Xcode StoreKit testing, but the shared scheme does **not** enable that file by default. It is not required for RevenueCat Test Store testing.

**App Store / TestFlight:** create the iOS app in RevenueCat and configure its connection to App Store Connect. Create one Apple subscription group containing `dev.lookfar.plus.annual` and `dev.lookfar.plus.monthly`, set the prices/periods, and connect the products to the RevenueCat entitlement and offering. Use the iOS public `appl_` SDK key before archiving; Release builds reject Test Store keys. TestFlight uses Apple's sandbox, not the RevenueCat Test Store or Xcode's local StoreKit file. Purchase, restore, and entitlement checks must be repeated in that environment.

Only public SDK keys belong in this config. Do not put RevenueCat secret API keys or App Store Connect private credentials in the app. Production privacy/terms pages are still needed before activating subscriptions.

## Data and privacy

Rest history and monitoring preferences stay on the device. The current placeholder does not contact RevenueCat. When the deferred integration is activated, RevenueCat receives an anonymous app user identifier and purchase/customer subscription information to manage access. There is no Look Far account or app-owned backend. App Store payments are handled by Apple; the app does not collect payment-card details. See [RevenueCat's privacy policy](https://www.revenuecat.com/privacy/).

## Checks

Pure Swift timer/history tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/lookfar-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/lookfar-swift-cache \
swift test --disable-sandbox --scratch-path /tmp/lookfar-core-build
```

**Validation:** 15 core tests, 3 monitoring-configuration tests, and all 17 Simulator UI tests pass; the unsigned iOS Release build also succeeds. They cover timer/history behavior, one tree per completed rest, daily forest resets, legacy decoding, time zones, daylight-saving transitions, and completion idempotency. Configuration tests cover saved timing and legacy schedule decoding. UI coverage includes a real 10-second demo, a custom 30/10 rhythm, required access after completing/skipping the demo, denial, Simulator gating, revocation during onboarding/settings/membership/rest, authorized session restoration, tree rewards, Progress, and Learn. **Physical-iPhone Screen Time totals, all-app shielding, and audio/haptic delivery remain unvalidated.**

In Xcode, **Product → Test** runs the app UI tests. `--ui-testing` uses a two-second timer and nonpersistent history; add `--ui-testing-full-rest` for real durations (a 10-second onboarding trial, otherwise the configured rest duration). DEBUG UI tests use `--ui-testing-screen-time=<state>`, where state is `approved`, `notDetermined`, `denied`, `revoked-on-foreground`, or `restoring-approved`. These fixtures require `--ui-testing` and are absent from Release builds. `--skip-onboarding` skips the introduction but does not bypass required authorization. Normal runs use the full timer and the user’s saved records; sample history and the Settings testing lab have been removed.

`scripts/generate_project.py` regenerates the checked-in Xcode project using only Python's standard library. Run it after adding/removing source files. Reapply any local signing choices after regeneration.

The current app promises a break habit. It does not claim to correct myopia, slow axial elongation, prevent retinal disease, or verify that users looked into the distance.
