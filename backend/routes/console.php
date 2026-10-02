<?php

use Illuminate\Support\Facades\Schedule;
use App\Jobs\SyncFixtures;
use App\Models\Fixture;

Schedule::call(function() {
    if (!config('matchiq.provider_key')) return;
    SyncFixtures::dispatch(['date'=>now('UTC')->toDateString()]);
    SyncFixtures::dispatch(['date'=>now('UTC')->addDay()->toDateString()]);
})->hourly()->name('fixtures-sync')->withoutOverlapping()->onOneServer();

Schedule::call(function() {
    if (!config('matchiq.provider_key')) return;
    $active=Fixture::whereBetween('kickoff',[now()->subHours(3),now()->addMinutes(5)])
        ->whereIn('status',['NS','1H','HT','2H','ET','BT','P','LIVE'])->exists();
    if($active) SyncFixtures::dispatch(['live'=>'all']);
})->everyFiveMinutes()->name('live-sync')->withoutOverlapping()->onOneServer();

Schedule::command('tickets:run')->hourlyAt(5)->withoutOverlapping(30)->onOneServer();
Schedule::command('tickets:run --settle-only')->everyMinute()->withoutOverlapping()->onOneServer();

Schedule::command('predictions:evaluate')->everyMinute()->withoutOverlapping()->onOneServer();
Schedule::command('sanctum:prune-expired --hours=24')->daily()->onOneServer();

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');
