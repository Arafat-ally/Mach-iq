<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::table('users',function(Blueprint $table) {
            $table->string('contact_email',254)->nullable();
            $table->string('device_key_hash',64)->nullable()->unique();
        });
    }
    public function down(): void {
        Schema::table('users',function(Blueprint $table) {
            $table->dropUnique(['device_key_hash']);
            $table->dropColumn(['contact_email','device_key_hash']);
        });
    }
};
