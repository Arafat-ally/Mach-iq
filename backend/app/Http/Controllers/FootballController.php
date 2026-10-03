<?php
namespace App\Http\Controllers;
use App\Contracts\FootballDataProvider;
use App\Models\{Fixture,League,Team};
use App\Services\FixtureSync;
use Illuminate\Http\Request;
use Carbon\CarbonImmutable;
class FootballController extends Controller {
    public function fixtures(Request $r) {
        $data = $r->validate(['date'=>'nullable|date_format:Y-m-d','timezone'=>'nullable|timezone','utc_offset'=>'nullable|integer|between:-840,840',
            'group'=>'nullable|in:all,upcoming,live,finished','range'=>'nullable|in:results,upcoming','live'=>'nullable|boolean','league_id'=>'nullable|integer','team_id'=>'nullable|integer','search'=>'nullable|string|max:100']);
        $zone = $data['timezone'] ?? 'UTC';
        if (!isset($data['timezone']) && isset($data['utc_offset'])) {
            $offset=(int)$data['utc_offset'];
            $zone=sprintf('%s%02d:%02d',$offset<0 ? '-' : '+',intdiv(abs($offset),60),abs($offset)%60);
        }
        $day = CarbonImmutable::parse($data['date'] ?? now($zone)->toDateString(),$zone)->startOfDay();
        $query = Fixture::with(['homeTeam','awayTeam','league']);
        if ($r->boolean('live')) $query->whereIn('status',['1H','HT','2H','ET','BT','P','LIVE']);
        elseif (!$r->filled('team_id') && !$r->filled('range')) $query->where('kickoff','>=',$day->utc())->where('kickoff','<',$day->addDay()->utc());
        if($r->input('group')==='upcoming')$query->whereIn('status',['NS','TBD']);
        if($r->input('group')==='live')$query->whereIn('status',['1H','HT','2H','ET','BT','P','LIVE']);
        if($r->input('group')==='finished')$query->whereIn('status',['FT','AET','PEN']);
        if($r->input('range')==='results')$query->whereIn('status',['FT','AET','PEN'])->where('kickoff','<',now());
        if($r->input('range')==='upcoming')$query->where('kickoff','>',now());
        if ($r->filled('league_id')) $query->where('league_id',$data['league_id']);
        if ($r->filled('team_id')) $query->where(fn($q)=>$q->where('home_team_id',$data['team_id'])->orWhere('away_team_id',$data['team_id']));
        if ($r->filled('search')) $query->where(fn($q)=>$q->whereHas('homeTeam',fn($t)=>$t->where('name','like','%'.$data['search'].'%'))->orWhereHas('awayTeam',fn($t)=>$t->where('name','like','%'.$data['search'].'%'))->orWhereHas('league',fn($t)=>$t->where('name','like','%'.$data['search'].'%')->orWhere('data->country','like','%'.$data['search'].'%')));
        $rows = $query->orderBy('kickoff',$r->input('range')==='results'?'desc':'asc')->paginate(100);
        return response()->json(['data'=>$rows->items(),'next_page'=>$rows->nextPageUrl(),
            'synced_at'=>Fixture::max('synced_at'),'stale'=>!Fixture::where('synced_at','>',now()->subMinutes(10))->exists(),
            'provider_configured'=>(bool)config('matchiq.provider_key')]);
    }
    public function fixture(Fixture $fixture) { return ['data'=>$fixture->load(['homeTeam','awayTeam','league'])]; }
    public function detail(Request $r, Fixture $fixture, string $section, FootballDataProvider $provider) {
        if($section==='momentum')return ['data'=>[],'supported'=>false,'message'=>'The connected provider does not supply a reliable momentum time series. Match events are available separately.'];
        if($section==='analysis')return ['data'=>\App\Models\Prediction::where('fixture_id',$fixture->id)->latest('id')->first()];
        if(in_array($section,['home_form','away_form']))return $provider->fetch('fixtures',['team'=>($section==='home_form'?$fixture->homeTeam:$fixture->awayTeam)->provider_external_id,'last'=>5]);
        $map = ['statistics'=>'fixtures/statistics','events'=>'fixtures/events','lineups'=>'fixtures/lineups','injuries'=>'injuries','odds'=>'odds','h2h'=>'fixtures/headtohead'];
        abort_unless(isset($map[$section]),404);
        if ($section === 'lineups' && $fixture->kickoff->isAfter(now()->addHours(2))) return ['data'=>[],'message'=>'Lineups are not available yet.','confirmed'=>false];
        $filters = $section === 'h2h' ? ['h2h'=>$fixture->homeTeam->provider_external_id.'-'.$fixture->awayTeam->provider_external_id,'last'=>10] : ['fixture'=>$fixture->provider_external_id];
        $cacheKey='completed-section:'.$fixture->id.':'.$section;
        if(in_array($fixture->status,['FT','AET','PEN'])&&in_array($section,['statistics','events','lineups'])) {
            if($cached=\Illuminate\Support\Facades\Cache::get($cacheKey))return $cached;
            $result=$provider->fetch($map[$section],$filters);
            if(!$result['stale']&&!empty($result['data']))\Illuminate\Support\Facades\Cache::put($cacheKey,$result,604800);
            return $result;
        }
        return $provider->fetch($map[$section],$filters);
    }
    public function leagues(Request $r) { return League::when($r->boolean('popular'),fn($q)=>$q->where(fn($q)=>$q->where('featured',true)->orWhereIn('provider_external_id',['2','3','39','140','135','78','61','307'])))->when($r->filled('search'), fn($q)=>$q->where('name','like','%'.substr($r->search,0,100).'%'))->orderBy('name')->paginate(100); }
    public function teams(Request $r) { return Team::when($r->filled('search'), fn($q)=>$q->where('name','like','%'.substr($r->search,0,100).'%'))->orderBy('name')->paginate(100); }
    public function league(Request $r, League $league, FootballDataProvider $provider) {
        $r->validate(['season'=>'nullable|integer|min:1900|max:2100']);
        $season = $r->integer('season') ?: Fixture::where('league_id',$league->id)->max('season');
        try{$standings=$season?$provider->fetch('standings',['league'=>$league->provider_external_id,'season'=>$season]):['data'=>[]];}catch(\Throwable $e){$standings=['data'=>[],'unavailable'=>true];} return ['data'=>$league,'standings'=>$standings];
    }
    public function team(Team $team, FootballDataProvider $provider) {
        return ['data'=>$team,'squad'=>$provider->fetch('players/squads',['team'=>$team->provider_external_id])];
    }
    public function search(Request $r) {
        $r->validate(['q'=>'required|string|min:2|max:100']); $pattern='%'.$r->q.'%';
        return ['teams'=>Team::where('name','like',$pattern)->limit(20)->get(), 'leagues'=>League::where('name','like',$pattern)->limit(20)->get(),
            'fixtures'=>Fixture::with(['homeTeam','awayTeam','league'])->where(fn($q)=>$q->whereHas('homeTeam',fn($t)=>$t->where('name','like',$pattern))->orWhereHas('awayTeam',fn($t)=>$t->where('name','like',$pattern)))->orderByDesc('kickoff')->limit(20)->get()];
    }
}
