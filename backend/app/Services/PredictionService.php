<?php
namespace App\Services;
use App\Models\{Fixture,Prediction};
use Illuminate\Support\Facades\{Cache,DB,Http};
class PredictionService {
    public function generate(Fixture $fixture): Prediction {
        return Cache::lock('prediction:'.$fixture->id,45)->block(5,function() use($fixture) {
            $existing=Prediction::where('fixture_id',$fixture->id)->latest('id')->first();
            if ($existing) return $existing;
            abort_if($fixture->kickoff->isPast() || $fixture->status !== 'NS',422,'Predictions must be generated before kickoff.');
            abort_unless(config('matchiq.prediction_url') && config('matchiq.prediction_key'),503,'Prediction service unavailable.');
            $snapshot=now();
            $payload=['fixture_id'=>$fixture->id,'kickoff'=>$fixture->kickoff->toIso8601String(),'snapshot_at'=>$snapshot->toIso8601String(),
                'home_history'=>$this->history($fixture,$fixture->home_team_id), 'away_history'=>$this->history($fixture,$fixture->away_team_id)];
            abort_if(count($payload['home_history'])<5 || count($payload['away_history'])<5,422,'Insufficient historical data for analysis.');
            try {
                $response=Http::withHeaders(['X-Service-Key'=>config('matchiq.prediction_key')])->timeout(20)->post(rtrim(config('matchiq.prediction_url'),'/').'/predict',$payload);
            } catch (\Illuminate\Http\Client\ConnectionException $e) { abort(503,'Prediction service unavailable.'); }
            abort_unless($response->successful(),503,'Prediction unavailable.');
            $output=$response->json();
            abort_unless(is_array($output['markets'] ?? null) && is_string($output['model_version'] ?? null),502,'Invalid prediction response.');
            foreach ($output['markets'] as $market=>$selections) {
                $sum=0;
                foreach ($selections as $selection=>$value) {
                    $p=$value['probability'] ?? -1;
                    abort_unless(is_numeric($p) && is_finite((float)$p) && $p>=0 && $p<=1,502,'Invalid probability.');
                    $sum+=$p;
                }
                abort_if($market!=='double_chance' && abs($sum-1)>0.00001,502,'Invalid probability sum.');
            }
            return DB::transaction(function() use($fixture,$payload,$output,$snapshot) {
                $current=Fixture::whereKey($fixture->id)->lockForUpdate()->firstOrFail();
                abort_if($current->kickoff->isPast() || $current->status!=='NS',422,'Kickoff reached; analysis locked.');
                $version=DB::table('model_versions')->where('name',$output['model_version'])->first();
                if (!$version) {
                    DB::table('model_versions')->insertOrIgnore(['name'=>$output['model_version'],'metadata'=>json_encode(['calibrated'=>false]),'created_at'=>now(),'updated_at'=>now()]);
                    $version=DB::table('model_versions')->where('name',$output['model_version'])->first();
                }
                $prediction=Prediction::create(['fixture_id'=>$fixture->id,'model_version_id'=>$version->id,'generated_at'=>now(),
                    'data_snapshot_time'=>$snapshot,'data_quality'=>$output['data_quality'],'data_snapshot'=>$payload,'output'=>$output]);
                foreach($output['markets'] as $market=>$selections) foreach($selections as $selection=>$value) {
                    DB::table('prediction_probabilities')->insert(['prediction_id'=>$prediction->id,'market'=>$market,'selection'=>$selection,
                        'probability'=>$value['probability'],'fair_odds'=>$value['probability']>1e-9 ? 1/$value['probability'] : null,'created_at'=>now(),'updated_at'=>now()]);
                }
                DB::table('prediction_explanations')->insert(['prediction_id'=>$prediction->id,'factors'=>json_encode($output['factors'] ?? []),'created_at'=>now(),'updated_at'=>now()]);
                return $prediction;
            });
        });
    }
    private function history(Fixture $target,int $team): array {
        return Fixture::where('league_id',$target->league_id)->where('status','FT')->where('kickoff','<',now())->where('kickoff','<',$target->kickoff)
            ->whereNotNull('home_goals')->whereNotNull('away_goals')->where(fn($q)=>$q->where('home_team_id',$team)->orWhere('away_team_id',$team))
            ->orderByDesc('kickoff')->limit(20)->get()->map(fn($f)=>['fixture_id'=>$f->id,'played_at'=>$f->kickoff->toIso8601String(),
                'goals_for'=>$f->home_team_id===$team ? $f->home_goals : $f->away_goals,
                'goals_against'=>$f->home_team_id===$team ? $f->away_goals : $f->home_goals,'home'=>$f->home_team_id===$team])->all();
    }
}
