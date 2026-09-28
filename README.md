# MatchIQ

Analyze • Understand • Decide

Flutter Android/iOS football intelligence app backed by Laravel, PostgreSQL, Redis and a private Python Poisson prediction service. No demonstration football data is inserted into production.

## Repository

- `mobile/` — onboarding, email/social auth integration, fixtures/date/live browsing, match centers, analysis builder/results, favorites, saved analyses, model history, profile, localization and subscription/advertising integrations.
- `backend/` — Laravel REST API, Sanctum, RBAC admin panel, provider caching/quota locks, fixture sync, immutable prediction snapshots, entitlement verification, queues and scheduler.
- `prediction/` — FastAPI, time-weighted goal features, Poisson probabilities, fair odds, explanations and evaluation.
- `.github/workflows/ci.yml` — backend, PostgreSQL/Redis, Python and Flutter checks.
- `compose.yaml` — local multi-service deployment.

## Railway

Project: gregarious-enchantment (`d5d39dfc-0c21-44ff-9fb9-70f505bdebe1`).

API URL: https://mach-iq-production.up.railway.app

Configured services: Mach-iq API, Postgres, Redis, matchiq-prediction. API health endpoint reports individual dependency state without exposing secrets. `/up` is Laravel liveness. PostgreSQL schema migrations have run successfully. Additional worker and scheduler services must be provisioned from the backend image with SERVICE_ROLE=worker and SERVICE_ROLE=scheduler. These roles already exist in `backend/deploy/start.sh`.

API: root `/backend`, Dockerfile `/backend/Dockerfile`, port 8080, healthcheck `/up`. Start: `sh -c "php artisan migrate --force && exec sh deploy/start.sh"`.

Prediction: root `/prediction`, Dockerfile `/prediction/Dockerfile`, port 8000, healthcheck `/health`. Keep this service on private networking. Both services need the same PREDICTION_SERVICE_KEY. Set the API PREDICTION_ENGINE_URL to `http://matchiq-prediction.railway.internal:8000`.

Configure through Railway service settings. Config-as-code availability depends on the service's Railway migration eligibility; the Dockerfiles do not depend on legacy railway.json support.

## Required configuration

See `backend/.env.example`. Production requires APP_ENV=production, APP_DEBUG=false, APP_KEY, APP_URL, DB_CONNECTION=pgsql, DATABASE_URL, REDIS_URL, REDIS_CLIENT=predis, CACHE_STORE=redis and QUEUE_CONNECTION=redis.

API_FOOTBALL_KEY is server-only. Set API_FOOTBALL_DAILY_QUOTA to your actual provider subscription quota. Free-tier endpoint/season restrictions still apply; the app never invents unavailable data. Historical data for the target league is required for predictions: `php artisan football:sync --league=ID --season=YEAR`. This must be permitted by the provider plan. At least five completed matches per team are required.

SMTP must be configured for email verification/reset. Firebase credentials/project configuration are required for social identity and push. RevenueCat server secrets, entitlement `pro`, products and store setup are required for subscriptions. AdMob production IDs and consent configuration are required for ads. Never commit credentials or send server keys to Flutter.

## Local setup and checks

```sh
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan test
php artisan matchiq:check-infrastructure
php artisan football:sync
```

Run `php artisan queue:work redis` and `php artisan schedule:work` separately. Grant admin only to a verified existing account with `php artisan matchiq:admin EMAIL`.

```sh
cd prediction
python -m venv .venv
pip install -r requirements.txt
python -m pytest -q
uvicorn app.main:app --port 8000
```

Flutter build/signing instructions are in `mobile/README.md`. Android release keys and key.properties are excluded from version control and must be backed up securely. iOS build/signing needs macOS/Xcode.

## Verification and honest release status

Laravel: 15 tests / 58 assertions passed in the latest backend suite. Python: 6 tests passed. Flutter: 3 tests passed and static analysis passed. Railway PostgreSQL migrations and HTTP 200 liveness passed. Database, Redis and prediction service connectivity are verified. APK build is being verified separately.

This repository is not a claim of a fully validated store launch. Real provider coverage, delivery of email/push, store purchases, production ads, worker/scheduler provisioning, physical-device testing and operator privacy details require completion or owner configuration. The model is an uncalibrated statistical baseline; historical predictions remain immutable and limitations accompany outputs.

Predictions are statistical estimates and do not guarantee outcomes.
