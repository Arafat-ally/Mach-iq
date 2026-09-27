<?php
namespace App\Services;
use App\Contracts\FootballDataProvider;
use Illuminate\Support\Facades\{Cache, DB, Http};
use Symfony\Component\HttpKernel\Exception\HttpException;

class ApiFootballProvider implements FootballDataProvider {
    public const ENDPOINTS = ['countries','leagues','leagues/seasons','teams','teams/statistics','teams/seasons',
        'fixtures','fixtures/events','fixtures/statistics','fixtures/headtohead','fixtures/lineups',
        'standings','injuries','players','players/squads','players/topscorers','coachs','transfers','trophies',
        'sidelined','odds','odds/live','odds/bookmakers','odds/bets','predictions'];

    public function fetch(string $resource, array $filters = []): array {
        abort_unless(in_array($resource, self::ENDPOINTS, true), 422, 'Unsupported data resource.');
        ksort($filters);
        $key = 'football:'.hash('sha256', $resource.json_encode($filters));
        $cached = Cache::get($key);
        if ($cached && $cached['expires_at'] > time()) {
            $this->usage($resource, 200, 0, true);
            return $this->envelope($cached, false);
        }
        // Shared lock collapses concurrent misses across API instances.
        $lock = Cache::lock($key.':lock', 20);
        if (!$lock->get()) {
            if ($cached) return $this->envelope($cached, true);
            throw new HttpException(503, 'Data synchronization in progress. Please retry.');
        }
        try {
            $cached = Cache::get($key);
            if ($cached && $cached['expires_at'] > time()) return $this->envelope($cached, false);
            if (!config('matchiq.provider_key')) return $this->unavailable($cached);
            $quotaKey = 'provider-quota:'.now('UTC')->toDateString();
            $quotaLock = Cache::lock($quotaKey.':lock', 5);
            $allowed = $quotaLock->block(2, function() use ($quotaKey) {
                $used = (int) Cache::get($quotaKey, 0);
                if ($used >= floor(config('matchiq.provider_quota') * .95)) return false;
                Cache::put($quotaKey, $used + 1, now('UTC')->endOfDay()->addMinute());
                return true;
            });
            if (!$allowed) return $this->unavailable($cached, 'Provider quota reached.');
            $start = microtime(true);
            try {
                $response = Http::baseUrl(config('matchiq.provider_url'))->withHeaders([
                    'x-apisports-key' => config('matchiq.provider_key')])->connectTimeout(3)->timeout(12)->get($resource, $filters);
                $valid = $response->successful() && empty($response->json('errors')) && is_array($response->json('response'));
                $this->usage($resource, $valid ? 200 : ($response->successful() ? 502 : $response->status()), (int)((microtime(true)-$start)*1000), false);
                if (!$valid) return $this->unavailable($cached);
                $ttlKey = isset($filters['live']) ? 'fixtures/live' : $resource;
                $ttl = config('matchiq.ttl.'.$ttlKey, config('matchiq.ttl.default'));
                $value = ['data'=>$response->json('response'), 'paging'=>$response->json('paging'),
                    'updated_at'=>now()->toIso8601String(), 'expires_at'=>time()+$ttl];
                Cache::put($key, $value, max(86400, $ttl * 2));
                Cache::put('provider:last_success', now()->toIso8601String(), 86400);
                return $this->envelope($value, false);
            } catch (\Illuminate\Http\Client\ConnectionException $e) {
                $this->usage($resource, 503, (int)((microtime(true)-$start)*1000), false);
                return $this->unavailable($cached);
            }
        } finally { $lock->release(); }
    }
    private function unavailable(?array $cached, string $message = 'Football data temporarily unavailable.'): array {
        if ($cached) return $this->envelope($cached, true);
        throw new HttpException(503, $message);
    }
    private function envelope(array $value, bool $stale): array {
        return ['data'=>$value['data'], 'paging'=>$value['paging'] ?? null, 'updated_at'=>$value['updated_at'], 'stale'=>$stale];
    }
    private function usage(string $endpoint, int $status, int $milliseconds, bool $hit): void {
        DB::table('api_usage')->insert(['provider'=>'api-football', 'endpoint'=>$endpoint,
            'status'=>$status, 'response_time'=>$milliseconds, 'cache_hit'=>$hit,
            'request_count'=>$hit ? 0 : 1, 'created_at'=>now()]);
    }
}
