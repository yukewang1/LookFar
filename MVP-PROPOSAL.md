# Look Far — iOS MVP and validation plan

Updated September 19, 2026 to reflect the implemented native app and current product decisions. The chosen name is **Look Far**, with the subtitle **Eye Strain Relief & Breaks**, using the selected dark forest design. The Look Far app and RevenueCat iOS SDK 5.90.2 Test Store integration passed all 9 core tests and 4 UI tests. Real Screen Time behavior, physical-device reliability, Apple sandbox purchases, and TestFlight distribution remain unvalidated. See [README.md](README.md) for running, signing, and test instructions.

**Product direction:** help people with myopia or recurring discomfort from long screen hours take regular breaks from close-up use. General preventive habit-building is secondary. The initial beta should recruit adults from that audience; automatic coverage is limited to selected iPhone apps, categories, and websites, not laptop work or every near task.

The MVP includes three 20-20-20 variants, manual rests, optional selected-app pauses, week/month progress charts, and recurring subscription flows. The featured offer is **US$39.99/year**, with **US$7.99/month** available. Pricing and retention remain hypotheses to test; access is currently open regardless of subscription state.

## Evidence and competitive context

The research and competitor observations below are retained from the **September 18, 2026 review**, not a new literature search or market refresh. Competitor descriptions come from public listings and developer documentation, not hands-on testing. Prices are historical USD observations from the US storefront or explicitly USD developer pages and may change.

**What the evidence supports.** The American Optometric Association recommends looking about 20 feet away for 20 seconds every 20 minutes as practical advice for digital eye strain. This makes a useful default, but does not establish an optimal dose or validate an app. [AOA guidance](https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome)

The research is mixed:

