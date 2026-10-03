# MatchIQ 2.1 Android verification

## Implemented in this release

- Supplied gold MATCHIQ crest is used without redrawing it, including Android launcher and native launch screen, welcome, account screens, header and profile.
- Stadium background, compact navy/blue/gold interface, name-and-email device registration retained by explicit user choice. Existing password accounts remain supported; unconfigured social buttons are hidden.
- Main navigation: Home, Matches, Analysis, Tickets, Profile. Leagues remain reachable from Home and Search.
- Matches offers date navigation and All / Upcoming / Live / Finished with server-side status filtering before pagination. A delayed fixture still marked NS by the provider remains upcoming, independently of the phone clock.
- Human-readable ticket categories, match statuses and dates. H2H summaries and explicit empty states.
- Daily generator prioritizes fixtures with actual available quotes; odds pagination is bounded at three pages to protect the free provider quota. League history fetching follows these same eligible fixtures.
- Existing ticket snapshots, ownership, settlement and separate daily/personal statistics remain intact.

## Verification

- Backend: 26 tests, 149 assertions including ownership, immutable snapshots, losing tickets, regulation time, quota, provider caching and status/date groups.
- Flutter: 6 tests including device form, navigation/Arabic RTL, empty data, offline data, and branded welcome/account layouts at 320x640 and 800x1100.
- Signed Android release passed emulator startup/foreground/crash checks. Welcome, Create Account and Home screenshots inspected on Android API 30. Get Started opened the device-account form correctly. APK signature matches the prior release.

## External or incomplete production requirements

This is not a declaration that the entire master prompt is production complete.

- Current provider data and quota determine whether enough fixtures, recent history and bookmaker odds exist to publish each category. Empty categories are never filled with fabricated selections.
- Prediction engine is the existing historical-goals statistical model, not a calibrated model incorporating every requested injury/xG/lineup feature. The app states available limitations.
- Momentum is unavailable because no reliable provider time series is configured. Unsupported corners/cards predictions are not generated or guessed.
- SMTP delivery, Firebase push, social sign-in, store subscription configuration, final operator legal/support details require production configuration; no live end-to-end claim is made for those services.
- Completed automated settlement is covered by database tests; full production settlement requires official fixture results to arrive.
- Further device coverage, accessibility, complete translation of all secondary copy, and broader end-to-end account/paid-plan QA remain release work.

## Artwork

Original user-supplied crest: `mobile/assets/branding/matchiq-crest.png` (unchanged copy).
Generated background: `mobile/assets/branding/stadium.png`.
Generated with built-in imagegen, not an external CLI. Prompt: "Create a production mobile app BACKGROUND bitmap only, portrait 9:16. Premium football analytics stadium at night, near-black deep navy upper 65 percent with very subtle blue storm clouds, stadium floodlights far left/right edges around lower middle, electric blue and small gold light strips around stadium seating along lower third, realistic lush pitch at bottom 15 percent. A small football at bottom center, mostly obscured by shadow. Photoreal cinematic polished sports branding. Center area dark and calm to place actual login form over. No logos, no text, no letters, no UI, no phone frame. This is an atmospheric background for MATCHIQ app whose supplied logo is gold crowned M with electric blue accents; do not draw any logo."
