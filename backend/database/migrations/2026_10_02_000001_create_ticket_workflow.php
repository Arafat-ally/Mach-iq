<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('market_quotes',function(Blueprint $t) {
            $t->id();$t->foreignId('fixture_id')->constrained();$t->string('market');$t->string('selection');
            $t->string('bookmaker');$t->decimal('odds',12,4);$t->timestampTz('observed_at');$t->timestamps();
            $t->unique(['fixture_id','market','selection','bookmaker']);
        });
        foreach(['daily_tickets','user_analyses'] as $table) Schema::create($table,function(Blueprint $t) use($table) {
            $t->id();
            if($table==='daily_tickets') {$t->date('ticket_date');$t->string('category');$t->unique(['ticket_date','category']);}
            else {$t->foreignId('user_id')->constrained();$t->foreignId('daily_ticket_id')->nullable()->constrained();$t->uuid('request_key');$t->unique(['user_id','request_key']);}
            $t->string('name');$t->string('status')->default('PENDING')->index();$t->decimal('total_odds',24,6)->nullable();
            $t->double('confidence');$t->unsignedInteger('selection_count');$t->timestampTz('generated_at');
            $t->timestampTz('locked_at')->nullable();$t->timestampTz('settled_at')->nullable();$t->timestamps();
        });
        foreach(['daily_ticket_items'=>'daily_ticket_id','user_analysis_items'=>'user_analysis_id'] as $table=>$parent) Schema::create($table,function(Blueprint $t) use($parent) {
            $t->id();$t->foreignId($parent)->constrained();$t->foreignId('fixture_id')->constrained();$t->foreignId('prediction_id')->constrained();
            $t->foreignId('quote_id')->nullable()->constrained('market_quotes');$t->string('market');$t->string('selection');
            $t->decimal('odds_at_prediction',12,4)->nullable();$t->string('bookmaker')->nullable();$t->timestampTz('odds_observed_at')->nullable();
            $t->double('confidence_at_prediction');$t->timestampTz('prediction_created_at');$t->timestampTz('kickoff_time');
            $t->timestampTz('locked_at')->nullable();$t->string('status')->default('PENDING')->index();$t->string('settlement_reason')->nullable();
            $t->integer('final_home')->nullable();$t->integer('final_away')->nullable();$t->timestampTz('settled_at')->nullable();$t->timestamps();
            $t->unique([$parent,'fixture_id']);
        });
        Schema::create('ticket_bookmarks',function(Blueprint $t) {$t->id();$t->foreignId('user_id')->constrained();$t->foreignId('daily_ticket_id')->constrained();$t->unique(['user_id','daily_ticket_id']);$t->timestamps();});
    }
    public function down(): void {
        foreach(['ticket_bookmarks','user_analysis_items','daily_ticket_items','user_analyses','daily_tickets','market_quotes'] as $t) Schema::dropIfExists($t);
    }
};
