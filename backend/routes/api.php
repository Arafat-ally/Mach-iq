<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\{AuthController,FootballController,AccountController,AnalysisController,HealthController,AdminController};
Route::get('health',HealthController::class);
Route::get('daily-tickets',[\App\Http\Controllers\TicketController::class,'daily'])->middleware('throttle:api');
Route::get('daily-tickets/{id}',[\App\Http\Controllers\TicketController::class,'dailyDetail'])->whereNumber('id')->middleware('throttle:api');
Route::get('performance/daily',fn(\Illuminate\Http\Request $r,\App\Http\Controllers\TicketController $c)=>$c->stats($r,'daily'))->middleware('throttle:api');
Route::post('subscriptions/webhook',[\App\Http\Controllers\SubscriptionController::class,'webhook'])->middleware('throttle:60,1');
Route::middleware('throttle:api')->group(function() {
    Route::prefix('auth')->middleware('throttle:auth')->group(function() {
        Route::post('device',[AuthController::class,'device']);
        Route::post('register',[AuthController::class,'register']); Route::post('login',[AuthController::class,'login']);
        Route::post('social',\App\Http\Controllers\IdentityController::class);
        Route::post('forgot-password',[AuthController::class,'forgot']); Route::post('reset-password',[AuthController::class,'reset']);
    });
    Route::get('email/verify/{id}/{hash}',[AuthController::class,'verify'])->middleware('signed')->name('verification.verify');
    Route::get('fixtures',[FootballController::class,'fixtures']); Route::get('fixtures/{fixture}',[FootballController::class,'fixture']);
    Route::get('fixtures/{fixture}/{section}',[FootballController::class,'detail']);
    Route::get('leagues',[FootballController::class,'leagues']); Route::get('leagues/{league}',[FootballController::class,'league']);
    Route::get('teams',[FootballController::class,'teams']); Route::get('teams/{team}',[FootballController::class,'team']);
    Route::get('search',[FootballController::class,'search'])->middleware('throttle:search');
    Route::middleware(['auth:sanctum','active'])->group(function() {
        Route::get('my-analyses',[\App\Http\Controllers\TicketController::class,'personal']);
        Route::get('my-analyses/{id}',[\App\Http\Controllers\TicketController::class,'personalDetail']);
        Route::post('analysis-preview',[\App\Http\Controllers\TicketController::class,'preview'])->middleware('throttle:analysis');
        Route::post('my-analyses',[\App\Http\Controllers\TicketController::class,'save'])->middleware('throttle:analysis');
        Route::get('ticket-bookmarks',[\App\Http\Controllers\TicketController::class,'bookmarks']);
        Route::match(['PUT','DELETE'],'daily-tickets/{id}/bookmark',[\App\Http\Controllers\TicketController::class,'bookmark']);
        Route::post('daily-tickets/{id}/picks',[\App\Http\Controllers\TicketController::class,'picks']);
        Route::get('performance/personal',fn(\Illuminate\Http\Request $r,\App\Http\Controllers\TicketController $c)=>$c->stats($r,'personal'));
        Route::post('auth/refresh',[AuthController::class,'refresh']); Route::post('auth/logout',[AuthController::class,'logout']);
        Route::post('auth/verification-notification',function(\Illuminate\Http\Request $r) { if(!$r->user()->hasVerifiedEmail()) $r->user()->sendEmailVerificationNotification(); return ['sent'=>true]; })->middleware('throttle:auth');
        Route::get('profile',[AccountController::class,'profile']); Route::patch('profile',[AccountController::class,'update']);
        Route::post('subscriptions/sync',[\App\Http\Controllers\SubscriptionController::class,'sync'])->middleware('throttle:6,1');
        Route::get('favorites',[AccountController::class,'favorites']);
        Route::match(['PUT','DELETE'],'favorites/{type}/{id}',[AccountController::class,'favorite']);
        Route::get('notifications',[AccountController::class,'notifications']); Route::patch('notifications/{id}',[AccountController::class,'readNotification']);
        Route::post('devices',[AccountController::class,'device']); Route::post('ad-events',[AccountController::class,'adEvent']);
        Route::post('analyses',[AnalysisController::class,'create'])->middleware('throttle:analysis');
        Route::get('saved-analyses',[AnalysisController::class,'saved']); Route::post('saved-analyses',[AnalysisController::class,'save']);
        Route::delete('saved-analyses/{id}',[AnalysisController::class,'delete']); Route::get('history',[AnalysisController::class,'history']);
        Route::prefix('admin')->middleware('admin')->group(function() {
            Route::put('users/{user}/trial',[AdminController::class,'trial']);
            Route::delete('users/{user}/trial',[AdminController::class,'revokeTrial']);
            Route::get('dashboard',[AdminController::class,'dashboard']); Route::get('users',[AdminController::class,'users']);
            Route::patch('users/{user}',[AdminController::class,'disable']); Route::get('settings',[AdminController::class,'settings']);
            Route::put('settings/{key}',[AdminController::class,'updateSetting']);
        });
    });
});
