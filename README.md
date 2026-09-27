# MatchIQ

Analyze • Understand • Decide

Football intelligence application built in the existing Arafat-ally/Mach-iq repository.

## Work in progress

This initial checkpoint is **not a production release**. Implementation and verification are ongoing. The mobile UI is being connected and is not yet build-verified. No Railway services have been deployed by this change. No live football data or predictions are seeded.

## Repository

- `backend/`: Laravel API, authentication, provider caching, fixture synchronization, immutable prediction snapshots, account data, subscription verification and admin endpoints.
- `mobile/`: Flutter Android/iOS/web application; work in progress.
- `prediction/`: Python FastAPI statistical Poisson service, feature extraction and evaluation.

## Verification at this checkpoint

- Python: 6 model/API tests passed.
- Laravel: initial schema migrations ran successfully against a local SQLite test database. PostgreSQL verification pending.
- Flutter: dependency installation succeeded; analysis/build checks pending.
- Railway: not deployed or verified.

## Configuration

Use `backend/.env.example` for required server configuration. Never put server credentials in the mobile app. Provider data needs `API_FOOTBALL_KEY`; prediction requests need a shared `PREDICTION_SERVICE_KEY`; subscriptions use server-verified RevenueCat entitlements. OAuth and push need Firebase configuration. Credentials are not committed.

Predictions are statistical estimates and do not guarantee outcomes. The initial Poisson model is not empirically calibrated; its limitations accompany every prediction.
