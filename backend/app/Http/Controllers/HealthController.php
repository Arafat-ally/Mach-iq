<?php
namespace App\Http\Controllers;
use Illuminate\Support\Facades\{DB,Redis,Cache,Http};
class HealthController extends Controller {
    public function __invoke() {
        $state=['database'=>'unavailable','redis'=>'unavailable','football_provider'=>'not_configured','prediction_engine'=>'not_configured'];
        try { DB::select('select 1'); $state['database']='connected'; } catch (\Throwable $e) {}
        try { Redis::ping(); $state['redis']='connected'; } catch (\Throwable $e) {}
        if(config('matchiq.provider_key')) {
            try { $state['football_provider']=Cache::get('provider:last_success') ? 'connected' : 'not_yet_verified'; } catch (\Throwable $e) { $state['football_provider']='unavailable'; }
        }
        if(config('matchiq.prediction_url')) {
            try { $res=Http::timeout(2)->get(rtrim(config('matchiq.prediction_url'),'/').'/health'); $state['prediction_engine']=$res->successful() && $res->json('status')==='ok' ? 'connected':'unavailable'; } catch (\Throwable $e) { $state['prediction_engine']='unavailable'; }
        }
        $ok=count(array_filter($state,fn($x)=>$x==='connected'))===4;
        return response()->json(['status'=>$ok ? 'ok':'degraded']+$state,$ok ? 200:503);
    }
}
