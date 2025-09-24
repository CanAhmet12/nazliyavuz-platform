<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SharedFile extends Model
{
    use HasFactory;

    protected $fillable = [
        'uploaded_by_id',
        'receiver_id',
        'reservation_id',
        'file_name',
        'file_path',
        'file_url',
        'file_type',
        'file_size',
        'description',
        'category',
    ];

    protected function casts(): array
    {
        return [
            'file_size' => 'integer',
        ];
    }

    /**
     * Get the user who uploaded the file
     */
    public function uploadedBy()
    {
        return $this->belongsTo(User::class, 'uploaded_by_id');
    }

    /**
     * Get the user who is the receiver of the file
     */
    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    /**
     * Get the reservation associated with the file
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Scope for files by category
     */
    public function scopeByCategory($query, string $category)
    {
        return $query->where('category', $category);
    }

    /**
     * Scope for files uploaded by specific user
     */
    public function scopeUploadedBy($query, int $userId)
    {
        return $query->where('uploaded_by_id', $userId);
    }

    /**
     * Scope for files received by specific user
     */
    public function scopeReceivedBy($query, int $userId)
    {
        return $query->where('receiver_id', $userId);
    }

    /**
     * Scope for files in specific reservation
     */
    public function scopeInReservation($query, int $reservationId)
    {
        return $query->where('reservation_id', $reservationId);
    }

    /**
     * Get file size in human readable format
     */
    public function getFileSizeFormattedAttribute(): string
    {
        $bytes = $this->file_size;
        $units = ['B', 'KB', 'MB', 'GB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, 2) . ' ' . $units[$i];
    }

    /**
     * Get file icon based on type
     */
    public function getFileIconAttribute(): string
    {
        $mimeType = $this->file_type;
        
        if (str_starts_with($mimeType, 'image/')) {
            return 'image';
        } elseif (str_starts_with($mimeType, 'video/')) {
            return 'video';
        } elseif (str_starts_with($mimeType, 'audio/')) {
            return 'audio';
        } elseif (str_starts_with($mimeType, 'application/pdf')) {
            return 'picture_as_pdf';
        } elseif (str_starts_with($mimeType, 'application/')) {
            return 'description';
        } elseif (str_starts_with($mimeType, 'text/')) {
            return 'text_snippet';
        } else {
            return 'insert_drive_file';
        }
    }

    /**
     * Get category in Turkish
     */
    public function getCategoryInTurkishAttribute(): string
    {
        $categories = [
            'document' => 'Döküman',
            'homework' => 'Ödev',
            'notes' => 'Notlar',
            'resource' => 'Kaynak',
            'other' => 'Diğer',
        ];

        return $categories[$this->category] ?? $this->category;
    }

    /**
     * Check if file is image
     */
    public function getIsImageAttribute(): bool
    {
        return str_starts_with($this->file_type, 'image/');
    }

    /**
     * Check if file is video
     */
    public function getIsVideoAttribute(): bool
    {
        return str_starts_with($this->file_type, 'video/');
    }

    /**
     * Check if file is audio
     */
    public function getIsAudioAttribute(): bool
    {
        return str_starts_with($this->file_type, 'audio/');
    }

    /**
     * Check if file is PDF
     */
    public function getIsPdfAttribute(): bool
    {
        return $this->file_type === 'application/pdf';
    }

    /**
     * Check if file is document
     */
    public function getIsDocumentAttribute(): bool
    {
        return str_starts_with($this->file_type, 'application/') && 
               !str_starts_with($this->file_type, 'application/pdf');
    }

    /**
     * Get time since file was uploaded
     */
    public function getTimeSinceUploadedAttribute(): string
    {
        return $this->created_at->diffForHumans();
    }

    /**
     * Get download URL (if file_url is accessible)
     */
    public function getDownloadUrlAttribute(): string
    {
        return $this->file_url;
    }

    /**
     * Check if user can download this file
     */
    public function canBeDownloadedBy(User $user): bool
    {
        return $this->uploaded_by_id === $user->id || $this->receiver_id === $user->id;
    }

    /**
     * Check if user can delete this file
     */
    public function canBeDeletedBy(User $user): bool
    {
        return $this->uploaded_by_id === $user->id || $this->receiver_id === $user->id;
    }

    /**
     * Get file extension
     */
    public function getFileExtensionAttribute(): string
    {
        return pathinfo($this->file_name, PATHINFO_EXTENSION);
    }

    /**
     * Get file name without extension
     */
    public function getFileNameWithoutExtensionAttribute(): string
    {
        return pathinfo($this->file_name, PATHINFO_FILENAME);
    }
}