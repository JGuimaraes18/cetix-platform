<?php

declare(strict_types=1);

use Illuminate\Http\Request;

Route::get('/v1/health', function (): \Illuminate\Http\JsonResponse {
    $checks = [];

    try {
        DB::connection()->getPdo();
        $checks['database'] = 'ok';
    } catch (\Throwable $e) {
        $checks['database'] = 'error: '.$e->getMessage();
    }

    try {
        $redis = app('redis')->connection();
        $redis->ping();
        $checks['redis'] = 'ok';
    } catch (\Throwable $e) {
        $checks['redis'] = 'error: '.$e->getMessage();
    }

    $healthy = $checks['database'] === 'ok' && $checks['redis'] === 'ok';

    return response()->json([
        'status' => $healthy ? 'ok' : 'error',
        'checks' => $checks,
    ], $healthy ? 200 : 503);
});
