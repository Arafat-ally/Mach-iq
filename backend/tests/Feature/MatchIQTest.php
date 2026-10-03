<?php
namespace Tests\Feature;
use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{Http,Cache,DB,Notification};
use App\Models\{User,Fixture,League,Team,Prediction};
use App\Services\{ApiFootballProvider,Entitlements,PredictionService};
use Laravel\Sanctum\Sanctum;

class MatchIQTest extends TestCase {
    use RefreshDatabase;
    public function test_admin_can_grant_expire_and_revoke_trials_without_touching_paid_subscriptions(): void {
        $user=User::factory()->unverified()->create(['contact_email'=>'trial@example.com']);
        Sanctum::actingAs($user);
        $this->putJson('/api/admin/users/'.$user->id.'/trial',['days'=>7])->assertForbidden();
        $admin=User::factory()->create(['role'=>'admin']);Sanctum::actingAs($admin);
        $this->getJson('/api/admin/users?search=trial@example.com')->assertOk()->assertJsonPath('data.0.id',$user->id);
        $this->putJson('/api/admin/users/'.$user->id.'/trial',['days'=>0])->assertUnprocessable();
        $this->putJson('/api/admin/users/'.$user->id.'/trial',['days'=>7])->assertOk();
        $this->assertTrue((new Entitlements)->pro($user));
        $this->assertDatabaseHas('audit_logs',['user_id'=>$admin->id,'action'=>'trial.granted','target'=>(string)$user->id]);
        $this->travel(8)->days();$this->assertFalse((new Entitlements)->pro($user));$this->travelBack();
        $this->putJson('/api/admin/users/'.$user->id.'/trial',['days'=>14])->assertOk();
        $this->assertDatabaseCount('subscriptions',1);
        DB::table('subscriptions')->insert(['user_id'=>$user->id,'provider'=>'store','provider_external_id'=>'paid-test','plan'=>'pro','status'=>'active','expires_at'=>now()->addMonth()]);
        $this->deleteJson('/api/admin/users/'.$user->id.'/trial')->assertNoContent();
        $this->assertTrue((new Entitlements)->pro($user));
        $this->assertDatabaseHas('subscriptions',['provider_external_id'=>'paid-test','status'=>'active']);
        $this->assertDatabaseHas('subscriptions',['provider_external_id'=>'admin-trial:'.$user->id,'status'=>'revoked']);
    }
    public function test_device_account_requires_no_password_and_cannot_claim_email_owner(): void {
        Notification::fake();
        $owner=User::factory()->create(['email'=>'owner@example.com','role'=>'admin']);
        $payload=['name'=>'Device user','email'=>'owner@example.com','device_key'=>str_repeat('a',64)];
        $first=$this->postJson('/api/auth/device',$payload)->assertOk()
            ->assertJsonPath('user.email','owner@example.com')->assertJsonPath('user.role','user')
            ->assertJsonPath('user.email_verified_at',null)->assertJsonMissingPath('user.device_key_hash');
        $this->assertNotEquals($owner->id,$first->json('user.id'));
        $this->postJson('/api/auth/device',$payload)->assertOk()->assertJsonPath('user.id',$first->json('user.id'));
        $payload['device_key']=str_repeat('b',64);
        $other=$this->postJson('/api/auth/device',$payload)->assertOk();
        $this->assertNotEquals($first->json('user.id'),$other->json('user.id'));
        $this->assertDatabaseMissing('users',['device_key_hash'=>$payload['device_key']]);
        Notification::assertNothingSent();
    }
    public function test_device_account_validation_and_disabled_account(): void {
        $this->postJson('/api/auth/device',['name'=>'Test','email'=>'invalid','device_key'=>'short'])->assertUnprocessable();
        $payload=['name'=>'Test','email'=>'test@example.com','device_key'=>str_repeat('c',64)];
        $id=$this->postJson('/api/auth/device',$payload)->assertOk()->json('user.id');
        User::findOrFail($id)->forceFill(['disabled_at'=>now()])->save();
        $this->postJson('/api/auth/device',$payload)->assertForbidden();
    }
    private function fixture(array $attributes=[]): Fixture {
        $league=League::firstOrCreate(['provider_external_id'=>'39'],['provider'=>'api-football','name'=>'Test league']);
        $home=Team::firstOrCreate(['provider_external_id'=>'1'],['provider'=>'api-football','name'=>'Test home']);
        $away=Team::firstOrCreate(['provider_external_id'=>'2'],['provider'=>'api-football','name'=>'Test away']);
        return Fixture::create($attributes+['provider'=>'api-football','provider_external_id'=>(string)random_int(10000,999999),
            'league_id'=>$league->id,'home_team_id'=>$home->id,'away_team_id'=>$away->id,'season'=>2026,
            'kickoff'=>now()->addDay(),'status'=>'NS','data'=>[],'synced_at'=>now()]);
    }
    public function test_match_groups_use_provider_status_with_selected_date(): void {
        $this->travelTo(\Carbon\Carbon::parse('2026-10-02 12:00:00','UTC'));
        $this->fixture(['kickoff'=>now()->subHour(),'status'=>'NS']);
        $this->fixture(['kickoff'=>now()->subHour(),'status'=>'HT']);
        $this->fixture(['kickoff'=>now()->subHours(3),'status'=>'FT']);
        $this->fixture(['kickoff'=>now()->subDay(),'status'=>'FT']);
        $this->fixture(['kickoff'=>now()->addHour(),'status'=>'PST']);
        foreach(['upcoming'=>'NS','live'=>'HT','finished'=>'FT'] as $group=>$status) {
            $this->getJson('/api/fixtures?date=2026-10-02&group='.$group)->assertOk()->assertJsonCount(1,'data')->assertJsonPath('data.0.status',$status);
        }
        $this->getJson('/api/fixtures?date=2026-10-02&group=all')->assertJsonCount(4,'data');
        $this->getJson('/api/fixtures?group=invalid')->assertUnprocessable();
    }
    public function test_register_login_logout_and_admin_rejection(): void {
        Notification::fake();
        $registration=$this->postJson('/api/auth/register',['name'=>'Tester','email'=>'test@example.com','password'=>'StrongPassword123','password_confirmation'=>'StrongPassword123']);
        $registration->assertCreated()->assertJsonStructure(['token','user']);
        $registration->assertJsonPath('user.email_verified_at',null);
        Notification::assertNothingSent();
        $token=$registration->json('token');
        $this->withToken($token)->getJson('/api/admin/dashboard')->assertForbidden();
        $this->withToken($token)->getJson('/api/profile')->assertOk()->assertJsonPath('is_pro',false);
        $this->withToken($token)->postJson('/api/auth/logout')->assertNoContent();
        $this->assertDatabaseCount('personal_access_tokens',0);
    }
    public function test_disabled_account_and_role_mass_assignment(): void {
        Notification::fake();
        $this->postJson('/api/auth/register',['name'=>'Tester','email'=>'test@example.com','password'=>'StrongPassword123','password_confirmation'=>'StrongPassword123','role'=>'admin'])->assertCreated();
        $this->assertDatabaseHas('users',['email'=>'test@example.com','role'=>'user']);
        $user=User::first();$user->forceFill(['disabled_at'=>now()])->save();
        $this->postJson('/api/auth/login',['email'=>'test@example.com','password'=>'StrongPassword123'])->assertStatus(422);
    }
    public function test_fixtures_respect_local_date_and_live_filter(): void {
        $this->fixture(['kickoff'=>'2026-09-27 22:30:00','status'=>'1H']);
        $this->getJson('/api/fixtures?date=2026-09-28&timezone=Africa/Nairobi')->assertOk()->assertJsonCount(1,'data');
        $this->getJson('/api/fixtures?date=2026-09-27&timezone=Africa/Nairobi')->assertJsonCount(0,'data');
        $this->getJson('/api/fixtures?live=1')->assertJsonCount(1,'data');
        $this->getJson('/api/fixtures?date=2026-09-28&utc_offset=180')->assertOk()->assertJsonCount(1,'data');
        $this->getJson('/api/fixtures?date=2026-09-28&utc_offset=900')->assertStatus(422);
    }
    public function test_provider_adapter_cache_prevents_duplicate_requests(): void {
        config(['matchiq.provider_key'=>'test-only','matchiq.provider_quota'=>100]);
        Http::fake(['*'=>Http::response(['errors'=>[],'response'=>[['name'=>'Test country']]],200)]);
        $provider=new ApiFootballProvider;
        $first=$provider->fetch('countries'); $second=$provider->fetch('countries');
        $this->assertSame($first,$second); Http::assertSentCount(1);
        $this->assertDatabaseHas('api_usage',['cache_hit'=>true,'request_count'=>0]);
    }
    public function test_missing_provider_and_quota_fail_gracefully(): void {
        config(['matchiq.provider_key'=>null]);
        $fixture=$this->fixture();
        $this->getJson('/api/fixtures/'.$fixture->id.'/statistics')->assertStatus(503)->assertJsonMissing(['exception']);
        config(['matchiq.provider_key'=>'test-only','matchiq.provider_quota'=>100]);
        Cache::put('provider-quota:'.now('UTC')->toDateString(),95);
        Http::fake();
        $this->getJson('/api/fixtures/'.$fixture->id.'/statistics')->assertStatus(503);
        Http::assertNothingSent();
    }
    public function test_provider_key_trims_paste_whitespace_and_rejects_embedded_newlines(): void {
        config(['matchiq.provider_key'=>" test-only\r\n",'matchiq.provider_quota'=>100]);
        Http::fake(['*'=>Http::response(['errors'=>[],'response'=>[]],200)]);
        (new ApiFootballProvider)->fetch('countries');
        Http::assertSent(fn($request) => $request->hasHeader('x-apisports-key', 'test-only'));
        config(['matchiq.provider_key'=>"test\ninjected"]);
        $fixture=$this->fixture();
        $this->getJson('/api/fixtures/'.$fixture->id.'/statistics')->assertStatus(503)->assertJsonMissing(['exception']);
        Http::assertSentCount(1);
    }
    public function test_lineups_do_not_call_provider_far_before_kickoff(): void {
        Http::fake();$fixture=$this->fixture();
        $this->getJson('/api/fixtures/'.$fixture->id.'/lineups')->assertOk()->assertJsonPath('confirmed',false);
        Http::assertNothingSent();
    }
    public function test_favorites_are_owned_and_idempotent(): void {
        $user=User::factory()->create();Sanctum::actingAs($user);$fixture=$this->fixture();
        $this->putJson('/api/favorites/matches/'.$fixture->id)->assertOk();
        $this->putJson('/api/favorites/matches/'.$fixture->id)->assertOk();
        $this->assertDatabaseCount('saved_matches',1);
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/favorites')->assertJsonCount(0,'matches');
        $this->deleteJson('/api/favorites/matches/'.$fixture->id)->assertOk();
        $this->assertDatabaseCount('saved_matches',1);
    }
    public function test_free_limit_pro_expiry_and_ads(): void {
        $user=User::factory()->create();$e=new Entitlements;
        config(['matchiq.free_limit'=>1]);$e->consume($user,1);
        try { $e->consume($user,1);$this->fail('Expected daily limit'); } catch(\Symfony\Component\HttpKernel\Exception\HttpException $error) { $this->assertSame(429,$error->getStatusCode()); }
        DB::table('subscriptions')->insert(['user_id'=>$user->id,'provider'=>'test','provider_external_id'=>'test-entitlement','plan'=>'pro','status'=>'active','expires_at'=>now()->addDay()]);
        $this->assertTrue($e->pro($user));Sanctum::actingAs($user);
        $this->postJson('/api/ad-events',['event_id'=>fake()->uuid(),'type'=>'banner','placement'=>'home'])->assertForbidden();
        DB::table('subscriptions')->update(['expires_at'=>now()->subSecond()]);$this->assertFalse($e->pro($user));
    }
    public function test_no_postkickoff_prediction_and_no_usage_charge_for_failure(): void {
        $fixture=$this->fixture(['kickoff'=>now()->subMinute()]);$user=User::factory()->create();Sanctum::actingAs($user);
        $this->postJson('/api/analyses',['fixture_ids'=>[$fixture->id]])->assertOk()->assertJsonStructure(['data'=>[['error']]]);
        $this->assertDatabaseHas('analysis_usage',['user_id'=>$user->id,'count'=>0]);$this->assertDatabaseCount('predictions',0);
    }
    public function test_unverified_accounts_can_analyse_but_free_multimatch_is_rejected(): void {
        $fixture=$this->fixture(['kickoff'=>now()->subMinute()]);$second=$this->fixture();
        Sanctum::actingAs(User::factory()->unverified()->create());
        $this->postJson('/api/analyses',['fixture_ids'=>[$fixture->id]])->assertOk()->assertJsonStructure(['data'=>[['error']]]);
        $this->postJson('/api/analyses',['fixture_ids'=>[$fixture->id,$second->id]])->assertForbidden();
    }
    public function test_admin_disable_is_audited_and_self_disable_rejected(): void {
        $admin=User::factory()->create(['role'=>'admin']);$user=User::factory()->create();Sanctum::actingAs($admin);
        $this->patchJson('/api/admin/users/'.$user->id,['disabled'=>true])->assertOk();
        $this->assertDatabaseHas('audit_logs',['action'=>'account.status','target'=>(string)$user->id]);
        $this->patchJson('/api/admin/users/'.$admin->id,['disabled'=>true])->assertStatus(422);
    }
    public function test_client_cannot_grant_pro_and_webhook_requires_authentication(): void {
        Sanctum::actingAs(User::factory()->create());
        $this->patchJson('/api/profile',['is_pro'=>true,'role'=>'admin'])->assertOk();
        $this->getJson('/api/profile')->assertJsonPath('is_pro',false);
        $this->postJson('/api/subscriptions/webhook',['event'=>['id'=>'x','app_user_id'=>'1']])->assertUnauthorized();
    }
    public function test_authentication_is_rate_limited(): void {
        for($i=0;$i<5;$i++) $this->postJson('/api/auth/login',['email'=>'missing@example.com','password'=>'wrong'])->assertStatus(422);
        $this->postJson('/api/auth/login',['email'=>'missing@example.com','password'=>'wrong'])->assertStatus(429);
    }
}
