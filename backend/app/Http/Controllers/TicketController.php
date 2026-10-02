<?php
namespace App\Http\Controllers;
use App\Services\{TicketService,Entitlements};
use App\Models\Fixture;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{DB,Cache};
class TicketController extends Controller {
    private function tables(string $source): array {
        abort_unless(in_array($source,['daily','personal']),422);
        return $source==='daily'?['daily_tickets','daily_ticket_items','daily_ticket_id']:['user_analyses','user_analysis_items','user_analysis_id'];
    }
    private function scope(Request $r,string $source) {
        [$table]=$this->tables($source);$q=DB::table($table);
        if($source==='personal')$q->where('user_id',$r->user()->id);
        $r->validate(['date'=>'nullable|date_format:Y-m-d','days'=>'nullable|in:1,7,30,90,all','category'=>'nullable|in:safe,balanced,high_odds,full','status'=>'nullable|in:PENDING,PARTIAL,WIN,LOSS,VOID,settled']);
        if($r->filled('date'))$q->whereDate('generated_at',$r->date);
        elseif($r->input('days','all')!=='all')$q->where('generated_at','>=',now('UTC')->startOfDay()->subDays((int)$r->days-1));
        if($source==='daily'&&$r->filled('category'))$q->where('category',$r->category);
        if($r->input('status')==='settled')$q->whereNotNull('settled_at');elseif($r->filled('status'))$q->where('status',$r->status);
        return $q;
    }
    public function daily(Request $r,TicketService $service) {
        $rows=$this->scope($r,'daily')->orderByDesc('generated_at')->paginate(20);
        $rows->through(fn($t)=>$service->detail('daily',$t->id));
        return ['tickets'=>$rows,'generation'=>Cache::get('tickets:last_generation'),'data_status'=>Cache::get('tickets:data_status')];
    }
    public function dailyDetail(int $id,TicketService $service){return ['data'=>$service->detail('daily',$id)];}
    public function personal(Request $r,TicketService $service){return $this->scope($r,'personal')->orderByDesc('id')->paginate(20)->through(fn($t)=>$service->detail('personal',$t->id));}
    public function personalDetail(Request $r,int $id,TicketService $service){abort_unless(DB::table('user_analyses')->where('id',$id)->where('user_id',$r->user()->id)->exists(),404);return ['data'=>$service->detail('personal',$id)];}
    public function preview(Request $r,TicketService $service) {
        $data=$r->validate(['fixture_ids'=>'required|array|min:1|max:20','fixture_ids.*'=>'required|integer|distinct|exists:fixtures,id']);$result=[];
        foreach($data['fixture_ids'] as $id)try {
            $f=Fixture::with('homeTeam','awayTeam','league')->findOrFail($id);$options=$service->candidates($f);
            $withOdds=array_values(array_filter($options,fn($x)=>$x['odds_at_prediction']!==null));$best=$withOdds[0]??$options[0]??null;
            if(!$best)abort(422,'No supported prediction available.');
            $p=\App\Models\Prediction::findOrFail($best['prediction_id']);
            $result[]=$best+['fixture'=>$f,'factors'=>$p->output['factors']??[],'expected_goals'=>$p->output['expected_goals']??null,'limitations'=>$p->output['limitations']??[]];
        }catch(\Throwable $e){$result[]=['fixture_id'=>$id,'error'=>$e instanceof \Symfony\Component\HttpKernel\Exception\HttpException?$e->getMessage():'Analysis temporarily unavailable.'];}
        $preview=(string)\Illuminate\Support\Str::uuid();Cache::put('analysis-preview:'.$r->user()->id.':'.$preview,$result,1800);return ['data'=>$result,'preview_id'=>$preview];
    }
    public function save(Request $r,TicketService $service,Entitlements $entitlements) {
        $data=$r->validate(['name'=>'required|string|max:100','request_key'=>'required|uuid','preview_id'=>'required|uuid','items'=>'required|array|min:1|max:20','items.*.fixture_id'=>'required|integer|distinct|exists:fixtures,id','items.*.market'=>'required|string','items.*.selection'=>'required|string']);
        return Cache::lock('save-analysis:'.$r->user()->id.':'.$data['request_key'],60)->block(5,function() use($r,$data,$service,$entitlements) {
            $existing=DB::table('user_analyses')->where('user_id',$r->user()->id)->where('request_key',$data['request_key'])->first();if($existing)return ['data'=>$service->detail('personal',$existing->id)];
            abort_if(count($data['items'])>1&&!$entitlements->pro($r->user()),403,'Pro subscription required for multi-match analysis.');
            $preview=Cache::get('analysis-preview:'.$r->user()->id.':'.$data['preview_id']);abort_unless($preview,422,'Analysis preview expired. Please analyse again.');$items=[];foreach($data['items'] as $input){$item=collect($preview)->first(fn($x)=>!isset($x['error'])&&$x['fixture_id']===$input['fixture_id']&&$x['market']===$input['market']&&$x['selection']===$input['selection']);abort_unless($item,422,'Unsupported prediction selection.');$items[]=\Illuminate\Support\Arr::only($item,['fixture_id','prediction_id','quote_id','market','selection','odds_at_prediction','bookmaker','odds_observed_at','confidence_at_prediction','prediction_created_at','kickoff_time']);}
            $id=DB::transaction(function()use($entitlements,$r,$data,$items,$service){$entitlements->consume($r->user(),count($items));return $service->create('personal',['user_id'=>$r->user()->id,'name'=>$data['name'],'request_key'=>$data['request_key']],$items);});
            return response()->json(['data'=>$service->detail('personal',$id)],201);
        });
    }
    public function bookmark(Request $r,int $id) {
        abort_unless(DB::table('daily_tickets')->where('id',$id)->exists(),404);
        $where=['user_id'=>$r->user()->id,'daily_ticket_id'=>$id];
        if($r->isMethod('delete'))DB::table('ticket_bookmarks')->where($where)->delete();
        else DB::table('ticket_bookmarks')->insertOrIgnore($where+['created_at'=>now(),'updated_at'=>now()]);
        return ['saved'=>!$r->isMethod('delete')];
    }
    public function bookmarks(Request $r,TicketService $service){return ['data'=>DB::table('ticket_bookmarks')->where('user_id',$r->user()->id)->orderByDesc('id')->get()->map(fn($b)=>$service->detail('daily',$b->daily_ticket_id))];}
    public function picks(Request $r,int $id) {
        abort_unless(DB::table('daily_tickets')->where('id',$id)->exists(),404);
        foreach(DB::table('daily_ticket_items')->where('daily_ticket_id',$id)->get() as $item)DB::table('saved_matches')->insertOrIgnore(['user_id'=>$r->user()->id,'fixture_id'=>$item->fixture_id,'created_at'=>now(),'updated_at'=>now()]);return ['saved'=>true];
    }
    public function stats(Request $r,string $source) {
        [$table,$items,$key]=$this->tables($source);if($source==='personal')abort_unless($r->user(),401);
        $tickets=$this->scope($r,$source)->get();$ids=$tickets->pluck('id');
        $rows=DB::table($items)->join('fixtures','fixtures.id','=',$items.'.fixture_id')->join('leagues','leagues.id','=','fixtures.league_id')->whereIn($items.'.'.$key,$ids)->select($items.'.*','leagues.name as league','leagues.id as league_id')->get();
        $metric=function($rows){$win=$rows->where('status','WIN')->count();$loss=$rows->where('status','LOSS')->count();return ['total'=>$rows->count(),'won'=>$win,'lost'=>$loss,'void'=>$rows->where('status','VOID')->count(),'pending'=>$rows->whereIn('status',['PENDING','PARTIAL'])->count(),'rate'=>$win+$loss?$win/($win+$loss):null];};
        return ['source'=>$source,'tickets'=>$metric($tickets),'selections'=>$metric($rows),
            'markets'=>$rows->groupBy(fn($r)=>str_starts_with($r->market,'goals_')?'Over/Under':$r->market)->map(fn($v,$k)=>['name'=>$k]+$metric($v))->values(),
            'leagues'=>$rows->groupBy('league_id')->map(fn($v)=>['name'=>$v->first()->league]+$metric($v))->values(),
            'trend'=>$rows->groupBy(fn($r)=>substr($r->prediction_created_at,0,10))->sortKeys()->map(fn($v,$k)=>['date'=>$k]+$metric($v))->values()];
    }
}
