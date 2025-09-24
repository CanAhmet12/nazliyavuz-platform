<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Lesson;
use App\Models\Reservation;

class LessonController extends Controller
{
    /**
     * Get lesson status for reservation
     */
    public function getLessonStatus(Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user has access to this reservation
            if ($reservation->student_id !== $user->id && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyona erişim yetkiniz yok'
                    ]
                ], 403);
            }

            // Get or create lesson record
            $lesson = Lesson::firstOrCreate(
                ['reservation_id' => $reservation->id],
                [
                    'teacher_id' => $reservation->teacher_id,
                    'student_id' => $reservation->student_id,
                    'status' => 'not_started',
                ]
            );

            return response()->json([
                'success' => true,
                'lesson' => [
                    'id' => $lesson->id,
                    'status' => $lesson->status,
                    'start_time' => $lesson->start_time?->toISOString(),
                    'end_time' => $lesson->end_time?->toISOString(),
                    'notes' => $lesson->notes,
                    'rating' => $lesson->rating,
                    'feedback' => $lesson->feedback,
                    'duration_minutes' => $lesson->duration_minutes,
                    'created_at' => $lesson->created_at->toISOString(),
                    'updated_at' => $lesson->updated_at->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Get lesson status failed', [
                'error' => $e->getMessage(),
                'reservation_id' => $reservation->id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_LESSON_STATUS_ERROR',
                    'message' => 'Ders durumu alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Start lesson
     */
    public function startLesson(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_id' => 'required|exists:reservations,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $reservation = Reservation::findOrFail($request->reservation_id);

            // Check if user has access to this reservation
            if ($reservation->student_id !== $user->id && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyona erişim yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if reservation is accepted
            if ($reservation->status !== 'accepted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu rezervasyon henüz kabul edilmemiş'
                    ]
                ], 400);
            }

            // Get or create lesson record
            $lesson = Lesson::firstOrCreate(
                ['reservation_id' => $reservation->id],
                [
                    'teacher_id' => $reservation->teacher_id,
                    'student_id' => $reservation->student_id,
                    'status' => 'not_started',
                ]
            );

            // Check if lesson can be started
            if ($lesson->status !== 'not_started') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu ders zaten başlatılmış veya tamamlanmış'
                    ]
                ], 400);
            }

            // Start lesson
            $lesson->update([
                'status' => 'in_progress',
                'start_time' => now(),
            ]);

            // Send notification to both users
            $this->sendLessonStartedNotification($lesson);

            Log::info('Lesson started successfully', [
                'lesson_id' => $lesson->id,
                'reservation_id' => $reservation->id,
                'user_id' => $user->id,
                'start_time' => $lesson->start_time,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders başlatıldı',
                'lesson' => [
                    'id' => $lesson->id,
                    'status' => $lesson->status,
                    'start_time' => $lesson->start_time->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Start lesson failed', [
                'error' => $e->getMessage(),
                'reservation_id' => $request->reservation_id ?? null,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'START_LESSON_ERROR',
                    'message' => 'Ders başlatılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * End lesson
     */
    public function endLesson(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_id' => 'required|exists:reservations,id',
            'notes' => 'sometimes|string|max:1000',
            'rating' => 'sometimes|integer|min:1|max:5',
            'feedback' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $reservation = Reservation::findOrFail($request->reservation_id);

            // Check if user has access to this reservation
            if ($reservation->student_id !== $user->id && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyona erişim yetkiniz yok'
                    ]
                ], 403);
            }

            // Get lesson record
            $lesson = Lesson::where('reservation_id', $reservation->id)->first();

            if (!$lesson) {
                return response()->json([
                    'error' => [
                        'code' => 'LESSON_NOT_FOUND',
                        'message' => 'Ders kaydı bulunamadı'
                    ]
                ], 404);
            }

            // Check if lesson can be ended
            if ($lesson->status !== 'in_progress') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu ders henüz başlatılmamış veya zaten tamamlanmış'
                    ]
                ], 400);
            }

            // Calculate duration
            $endTime = now();
            $durationMinutes = $lesson->start_time ? $endTime->diffInMinutes($lesson->start_time) : 0;

            // End lesson
            $lesson->update([
                'status' => 'completed',
                'end_time' => $endTime,
                'duration_minutes' => $durationMinutes,
                'notes' => $request->notes,
                'rating' => $request->rating,
                'feedback' => $request->feedback,
            ]);

            // Update reservation status
            $reservation->update(['status' => 'completed']);

            // Send notification to both users
            $this->sendLessonCompletedNotification($lesson);

            Log::info('Lesson completed successfully', [
                'lesson_id' => $lesson->id,
                'reservation_id' => $reservation->id,
                'user_id' => $user->id,
                'duration_minutes' => $durationMinutes,
                'end_time' => $lesson->end_time,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders tamamlandı',
                'lesson' => [
                    'id' => $lesson->id,
                    'status' => $lesson->status,
                    'duration_minutes' => $lesson->duration_minutes,
                    'end_time' => $lesson->end_time->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('End lesson failed', [
                'error' => $e->getMessage(),
                'reservation_id' => $request->reservation_id ?? null,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'END_LESSON_ERROR',
                    'message' => 'Ders tamamlanırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get user's lessons
     */
    public function getUserLessons(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Lesson::with(['teacher.user', 'student.user', 'reservation.category'])
                ->where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                });

            // Filter by status
            if ($request->has('status')) {
                $query->where('status', $request->status);
            }

            // Filter by date range
            if ($request->has('date_from')) {
                $query->whereDate('created_at', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $query->whereDate('created_at', '<=', $request->date_to);
            }

            // Sort
            $sortBy = $request->get('sort_by', 'created_at');
            $sortOrder = $request->get('sort_order', 'desc');
            $query->orderBy($sortBy, $sortOrder);

            // Pagination
            $perPage = $request->get('per_page', 20);
            $lessons = $query->paginate($perPage);

            return response()->json([
                'data' => $lessons->items(),
                'meta' => [
                    'current_page' => $lessons->currentPage(),
                    'last_page' => $lessons->lastPage(),
                    'per_page' => $lessons->perPage(),
                    'total' => $lessons->total(),
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Get user lessons failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_LESSONS_ERROR',
                    'message' => 'Dersler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get lesson statistics
     */
    public function getLessonStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $stats = [
                'total_lessons' => Lesson::where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                })->count(),
                
                'completed_lessons' => Lesson::where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                })->where('status', 'completed')->count(),
                
                'total_duration' => Lesson::where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                })->where('status', 'completed')->sum('duration_minutes'),
                
                'average_rating' => Lesson::where('teacher_id', $user->id)
                    ->where('status', 'completed')
                    ->whereNotNull('rating')
                    ->avg('rating'),
                
                'this_month_lessons' => Lesson::where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                })->whereMonth('created_at', now()->month)
                  ->whereYear('created_at', now()->year)
                  ->count(),
            ];

            return response()->json([
                'data' => $stats,
                'message' => 'Ders istatistikleri'
            ]);

        } catch (\Exception $e) {
            Log::error('Get lesson statistics failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_STATISTICS_ERROR',
                    'message' => 'İstatistikler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get upcoming lessons
     */
    public function getUpcomingLessons(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $upcomingLessons = Lesson::with(['teacher.user', 'student.user', 'reservation.category'])
                ->where(function ($q) use ($user) {
                    $q->where('teacher_id', $user->id)
                      ->orWhere('student_id', $user->id);
                })
                ->whereIn('status', ['not_started', 'in_progress'])
                ->whereHas('reservation', function ($q) {
                    $q->where('scheduled_at', '>=', now());
                })
                ->orderBy('created_at', 'asc')
                ->limit(10)
                ->get();

            return response()->json([
                'data' => $upcomingLessons,
                'message' => 'Yaklaşan dersler'
            ]);

        } catch (\Exception $e) {
            Log::error('Get upcoming lessons failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_UPCOMING_LESSONS_ERROR',
                    'message' => 'Yaklaşan dersler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update lesson notes
     */
    public function updateLessonNotes(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|exists:lessons,id',
            'notes' => 'required|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $lesson = Lesson::findOrFail($request->lesson_id);

            // Check if user has access to this lesson
            if ($lesson->teacher_id !== $user->id && $lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu derse erişim yetkiniz yok'
                    ]
                ], 403);
            }

            $lesson->update(['notes' => $request->notes]);

            return response()->json([
                'success' => true,
                'message' => 'Ders notları güncellendi',
                'lesson' => $lesson
            ]);

        } catch (\Exception $e) {
            Log::error('Update lesson notes failed', [
                'error' => $e->getMessage(),
                'lesson_id' => $request->lesson_id ?? null,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'UPDATE_NOTES_ERROR',
                    'message' => 'Ders notları güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Rate lesson
     */
    public function rateLesson(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|exists:lessons,id',
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $lesson = Lesson::findOrFail($request->lesson_id);

            // Check if user is the student
            if ($lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler ders değerlendirebilir'
                    ]
                ], 403);
            }

            // Check if lesson is completed
            if ($lesson->status !== 'completed') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece tamamlanan dersler değerlendirilebilir'
                    ]
                ], 400);
            }

            $lesson->update([
                'rating' => $request->rating,
                'feedback' => $request->feedback,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders değerlendirildi',
                'lesson' => $lesson
            ]);

        } catch (\Exception $e) {
            Log::error('Rate lesson failed', [
                'error' => $e->getMessage(),
                'lesson_id' => $request->lesson_id ?? null,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'RATE_LESSON_ERROR',
                    'message' => 'Ders değerlendirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Send lesson started notification
     */
    private function sendLessonStartedNotification(Lesson $lesson): void
    {
        // Implementation for sending notification
        Log::info('Lesson started notification sent', [
            'lesson_id' => $lesson->id,
            'teacher_id' => $lesson->teacher_id,
            'student_id' => $lesson->student_id,
        ]);
    }

    /**
     * Send lesson completed notification
     */
    private function sendLessonCompletedNotification(Lesson $lesson): void
    {
        // Implementation for sending notification
        Log::info('Lesson completed notification sent', [
            'lesson_id' => $lesson->id,
            'teacher_id' => $lesson->teacher_id,
            'student_id' => $lesson->student_id,
        ]);
    }
}