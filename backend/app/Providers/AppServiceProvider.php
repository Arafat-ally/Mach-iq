<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(\App\Contracts\FootballDataProvider::class, \App\Services\ApiFootballProvider::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        \Illuminate\Support\Facades\RateLimiter::for('api', fn($r) => \Illuminate\Cache\RateLimiting\Limit::perMinute(120)->by($r->user()?->id ?: $r->ip()));
        \Illuminate\Support\Facades\RateLimiter::for('auth', fn($r) => [\Illuminate\Cache\RateLimiting\Limit::perMinute(10)->by($r->ip()), \Illuminate\Cache\RateLimiting\Limit::perMinute(5)->by(strtolower((string)$r->input('email')))]);
        \Illuminate\Support\Facades\RateLimiter::for('analysis', fn($r) => \Illuminate\Cache\RateLimiting\Limit::perMinute(5)->by($r->user()?->id ?: $r->ip()));
        \Illuminate\Support\Facades\RateLimiter::for('search', fn($r) => \Illuminate\Cache\RateLimiting\Limit::perMinute(30)->by($r->user()?->id ?: $r->ip()));
        \Illuminate\Auth\Notifications\ResetPassword::createUrlUsing(fn($user,$token) => config('matchiq.frontend_url').'/#/reset-password?token='.urlencode($token).'&email='.urlencode($user->email));
    }
}
