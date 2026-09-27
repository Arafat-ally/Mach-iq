<?php
namespace App\Services;
use App\Contracts\FootballDataProvider;
use App\Models\{Fixture, Team, League};
use Illuminate\Support\Facades\DB;
class FixtureSync {
    public function __construct(private FootballDataProvider $provider) {}
    public function sync(array $filters): array {
        $result = $this->provider->fetch('fixtures', $filters);
        foreach ($result['data'] as $row) {
            DB::transaction(function() use ($row, $result) {
                $league = League::updateOrCreate(['provider'=>'api-football','provider_external_id'=>(string)$row['league']['id']],
                    ['name'=>$row['league']['name'],'logo'=>$row['league']['logo'] ?? null,'data'=>$row['league'],'synced_at'=>$result['updated_at']]);
                $teams = [];
                foreach (['home','away'] as $side) {
                    $team = $row['teams'][$side];
                    $teams[$side] = Team::updateOrCreate(['provider'=>'api-football','provider_external_id'=>(string)$team['id']],
                        ['name'=>$team['name'],'logo'=>$team['logo'] ?? null,'data'=>$team,'synced_at'=>$result['updated_at']]);
                }
                Fixture::updateOrCreate(['provider'=>'api-football','provider_external_id'=>(string)$row['fixture']['id']],
                    ['league_id'=>$league->id,'home_team_id'=>$teams['home']->id,'away_team_id'=>$teams['away']->id,
                    'season'=>$row['league']['season'],'kickoff'=>\Carbon\Carbon::parse($row['fixture']['date'])->utc(),
                    'status'=>$row['fixture']['status']['short'],'elapsed'=>$row['fixture']['status']['elapsed'] ?? null,
                    'home_goals'=>$row['goals']['home'],'away_goals'=>$row['goals']['away'],'data'=>$row,'synced_at'=>$result['updated_at']]);
            });
        }
        return $result;
    }
}
