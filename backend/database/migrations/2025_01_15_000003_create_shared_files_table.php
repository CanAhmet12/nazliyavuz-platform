<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('shared_files', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('reservation_id')->nullable()->constrained()->onDelete('set null');
            $table->string('filename');
            $table->text('description')->nullable();
            $table->enum('category', ['document', 'homework', 'notes', 'resource', 'other'])->default('document');
            $table->string('file_path');
            $table->string('file_url');
            $table->bigInteger('file_size');
            $table->string('mime_type');
            $table->timestamps();
            
            $table->index(['sender_id', 'receiver_id']);
            $table->index(['receiver_id', 'created_at']);
            $table->index(['reservation_id']);
            $table->index(['category']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('shared_files');
    }
};
