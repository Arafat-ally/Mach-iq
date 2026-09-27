<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Prediction extends Model {
    protected $guarded = [];
    protected function casts(): array { return ['output'=>'array','data_snapshot'=>'array','generated_at'=>'datetime','locked_at'=>'datetime']; }
    protected static function booted(): void {
        static::updating(function ($prediction) {
            $changes = array_diff(array_keys($prediction->getDirty()), ['locked_at', 'updated_at']);
            if ($changes) throw new \LogicException('Predictions are immutable.');
        });
        static::deleting(fn() => throw new \LogicException('Predictions cannot be deleted.'));
    }
    public function fixture() { return $this->belongsTo(Fixture::class); }
}
