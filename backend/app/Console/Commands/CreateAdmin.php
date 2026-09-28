<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;
use App\Models\User;
class CreateAdmin extends Command {
    protected $signature='matchiq:admin {email}';
    protected $description='Grant administrator role to an existing password account (operator only)';
    public function handle(): int {
        $user=User::where('email',strtolower($this->argument('email')))->first();
        if(!$user || $user->device_key_hash || $user->disabled_at) { $this->error('Create an active password account for the admin website first.'); return 1; }
        $user->forceFill(['role'=>'admin'])->save();
        \Illuminate\Support\Facades\DB::table('audit_logs')->insert(['user_id'=>$user->id,'action'=>'admin.granted.cli','target'=>(string)$user->id,'created_at'=>now()]);
        $this->info('Administrator role granted.'); return 0;
    }
}
