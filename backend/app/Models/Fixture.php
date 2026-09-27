<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Fixture extends Model {
    protected $guarded = [];
    protected function casts(): array { return ['data'=>'array','kickoff'=>'immutable_datetime','synced_at'=>'datetime']; }
    public function homeTeam() { return $this->belongsTo(Team::class, 'home_team_id'); }
    public function awayTeam() { return $this->belongsTo(Team::class, 'away_team_id'); }
    public function league() { return $this->belongsTo(League::class); }
}
