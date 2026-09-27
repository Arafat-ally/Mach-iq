<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use App\Services\FixtureSync;
class SyncFootball extends Command {
    protected $signature='football:sync {--date=} {--league=} {--season=} {--live}';
    protected $description='Synchronize provider fixtures without inserting demonstration data';
    public function handle(FixtureSync $sync): int {
        $filters=[];
        if($this->option('live')) $filters['live']='all';
        elseif($this->option('season')) {
            if(!$this->option('league')) { $this->error('--league is required with --season'); return 1; }
            $filters=['season'=>$this->option('season'),'league'=>$this->option('league')];
        } else $filters['date']=$this->option('date') ?: now('UTC')->toDateString();
        $result=$sync->sync($filters); $this->info(count($result['data']).' fixtures synchronized'); return 0;
    }
}
