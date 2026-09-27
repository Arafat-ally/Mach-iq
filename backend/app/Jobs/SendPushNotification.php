<?php
namespace App\Jobs;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\{DB,Http};
use App\Models\User;
use Google\Auth\Credentials\ServiceAccountCredentials;
class SendPushNotification implements ShouldQueue {
    use Queueable;
    public int $tries=3;
    public function __construct(public int $userId,public string $category,public string $title,public string $body,public array $data=[]) {}
    public function handle(): void {
        $user=User::find($this->userId); if(!$user || $user->disabled_at) return;
        $preferences=json_decode($user->notification_preferences ?: '{}',true);
        if(($preferences[$this->category] ?? true)===false) return;
        $config=config('services.firebase.credentials'); if(!$config) return;
        $credentials=new ServiceAccountCredentials('https://www.googleapis.com/auth/firebase.messaging',json_decode($config,true,512,JSON_THROW_ON_ERROR));
        $token=$credentials->fetchAuthToken()['access_token'];
        foreach(DB::table('device_tokens')->where('user_id',$this->userId)->get() as $device) {
            $response=Http::withToken($token)->timeout(10)->post('https://fcm.googleapis.com/v1/projects/'.config('services.firebase.project_id').'/messages:send',
                ['message'=>['token'=>decrypt($device->token),'notification'=>['title'=>$this->title,'body'=>$this->body],'data'=>array_map('strval',$this->data)]]);
            if($response->status()===404) DB::table('device_tokens')->where('id',$device->id)->delete();
            elseif(!$response->successful()) throw new \RuntimeException('Push delivery failed: '.$response->status());
        }
    }
}
