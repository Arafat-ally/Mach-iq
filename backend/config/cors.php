<?php
return ['paths' => ['api/*'], 'allowed_methods' => ['*'],
    'allowed_origins' => array_filter(explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost:3000'))),
    'allowed_origins_patterns' => [], 'allowed_headers' => ['Content-Type', 'Authorization', 'Accept'],
    'exposed_headers' => [], 'max_age' => 600, 'supports_credentials' => false];
