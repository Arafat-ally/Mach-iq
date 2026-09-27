<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\Prediction;
class EvaluatePredictions extends Command {
    protected $signature='predictions:evaluate';
    protected $description='Lock pre-match snapshots and settle completed 90-minute markets';
    public function handle(): int {
        Prediction::whereNull('locked_at')->whereHas('fixture',fn($q)=>$q->where('kickoff','<=',now()))->update(['locked_at'=>now()]);
        Prediction::with('fixture')->whereHas('fixture',fn($q)=>$q->where('status','FT')->whereNotNull('home_goals')->whereNotNull('away_goals'))
            ->chunkById(100,function($predictions) {
                foreach($predictions as $p) {
                    $f=$p->fixture; $h=$f->home_goals; $a=$f->away_goals;
                    // Only FT (regulation time) is settled. Extra time, cancellations and abandoned matches are excluded.
                    $outcomes=['1x2'=>$h>$a ? 'home':($h===$a ? 'draw':'away'),'btts'=>$h>0 && $a>0 ? 'yes':'no'];
                    foreach([0.5,1.5,2.5,3.5] as $line) $outcomes['goals_'.$line]=$h+$a>$line ? 'over':'under';
                    foreach($outcomes as $market=>$outcome) {
                        $values=$p->output['markets'][$market] ?? []; if(!$values) continue;
                        $best=array_keys($values)[0]; $brier=0;
                        foreach($values as $selection=>$value) {
                            $brier+=($value['probability']-(int)($selection===$outcome))**2;
                            if($value['probability']>$values[$best]['probability']) $best=$selection;
                        }
                        DB::table('prediction_results')->insertOrIgnore(['prediction_id'=>$p->id,'market'=>$market,'outcome'=>$outcome,
                            'correct'=>$best===$outcome,'brier_score'=>$brier,'log_loss'=>-log(max(1e-15,$values[$outcome]['probability'])),
                            'selected_probability'=>$values[$best]['probability'],'created_at'=>now(),'updated_at'=>now()]);
                    }
                }
            });
        return 0;
    }
}
