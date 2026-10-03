# MatchIQ offline demo (2.2.0+6)

Build with `flutter build apk --release --dart-define=DEMO_MODE=true`.
Without this flag the app continues to use the production API.

The demo displays a persistent DEMO / Sample data / Offline banner. All fixtures,
scores, odds, predictions, players and statistics are fictional examples, even
when recognizable club names are used. It makes no football API requests and
does not require an API key. Club badges use local initials.

Included flows:
- Upcoming, live and finished fixtures; date, league and search filters.
- Match statistics, events, H2H, lineups, injuries, momentum and analysis.
- Four daily ticket categories with 30 days of example history.
- Select matches, preview and save a personal analysis; saved odds remain fixed.
- Favorites, bookmarks, notifications, personal and daily performance.
- Name/email account entry, profile edits and a local Demo Pro membership.

Profile > Demo Controls > Simulate Results settles saved pending personal
analyses. Open My Analyses to inspect their results and performance. This does
not settle production tickets. Demo Pro can be switched off and on without a
payment provider. Push notifications are represented locally, not delivered.

Demo accounts and saved items use separate `demo:` preferences. Production
tokens are neither read nor overwritten. Data stays on the device; uninstalling
or clearing application storage removes it. A fresh installation starts with a
sample account. No email is sent and no purchase is made.

Verification: nine Flutter tests pass, including demo fixture/section coverage,
save idempotency, local persistence, settlement, independent public performance
and narrow-screen rendering/navigation. See ANDROID-2.1-VERIFICATION.md for the
branding assets and generated stadium prompt retained in this release.
