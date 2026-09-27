<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\User;
use App\Services\SubscriptionVerifier;
class SubscriptionController extends Controller {
    public function sync(Request $r,SubscriptionVerifier $verifier) { return ['is_pro'=>$verifier->sync($r->user())]; }
    public function webhook(Request $r,SubscriptionVerifier $verifier) {
        $secret=config('services.revenuecat.webhook_secret');
        abort_unless($secret && hash_equals($secret,(string)$r->header('Authorization')),401);
        $data=$r->validate(['event.id'=>'required|string|max:200','event.app_user_id'=>'required|string|max:100']);
        $event=$data['event'];
        if(DB::table('subscription_events')->where('provider_external_id',$event['id'])->exists()) return ['received'=>true];
        $user=ctype_digit($event['app_user_id']) ? User::find($event['app_user_id']) : null;
        if($user) $verifier->sync($user);
        DB::table('subscription_events')->insertOrIgnore(['provider'=>'revenuecat','provider_external_id'=>$event['id'],
            'data'=>json_encode(['user_id'=>$user?->id]),'created_at'=>now(),'updated_at'=>now()]);
        return ['received'=>true];
    }
}
