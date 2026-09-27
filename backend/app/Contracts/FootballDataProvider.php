<?php
namespace App\Contracts;
interface FootballDataProvider {
    /** Return a common envelope: data, stale, updated_at. Never disclose provider credentials. */
    public function fetch(string $resource, array $filters = []): array;
}
