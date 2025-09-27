<?php

namespace App\Http\Controllers;

use App\Services\MailService;
use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class ReservationController extends Controller
{
    protected MailService $mailService;

    public function __construct(MailService $mailService)
    {
        $this->mailService = $mailService;
    }

    /**
     * Get user's reservations
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Reservation::query();
            
            // Filter by user role
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            // Apply status filter
            if ($request->has('status') && $request->status) {
                $query->where('status', $request->status);
            }
            
            // Apply date range filter
            if ($request->has('from_date') && $request->from_date) {
                $query->whereDate('proposed_datetime', '>=', $request->from_date);
            }
            
            if ($request->has('to_date') && $request->to_date) {
                $query->whereDate('proposed_datetime', '<=', $request->to_date);
            }
            
            // Load relationships
            $query->with([
                'teacher.user:id,name,email,profile_photo_url',
                'student:id,name,email,profile_photo_url',
                'category:id,name,slug'
            ]);
            
            // Order by most recent first
            $query->orderBy('proposed_datetime', 'desc');
            
            $reservations = $query->paginate($request->get('per_page', 20));
            
            // Format reservations data
            $formattedReservations = $reservations->getCollection()->map(function ($reservation) use ($user) {
                return [
                    'id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'duration_minutes' => $reservation->duration_minutes,
                    'price' => $reservation->price,
                    'status' => $reservation->status,
                    'notes' => $reservation->notes,
                    'teacher_notes' => $reservation->teacher_notes,
                    'teacher' => [
                        'id' => $reservation->teacher?->user_id,
                        'name' => $reservation->teacher?->user?->name,
                        'email' => $reservation->teacher?->user?->email,
                        'profile_photo_url' => $reservation->teacher?->user?->profile_photo_url,
                    ],
                    'student' => [
                        'id' => $reservation->student?->id,
                        'name' => $reservation->student?->name,
                        'email' => $reservation->student?->email,
                        'profile_photo_url' => $reservation->student?->profile_photo_url,
                    ],
                    'category' => [
                        'id' => $reservation->category?->id,
                        'name' => $reservation->category?->name,
                        'slug' => $reservation->category?->slug,
                    ],
                    'created_at' => $reservation->created_at->toISOString(),
                    'updated_at' => $reservation->updated_at->toISOString(),
                ];
            });
            
            return response()->json([
                'success' => true,
                'reservations' => $formattedReservations,
                'pagination' => [
                    'current_page' => $reservations->currentPage(),
                    'last_page' => $reservations->lastPage(),
                    'per_page' => $reservations->perPage(),
                    'total' => $reservations->total(),
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting reservations: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'RESERVATIONS_FETCH_ERROR',
                    'message' => 'Rezervasyonlar yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create a new reservation
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'teacher_id' => 'required|exists:users,id',
                'category_id' => 'required|exists:categories,id',
                'subject' => 'required|string|max:255',
                'proposed_datetime' => 'required|date|after:now',
                'duration_minutes' => 'required|integer|min:30|max:180',
                'notes' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check if user is a student
            if ($user->role !== 'student') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler rezervasyon oluşturabilir'
                    ]
                ], 403);
            }

            // Check if teacher exists and is approved
            $teacher = User::where('id', $request->teacher_id)
                ->where('role', 'teacher')
                ->first();

            if (!$teacher) {
                return response()->json([
                    'error' => [
                        'code' => 'TEACHER_NOT_FOUND',
                        'message' => 'Öğretmen bulunamadı'
                    ]
                ], 404);
            }

            // Get teacher's price
            $teacherProfile = Teacher::where('user_id', $teacher->id)->first();
            $pricePerHour = $teacherProfile?->price_hour ?? 0;
            $totalPrice = ($pricePerHour / 60) * $request->duration_minutes;

            // Create reservation
            $reservation = Reservation::create([
                'student_id' => $user->id,
                'teacher_id' => $request->teacher_id,
                'category_id' => $request->category_id,
                'subject' => $request->subject,
                'proposed_datetime' => $request->proposed_datetime,
                'duration_minutes' => $request->duration_minutes,
                'price' => $totalPrice,
                'notes' => $request->notes,
                'status' => 'pending',
            ]);

            // Load relationships for response
            $reservation->load(['teacher.user', 'student', 'category']);

            // Send notification email to teacher
            try {
                $this->mailService->sendReservationNotification($reservation);
            } catch (\Exception $e) {
                Log::warning('Failed to send reservation notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon başarıyla oluşturuldu',
                'reservation' => [
                    'id' => $reservation->id,
                    'subject' => $reservation->subject,
                    'proposed_datetime' => $reservation->proposed_datetime->toISOString(),
                    'duration_minutes' => $reservation->duration_minutes,
                    'price' => $reservation->price,
                    'status' => $reservation->status,
                    'teacher' => [
                        'name' => $reservation->teacher?->user?->name,
                        'email' => $reservation->teacher?->user?->email,
                    ],
                    'category' => [
                        'name' => $reservation->category?->name,
                    ],
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('Error creating reservation: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_CREATE_ERROR',
                    'message' => 'Rezervasyon oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Update reservation status
     */
    public function updateStatus(Request $request, Reservation $reservation): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'status' => 'required|in:accepted,rejected,cancelled,completed',
                'teacher_notes' => 'nullable|string|max:500',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check permissions
            if ($user->role === 'teacher' && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu güncelleme yetkiniz yok'
                    ]
                ], 403);
            }

            if ($user->role === 'student' && $reservation->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu güncelleme yetkiniz yok'
                    ]
                ], 403);
            }

            // Update reservation
            $reservation->update([
                'status' => $request->status,
                'teacher_notes' => $request->teacher_notes,
            ]);

            // Send notification email
            try {
                $this->mailService->sendReservationStatusUpdate($reservation);
            } catch (\Exception $e) {
                Log::warning('Failed to send status update notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon durumu güncellendi',
                'reservation' => [
                    'id' => $reservation->id,
                    'status' => $reservation->status,
                    'teacher_notes' => $reservation->teacher_notes,
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error updating reservation status: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_UPDATE_ERROR',
                    'message' => 'Rezervasyon güncellenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Cancel a reservation
     */
    public function destroy(Reservation $reservation): JsonResponse
    {
        try {
            $user = Auth::user();

            // Check if user can cancel this reservation
            if ($reservation->student_id !== $user->id && $reservation->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu rezervasyonu iptal etme yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if reservation can be cancelled
            if ($reservation->status === 'completed') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Tamamlanmış rezervasyonlar iptal edilemez'
                    ]
                ], 400);
            }

            // Cancel reservation
            $reservation->update(['status' => 'cancelled']);

            // Send notification
            try {
                $this->mailService->sendReservationCancellation($reservation);
            } catch (\Exception $e) {
                Log::warning('Failed to send cancellation notification: ' . $e->getMessage());
            }

            return response()->json([
                'success' => true,
                'message' => 'Rezervasyon iptal edildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error cancelling reservation: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'RESERVATION_CANCEL_ERROR',
                    'message' => 'Rezervasyon iptal edilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get reservation statistics
     */
    public function getStatistics(): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Reservation::query();
            
            // Filter by user role
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            $totalReservations = $query->count();
            $pendingReservations = $query->where('status', 'pending')->count();
            $confirmedReservations = $query->where('status', 'accepted')->count();
            $completedReservations = $query->where('status', 'completed')->count();
            $cancelledReservations = $query->where('status', 'cancelled')->count();
            
            // This month reservations
            $thisMonthReservations = $query->whereMonth('created_at', now()->month)
                ->whereYear('created_at', now()->year)->count();
            
            // Total spent/earned
            $totalAmount = $query->where('status', 'completed')->sum('price');
            
            return response()->json([
                'success' => true,
                'statistics' => [
                    'total_reservations' => $totalReservations,
                    'pending_reservations' => $pendingReservations,
                    'confirmed_reservations' => $confirmedReservations,
                    'completed_reservations' => $completedReservations,
                    'cancelled_reservations' => $cancelledReservations,
                    'this_month' => $thisMonthReservations,
                    'total_amount' => $totalAmount,
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting reservation statistics: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'STATISTICS_ERROR',
                    'message' => 'İstatistikler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}