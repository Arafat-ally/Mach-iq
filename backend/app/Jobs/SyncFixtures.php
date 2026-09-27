<?php
namespace App\Jobs;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use App\Services\FixtureSync;
class SyncFixtures implements ShouldQueue {
    use Queueable;
    public int $tries=3;
    public int $timeout=30;
    public function __construct(public array $filters) {}
    public function backoff(): array { return [30,120,600]; }
    public function handle(FixtureSync $sync): void { $sync->sync($this->filters); }
}
