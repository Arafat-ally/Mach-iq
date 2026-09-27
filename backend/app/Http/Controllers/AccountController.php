<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Services\Entitlements;
class AccountController extends Controller {
    public function profile(Request $r, Entitlements $e) {
        return ['user'=>$r->user(),'is_pro'=>$e->pro($r->user()),'daily_limit'=>$e->limit($r->user()),
            'used_today'=>(int)DB::table('analysis_usage')->where('user_id',$r->user()->id)->where('date',now('UTC')->toDateString())->value('count'),
            'ads_eligible'=>!$e->pro($r->user())];
    }
    public function update(Request $r) {
        $data=$r->validate(['name'=>'sometimes|required|string|max:100','language'=>'sometimes|in:en,so,ar','timezone'=>'sometimes|timezone',
            'notification_preferences'=>'sometimes|array','notification_preferences.*'=>'boolean']);
        if(isset($data['notification_preferences'])) $data['notification_preferences']=json_encode($data['notification_preferences']);
        $r->user()->forceFill($data)->save(); return ['user'=>$r->user()];
    }
    public function favorites(Request $r) {
        return ['matches'=>\App\Models\Fixture::with('homeTeam','awayTeam','league')->whereIn('id',DB::table('saved_matches')->where('user_id',$r->user()->id)->select('fixture_id'))->get(),
            'teams'=>\App\Models\Team::whereIn('id',DB::table('favorite_teams')->where('user_id',$r->user()->id)->select('team_id'))->get(),
            'leagues'=>\App\Models\League::whereIn('id',DB::table('favorite_leagues')->where('user_id',$r->user()->id)->select('league_id'))->get()];
    }
    public function favorite(Request $r,string $type,int $id) {
        $map=['matches'=>['saved_matches','fixture_id','fixtures'],'teams'=>['favorite_teams','team_id','teams'],'leagues'=>['favorite_leagues','league_id','leagues']];
        abort_unless(isset($map[$type]),404); [$table,$key,$entity]=$map[$type];
        abort_unless(DB::table($entity)->where('id',$id)->exists(),404);
        $where=['user_id'=>$r->user()->id,$key=>$id];
        if($r->isMethod('delete')) DB::table($table)->where($where)->delete();
        else DB::table($table)->insertOrIgnore($where+['created_at'=>now(),'updated_at'=>now()]);
        return ['saved'=>!$r->isMethod('delete')];
    }
    public function notifications(Request $r) { return $r->user()->notifications()->paginate(30); }
    public function readNotification(Request $r,string $id) {
        $notification=$r->user()->notifications()->whereKey($id)->firstOrFail(); $notification->markAsRead(); return ['read'=>true];
    }
    public function device(Request $r) {
        $data=$r->validate(['token'=>'required|string|max:4096','platform'=>'required|in:android,ios']);
        DB::table('device_tokens')->updateOrInsert(['token_hash'=>hash('sha256',$data['token'])],
            ['user_id'=>$r->user()->id,'token'=>encrypt($data['token']),'platform'=>$data['platform'],'created_at'=>now(),'updated_at'=>now()]);
        return response()->noContent();
    }
    public function adEvent(Request $r,Entitlements $e) {
        abort_if($e->pro($r->user()),403,'Ads are disabled for Pro accounts.');
        $data=$r->validate(['event_id'=>'required|uuid','type'=>'required|in:banner,native,interstitial,rewarded','placement'=>'required|string|max:60']);
        DB::table('ad_events')->insertOrIgnore($data+['user_id'=>$r->user()->id,'verified'=>false,'created_at'=>now(),'updated_at'=>now()]);
        // Client callbacks never grant credits. Only verified provider callbacks may do so.
        return response()->noContent();
    }
}
