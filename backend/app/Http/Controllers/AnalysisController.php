<?php
namespace App\Http\Controllers;
use App\Models\{Fixture,Prediction};
use App\Services\{Entitlements,PredictionService};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class AnalysisController extends Controller {
    public function create(Request $r, Entitlements $entitlements, PredictionService $service) {
        $data=$r->validate(['fixture_ids'=>'required|array|min:1|max:20','fixture_ids.*'=>'required|integer|distinct|exists:fixtures,id']);
        $ids=$data['fixture_ids'];
        abort_if(count($ids)>1 && !$entitlements->pro($r->user()),403,'Pro subscription required for multi-match analysis.');
        $date=now('UTC')->toDateString(); $entitlements->consume($r->user(),count($ids));
        $results=[];
        foreach($ids as $id) {
            try { $results[]=['fixture_id'=>$id,'prediction'=>$service->generate(Fixture::findOrFail($id))->load('fixture.homeTeam','fixture.awayTeam','fixture.league')]; }
            catch (\Throwable $e) {
                $entitlements->refund($r->user(),1,$date);
                $results[]=['fixture_id'=>$id,'error'=>$e instanceof \Symfony\Component\HttpKernel\Exception\HttpException ? $e->getMessage() : 'Analysis temporarily unavailable.'];
            }
        }
        return ['data'=>$results];
    }
    public function save(Request $r) {
        $data=$r->validate(['name'=>'required|string|max:100','matches'=>'required|array|min:1|max:20',
            'matches.*.prediction_id'=>'required|integer|exists:predictions,id','matches.*.market'=>'required|string|max:40','matches.*.selection'=>'required|string|max:40']);
        return DB::transaction(function() use($r,$data) {
            $id=DB::table('saved_analyses')->insertGetId(['user_id'=>$r->user()->id,'name'=>$data['name'],'created_at'=>now(),'updated_at'=>now()]);
            foreach($data['matches'] as $match) {
                abort_unless(DB::table('prediction_probabilities')->where($match)->exists(),422,'Unknown prediction selection.');
                DB::table('saved_analysis_matches')->insertOrIgnore($match+['saved_analysis_id'=>$id,'created_at'=>now(),'updated_at'=>now()]);
            }
            return response()->json(['id'=>$id],201);
        });
    }
    public function saved(Request $r) {
        $analyses=DB::table('saved_analyses')->where('user_id',$r->user()->id)->latest('id')->paginate(30);
        $analyses->getCollection()->transform(function($row) {
            $row->matches=DB::table('saved_analysis_matches')->where('saved_analysis_id',$row->id)->get()->map(function($match) {
                $match->prediction=Prediction::with('fixture.homeTeam','fixture.awayTeam','fixture.league')->find($match->prediction_id); return $match;
            }); return $row;
        });
        return $analyses;
    }
    public function delete(Request $r,int $id) {
        abort_unless(DB::table('saved_analyses')->where('id',$id)->where('user_id',$r->user()->id)->delete(),404);
        return response()->noContent();
    }
    public function history(Request $r, Entitlements $entitlements) {
        $r->validate(['days'=>'nullable|in:7,30,90,all','market'=>'nullable|string|max:40','model_version_id'=>'nullable|integer']);
        $days=$r->input('days','7');
        abort_if(($days==='all' || (int)$days>7) && !$entitlements->pro($r->user()),403,'Pro subscription required for extended history.');
        $q=DB::table('prediction_results')->join('predictions','predictions.id','=','prediction_results.prediction_id');
        if($days!=='all') $q->where('predictions.generated_at','>=',now()->subDays((int)$days));
        if($r->filled('market')) $q->where('market',$r->market);
        if($r->filled('model_version_id')) $q->where('model_version_id',$r->integer('model_version_id'));
        $rows=$q->select('prediction_results.*','predictions.model_version_id')->get();
        $total=$rows->count(); $correct=$rows->where('correct',true)->count();
        $bins=[];
        for($i=0;$i<10;$i++) {
            $bin=$rows->filter(fn($x)=>min(9,(int)floor($x->selected_probability*10))===$i);
            $bins[]=['lower'=>$i/10,'count'=>$bin->count(),'mean_probability'=>$bin->avg('selected_probability'),
                'observed_frequency'=>$bin->count() ? $bin->where('correct',true)->count()/$bin->count() : null];
        }
        return ['total'=>$total,'correct'=>$correct,'incorrect'=>$total-$correct,'accuracy'=>$total ? $correct/$total : null,
            'brier_score'=>$rows->avg('brier_score'),'log_loss'=>$rows->avg('log_loss'),'calibration'=>$bins,
            'data'=>$rows->take(500)->values(),'model_versions'=>DB::table('model_versions')->get()];
    }
}
