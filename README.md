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
- Break reminders run automatically after Screen Time access is granted, with no off switch or active-hours window. The default rhythm is 20 minutes of aggregate use followed by a 20-second break. Customize both values only in Settings → Break timing, using native scrolling wheels (5–120 minutes and 5–120 seconds, in steps of 5). Save applies both together; Back discards edits. Any break can be skipped.
- Guided rest with a “Look far” instruction, brief end cue, quiet horizon, seconds remaining, and elapsed progress. The timer uses its saved deadline, supports interrupted-session recovery, and ends with sound/haptic feedback. Reduce Motion disables the repeating horizon and progress animation.
- Today’s forest starts empty each local day and grows one tree per completed guided rest. Past rests remain in Progress; no history is deleted at the daily reset. Screen time, completed breaks, rest duration, and streak sit alongside the forest.
- Progress with weekly/monthly charts and dated history. Confirmed breaks and skips stay separate and never award trees.
- Eye-health education and practical tips in the third tab, Learn.
- Required individual Screen Time authorization and all eligible apps included by default; Settings → Break reminders → Customize apps narrows the monitored apps. Losing access blocks the main UI and closes settings, membership, or an active break. An interrupted break earns no tree; past history is preserved.
- A Device Activity Report extension displays today's aggregate screen time on this iPhone. Its usage data stays inside Apple's report extension.

**Simulator limits:** iOS Simulator cannot provide real Screen Time authorization, usage totals, or shielding. The introduction and demo rest can be previewed, but there is no normal bypass into the app. Explicit DEBUG authorization fixtures let UI tests exercise the dashboard and permission states; they do not validate Screen Time itself. Being away from this app never silently counts as being away from the phone.

**Existing users:** saved history, explicit app selections, usage intervals, and authorized active sessions are preserved. Legacy routine presets no longer apply; the rest duration defaults to 20 seconds until changed in Settings. Enabled active-hours schedules and older registrations without usage checkpoints are replaced on the next app refresh, starting a fresh usage cycle while preserving any pending break and guided deadline. Saving timing in Settings also starts a fresh usage cycle; an in-progress rest retains its original duration. There is no history deletion or service downtime.

**Reminder and Settings changes:** tapping “Start rest” on a shield saves the start time immediately and opens the running countdown without a second prompt. Repeated taps keep the same deadline; a late app launch still reconciles the rest and any shield skip. Ordinary in-app reminders continue to wait for an explicit start. Settings keeps only “Customize apps” under “Break reminders”; end notifications, the monitoring toggle, the release/stop action, and “Restart introduction” are removed. Existing authorized users who previously disabled monitoring are re-enabled on their next refresh. Pending end notifications from older builds are cleared at launch. History and preferences are preserved, with no service downtime. “Delete rest history” remains a confirmed, irreversible local reset of recorded rests, trees, and streaks; it leaves timing, app selection, and Screen Time access intact.

**Estimated gaps:** automatic monitoring registers cumulative checkpoints every minute of eligible usage. iOS delivers them to the monitoring extension; the main app does not need to remain open, and checkpoint state is saved between callbacks. Between accepted callbacks, elapsed wall time minus newly counted usage estimates time away. At five minutes or more, Look Far starts a fresh usage cycle before showing a break, including when the final threshold callback detects the gap. The first checkpoint establishes a baseline; duplicates and older checkpoints are ignored, and a new local day starts a new baseline. Already pending or active breaks are preserved. Estimated resets do not award trees or add rest history.

Detection happens after usage resumes, usually at the next minute checkpoint. The fresh cycle discards usage before detection (typically up to one resumed minute; potentially more if callbacks are missed). Callback delays and several shorter gaps can resemble one long break. With a custom app selection, time spent in unselected apps also looks like time away. This is an estimate, not verified whole-phone inactivity or a confirmed eye rest. “I already took a break” on the break prompt remains an explicit reset.

The short break timer uses its saved deadline. In the foreground, it completes and releases restrictions automatically. After locking or terminating the app, release is reconciled on return, a shield action, or a later monitoring callback; exact background release is not promised. End notifications have been removed; sound and haptic feedback are available while the app is active. Skipping a break releases this app's restrictions.

**Reminder repair in 0.1.0 (3):** build 2's extensions checked `AuthorizationCenter.authorizationStatus`, whose [initial value is always `notDetermined`](https://developer.apple.com/documentation/familycontrols/authorizationcenter/authorizationstatus). That could discard usage callbacks, clear pending breaks, and prevent extensions from starting another cycle. Authorization is now requested and checked in the app; extensions process the current enabled cycle and rely on iOS to enforce authorization (`startMonitoring` can throw `unauthorized`). The app also checks for pending breaks every two seconds while active, without restarting monitoring. A prompt received while Settings is open appears after Settings closes.

**Schedule repair in 0.1.0 (4):** build 3 still recorded no monitor callbacks on the test iPhone. The equal midnight start/end schedule resolves to the following day on the current framework, reproduced with `DeviceActivitySchedule.nextInterval` in Simulator. Daily bounds are now 00:00:00–23:59:59 so registration during the day resolves to today's interval. The final second before midnight is outside the schedule. Diagnostics includes the resolved interval and whether it covers the capture time; physical-device callback delivery still needs verification.

