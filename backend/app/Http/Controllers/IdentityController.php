<?php
namespace App\Http\Controllers;
use App\Models\User;
use Firebase\JWT\{JWT,Key};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{Cache,Http};
class IdentityController extends Controller {
    public function __invoke(Request $r) {
        $r->validate(['id_token'=>'required|string|max:10000']);
        $project=config('services.firebase.project_id'); abort_unless($project,503,'Social sign-in is not configured.');
        try {
            $certs=Cache::remember('firebase:certs',1800,fn()=>Http::timeout(8)->get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com')->throw()->json());
            $keys=array_map(fn($cert)=>new Key($cert,'RS256'),$certs);
            $claims=JWT::decode($r->id_token,$keys);
            abort_unless($claims->aud===$project && $claims->iss==='https://securetoken.google.com/'.$project && !empty($claims->sub)
                && !empty($claims->email_verified) && filter_var($claims->email ?? '',FILTER_VALIDATE_EMAIL),401);
        } catch(\Throwable $e) { abort(401,'Invalid identity token.'); }
        $user=User::firstOrCreate(['email'=>strtolower($claims->email)],['name'=>$claims->name ?? 'MatchIQ User','password'=>\Illuminate\Support\Str::random(64)]);
        abort_if($user->disabled_at,403);
        $user->forceFill(['email_verified_at'=>$user->email_verified_at ?: now(),'last_active_at'=>now()])->save();
        return ['user'=>$user,'token'=>$user->createToken('mobile',['*'],now()->addDays(30))->plainTextToken,'expires_in'=>2592000];
    }
}
