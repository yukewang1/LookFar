# Look Far design QA

Source: `Design/selected-reference.png`, selected concept 3. Final implementation: `Design/QA/today-final.png` and `today-final-normalized.png`.

Viewport: native iPhone 17e, 390 × 844 points, iOS 26.5. Implementation captures are 1170 × 2532 pixels at 3× density. The 853 × 1844 source and implementation were normalized to approximately 390 × 844 and opened together in the same comparison input. CSS viewport does not apply. Neither image includes a device bezel; the implementation uses the actual system status bar and native iOS tabs.

State: Today, classic 20/20 routine. The current empty history shows zero timed rests; the source illustrates four. This intentional content difference follows removal of sample data. The inactive monitoring line reflects Simulator capabilities. Look Far replaces the source’s placeholder name. These requested differences are excluded from fidelity findings.

## Comparison history

1. Initial checks found an untappable blank area in the progress row, an oversized landscape, and a truncated pause heading. Full hit shapes, constrained landscape dimensions, and a taller scrollable pause sheet resolved them. The original app flow tests passed after these fixes.
2. The first normalized comparison found a P2 hard lower edge on the landscape. A fade using the existing raster asset resolved it; subsequent combined source/implementation comparisons confirmed a seamless lower edge.
3. The Look Far rename removes demo copy, synthetic progress, and the testing lab. The latest source/Today pair was compared together after a clean Simulator restart. The new branding and zero-history state preserve the selected composition. Onboarding, plans, and active/restored purchase screens were inspected from native captures. The subtitle is readable, both actual plan prices and the purchase action are visible, and app-authored demo labels are absent. No actionable P0/P1/P2 findings remain at this viewport.

## Required fidelity surfaces

- **Typography:** native system serif headings retain the source’s two-line hierarchy. The generated source supplied no font file; system serif is an accepted approximation. Sans-serif labels and the new onboarding subtitle remain readable. No primary heading truncation is visible.
- **Spacing:** 24-point main margins, cream capsule action, routine summary, reset, and progress shortcut retain the composition. Image height accommodates native safe areas. Native floating tabs are an intentional platform difference. Onboarding remains scrollable and its Continue action is visible at the tested size.
- **Colors:** shared forest, ivory, sage, and secondary-text tokens preserve the visual direction. Background grain outside the landscape is omitted as an accepted native simplification.
- **Imagery:** the actual generated raster preserves lake, layered hills, left-side pines, and distant warm moon. The lower fade has no visible seam. Smaller moon and different tree silhouettes are P3 differences; no code-drawn replacement is used.
- **Copy/content:** Look Far and Eye Strain Relief & Breaks are the chosen brand and subtitle. Timed rests, confirmed breaks, and skips remain distinct. Prices come from RevenueCat. Health limitations, billing terms, and privacy information remain; app-authored demo/prototype wording and synthetic history are removed.

The normalized comparison makes layout, type, and controls readable without a separate crop. Onboarding and plan text were also inspected in larger native captures. App-owned content is distinguished from system chrome.

## Verification and remaining gaps

- Renamed app build passed; all 9 core tests and all 4 iOS UI tests passed (`/tmp/lookfar-renamed-tests.xcresult`).
- Covered onboarding, timed completion/history, routine changes, confirmed breaks without inflated timed-rest or skip counts, metrics/learning navigation, annual/monthly selection, RevenueCat prices, cancellation, simulated failure/success, restore, and retained entitlement after relaunch.
- Normal launches use actual history and full rest durations. RevenueCat’s SDK-owned Test Store confirmation remains part of local purchase testing.
- Physical-device Screen Time behavior, Apple sandbox/TestFlight purchases, largest Dynamic Type sizes, and VoiceOver traversal remain unvalidated. The removed pause preview is no longer a test surface; physical automatic pauses still require device validation.
- Source-font approximation, native floating tabs, and minor landscape differences remain accepted P3 refinements.

final result: passed