On the first authorized refresh after a registration upgrade, enabled monitoring starts a fresh usage cycle once. History, app selections, timing, pending breaks, and guided-rest deadlines are preserved. Reconciling an older completed rest also preserves any newer cycle already started by an extension. No data deletion or service downtime is required.

**In-app diagnostics:** open Settings → About → Diagnostics, then Refresh or Copy diagnostic report. Release builds keep the latest 200 events per process in the local App Group: registration attempts/results, interval and usage callbacks, checkpoint decisions, cycle reset reasons, shield actions, and failures. The report includes the build, iOS version, authorization, shared configuration, registered schedule/events, and last recorded callback. It excludes app/website names and selection tokens and uploads nothing automatically. Opening or copying the report does not reset monitoring.

For a physical-device retest, grant Screen Time access, select the 5-minute setting, and use eligible apps continuously. Check for a shield, then repeat while remaining in Look Far. If either prompt is missing, copy the diagnostics before changing the timing or app selection so the current registration and recent callbacks remain visible. `monitoring.registered` proves registration only; `usage.callback` proves the extension ran, and `usage.decision` explains whether it saved progress, restarted, ignored a callback, or requested a shield. Simulator tests cannot establish iOS 27 callback delivery or shielding.

## Physical iPhone and TestFlight

**Bundle identity changed:** the app now uses `dev.local.lookfar` and App Group `group.dev.local.lookfar`. It installs separately from the earlier Stillfar build. Existing Stillfar history stays in that app’s container and is not automatically migrated; retain the earlier app if you need its records.

The project selects **Norvane Systems Ltd.** (team `VRT5976586`). The app and all four extension identifiers are registered with Family Controls (Development and Distribution). App Group `group.dev.local.lookfar` is configured for the app and monitoring/shield extensions. Sign into that team in Xcode for signed builds. Real Screen Time behavior still requires a physical-device test.

The report extension, `dev.local.lookfar.screentimereport`, deliberately has no App Group; it renders usage totals within its sandbox. Apple's Family Controls distribution approval is in place, and distribution signing passed for the app and all four extensions. The source project does not include signing credentials.

To test the estimated gap on an iPhone:

1. Grant Screen Time access and set Break timing to 5 minutes / 10 seconds. Use eligible apps continuously; confirm that the shield appears around five counted minutes and Skip releases it.
2. Start a fresh cycle, use eligible apps for about three minutes, then lock the phone for at least six minutes. Resume usage. The old two-minute remainder should not trigger a break; the next usage checkpoint should restart the cycle, with a shield after roughly another five counted minutes.
3. Repeat with a short gap under five minutes; usage should continue accumulating. Also test the normal 20-minute setting and a custom app selection, keeping the limitations above in mind.
4. Repeat with Look Far backgrounded and after force-quitting it. Verify that an already displayed prompt or a running rest is not dismissed by the gap estimate, and that automatic reminders still work after a rest ends while Look Far is backgrounded. Check across midnight as well. These checks require real Screen Time callbacks; Simulator fixtures cannot validate them.

**App Store Connect:** [Look Far: Eye Strain Relief](https://appstoreconnect.apple.com/apps/6813801317/distribution/info), app ID `6813801317`, SKU `lookfar-ios`, English (U.S.), Health & Fitness. Its subtitle is **Eye Strain Relief & Breaks**. Build **0.1.0 (2)** is available for internal TestFlight testing in **Yuke Automatic**, with the tester invited and automatic distribution enabled for future Xcode builds. The App Store draft remains in Prepare for Submission and has not been submitted for review. The visible name inside the app remains **Look Far**. The store draft starts at version 1.0; align it with the intended release build before submission.

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

**Validation for estimated gaps:** 26 core tests, 16 monitoring-configuration tests, and three affected Simulator UI tests pass; the unsigned iOS Release build also succeeds. Coverage includes the five-minute boundary, continuous use, skipped/duplicate checkpoints, persistence, generation changes, midnight, clock rollback, pending/expired rests, reset-before-shield ordering, and event registration through 120 minutes. The UI rerun covers custom 30/10 timing, largest Dynamic Type, and explicit break confirmation. The earlier 17-case UI suite covered onboarding, permissions/revocation, rest recovery, forest rewards, Progress, and Learn. **Physical-iPhone checkpoint delivery, gap estimates, Screen Time totals, all-app shielding, and audio/haptic delivery remain unvalidated.**

In Xcode, **Product → Test** runs the app UI tests. `--ui-testing` uses a two-second timer and nonpersistent history; add `--ui-testing-full-rest` for real durations (a 10-second onboarding trial, otherwise the configured rest duration). DEBUG UI tests use `--ui-testing-screen-time=<state>`, where state is `approved`, `notDetermined`, `denied`, `revoked-on-foreground`, or `restoring-approved`. These fixtures require `--ui-testing` and are absent from Release builds. `--ui-testing-shield-rest` simulates a rest started three seconds before app launch; `--ui-testing-shield-rest-on-foreground` simulates starting a rest while the app is backgrounded. `--skip-onboarding` skips the introduction but does not bypass required authorization. Normal runs use the full timer and the user’s saved records; sample history and the Settings testing lab have been removed.

`scripts/generate_project.py` regenerates the checked-in Xcode project using only Python's standard library. Run it after adding/removing source files. Reapply any local signing choices after regeneration.

The current app promises a break habit. It does not claim to correct myopia, slow axial elongation, prevent retinal disease, or verify that users looked into the distance.
