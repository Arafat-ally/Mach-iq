<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use App\Services\{TicketDataSync,TicketService};
use Illuminate\Support\Facades\Cache;
class TicketPipeline extends Command {
    protected $signature='tickets:run {--settle-only}';
    protected $description='Synchronize real data, generate daily tickets and settle immutable snapshots';
    public function handle(TicketDataSync $sync,TicketService $tickets): int {
        if(!$this->option('settle-only')){$errors=$sync->prepare();foreach($errors as $error)$this->warn($error);$this->info($tickets->daily().' daily tickets generated.');}
        $tickets->settle();Cache::put('tickets:last_settlement',now()->toIso8601String(),86400);return 0;
    }
}
