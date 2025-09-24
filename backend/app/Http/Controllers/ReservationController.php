<?php

namespace App\Http\Controllers;

use App\Services\MailService;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

class ReservationController extends Controller
{
    protected MailService $mailService;

    public function __construct(MailService $mailService)
    {
        $this->mailService = $mailService;
    }

    /**
     * Get student's reservations
     */
    public function studentReservations(Request $request): JsonResponse
    {
        $user = auth()->user();
        
        \Log::info('🔄 Student reservations requested by user: ' . $user->id);
        
        if ($user->role !== 'student') {
            \Log::warning('❌ Non-student user tried to access student reservations');
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Sadece öğrenciler rezervasyon görüntüleyebilir'
                ]
            ], 403);
        }

        $query = $user->studentReservations()->with(['teacher.user', 'category']);

        // Durum filtresi
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Tarih filtresi
        if ($request->has('date_from')) {
            $query->where('proposed_datetime', '>=', $request->date_from);
        }
        if ($request->has('date_to')) {
            $query->where('proposed_datetime', '<=', $request->date_to);
        }

        $reservations = $query->orderBy('proposed_datetime', 'desc')->paginate(20);
        
        \Log::info('✅ Found ' . $reservations->count() . ' reservations for user: ' . $user->id);

        return response()->json([
            'data' => $reservations->items(),
            'meta' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ]
        ]);
    }

    /**
     * Get teacher's reservations
     */
    public function teacherReservations(Request $request): JsonResponse
    {
        $user = auth()->user();
        $teacher = $user->teacher;

        if (!$teacher) {
            return response()->json([
                'error' => [
                    'code' => 'NOT_FOUND',
                    'message' => 'Öğretmen profili bulunamadı'
                ]
            ], 404);
        }

        $query = $teacher->reservations()->with(['student', 'category']);

        // Durum filtresi
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Tarih filtresi
        if ($request->has('date_from')) {
            $query->where('proposed_datetime', '>=', $request->date_from);
        }
        if ($request->has('date_to')) {
            $query->where('proposed_datetime', '<=', $request->date_to);
        }

        $reservations = $query->orderBy('proposed_datetime', 'desc')->paginate(20);

        return response()->json([
            'data' => $reservations->items(),
            'meta' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ]
        ]);
    }

    /**
     * Create new reservation
     */
    public function store(Request $request): JsonResponse
    {
        $user = auth()->user();
        
        if ($user->role !== 'student') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Sadece öğrenciler rezervasyon oluşturabilir'
                ]
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'teacher_id' => 'required|exists:teachers,user_id',
            'category_id' => 'required|exists:categories,id',
            'subject' => 'required|string|max:255',
            'proposed_datetime' => 'required|date|after:now',
            'duration_minutes' => 'required|integer|min:30|max:480', // 30 dakika - 8 saat
            'notes' => 'nullable|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        // Öğretmenin bu kategoride ders verip vermediğini kontrol et
        $teacher = Teacher::find($request->teacher_id);
        if (!$teacher->categories()->where('category_id', $request->category_id)->exists()) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_CATEGORY',
                    'message' => 'Bu öğretmen bu kategoride ders vermiyor'
                ]
            ], 400);
        }

        // Çakışan rezervasyon kontrolü (SQLite uyumlu)
        $startTime = $request->proposed_datetime;
        $endTime = date('Y-m-d H:i:s', strtotime($startTime) + ($request->duration_minutes * 60));
        
        $conflictingReservation = Reservation::where('teacher_id', $request->teacher_id)
            ->where('status', '!=', 'cancelled')
            ->where('status', '!=', 'rejected')
            ->where(function ($query) use ($startTime, $endTime) {
                // Yeni rezervasyonun başlangıcı mevcut rezervasyonun içinde
                $query->whereBetween('proposed_datetime', [$startTime, $endTime])
                      // Veya mevcut rezervasyonun bitişi yeni rezervasyonun içinde
                      ->orWhere(function ($q) use ($startTime, $endTime) {
                          $q->where('proposed_datetime', '<', $endTime)
                            ->where('proposed_datetime', '>=', $startTime);
                      });
            })
            ->first();

        if ($conflictingReservation) {
            return response()->json([
                'error' => [
                    'code' => 'CONFLICTING_RESERVATION',
                    'message' => 'Bu saatte zaten bir rezervasyon var'
                ]
            ], 409);
        }

        // Fiyat hesapla
        $price = $teacher->price_hour * ($request->duration_minutes / 60);

        DB::beginTransaction();
        try {
            $reservation = Reservation::create([
                'student_id' => $user->id,
                'teacher_id' => $request->teacher_id,
                'category_id' => $request->category_id,
                'subject' => $request->subject,
                'proposed_datetime' => $request->proposed_datetime,
                'duration_minutes' => $request->duration_minutes,
                'price' => $price,
                'status' => 'pending',
                'notes' => $request->notes,
            ]);

            // Öğretmene bildirim gönder
            $this->mailService->sendReservationNotification($reservation);

            // Rezervasyon onaylandığında öğrenciye e-posta gönder
            if ($reservation->status === 'confirmed') {
                $this->mailService->sendReservationConfirmation($reservation);
            }

            DB::commit();
            $teacher->user->notifications()->create([
                'type' => 'reservation_request',
                'payload' => [
                    'title' => 'Yeni Rezervasyon Talebi',
                    'message' => "{$user->name} size rezervasyon talebi gönderdi",
                    'data' => [
                        'reservation_id' => $reservation->id,
                        'student_name' => $user->name,
                        'subject' => $request->subject,
                        'proposed_datetime' => $request->proposed_datetime,
                    ]
                ]
            ]);

            DB::commit();

            $reservation->load(['teacher.user', 'category']);

            return response()->json([
                'message' => 'Rezervasyon talebi başarıyla gönderildi',
                'reservation' => $reservation
            ], 201);

        } catch (\Exception $e) {
            DB::rollback();
            return response()->json([
                'error' => [
                    'code' => 'SERVER_ERROR',
                    'message' => 'Rezervasyon oluşturulurken hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update reservation
     */
    public function update(Request $request, Reservation $reservation): JsonResponse
    {
        $user = auth()->user();

        // Sadece rezervasyon sahibi güncelleyebilir
        if ($reservation->student_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu rezervasyonu güncelleyemezsiniz'
                ]
            ], 403);
        }

        // Sadece bekleyen rezervasyonlar güncellenebilir
        if ($reservation->status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Sadece bekleyen rezervasyonlar güncellenebilir'
                ]
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'subject' => 'sometimes|string|max:255',
            'proposed_datetime' => 'sometimes|date|after:now',
            'duration_minutes' => 'sometimes|integer|min:30|max:480',
            'notes' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $reservation->update($request->only(['subject', 'proposed_datetime', 'duration_minutes', 'notes']));

        // Fiyatı yeniden hesapla
        if ($request->has('duration_minutes')) {
            $price = $reservation->teacher->price_hour * ($request->duration_minutes / 60);
            $reservation->update(['price' => $price]);
        }

        $reservation->load(['teacher.user', 'category']);

        return response()->json([
            'message' => 'Rezervasyon başarıyla güncellendi',
            'reservation' => $reservation
        ]);
    }

    /**
     * Delete reservation
     */
    public function destroy(Reservation $reservation): JsonResponse
    {
        $user = auth()->user();

        // Sadece rezervasyon sahibi silebilir
        if ($reservation->student_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu rezervasyonu silemezsiniz'
                ]
            ], 403);
        }

        // Sadece bekleyen rezervasyonlar silinebilir
        if ($reservation->status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Sadece bekleyen rezervasyonlar silinebilir'
                ]
            ], 400);
        }

        $reservation->delete();

        return response()->json([
            'message' => 'Rezervasyon başarıyla silindi'
        ]);
    }

    /**
     * Update reservation status (Teacher only)
     */
    public function updateStatus(Request $request, Reservation $reservation): JsonResponse
    {
        $user = auth()->user();
        $teacher = $user->teacher;

        if (!$teacher || $reservation->teacher_id !== $teacher->user_id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu rezervasyonu yönetemezsiniz'
                ]
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|in:accepted,rejected',
            'teacher_notes' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        // Sadece bekleyen rezervasyonlar güncellenebilir
        if ($reservation->status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Sadece bekleyen rezervasyonlar güncellenebilir'
                ]
            ], 400);
        }

        $reservation->update([
            'status' => $request->status,
            'teacher_notes' => $request->teacher_notes,
        ]);

        // E-posta bildirimi gönder
        if ($request->status === 'accepted') {
            $this->mailService->sendReservationConfirmation($reservation);
        }

        // Öğrenciye bildirim gönder
        $reservation->student->notifications()->create([
            'type' => 'reservation_response',
            'payload' => [
                'title' => 'Rezervasyon Yanıtı',
                'message' => $request->status === 'accepted' 
                    ? "Rezervasyonunuz kabul edildi" 
                    : "Rezervasyonunuz reddedildi",
                'data' => [
                    'reservation_id' => $reservation->id,
                    'status' => $request->status,
                    'teacher_notes' => $request->teacher_notes,
                ]
            ]
        ]);

        // E-posta bildirimi gönder
        if ($request->status === 'accepted') {
            $this->mailService->sendReservationConfirmation($reservation);
        }

        $reservation->load(['student', 'category']);

        return response()->json([
            'message' => 'Rezervasyon durumu başarıyla güncellendi',
            'reservation' => $reservation
        ]);
    }

    /**
     * Admin: Get all reservations
     */
    public function adminIndex(Request $request): JsonResponse
    {
        $query = Reservation::with(['student', 'teacher.user', 'category']);

        // Filtreleme
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('teacher_id')) {
            $query->where('teacher_id', $request->teacher_id);
        }

        if ($request->has('student_id')) {
            $query->where('student_id', $request->student_id);
        }

        if ($request->has('date_from')) {
            $query->where('proposed_datetime', '>=', $request->date_from);
        }

        if ($request->has('date_to')) {
            $query->where('proposed_datetime', '<=', $request->date_to);
        }

        $reservations = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'data' => $reservations->items(),
            'meta' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ]
        ]);
    }
}