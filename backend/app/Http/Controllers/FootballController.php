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
            'live'=>'nullable|boolean','league_id'=>'nullable|integer','team_id'=>'nullable|integer','search'=>'nullable|string|max:100']);
        $zone = $data['timezone'] ?? 'UTC';
        if (!isset($data['timezone']) && isset($data['utc_offset'])) {
            $offset=(int)$data['utc_offset'];
            $zone=sprintf('%s%02d:%02d',$offset<0 ? '-' : '+',intdiv(abs($offset),60),abs($offset)%60);
        }
        $day = CarbonImmutable::parse($data['date'] ?? now($zone)->toDateString(),$zone)->startOfDay();
        $query = Fixture::with(['homeTeam','awayTeam','league']);
        if ($r->boolean('live')) $query->whereIn('status',['1H','HT','2H','ET','BT','P','LIVE']);
        elseif (!$r->filled('team_id')) $query->where('kickoff','>=',$day->utc())->where('kickoff','<',$day->addDay()->utc());
        if ($r->filled('league_id')) $query->where('league_id',$data['league_id']);
        if ($r->filled('team_id')) $query->where(fn($q)=>$q->where('home_team_id',$data['team_id'])->orWhere('away_team_id',$data['team_id']));
        if ($r->filled('search')) $query->where(fn($q)=>$q->whereHas('homeTeam',fn($t)=>$t->where('name','like','%'.$data['search'].'%'))->orWhereHas('awayTeam',fn($t)=>$t->where('name','like','%'.$data['search'].'%')));
        $rows = $query->orderBy('kickoff')->paginate(100);
        return response()->json(['data'=>$rows->items(),'next_page'=>$rows->nextPageUrl(),
            'synced_at'=>Fixture::max('synced_at'),'stale'=>!Fixture::where('synced_at','>',now()->subMinutes(10))->exists(),
            'provider_configured'=>(bool)config('matchiq.provider_key')]);
    }
    public function fixture(Fixture $fixture) { return ['data'=>$fixture->load(['homeTeam','awayTeam','league'])]; }
    public function detail(Request $r, Fixture $fixture, string $section, FootballDataProvider $provider) {
        $map = ['statistics'=>'fixtures/statistics','events'=>'fixtures/events','lineups'=>'fixtures/lineups','injuries'=>'injuries','odds'=>'odds','h2h'=>'fixtures/headtohead'];
        abort_unless(isset($map[$section]),404);
        if ($section === 'lineups' && $fixture->kickoff->isAfter(now()->addHours(2))) return ['data'=>[],'message'=>'Lineups are not available yet.','confirmed'=>false];
        $filters = $section === 'h2h' ? ['h2h'=>$fixture->homeTeam->provider_external_id.'-'.$fixture->awayTeam->provider_external_id,'last'=>10] : ['fixture'=>$fixture->provider_external_id];
        return $provider->fetch($map[$section],$filters);
    }
    public function leagues(Request $r) { return League::when($r->filled('search'), fn($q)=>$q->where('name','like','%'.substr($r->search,0,100).'%'))->orderBy('name')->paginate(100); }
    public function teams(Request $r) { return Team::when($r->filled('search'), fn($q)=>$q->where('name','like','%'.substr($r->search,0,100).'%'))->orderBy('name')->paginate(100); }
    public function league(Request $r, League $league, FootballDataProvider $provider) {
        $r->validate(['season'=>'nullable|integer|min:1900|max:2100']);
        $season = $r->integer('season') ?: Fixture::where('league_id',$league->id)->max('season');
        return ['data'=>$league,'standings'=>$season ? $provider->fetch('standings',['league'=>$league->provider_external_id,'season'=>$season]) : ['data'=>[]]];
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
