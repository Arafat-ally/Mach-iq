<?php
namespace App\Http\Middleware;
use Closure;
class ActiveAccount {
    public function handle($request, Closure $next) {
        abort_if($request->user()?->disabled_at, 403, 'Account disabled.');
        return $next($request);
    }
}
