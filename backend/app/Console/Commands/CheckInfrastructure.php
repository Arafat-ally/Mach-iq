<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\{DB,Cache,Redis};
class CheckInfrastructure extends Command {
    protected $signature='matchiq:check-infrastructure';
    protected $description='Verify PostgreSQL and real Redis connectivity without revealing credentials';
    public function handle(): int {
        try {
            DB::select('select 1'); Redis::ping();
            Cache::put('matchiq:infrastructure-check','ok',30);
            if(Cache::get('matchiq:infrastructure-check')!=='ok') throw new \RuntimeException('Cache verification failed');
            $this->info('Database and Redis connected.'); return 0;
        } catch (\Throwable $e) { $this->error('Infrastructure unavailable. Check private service configuration.'); return 1; }
    }
}
