<?php

declare(strict_types=1);

arch('providers do not access module internals', function (): void {
    expect('App\Providers')
        ->not->toUse('App\Modules');
});

arch('shared module classes do not use HTTP classes', function (): void {
    expect('App\Modules\Shared')
        ->not->toUse('Illuminate\Http');
});
