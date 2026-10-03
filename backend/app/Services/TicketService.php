<?php
namespace App\Services;
use App\Models\{Fixture,Prediction,User};
use Illuminate\Support\Facades\{DB,Cache};
use Illuminate\Support\Str;
class TicketService {
    public const CATEGORIES=['safe'=>[2,5,.72],'balanced'=>[4,8,.60],'high_odds'=>[5,12,.40],'full'=>[10,16,.50]];
    public function __construct(private PredictionService $predictions) {}
    public function candidates(Fixture $f): array {
        abort_if($f->kickoff->isPast()||$f->status!=='NS',422,'This match has started.');
        $p=$this->predictions->generate($f);$rows=[];
        foreach(DB::table('prediction_probabilities')->where('prediction_id',$p->id)->get() as $v) {
            $quote=DB::table('market_quotes')->where('fixture_id',$f->id)->where('market',$v->market)->where('selection',$v->selection)
                ->where('observed_at','>=',now()->subHours(6))->orderByDesc('observed_at')->orderBy('bookmaker')->first();
            $rows[]=['fixture_id'=>$f->id,'prediction_id'=>$p->id,'quote_id'=>$quote?->id,'market'=>$v->market,'selection'=>$v->selection,
                'odds_at_prediction'=>$quote?->odds,'bookmaker'=>$quote?->bookmaker,'odds_observed_at'=>$quote?->observed_at,
                'confidence_at_prediction'=>$v->probability,'prediction_created_at'=>$p->generated_at,'kickoff_time'=>$f->kickoff];
        }
        usort($rows,fn($a,$b)=>$b['confidence_at_prediction']<=>$a['confidence_at_prediction']);return $rows;
    }
    public function create(string $source,array $meta,array $items): int {
        $table=$source==='daily'?'daily_tickets':'user_analyses';$itemTable=$source==='daily'?'daily_ticket_items':'user_analysis_items';$key=$source==='daily'?'daily_ticket_id':'user_analysis_id';
        abort_if(!$items || count($items)>20,422,'Select between 1 and 20 matches.');
        abort_if(count(array_unique(array_column($items,'fixture_id')))!==count($items),422,'One selection per fixture is allowed.');
        return DB::transaction(function() use($table,$itemTable,$key,$meta,$items) {
            // Always recheck under row locks after provider/model calls and before saving snapshots.
            $fixtures=Fixture::whereIn('id',array_column($items,'fixture_id'))->orderBy('id')->lockForUpdate()->get();
            foreach($fixtures as $f) abort_if($f->kickoff->isPast()||$f->status!=='NS',422,'Kickoff reached. Ticket cannot be created or edited.');
            $odds=1.;$confidence=1.;
            foreach($items as $item) {$odds=$odds===null||$item['odds_at_prediction']===null?null:$odds*(float)$item['odds_at_prediction'];$confidence*=$item['confidence_at_prediction'];}
            $id=DB::table($table)->insertGetId($meta+['status'=>'PENDING','total_odds'=>$odds,'confidence'=>$confidence,'selection_count'=>count($items),'generated_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);
            foreach($items as $item) DB::table($itemTable)->insert($item+[$key=>$id,'created_at'=>now(),'updated_at'=>now()]);
            return $id;
        });
    }
    public function daily(): int {
        return Cache::lock('daily-ticket-generation',1800)->get(function() {
            $date=now('UTC')->toDateString();$pool=[];$created=0;
            $fixtures=Fixture::whereIn('id',DB::table('market_quotes')->where('observed_at','>=',now()->subHours(6))->select('fixture_id'))->where('status','NS')->whereBetween('kickoff',[now()->addMinutes(10),now('UTC')->endOfDay()])->orderByDesc('featured')->orderBy('kickoff')->limit(40)->get();
            foreach($fixtures as $f) {try {$pool[$f->id]=array_values(array_filter($this->candidates($f),fn($x)=>$x['odds_at_prediction']!==null));}catch(\Throwable $e){report($e);}}
            foreach(self::CATEGORIES as $category=>[$min,$max,$threshold]) {
                if(DB::table('daily_tickets')->where('ticket_date',$date)->where('category',$category)->exists()) continue;
                $items=[];$marketCounts=[];
                foreach($pool as $options) {
                    $options=array_values(array_filter($options,fn($x)=>$x['confidence_at_prediction']>=$threshold));
                    if(!$options)continue;
                    if($category==='high_odds')usort($options,fn($a,$b)=>(float)$b['odds_at_prediction']<=>(float)$a['odds_at_prediction']);
                    if($category==='full')usort($options,fn($a,$b)=>($marketCounts[$a['market']]??0)<=>($marketCounts[$b['market']]??0));
                    $items[]=$options[0];$marketCounts[$options[0]['market']]=($marketCounts[$options[0]['market']]??0)+1;
                }
                usort($items,fn($a,$b)=>$b['confidence_at_prediction']<=>$a['confidence_at_prediction']);$items=array_slice($items,0,$max);
                if(count($items)<$min)continue;
                try {$id=$this->create('daily',['ticket_date'=>$date,'category'=>$category,'name'=>ucwords(str_replace('_',' ',$category)).' Shax'],$items);$created++;
                    $this->notify(null,'daily_ready',"Today's ".ucwords(str_replace('_',' ',$category)).' Shax is ready.',['ticket_id'=>$id]);
                }catch(\Throwable $e){report($e);}
            }
            Cache::put('tickets:last_generation',['at'=>now()->toIso8601String(),'created'=>$created,'fixtures_checked'=>$fixtures->count()],86400);return $created;
        }) ?: 0;
    }
    public function detail(string $source,int $id): array {
        $daily=$source==='daily';$ticket=DB::table($daily?'daily_tickets':'user_analyses')->find($id);abort_unless($ticket,404);
        $items=DB::table($daily?'daily_ticket_items':'user_analysis_items')->where($daily?'daily_ticket_id':'user_analysis_id',$id)->get();
        $fixtures=Fixture::with('homeTeam','awayTeam','league')->whereIn('id',$items->pluck('fixture_id'))->get()->keyBy('id');
        return (array)$ticket+['source'=>$source,'confidence_method'=>'Product of model probabilities; independence assumption; not calibrated.',
            'correct'=>$items->where('status','WIN')->count(),'incorrect'=>$items->where('status','LOSS')->count(),
            'items'=>$items->map(fn($x)=>(array)$x+['fixture'=>$fixtures[$x->fixture_id]??null])->all()];
    }
    public function settle(): void {
        foreach(['daily','personal'] as $source) {
            $daily=$source==='daily';$table=$daily?'daily_tickets':'user_analyses';$itemTable=$daily?'daily_ticket_items':'user_analysis_items';$key=$daily?'daily_ticket_id':'user_analysis_id';
            DB::table($table)->whereNull('settled_at')->orderBy('id')->chunkById(50,function($tickets) use($table,$itemTable,$key,$daily) {
                foreach($tickets as $ticket) DB::transaction(function() use($ticket,$table,$itemTable,$key,$daily) {
                    $current=DB::table($table)->where('id',$ticket->id)->lockForUpdate()->first();if($current->settled_at)return;
                    $items=DB::table($itemTable)->where($key,$ticket->id)->get();$locked=false;
                    foreach($items as $item) {
                        $f=Fixture::find($item->fixture_id);if(!$f)continue;
                        $started=now()->gte(\Carbon\Carbon::parse($item->kickoff_time))||$f->kickoff->isPast()||$f->status!=='NS';
                        if($started){$locked=true;if(!$item->locked_at)DB::table($itemTable)->where('id',$item->id)->update(['locked_at'=>now()]);}
                        if($item->status!=='PENDING')continue;
                        [$status,$h,$a,$reason]=MarketCatalog::settle($f,$item->market,$item->selection);
                        if($status!=='PENDING')DB::table($itemTable)->where('id',$item->id)->update(['status'=>$status,'final_home'=>$h,'final_away'=>$a,'settlement_reason'=>$reason,'settled_at'=>now(),'updated_at'=>now()]);
                    }
                    $items=DB::table($itemTable)->where($key,$ticket->id)->get();$pending=$items->where('status','PENDING')->count();
                    $status=$pending ? ($pending===$items->count()?'PENDING':'PARTIAL') : ($items->contains('status','LOSS')?'LOSS':($items->every(fn($i)=>$i->status==='VOID')?'VOID':'WIN'));
                    DB::table($table)->where('id',$ticket->id)->update(['status'=>$status,'locked_at'=>$current->locked_at?:($locked?now():null),'settled_at'=>$pending?null:now(),'updated_at'=>now()]);
                    if(!$daily&&!$pending)$this->notify($ticket->user_id,'analysis_settled','Analysis #'.$ticket->id.' — '.$items->where('status','WIN')->count().'/'.$items->count().' correct.',['analysis_id'=>$ticket->id,'status'=>$status]);
                });
            });
        }
    }
    private function notify(?int $userId,string $type,string $title,array $data): void {
        User::when($userId,fn($q)=>$q->whereKey($userId))->whereNull('disabled_at')->chunkById(100,function($users) use($type,$title,$data) {
            foreach($users as $user){$prefs=json_decode($user->notification_preferences??'{}',true);if(($prefs[$type]??true)===false)continue;
                DB::table('notifications')->insert(['id'=>(string)Str::uuid(),'type'=>$type,'notifiable_type'=>User::class,'notifiable_id'=>$user->id,'data'=>json_encode(['title'=>$title]+$data),'created_at'=>now(),'updated_at'=>now()]);}
        });
    }
}
