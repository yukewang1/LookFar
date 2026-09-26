# Look Far forest update QA

This update replaces the earlier rest-launch screen and routine picker with a daily forest dashboard. The old source-matching report no longer describes the current layout.

Visual QA uses the Look Far iPhone Simulator, iOS 26.5, at 390 × 844 points; native captures are 1170 × 2532 pixels. Verified captures: `Design/QA/guided-rest-concise.png`, `Design/QA/screen-time-required.png`, `Design/QA/screen-time-revoked.png`, and `Design/QA/settings-custom-rhythm.png`. UI completion tests use accelerated timers; the onboarding trial lasts 10 seconds, and normal rests use the duration saved in Settings (20 seconds by default). The app keeps its forest, ivory, sage, serif headings, and native three-tab navigation.

- Onboarding has one concise introduction that starts a 10-second guided trial immediately. Completion and Skip both lead to required Screen Time access before the minimal paywall. Denial offers no bypass. Primary actions stay visible.
- Settings alone offers screen-use and rest-duration controls, both in steps of 5. Automatic pauses run 24/7 without start/end-hour selectors; users can skip each break.
- During a break, “Look far.”, a brief end cue, seconds remaining, elapsed progress, and Skip accompany the quiet horizon. Countdown/progress use the saved session deadline. Reduce Motion disables the repeating horizon and progress animation. Every completed rest earns a tree.
- Today shows an initially empty grove, growing one tree per completed rest that day. It resets at local midnight without deleting history. The grove scrolls horizontally as it grows; Screen Time, rest totals, and a small manual-break action sit below it.
- Progress shows lifetime trees/streak, weekly/monthly completed-break charts, rest duration, and dated history. Confirmations/skips stay distinct.
- The paywall contains only its title, a short free-placeholder label, and Continue. Learn remains the third tab. Revoking Screen Time access closes membership/settings or the active rest and blocks the main UI. Interrupted rests earn no tree; past history remains intact.

Validation: 15 core tests, 3 monitoring-configuration tests, and 16 Simulator UI tests pass; the unsigned iOS Release build succeeds. The initial UI run passed 15/16 flows; after correcting the custom-rhythm test to use the captured native Stepper identifiers, its targeted rerun passed. Run the core command in `README.md` and Xcode **Product → Test**. UI coverage includes onboarding, demo skip, denied access, Simulator gating, revoked access during onboarding/settings/membership/rest, authorized session restoration, tree rewards, Progress, and Learn. Current run results are recorded in the pull request.

Physical-device Screen Time authorization, all-app threshold/shield behavior, actual report totals, audio/haptics, VoiceOver traversal, and the largest Dynamic Type sizes still need device QA. Normal Simulator runs preview the intro/rest but stop at the required-access gate. DEBUG UI tests use explicit authorization fixtures to test dashboard and permission states; they do not simulate real usage totals. Screen Time device behavior still needs signed physical-iPhone QA.
