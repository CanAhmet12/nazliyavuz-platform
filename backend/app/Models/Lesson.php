<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Lesson extends Model
{
    use HasFactory;

    protected $fillable = [
        'reservation_id',
        'teacher_id',
        'student_id',
        'status',
        'start_time',
        'end_time',
        'duration_minutes',
        'notes',
        'rating',
        'feedback',
    ];

    protected function casts(): array
    {
        return [
            'start_time' => 'datetime',
            'end_time' => 'datetime',
            'duration_minutes' => 'integer',
            'rating' => 'integer',
        ];
    }

    /**
     * Get the reservation associated with this lesson
     */
    public function reservation()
    {
        return $this->belongsTo(Reservation::class);
    }

    /**
     * Get the teacher of this lesson
     */
    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    /**
     * Get the student of this lesson
     */
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Scope for lessons by status
     */
    public function scopeByStatus($query, string $status)
    {
        return $query->where('status', $status);
    }

    /**
     * Scope for lessons by teacher
     */
    public function scopeByTeacher($query, int $teacherId)
    {
        return $query->where('teacher_id', $teacherId);
    }

    /**
     * Scope for lessons by student
     */
    public function scopeByStudent($query, int $studentId)
    {
        return $query->where('student_id', $studentId);
    }

    /**
     * Scope for completed lessons
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    /**
     * Scope for lessons in progress
     */
    public function scopeInProgress($query)
    {
        return $query->where('status', 'in_progress');
    }

    /**
     * Scope for lessons not started
     */
    public function scopeNotStarted($query)
    {
        return $query->where('status', 'not_started');
    }

    /**
     * Check if lesson is completed
     */
    public function getIsCompletedAttribute(): bool
    {
        return $this->status === 'completed';
    }

    /**
     * Check if lesson is in progress
     */
    public function getIsInProgressAttribute(): bool
    {
        return $this->status === 'in_progress';
    }

    /**
     * Check if lesson is not started
     */
    public function getIsNotStartedAttribute(): bool
    {
        return $this->status === 'not_started';
    }

    /**
     * Get status in Turkish
     */
    public function getStatusInTurkishAttribute(): string
    {
        $statuses = [
            'not_started' => 'Başlamadı',
            'in_progress' => 'Devam Ediyor',
            'completed' => 'Tamamlandı',
            'cancelled' => 'İptal Edildi',
        ];

        return $statuses[$this->status] ?? $this->status;
    }

    /**
     * Get duration in human readable format
     */
    public function getDurationFormattedAttribute(): ?string
    {
        if (!$this->duration_minutes) {
            return null;
        }

        $hours = floor($this->duration_minutes / 60);
        $minutes = $this->duration_minutes % 60;

        if ($hours > 0) {
            return "{$hours} saat {$minutes} dakika";
        }

        return "{$minutes} dakika";
    }

    /**
     * Get rating stars
     */
    public function getRatingStarsAttribute(): string
    {
        if (!$this->rating) {
            return '';
        }

        return str_repeat('★', $this->rating) . str_repeat('☆', 5 - $this->rating);
    }

    /**
     * Get time since lesson started
     */
    public function getTimeSinceStartedAttribute(): ?string
    {
        return $this->start_time ? $this->start_time->diffForHumans() : null;
    }

    /**
     * Get time since lesson ended
     */
    public function getTimeSinceEndedAttribute(): ?string
    {
        return $this->end_time ? $this->end_time->diffForHumans() : null;
    }

    /**
     * Calculate and update duration
     */
    public function updateDuration(): void
    {
        if ($this->start_time && $this->end_time) {
            $this->duration_minutes = $this->end_time->diffInMinutes($this->start_time);
            $this->save();
        }
    }

    /**
     * Check if lesson can be started
     */
    public function canBeStarted(): bool
    {
        return $this->status === 'not_started' && 
               $this->reservation && 
               $this->reservation->status === 'accepted';
    }

    /**
     * Check if lesson can be ended
     */
    public function canBeEnded(): bool
    {
        return $this->status === 'in_progress' && $this->start_time;
    }

    /**
     * Get average rating for teacher
     */
    public static function getAverageRatingForTeacher(int $teacherId): float
    {
        return static::where('teacher_id', $teacherId)
                    ->whereNotNull('rating')
                    ->avg('rating') ?? 0;
    }

    /**
     * Get total lessons count for teacher
     */
    public static function getTotalLessonsForTeacher(int $teacherId): int
    {
        return static::where('teacher_id', $teacherId)
                    ->where('status', 'completed')
                    ->count();
    }

    /**
     * Get total lessons count for student
     */
    public static function getTotalLessonsForStudent(int $studentId): int
    {
        return static::where('student_id', $studentId)
                    ->where('status', 'completed')
                    ->count();
    }

    /**
     * Get total duration for teacher
     */
    public static function getTotalDurationForTeacher(int $teacherId): int
    {
        return static::where('teacher_id', $teacherId)
                    ->where('status', 'completed')
                    ->sum('duration_minutes');
    }

    /**
     * Get total duration for student
     */
    public static function getTotalDurationForStudent(int $studentId): int
    {
        return static::where('student_id', $studentId)
                    ->where('status', 'completed')
                    ->sum('duration_minutes');
    }
}