| Study | Finding relevant to the product | Limit |
| --- | --- | --- |
| [Talens-Estarelles et al., 2023](https://pubmed.ncbi.nlm.nih.gov/35963776/) | In 29 symptomatic computer users, two weeks of reminders reduced reported symptoms; ocular-surface and tear-film measures did not improve significantly. Symptom improvement was not maintained after reminders stopped. | Small, short before/after study of laptop use. |
| [Johnson and Rosenfield, 2023](https://pubmed.ncbi.nlm.nih.gov/36473088/) | In 30 young participants, 20-second breaks at different frequencies did not significantly change symptoms during a demanding 40-minute tablet task. | Short laboratory task; does not establish every longer-term routine is ineffective. |
| [Redondo et al., 2025](https://pubmed.ncbi.nlm.nih.gov/40466853/) | In 24 young adults, breaks every 10 minutes and self-paced breaks improved some outcomes compared with no breaks during a 40-minute task. | Supports exploring schedules; does not prove a universally superior cadence or long-term benefit. |

Use the promise **“Helps you take regular breaks from close-up screen use.”** Treat comfort feedback as subjective and exploratory. Do not claim the product improves visual acuity, reverses myopia, prevents eye disease, diagnoses dry eye, or measures recovery. Condition-specific treatment is a separate product: for example, convergence insufficiency can involve specialist-guided exercises, which is not evidence for a generic exercise library. [National Eye Institute](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/convergence-insufficiency)

**The competitive position.** Existing products cover both enforcement and routine customization.

| Product | Publicly described behavior | Pricing observed | Product implication |
| --- | --- | --- | --- |
| [Noonrre](https://apps.apple.com/us/app/noonrre-app-blocker-detox/id6782772018) | Combined selected-app usage reaches 20 minutes; apps block; a 20-second distance break restores access. Pet/reward framing. | Free core; $3.99 optional lifetime pass; pricing change announced. | Closest direct alternative. Usage-based blocking is already available. |
| [Scrolless](https://apps.apple.com/us/app/scrolless-save-your-vision/id6751835715) | Usage-based restrictions, guided rests, skipping, and a marketed strain meter. | $44.99/year; seven-day trial. | Competes for the same eye-comfort audience. Its strain calculations are not independent clinical evidence. |
| [Eyefry](https://apps.apple.com/us/app/eyefry-eye-care-screen-time/id6758161682) | Scheduled selected-app blocking, look-away/blink prompts, snooze and reports. A rolling usage loop is not established by the listing. | $49.99/year; $24.99 discounted annual and $4.99/week also listed. | Similar bundle; distinguish schedules from accumulated-use thresholds. |
| [BlinkRest](https://apps.apple.com/us/app/blinkrest-20-20-20-lazy-eye/id1644601065) | Screen Time reminders, work sessions, distance breaks, optional exercises. Shielding is not established by the listing. | Free; $0.99 remove-ads purchase. | Routine variants and exercises are inexpensive alternatives already. |
| [Eye Care 20 20 20](https://apps.apple.com/us/app/eye-care-20-20-20/id967901219) | Conventional reminders, working hours, manual sessions. | $6.99/month or $49.99/year listed. | A timer alone enters an established category. |
| [Restio](https://kuthaygumus.github.io/restio/) | 20-20-20/Pomodoro timers, custom intervals, sound, Watch and Mac experiences. Selected-app shielding is not established. | Free core; $2.99/month, $14.99/year, $49.99 lifetime. | Important omission from the original plan: variants and calm guidance are already competitive features. |
| [ScreenZen](https://screenzen.co/) | App-opening pauses, usage limits and blocking. | Donation-supported; no subscription. | Strong substitute when the user mainly wants help interrupting scrolling. |
| [Apple Screen Distance](https://support.apple.com/en-us/105007) | Warns after prolonged viewing closer than 12 inches on supported TrueDepth devices. | Built in. | Addresses viewing distance, not periodic distance-gazing breaks. |

Scrolless's own FAQ documents missed triggers and restrictions that remain after a rest, including recovery procedures. That is concrete evidence that reliability deserves attention, but not evidence of how often its users encounter problems. [Scrolless troubleshooting](https://www.scrolless.com/faq)

My proposed advantage is **a predictable pause that is easy to understand, complete, and recover from**. Calm design and honest claims support that advantage; they do not establish a moat. App Store ratings and subscription offers do not establish revenue or willingness to pay for this particular product. Compare directly with Noonrre and ScreenZen during validation.

## Implemented MVP

The three routines share distance-looking guidance: “Look at something about 6 metres / 20 feet away. Blink comfortably.” They are habit preferences, not medically equivalent or optimized prescriptions.

| Preset | Usage threshold when automatic pauses are enabled | Timed rest |
| --- | --- | --- |
| Classic | 20 minutes of selected-app use | 20 seconds |
| Frequent | 10 minutes of selected-app use | 20 seconds |
| Longer | 20 minutes of selected-app use | 60 seconds |

The native SwiftUI flows now include:

1. **Introduction and Today:** three-screen onboarding, routine selection, manual “Start an eye rest,” recent counts, and user-confirmed reset. Manual rests work without Screen Time permission.
2. **Optional automatic pauses:** individual Screen Time authorization, a system app picker, one selection group, and one daily active window. A usage threshold applies this app's shield. Its actions open the guided break or skip and release. There is no automatic reminder-only mode in this prototype.
3. **Guided rest:** a subdued countdown, distance-looking guidance, sound/haptic completion, skip, and saved-deadline recovery. Users do not need to watch the screen. A completed timer records elapsed rest time; it does not verify gaze or benefit.
4. **Progress:** Week (past seven days) and Month (past 30 days) views, daily charts distinguishing timed rests from confirmed breaks, timed-rest minutes, days with a rest, skips, and recent activity. Normal runs display only the user’s saved records. No eye-strain score or recovery estimate is shown.
5. **Learn and Settings:** myopia and comfort education with AOA/NEI links, routine and sound controls, permission and schedule settings, and an unconditional release/stop control. The Settings testing lab and sample-history mode have been removed.
6. **Membership:** RevenueCat iOS SDK 5.90.2 replaces the direct StoreKit manager for offering/package selection, purchase, restore, and customer entitlement updates. RevenueCat Test Store is configured and its purchase, restore, and entitlement flows passed validation. No production subscription or feature gate has been activated.

### Resets, interruptions, and release

The automatic counter represents **accumulated selected-app use since reset**, not continuous near work. Standard Screen Time callbacks do not confirm whole-phone inactivity. Automatic confirmed-gap resets are therefore **not implemented**: leaving Look Far or leaving the selected apps is insufficient evidence of a break. “I already took a break” resets the cycle immediately and records a confirmation separately; skipping also starts fresh without adding timed-rest minutes.

In the foreground, the saved deadline drives completion and release. After locking or terminating the app, completion/release is reconciled when the user returns or interacts with the shield. Exact background unlock timing and notification delivery are not promised. The implementation has release and recovery paths; their reliability still requires physical-device validation. No purchase or completed exercise should ever be required to escape a restriction.

### Audience and health information

The Learn flow explains that myopia often involves an eye growing too long from front to back and that high myopia is associated with greater retinal-detachment risk. It also states explicitly that Look Far has not been shown to shorten the eye, slow myopia, or prevent retinal disease. This is educational context for the chosen audience, not a health claim for breaks or the subscription. Continue professional eye care; recurring discomfort should not automatically be attributed to screens. The app links to [NEI myopia information](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/nearsightedness-myopia) and [NEI retinal-detachment information](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/retinal-detachment).

The product promise remains **“Helps you take regular breaks from close-up screen use.”** A usability beta can establish whether people take and keep using breaks; it cannot establish clinical efficacy.

## Platform readiness

The checked-in Xcode project targets **iOS 26.5+** and includes the app, DeviceActivity monitor, shield configuration, and shield action extensions. It uses native SwiftUI, FamilyControls, DeviceActivity, ManagedSettings, RevenueCat iOS SDK 5.90.2, and local history/shared state. There is no Look Far account or app-owned backend. The renamed Look Far app passed all 9 core tests and 4 iOS Simulator UI tests. RevenueCat Test Store checks covered the correct US$39.99/year and US$7.99/month prices, cancellation, simulated failure and success, restore, and entitlement access retained after relaunch. These results do not validate physical-device usage detection or shielding, Apple sandbox purchases, or TestFlight distribution. [Apple Screen Time overview](https://developer.apple.com/videos/play/wwdc2021/10123/), [individual authorization](https://developer.apple.com/videos/play/wwdc2022/110336/)

The shield-to-app flow uses the iOS 26.5 action documented by Apple; test it with individual authorization on physical devices before committing to a public launch. Older iOS versions are excluded from this prototype. A short rest is tracked by its saved deadline, not by trying to schedule a 20-second DeviceActivity interval. [Shield action](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp), [DeviceActivity schedule minimum](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)

Physical iPhone testing still needs a configured Xcode account, registered extension identifiers and App Group, and the corresponding capabilities on the app and extensions. The main bundle dev.local.lookfar is registered under Norvane Systems Ltd. The App Store Connect draft [Look Far: Eye Strain Relief](https://appstoreconnect.apple.com/apps/6813801317/distribution/info) is created with app ID 6813801317 and subtitle Eye Strain Relief & Breaks. No build is uploaded. TestFlight still requires signing and Family Controls distribution entitlement approval. RevenueCat Test Store uses a public test_ SDK key for local Debug purchases. For TestFlight, configure the Apple products in App Store Connect and RevenueCat, then use the iOS public appl_ SDK key. Release builds reject Test Store keys. The optional Xcode StoreKit file is not enabled by default and does not configure TestFlight products. The project selects Norvane Systems Ltd. (team VRT5976586); signing credentials are not included. [Apple entitlement guidance](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)

Subscription configuration lives in Config/RevenueCat.xcconfig. Its public SDK key, entitlement ID (default plus), and optional offering ID (empty means current offering) become RevenueCatPublicSDKKey, RevenueCatEntitlementID, and RevenueCatOfferingID in Info.plist. Annual and monthly products must be attached to the entitlement and offered in matching packages. The Test Store, entitlement, offering, and public test key are configured; the README records the setup. App Store and TestFlight configuration remain separate work.

Rest history and routine preferences remain local and are not sent to RevenueCat. When connected, RevenueCat receives an anonymous app user identifier and purchase/customer subscription information for access management. This introduces a third-party subscription data flow, even though there is no app-owned backend. Publish appropriate privacy/terms information before production distribution.

## Next validation and commercial decisions

Before a paid launch, prove repeated selected-app use → threshold → shield → guided break/skip → release → fresh usage count on physical devices. Include both trigger intervals, past-activity handling, interrupted sessions, duplicate callbacks, restarts, active-window boundaries, permission revocation, and sound/notification settings. A persistent lockout or unusable release control blocks shipping. Simulator tests cannot close this gate.

Then recruit 20–30 adults with myopia or recurring screen discomfort for two weeks of use. Include people who ignore reminders and a subset willing to compare Noonrre or ScreenZen. Test usability and adherence, keeping manual use and automatic-pause use distinct. Proposed internal decision rules, not industry benchmarks:

- No unresolved persistent lockouts or failed release controls on supported test devices.
- At least half of activated automatic-pause testers keep it enabled and record at least two timed rests on three separate days in week two.
- Testers can describe a concrete reason to choose Look Far over the free alternative they tried.
- Any comfort feedback is voluntary, subjective, and separate from medical efficacy claims.
- Track missing follow-up explicitly instead of dropping nonresponders from retention denominators.

The current app stores local rest history; it does not implement a research backend or an export workflow. Agree on beta follow-up and data collection before enrollment. RevenueCat Test Store, TestFlight sandbox, and optional local StoreKit transactions are simulations, not willingness-to-pay evidence.

**Recurring pricing is the chosen direction:** feature US$39.99/year and retain US$7.99/month, showing the full annual charge and renewal terms clearly. Test conversion, cancellation, and sustained use before treating either price as validated. Free beta access remains appropriate while physical behavior and the paid offering are being tested. The existing free competitors make reliable pauses, a satisfying daily experience, and useful progress feedback important to evaluate; annual presentation alone does not establish value.

Keep camera/gaze measurement, AI advice, visual-acuity tests, treatment claims, exercise libraries, parent/child management, social rewards, streak penalties, Watch/macOS clients, HealthKit, cloud sync, multiple rule groups, and desktop tracking outside this MVP. If users mostly need breaks at a laptop, revisit the device strategy before broadening the iPhone scope.
