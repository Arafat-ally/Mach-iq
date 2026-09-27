<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $t) {
            $t->string('role')->default('user'); $t->timestamp('disabled_at')->nullable();
            $t->string('language', 5)->default('en'); $t->string('timezone')->default('UTC');
            $t->string('avatar')->nullable(); $t->json('notification_preferences')->nullable();
            $t->timestamp('last_active_at')->nullable()->index();
        });
        Schema::create('personal_access_tokens', function (Blueprint $t) {
            $t->id(); $t->morphs('tokenable'); $t->text('name'); $t->string('token',64)->unique();
            $t->text('abilities')->nullable(); $t->timestamp('last_used_at')->nullable();
            $t->timestamp('expires_at')->nullable()->index(); $t->timestamps();
        });
        foreach (['countries','leagues','teams','players','coaches','bookmakers','markets'] as $table) {
            Schema::create($table, function (Blueprint $t) use ($table) {
                $t->id(); $this->provider($t); $t->string('name')->index();
                $t->string('logo')->nullable(); $t->json('data')->nullable();
                $t->boolean('featured')->default(false); $t->timestamp('synced_at')->nullable(); $t->timestamps();
            });
        }
        Schema::create('seasons', function(Blueprint $t) {
            $t->id(); $t->foreignId('league_id')->constrained(); $t->integer('year');
            $t->unique(['league_id','year']); $t->timestamps();
        });
        Schema::create('fixtures', function(Blueprint $t) {
            $t->id(); $this->provider($t); $t->foreignId('league_id')->constrained();
            $t->foreignId('home_team_id')->constrained('teams'); $t->foreignId('away_team_id')->constrained('teams');
            $t->integer('season'); $t->timestampTz('kickoff')->index(); $t->string('status',10)->index();
            $t->integer('home_goals')->nullable(); $t->integer('away_goals')->nullable();
            $t->integer('elapsed')->nullable(); $t->json('data'); $t->boolean('featured')->default(false);
            $t->timestampTz('synced_at'); $t->timestamps();
        });
        foreach (['fixture_events','fixture_statistics','fixture_team_statistics','lineups','injuries','odds'] as $table) {
            Schema::create($table, function(Blueprint $t) {
                $t->id(); $t->foreignId('fixture_id')->constrained()->cascadeOnDelete();
                $this->provider($t); $t->json('data'); $t->timestampTz('synced_at'); $t->timestamps();
            });
        }
        Schema::create('lineup_players', function(Blueprint $t) {
            $t->id(); $t->foreignId('lineup_id')->constrained()->cascadeOnDelete();
            $t->foreignId('player_id')->constrained(); $t->boolean('starter'); $t->string('position')->nullable();
            $t->unique(['lineup_id','player_id']); $t->timestamps();
        });
        Schema::create('standings', function(Blueprint $t) {
            $t->id(); $this->provider($t); $t->foreignId('league_id')->constrained();
            $t->integer('season'); $t->json('data'); $t->timestampTz('synced_at'); $t->timestamps();
        });
        Schema::create('model_versions', function(Blueprint $t) {
            $t->id(); $t->string('name')->unique(); $t->json('metadata'); $t->timestamps();
        });
        Schema::create('predictions', function(Blueprint $t) {
            $t->id(); $t->foreignId('fixture_id')->constrained(); $t->foreignId('model_version_id')->constrained();
            $t->timestampTz('generated_at'); $t->timestampTz('data_snapshot_time');
            $t->timestampTz('locked_at')->nullable(); $t->string('data_quality');
            $t->json('data_snapshot'); $t->json('output');
            $t->unique(['fixture_id','model_version_id']); $t->timestamps();
        });
        Schema::create('prediction_probabilities', function(Blueprint $t) {
            $t->id(); $t->foreignId('prediction_id')->constrained(); $t->string('market');
            $t->string('selection'); $t->double('probability'); $t->double('fair_odds')->nullable();
            $t->unique(['prediction_id','market','selection']); $t->timestamps();
        });
        Schema::create('prediction_explanations', function(Blueprint $t) {
            $t->id(); $t->foreignId('prediction_id')->constrained(); $t->json('factors'); $t->timestamps();
        });
        Schema::create('prediction_results', function(Blueprint $t) {
            $t->id(); $t->foreignId('prediction_id')->constrained(); $t->string('market');
            $t->string('outcome'); $t->boolean('correct'); $t->double('brier_score'); $t->double('log_loss');
            $t->double('selected_probability'); $t->unique(['prediction_id','market']); $t->timestamps();
        });
        foreach (['saved_matches'=>'fixture','favorite_teams'=>'team','favorite_leagues'=>'league'] as $table=>$entity) {
            Schema::create($table, function(Blueprint $t) use ($entity) {
                $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete();
                $t->foreignId($entity.'_id')->constrained()->cascadeOnDelete();
                $t->unique(['user_id',$entity.'_id']); $t->timestamps();
            });
        }
        Schema::create('saved_analyses', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete(); $t->string('name'); $t->timestamps();
        });
        Schema::create('saved_analysis_matches', function(Blueprint $t) {
            $t->id(); $t->foreignId('saved_analysis_id')->constrained()->cascadeOnDelete();
            $t->foreignId('prediction_id')->constrained(); $t->string('market'); $t->string('selection');
            $t->unique(['saved_analysis_id','prediction_id','market']); $t->timestamps();
        });
        Schema::create('subscriptions', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete(); $t->string('provider');
            $t->string('provider_external_id')->unique(); $t->string('plan'); $t->string('status');
            $t->timestampTz('expires_at')->index(); $t->timestamps();
        });
        Schema::create('subscription_events', function(Blueprint $t) {
            $t->id(); $t->string('provider'); $t->string('provider_external_id')->unique();
            $t->json('data'); $t->timestamps();
        });
        Schema::create('analysis_usage', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->date('date'); $t->unsignedInteger('count')->default(0); $t->unique(['user_id','date']);
        });
        Schema::create('notifications', function(Blueprint $t) {
            $t->uuid('id')->primary(); $t->string('type'); $t->morphs('notifiable');
            $t->text('data'); $t->timestamp('read_at')->nullable(); $t->timestamps();
        });
        Schema::create('device_tokens', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->text('token'); $t->string('token_hash',64)->unique(); $t->string('platform'); $t->timestamps();
        });
        Schema::create('api_usage', function(Blueprint $t) {
            $t->id(); $t->string('provider'); $t->string('endpoint'); $t->integer('status');
            $t->integer('response_time'); $t->boolean('cache_hit'); $t->integer('request_count')->default(1);
            $t->timestamp('created_at')->index();
        });
        Schema::create('app_settings', function(Blueprint $t) {
            $t->string('key')->primary(); $t->json('value'); $t->timestamps();
        });
        Schema::create('audit_logs', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $t->string('action'); $t->string('target'); $t->json('metadata')->nullable(); $t->timestamp('created_at');
        });
        Schema::create('ad_events', function(Blueprint $t) {
            $t->id(); $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->string('event_id')->unique(); $t->string('type'); $t->string('placement');
            $t->boolean('verified')->default(false); $t->timestamps();
        });
    }
    private function provider(Blueprint $t): void {
        $t->string('provider')->default('api-football'); $t->string('provider_external_id');
        $t->unique(['provider','provider_external_id']);
    }
    public function down(): void {
        foreach (['ad_events','audit_logs','app_settings','api_usage','device_tokens','notifications','analysis_usage',
            'subscription_events','subscriptions','saved_analysis_matches','saved_analyses','favorite_leagues','favorite_teams','saved_matches',
            'prediction_results','prediction_explanations','prediction_probabilities','predictions','model_versions','standings','lineup_players',
            'odds','injuries','lineups','fixture_team_statistics','fixture_statistics','fixture_events','fixtures','seasons','markets','bookmakers','coaches','players','teams','leagues','countries','personal_access_tokens'] as $table) Schema::dropIfExists($table);
        Schema::table('users', fn(Blueprint $t) => $t->dropColumn(['role','disabled_at','language','timezone','avatar','notification_preferences','last_active_at']));
    }
};
