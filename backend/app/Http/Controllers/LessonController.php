<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Lesson;
use App\Models\User;

class LessonController extends Controller
{
    /**
     * Update lesson notes
     */
    public function updateNotes(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|integer|exists:lessons,id',
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

            // Check if user is the teacher of this lesson
            if ($lesson->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ders için not ekleme yetkiniz yok'
                    ]
                ], 403);
            }

            $lesson->update([
                'notes' => $request->notes
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ders notları başarıyla güncellendi',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating lesson notes: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_NOTES_ERROR',
                    'message' => 'Ders notları güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Rate a lesson
     */
    public function rateLesson(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'lesson_id' => 'required|integer|exists:lessons,id',
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:500',
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

            // Check if user is the student of this lesson
            if ($lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dersi değerlendirme yetkiniz yok'
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

            // Check if already rated
            if ($lesson->rating !== null) {
                return response()->json([
                    'error' => [
                        'code' => 'ALREADY_RATED',
                        'message' => 'Bu ders zaten değerlendirilmiş'
                    ]
                ], 400);
            }

            $lesson->update([
                'rating' => $request->rating,
                'feedback' => $request->feedback,
                'rated_at' => now()
            ]);

            // Update teacher's average rating
            $this->updateTeacherRating($lesson->teacher_id);

            return response()->json([
                'success' => true,
                'message' => 'Ders başarıyla değerlendirildi',
                'lesson' => $lesson->fresh()
            ]);

        } catch (\Exception $e) {
            Log::error('Error rating lesson: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_RATING_ERROR',
                    'message' => 'Ders değerlendirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get lesson details
     */
    public function show(int $id): JsonResponse
    {
        try {
            $user = Auth::user();
            $lesson = Lesson::with(['student', 'teacher', 'reservation'])
                ->findOrFail($id);

            // Check if user is either the teacher or student of this lesson
            if ($lesson->teacher_id !== $user->id && $lesson->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ders detaylarını görme yetkiniz yok'
                    ]
                ], 403);
            }

            return response()->json([
                'success' => true,
                'lesson' => $lesson
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting lesson details: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'LESSON_NOT_FOUND',
                    'message' => 'Ders bulunamadı'
                ]
            ], 404);
        }
    }

    /**
     * Update teacher's average rating
     */
    private function updateTeacherRating(int $teacherId): void
    {
        try {
            $lessons = Lesson::where('teacher_id', $teacherId)
                ->whereNotNull('rating')
                ->get();

            if ($lessons->count() > 0) {
                $averageRating = $lessons->avg('rating');
                $ratingCount = $lessons->count();

                \App\Models\Teacher::where('user_id', $teacherId)
                    ->update([
                        'rating_avg' => round($averageRating, 2),
                        'rating_count' => $ratingCount
                    ]);
            }
        } catch (\Exception $e) {
            Log::error('Error updating teacher rating: ' . $e->getMessage());
        }
    }
}