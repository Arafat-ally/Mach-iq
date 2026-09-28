<?php
namespace App\Http\Controllers;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{DB, Hash, Password};
use Illuminate\Validation\Rules\Password as PasswordRule;

class AuthController extends Controller {
    public function device(Request $r) {
        $data=$r->validate(['name'=>'required|string|max:100','email'=>'required|email|max:254',
            'device_key'=>'required|string|size:64|regex:/\A[a-f0-9]{64}\z/']);
        $hash=hash('sha256',$data['device_key']);
        // Email is contact information, never proof of ownership of another account.
        $user=User::where('device_key_hash',$hash)->first();
        abort_if($user?->disabled_at,403,'Account disabled.');
        if (!$user) {
            $user=new User;
            $user->email=\Illuminate\Support\Str::uuid().'@device.matchiq.invalid';
            $user->password=\Illuminate\Support\Str::random(64);
            $user->device_key_hash=$hash;
        }
        $user->name=$data['name'];
        $user->contact_email=strtolower($data['email']);
        $user->last_active_at=now();
        $user->save();
        return $this->session($user->refresh());
    }
    public function register(Request $r) {
        $data = $r->validate(['name'=>'required|string|max:100','email'=>'required|email|max:254|unique:users',
            'password'=>['required','confirmed',PasswordRule::min(12)->mixedCase()->numbers()]]);
        $data['email'] = strtolower($data['email']);
        $user = User::create($data);
        return response()->json($this->session($user),201);
    }
    public function login(Request $r) {
        $data = $r->validate(['email'=>'required|email','password'=>'required|string']);
        $user = User::where('email',strtolower($data['email']))->first();
        if (!$user || !Hash::check($data['password'],$user->password) || $user->disabled_at) {
            abort(422,'Invalid credentials.');
        }
        $user->forceFill(['last_active_at'=>now()])->save();
        return $this->session($user);
    }
    private function session(User $user): array {
        return ['user'=>$user, 'token'=>$user->createToken('mobile',['*'],now()->addDays(30))->plainTextToken,'expires_in'=>2592000];
    }
    public function refresh(Request $r) {
        return DB::transaction(function() use($r) {
            $r->user()->currentAccessToken()->delete();
            return $this->session($r->user());
        });
    }
    public function logout(Request $r) { $r->user()->currentAccessToken()->delete(); return response()->noContent(); }
    public function forgot(Request $r) {
        $r->validate(['email'=>'required|email']);
        Password::sendResetLink(['email'=>strtolower($r->email)]);
        return ['message'=>'If this account exists, a reset link has been sent.'];
    }
    public function reset(Request $r) {
        $data = $r->validate(['email'=>'required|email','token'=>'required|string',
            'password'=>['required','confirmed',PasswordRule::min(12)->mixedCase()->numbers()]]);
        $status = Password::reset($data, function(User $user,string $password) {
            $user->forceFill(['password'=>$password,'remember_token'=>\Illuminate\Support\Str::random(60)])->save();
            $user->tokens()->delete();
        });
        abort_unless($status === Password::PASSWORD_RESET,422,'Invalid or expired reset link.');
        return ['message'=>'Password reset.'];
    }
    public function verify(Request $r, int $id, string $hash) {
        $user = User::findOrFail($id);
        abort_unless(hash_equals(sha1($user->getEmailForVerification()),$hash),403);
        if (!$user->hasVerifiedEmail()) { $user->markEmailAsVerified(); event(new \Illuminate\Auth\Events\Verified($user)); }
        return ['message'=>'Email verified.'];
    }
}
