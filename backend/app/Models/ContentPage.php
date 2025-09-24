<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ContentPage extends Model
{
    use HasFactory;

    protected $fillable = [
        'slug',
        'title',
        'content',
        'meta_title',
        'meta_description',
        'is_active',
        'sort_order',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    /**
     * Get page by slug
     */
    public static function getBySlug(string $slug): ?self
    {
        return self::where('slug', $slug)
            ->where('is_active', true)
            ->first();
    }

    /**
     * Get all active pages
     */
    public static function getActivePages()
    {
        return self::where('is_active', true)
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * Scope for active pages
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope for ordered pages
     */
    public function scopeOrdered($query)
    {
        return $query->orderBy('sort_order');
    }
}
