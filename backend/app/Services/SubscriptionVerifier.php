<?php
namespace App\Services;
use App\Models\User;
use Illuminate\Support\Facades\{Http,DB};
use Carbon\Carbon;
class SubscriptionVerifier {
    public function sync(User $user): bool {
        abort_unless(config('services.revenuecat.key'),503,'Subscriptions are not configured.');
        $response=Http::withToken(config('services.revenuecat.key'))->timeout(10)->get('https://api.revenuecat.com/v1/subscribers/'.urlencode((string)$user->id));
        abort_unless($response->successful(),503,'Subscription verification unavailable.');
        $entitlement=$response->json('subscriber.entitlements.pro');
        $expires=$entitlement['expires_date'] ?? null;
        $active=$expires && Carbon::parse($expires)->isFuture();
        DB::table('subscriptions')->updateOrInsert(['provider_external_id'=>'revenuecat:'.$user->id],
            ['user_id'=>$user->id,'provider'=>'revenuecat','plan'=>$entitlement['product_identifier'] ?? 'free',
            'status'=>$active ? 'active':'expired','expires_at'=>$expires ? Carbon::parse($expires):now(), 'created_at'=>now(),'updated_at'=>now()]);
        return (bool)$active;
    }
}
