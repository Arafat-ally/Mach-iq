<?php
namespace App\Services;
use App\Contracts\FootballDataProvider;
use App\Models\Fixture;
use Illuminate\Support\Facades\{DB,Cache};
class TicketDataSync {
    public function __construct(private FootballDataProvider $provider,private FixtureSync $fixtures) {}
    public function quotes(array $filters): int {
        $result=$this->provider->fetch('odds',$filters);if($result['stale'])return 0;$count=0;
        foreach($result['data'] as $row) {
            $f=Fixture::where('provider_external_id',(string)data_get($row,'fixture.id'))->first();if(!$f||$f->kickoff->isPast())continue;
            $observed=\Carbon\Carbon::parse($row['update']??$result['updated_at']);
            foreach($row['bookmakers']??[] as $book)foreach($book['bets']??[] as $bet)foreach($bet['values']??[] as $value){
                $mapped=MarketCatalog::map((int)$bet['id'],(string)$value['value']);$odds=filter_var($value['odd']??null,FILTER_VALIDATE_FLOAT);
                if(!$mapped||!$odds||!is_finite($odds)||$odds<=1||$odds>1000)continue;
                DB::table('market_quotes')->updateOrInsert(['fixture_id'=>$f->id,'market'=>$mapped[0],'selection'=>$mapped[1],'bookmaker'=>(string)$book['name']],
                    ['odds'=>$odds,'observed_at'=>$observed,'created_at'=>now(),'updated_at'=>now()]);$count++;
            }
        }
        return $count;
    }
    public function prepare(): array {
        $errors=[];
        foreach([now('UTC')->toDateString(),now('UTC')->addDay()->toDateString()] as $date) {
            try{$this->fixtures->sync(['date'=>$date]);}catch(\Throwable $e){$errors[]='Fixtures: '.$e->getMessage();}
        }
        // A league-season request supplies both teams' past results with one cacheable request.
        $leagues=Fixture::with('league')->where('kickoff','>',now())->where('kickoff','<',now()->addDay())->orderByDesc('featured')->get()->unique('league_id')->take(4);
        foreach($leagues as $f) {
            $key='history-seeded:'.$f->league_id.':'.$f->season;
            if(Cache::has($key))continue;
            try{$this->fixtures->sync(['league'=>$f->league->provider_external_id,'season'=>$f->season]);Cache::put($key,true,86400);}
            catch(\Throwable $e){$errors[]='Historical results: '.$e->getMessage();}
        }
        try{$this->quotes(['date'=>now('UTC')->toDateString(),'page'=>1]);}catch(\Throwable $e){$errors[]='Odds: '.$e->getMessage();}
        // Settle selected historical fixtures too, even after a multi-day service outage.
        $ids=DB::table('daily_ticket_items')->where('status','PENDING')->pluck('fixture_id')->merge(DB::table('user_analysis_items')->where('status','PENDING')->pluck('fixture_id'))->unique();
        $external=Fixture::whereIn('id',$ids)->where('kickoff','<',now())->pluck('provider_external_id');
        foreach($external->chunk(20) as $chunk)try{$this->fixtures->sync(['ids'=>$chunk->implode('-')]);}catch(\Throwable $e){$errors[]='Settlement sync: '.$e->getMessage();}
        Cache::put('tickets:data_status',['updated_at'=>now()->toIso8601String(),'errors'=>array_values(array_unique($errors))],86400);return $errors;
    }
}
