<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\{AuthController,FootballController,AccountController,AnalysisController,HealthController,AdminController};
Route::get('health',HealthController::class);
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
