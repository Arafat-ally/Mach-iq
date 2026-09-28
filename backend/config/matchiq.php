<?php
return [
    'provider_key' => trim((string) env('API_FOOTBALL_KEY', '')),
    'provider_url' => 'https://v3.football.api-sports.io',
    'provider_quota' => (int) env('API_FOOTBALL_DAILY_QUOTA', 100),
    'prediction_url' => env('PREDICTION_ENGINE_URL'),
    'prediction_key' => env('PREDICTION_SERVICE_KEY'),
    'free_limit' => (int) env('FREE_DAILY_ANALYSES', 3),
    'pro_limit' => (int) env('PRO_DAILY_ANALYSES', 100),
    'sync_leagues' => array_filter(explode(',', env('SYNC_LEAGUE_IDS', ''))),
    'frontend_url' => env('FRONTEND_URL', 'http://localhost:3000'),
    'ttl' => ['countries' => 604800, 'leagues' => 86400, 'teams' => 86400,
        'fixtures' => 300, 'fixtures/live' => 30, 'standings' => 3600,
        'fixtures/lineups' => 900, 'odds' => 1800, 'default' => 3600],
];
