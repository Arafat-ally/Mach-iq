<?php
namespace Tests\Feature;
use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\{Fixture,League,Team,Prediction,User};
use App\Services\{TicketService,MarketCatalog};
use Laravel\Sanctum\Sanctum;
class TicketWorkflowTest extends TestCase {
    use RefreshDatabase;
    private function item(string $market='1x2',string $selection='home'): array {
        $league=League::firstOrCreate(['provider_external_id'=>'39'],['name'=>'League']);
        $home=Team::firstOrCreate(['provider_external_id'=>'1'],['name'=>'Home']);$away=Team::firstOrCreate(['provider_external_id'=>'2'],['name'=>'Away']);
        $f=Fixture::create(['provider_external_id'=>(string)random_int(100,999999),'league_id'=>$league->id,'home_team_id'=>$home->id,'away_team_id'=>$away->id,'season'=>2026,'kickoff'=>now()->addHour(),'status'=>'NS','data'=>[],'synced_at'=>now()]);
        DB::table('model_versions')->insertOrIgnore(['id'=>1,'name'=>'test','metadata'=>'{}','created_at'=>now(),'updated_at'=>now()]);
        $p=Prediction::create(['fixture_id'=>$f->id,'model_version_id'=>1,'generated_at'=>now(),'data_snapshot_time'=>now(),'data_quality'=>'LOW','data_snapshot'=>[],'output'=>[]]);
        return ['fixture_id'=>$f->id,'prediction_id'=>$p->id,'quote_id'=>null,'market'=>$market,'selection'=>$selection,'odds_at_prediction'=>1.5,'bookmaker'=>'Test','odds_observed_at'=>now(),'confidence_at_prediction'=>.8,'prediction_created_at'=>now(),'kickoff_time'=>$f->kickoff];
    }
    public function test_saved_snapshots_partial_loss_and_immutable_prices(): void {
        $service=app(TicketService::class);$one=$this->item();$two=$this->item('goals_2.5','over');
        $id=$service->create('daily',['ticket_date'=>today(),'category'=>'safe','name'=>'Safe'],[$one,$two]);
        Fixture::find($one['fixture_id'])->update(['status'=>'FT','home_goals'=>2,'away_goals'=>0]);
        $service->settle();$this->assertSame('PARTIAL',$service->detail('daily',$id)['status']);
        Fixture::find($two['fixture_id'])->update(['status'=>'FT','home_goals'=>1,'away_goals'=>1]);
        $service->settle();$ticket=$service->detail('daily',$id);
        $this->assertSame('LOSS',$ticket['status']);$this->assertEquals(2.25,$ticket['total_odds']);$this->assertEquals(.64,$ticket['confidence']);
        $this->assertSame(1,$ticket['correct']);$this->assertSame(1,$ticket['incorrect']);$this->assertNotNull($ticket['locked_at']);
        Fixture::find($two['fixture_id'])->update(['home_goals'=>9]);$service->settle();
        $this->assertSame('LOSS',$service->detail('daily',$id)['status']);
    }
    public function test_regulation_time_void_and_unsupported_market_rules(): void {
        $item=$this->item();$f=Fixture::find($item['fixture_id']);
        $f->update(['status'=>'AET','home_goals'=>3,'away_goals'=>1,'data'=>['score'=>['fulltime'=>['home'=>1,'away'=>1]]]]);
        $this->assertSame('WIN',MarketCatalog::settle($f,'1x2','draw')[0]);
        $this->assertSame('WIN',MarketCatalog::settle($f,'double_chance','home_draw')[0]);
        $this->assertSame('PENDING',MarketCatalog::settle($f,'corners_9.5','over')[0]);
        $f->update(['data'=>[]]);$this->assertSame('PENDING',MarketCatalog::settle($f,'btts','yes')[0]);
        $f->update(['status'=>'CANC']);$this->assertSame('VOID',MarketCatalog::settle($f,'1x2','home')[0]);
        $this->assertSame(['goals_2.5','over'],MarketCatalog::map(5,'Over 2.5'));$this->assertNull(MarketCatalog::map(99,'Home'));
    }
    public function test_personal_history_cannot_inflate_public_performance_or_leak(): void {
        $user=User::factory()->create();$other=User::factory()->create();$service=app(TicketService::class);$item=$this->item();
        $id=$service->create('personal',['user_id'=>$user->id,'request_key'=>Str::uuid(),'name'=>'Personal'],[$item]);
        Fixture::find($item['fixture_id'])->update(['status'=>'FT','home_goals'=>1,'away_goals'=>0]);$service->settle();$service->settle();
        $this->getJson('/api/performance/daily')->assertOk()->assertJsonPath('tickets.total',0);
        Sanctum::actingAs($user);$this->getJson('/api/performance/personal')->assertOk()->assertJsonPath('tickets.won',1)->assertJsonPath('selections.won',1);
        $this->assertDatabaseCount('notifications',1);
        Sanctum::actingAs($other);$this->getJson('/api/my-analyses/'.$id)->assertNotFound();$this->getJson('/api/performance/personal')->assertJsonPath('tickets.total',0);
    }
    public function test_cannot_create_after_kickoff_and_missing_odds_stay_null(): void {
        $item=$this->item();$item['odds_at_prediction']=null;$service=app(TicketService::class);
        $id=$service->create('daily',['ticket_date'=>today(),'category'=>'safe','name'=>'Safe'],[$item]);
        $this->assertNull($service->detail('daily',$id)['total_odds']);
        Fixture::find($item['fixture_id'])->update(['kickoff'=>now()->subMinute()]);
        $this->expectException(\Symfony\Component\HttpKernel\Exception\HttpException::class);
        $service->create('daily',['ticket_date'=>today(),'category'=>'balanced','name'=>'Balanced'],[$item]);
    }
}
