<?php
namespace App\Http\Controllers;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
class AdminController extends Controller {
    public function dashboard() {
        $today=DB::table('api_usage')->where('created_at','>=',today());
        $total=(clone $today)->count(); $hits=(clone $today)->where('cache_hit',true)->count();
        $requests=(clone $today)->sum('request_count'); $quota=config('matchiq.provider_quota');
        return ['users'=>User::count(),'daily_active'=>User::where('last_active_at','>=',now()->subDay())->count(),
            'monthly_active'=>User::where('last_active_at','>=',now()->subDays(30))->count(),
            'pro_users'=>DB::table('subscriptions')->where('status','active')->where('expires_at','>',now())->distinct()->count('user_id'),
            'predictions'=>DB::table('predictions')->count(),'ad_events'=>DB::table('ad_events')->count(),
            'requests_today'=>(int)$requests,'daily_quota'=>$quota,'remaining_quota'=>max(0,$quota-$requests),
            'quota_warning'=>$requests >= $quota*.95 ? 95:($requests >= $quota*.85 ? 85:($requests >= $quota*.70 ? 70:null)),
            'cache_hit_percent'=>$total ? $hits/$total*100 : null,'errors'=>(clone $today)->where('status','>=',400)->count(),
            'average_response_ms'=>(clone $today)->where('cache_hit',false)->avg('response_time'),
            'last_sync'=>DB::table('fixtures')->max('synced_at'),
            'analysis_volume'=>DB::table('predictions')->selectRaw('DATE(generated_at) as date, COUNT(*) as count')->groupByRaw('DATE(generated_at)')->orderBy('date')->get(),
            'model_performance'=>DB::table('prediction_results')->selectRaw('market, COUNT(*) as count, AVG(brier_score) as brier_score, AVG(log_loss) as log_loss')->groupBy('market')->get()];
    }
    public function users(Request $r) { return User::when($r->filled('search'),fn($q)=>$q->where('email','like','%'.substr($r->search,0,100).'%'))->paginate(30); }
    public function disable(Request $r,User $user) {
        $r->validate(['disabled'=>'required|boolean']); abort_if($user->id===$r->user()->id,422,'Cannot disable own account.');
        DB::transaction(function() use($r,$user) {
            $user->forceFill(['disabled_at'=>$r->boolean('disabled') ? now():null])->save();
            if($r->boolean('disabled')) $user->tokens()->delete();
            $this->audit($r,'account.status',(string)$user->id,['disabled'=>$r->boolean('disabled')]);
        }); return ['user'=>$user];
    }
    public function settings() { return DB::table('app_settings')->get(); }
    public function updateSetting(Request $r,string $key) {
        $rules=['free_limit'=>'integer|min:0|max:100','pro_limit'=>'integer|min:1|max:1000','maintenance'=>'boolean',
            'featured_leagues'=>'array','ad_placements'=>'array'];
        abort_unless(isset($rules[$key]),422,'Unknown setting.'); $data=$r->validate(['value'=>'required|'.$rules[$key]]);
        DB::table('app_settings')->updateOrInsert(['key'=>$key],['value'=>json_encode($data['value']),'created_at'=>now(),'updated_at'=>now()]);
        $this->audit($r,'settings.update',$key,$data); return ['saved'=>true];
    }
    private function audit(Request $r,string $action,string $target,array $metadata) {
        DB::table('audit_logs')->insert(['user_id'=>$r->user()->id,'action'=>$action,'target'=>$target,'metadata'=>json_encode($metadata),'created_at'=>now()]);
    }
}
