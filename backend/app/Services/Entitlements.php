<?php
namespace App\Services;
use App\Models\User;
use Illuminate\Support\Facades\DB;
class Entitlements {
    public function pro(User $user): bool {
        return DB::table('subscriptions')->where('user_id',$user->id)->where('status','active')->where('expires_at','>',now())->exists();
    }
    public function setting(string $key, mixed $default): mixed {
        $value = DB::table('app_settings')->where('key',$key)->value('value');
        return $value === null ? $default : json_decode($value,true);
    }
    public function limit(User $user): int {
        $key = $this->pro($user) ? 'pro_limit' : 'free_limit';
        return (int) $this->setting($key, config('matchiq.'.$key));
    }
    public function consume(User $user, int $count): void {
        DB::transaction(function() use($user,$count) {
            // Lock user row as well as usage: safe even when today's counter does not exist yet.
            User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            $date = now('UTC')->toDateString();
            DB::table('analysis_usage')->insertOrIgnore(['user_id'=>$user->id,'date'=>$date,'count'=>0]);
            $usage = DB::table('analysis_usage')->where('user_id',$user->id)->where('date',$date);
            abort_if($usage->value('count')+$count > $this->limit($user), 429, 'Daily analysis limit reached.');
            $usage->increment('count',$count);
        });
    }
    public function refund(User $user, int $count, string $date): void {
        DB::table('analysis_usage')->where('user_id',$user->id)->where('date',$date)->where('count','>=',$count)->decrement('count',$count);
    }
}
