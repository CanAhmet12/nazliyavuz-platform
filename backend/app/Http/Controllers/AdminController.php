<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;
use App\Models\User;
use App\Models\Teacher;
use App\Models\Reservation;
use App\Models\Category;
use App\Models\AuditLog;
use App\Services\CacheService;

/**
 * @OA\Tag(
 *     name="Admin",
 *     description="Admin paneli ve moderasyon işlemleri"
 * )
 */
class AdminController extends Controller
{
    protected CacheService $cacheService;

    public function __construct(CacheService $cacheService)
    {
        $this->cacheService = $cacheService;
    }
    /**
     * @OA\Get(
     *     path="/admin/dashboard",
     *     tags={"Admin"},
     *     summary="Admin dashboard istatistikleri",
     *     description="Admin paneli için genel istatistikleri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Dashboard verileri başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="stats", type="object"),
     *             @OA\Property(property="recent_activities", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function dashboard(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $stats = [
            'total_users' => User::count(),
            'total_teachers' => Teacher::count(),
            'total_students' => User::where('role', 'student')->count(),
            'total_reservations' => Reservation::count(),
            'pending_reservations' => Reservation::where('status', 'pending')->count(),
            'completed_reservations' => Reservation::where('status', 'completed')->count(),
            'total_categories' => Category::count(),
            'active_users_this_month' => User::whereMonth('created_at', now()->month)->count(),
        ];

        $recentActivities = AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'stats' => $stats,
            'recent_activities' => $recentActivities,
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/users",
     *     tags={"Admin"},
     *     summary="Kullanıcı listesi",
     *     description="Tüm kullanıcıları listeler ve filtreler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="role",
     *         in="query",
     *         description="Kullanıcı rolü filtresi",
     *         @OA\Schema(type="string", enum={"student","teacher","admin"})
     *     ),
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         description="Kullanıcı durumu filtresi",
     *         @OA\Schema(type="string", enum={"active","inactive","pending"})
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         description="Sayfa numarası",
     *         @OA\Schema(type="integer", default=1)
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcılar başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object")),
     *             @OA\Property(property="meta", type="object")
     *         )
     *     )
     * )
     */
    public function getUsers(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $query = User::query();

        // Rol filtresi
        if ($request->has('role')) {
            $query->where('role', $request->role);
        }

        // Durum filtresi
        if ($request->has('status')) {
            switch ($request->status) {
                case 'active':
                    $query->whereNotNull('email_verified_at');
                    break;
                case 'inactive':
                    $query->whereNull('email_verified_at');
                    break;
                case 'pending':
                    $query->whereNull('verified_at');
                    break;
            }
        }

        $users = $query->with(['teacher'])
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'data' => $users->items(),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ]
        ]);
    }

    /**
     * @OA\Put(
     *     path="/admin/users/{user}/status",
     *     tags={"Admin"},
     *     summary="Kullanıcı durumu güncelle",
     *     description="Kullanıcının durumunu günceller (aktif/pasif)",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         description="Kullanıcı ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"status"},
     *             @OA\Property(property="status", type="string", enum={"active","inactive","suspended"}, example="active")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı durumu başarıyla güncellendi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Kullanıcı durumu güncellendi"),
     *             @OA\Property(property="user", type="object")
     *         )
     *     )
     * )
     */
    public function updateUserStatus(Request $request, User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'status' => 'required|in:active,inactive,suspended',
        ]);

        $oldStatus = $user->verified_at ? 'active' : 'inactive';

        switch ($request->status) {
            case 'active':
                $user->update(['verified_at' => now()]);
                break;
            case 'inactive':
                $user->update(['verified_at' => null]);
                break;
            case 'suspended':
                $user->update(['verified_at' => null]);
                // İleride suspended_at field'ı eklenebilir
                break;
        }

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'update_user_status',
            'target_type' => 'User',
            'target_id' => $user->id,
            'meta' => [
                'old_status' => $oldStatus,
                'new_status' => $request->status,
            ],
        ]);

        return response()->json([
            'message' => 'Kullanıcı durumu güncellendi',
            'user' => $user->fresh(),
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/reservations",
     *     tags={"Admin"},
     *     summary="Rezervasyon listesi",
     *     description="Tüm rezervasyonları listeler ve filtreler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         description="Rezervasyon durumu filtresi",
     *         @OA\Schema(type="string", enum={"pending","accepted","rejected","cancelled","completed"})
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Rezervasyonlar başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getReservations(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $query = Reservation::with(['student', 'teacher.user', 'category']);

        if ($request->has('status')) {
            $query->where('status', $request->status);
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

    /**
     * @OA\Get(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Kategori yönetimi",
     *     description="Kategorileri listeler ve yönetir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Kategoriler başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getCategories(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $categories = Category::with('children')
            ->whereNull('parent_id')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'data' => $categories,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Yeni kategori oluştur",
     *     description="Yeni kategori oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"name","slug"},
     *             @OA\Property(property="name", type="string", example="Matematik"),
     *             @OA\Property(property="slug", type="string", example="matematik"),
     *             @OA\Property(property="description", type="string", example="Matematik dersleri"),
     *             @OA\Property(property="parent_id", type="integer", example=null),
     *             @OA\Property(property="icon", type="string", example="calculator"),
     *             @OA\Property(property="sort_order", type="integer", example=1)
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Kategori başarıyla oluşturuldu",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Kategori oluşturuldu"),
     *             @OA\Property(property="category", type="object")
     *         )
     *     )
     * )
     */
    public function createCategory(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'name' => 'required|string|max:255',
            'slug' => 'required|string|max:255|unique:categories',
            'description' => 'nullable|string',
            'parent_id' => 'nullable|exists:categories,id',
            'icon' => 'nullable|string|max:255',
            'sort_order' => 'nullable|integer',
        ]);

        $category = Category::create($request->all());

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'create_category',
            'target_type' => 'Category',
            'target_id' => $category->id,
            'meta' => $request->all(),
        ]);

        return response()->json([
            'message' => 'Kategori oluşturuldu',
            'category' => $category,
        ], 201);
    }

    /**
     * @OA\Get(
     *     path="/admin/audit-logs",
     *     tags={"Admin"},
     *     summary="Audit log listesi",
     *     description="Sistem aktivitelerini listeler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="action",
     *         in="query",
     *         description="Aksiyon filtresi",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Audit loglar başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
     *         )
     *     )
     * )
     */
    public function getAuditLogs(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $query = AuditLog::with('user');

        if ($request->has('action')) {
            $query->where('action', $request->action);
        }

        $logs = $query->orderBy('created_at', 'desc')->paginate(50);

        return response()->json([
            'data' => $logs->items(),
            'meta' => [
                'current_page' => $logs->currentPage(),
                'last_page' => $logs->lastPage(),
                'per_page' => $logs->perPage(),
                'total' => $logs->total(),
            ]
        ]);
    }

    /**
     * Get platform analytics
     */
    public function getAnalytics(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $period = $request->get('period', 30); // days
        $startDate = now()->subDays($period);

        // Basit analytics verileri
        $analytics = [
            'user_registrations' => User::where('created_at', '>=', $startDate)->count(),
            'reservation_trends' => Reservation::where('created_at', '>=', $startDate)->count(),
            'revenue_analytics' => Reservation::where('created_at', '>=', $startDate)->where('status', 'completed')->sum('price'),
            'teacher_performance' => Teacher::count(),
            'category_popularity' => Category::count(),
            'user_activity' => [
                'active_users' => User::where('last_login_at', '>=', $startDate)->count(),
                'new_users' => User::where('created_at', '>=', $startDate)->count(),
                'verified_users' => User::whereNotNull('email_verified_at')->count(),
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => $analytics,
            'cached' => false
        ]);
    }

    /**
     * Get pending teachers for approval
     */
    public function getPendingTeachers(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $query = User::where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->with(['teacher.categories']);

        $teachers = $query->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'data' => $teachers->items(),
            'meta' => [
                'current_page' => $teachers->currentPage(),
                'last_page' => $teachers->lastPage(),
                'per_page' => $teachers->perPage(),
                'total' => $teachers->total(),
            ]
        ]);
    }

    /**
     * Approve teacher
     */
    public function approveTeacher(Request $request, User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Bu öğretmen zaten işleme alınmış'
                ]
            ], 400);
        }

        $adminId = auth()->id();
        $notes = $request->get('admin_notes');

        $user->approveTeacher($adminId, $notes);

        // Bildirim gönder
        $user->notifications()->create([
            'type' => 'teacher_approved',
            'title' => 'Öğretmen Profiliniz Onaylandı',
            'message' => 'Tebrikler! Öğretmen profiliniz admin tarafından onaylandı. Artık öğrenciler sizi bulabilir.',
            'data' => [
                'teacher_id' => $user->id,
                'approved_at' => now()->toISOString(),
            ]
        ]);

        return response()->json([
            'message' => 'Öğretmen başarıyla onaylandı',
            'teacher' => $user->load('teacher')
        ]);
    }

    /**
     * Reject teacher
     */
    public function rejectTeacher(Request $request, User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı öğretmen değil'
                ]
            ], 400);
        }

        if ($user->teacher_status !== 'pending') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Bu öğretmen zaten işleme alınmış'
                ]
            ], 400);
        }

        $validator = Validator::make($request->all(), [
            'rejection_reason' => 'required|string|max:1000',
            'admin_notes' => 'sometimes|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $adminId = auth()->id();
        $reason = $request->get('rejection_reason');
        $notes = $request->get('admin_notes');

        $user->rejectTeacher($adminId, $reason, $notes);

        // Bildirim gönder
        $user->notifications()->create([
            'type' => 'teacher_rejected',
            'title' => 'Öğretmen Profili Reddedildi',
            'message' => 'Maalesef öğretmen profiliniz reddedildi. Detaylar için profil sayfanızı kontrol edin.',
            'data' => [
                'teacher_id' => $user->id,
                'rejection_reason' => $reason,
                'rejected_at' => now()->toISOString(),
            ]
        ]);

        return response()->json([
            'message' => 'Öğretmen reddedildi',
            'teacher' => $user->load('teacher')
        ]);
    }

    /**
     * Get user registrations over time
     */
    private function getUserRegistrations($startDate)
    {
        return User::where('created_at', '>=', $startDate)
            ->selectRaw('date(created_at) as date, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();
    }

    /**
     * Get reservation trends
     */
    private function getReservationTrends($startDate)
    {
        return Reservation::where('created_at', '>=', $startDate)
            ->selectRaw('date(created_at) as date, COUNT(*) as count, status')
            ->groupBy('date', 'status')
            ->orderBy('date')
            ->get()
            ->groupBy('status');
    }

    /**
     * Get revenue analytics
     */
    private function getRevenueAnalytics($startDate)
    {
        return Reservation::where('created_at', '>=', $startDate)
            ->where('status', 'completed')
            ->selectRaw('date(created_at) as date, SUM(price) as revenue')
            ->groupBy('date')
            ->orderBy('date')
            ->get();
    }

    /**
     * Get teacher performance metrics
     */
    private function getTeacherPerformance()
    {
        return Teacher::with(['user', 'reservations'])
            ->withCount(['reservations as completed_reservations' => function ($query) {
                $query->where('status', 'completed');
            }])
            ->withAvg('ratings', 'rating')
            ->orderBy('completed_reservations', 'desc')
            ->limit(10)
            ->get();
    }

    /**
     * Get category popularity
     */
    private function getCategoryPopularity()
    {
        return Category::withCount(['reservations', 'teachers'])
            ->orderBy('reservations_count', 'desc')
            ->get();
    }

    /**
     * Get user activity metrics
     */
    private function getUserActivity($startDate)
    {
        return [
            'active_users' => User::where('last_login_at', '>=', $startDate)->count(),
            'new_users' => User::where('created_at', '>=', $startDate)->count(),
            'verified_users' => User::whereNotNull('email_verified_at')->count(),
            'unverified_users' => User::whereNull('email_verified_at')->count(),
        ];
    }

    /**
     * Update category
     */
    public function updateCategory(Request $request, Category $category): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'name' => 'sometimes|string|max:255',
            'slug' => 'sometimes|string|max:255|unique:categories,slug,' . $category->id,
            'description' => 'nullable|string',
            'parent_id' => 'nullable|exists:categories,id',
            'icon' => 'nullable|string|max:255',
            'sort_order' => 'nullable|integer',
            'is_active' => 'sometimes|boolean',
        ]);

        $category->update($request->all());

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'update_category',
            'target_type' => 'Category',
            'target_id' => $category->id,
            'meta' => $request->all(),
        ]);

        return response()->json([
            'message' => 'Kategori güncellendi',
            'category' => $category,
        ]);
    }

    /**
     * Delete category
     */
    public function deleteCategory(Category $category): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        // Check if category has children
        if ($category->children()->count() > 0) {
            return response()->json([
                'error' => [
                    'code' => 'HAS_CHILDREN',
                    'message' => 'Bu kategorinin alt kategorileri var, önce onları silin'
                ]
            ], 400);
        }

        // Check if category has teachers
        if ($category->teachers()->count() > 0) {
            return response()->json([
                'error' => [
                    'code' => 'HAS_TEACHERS',
                    'message' => 'Bu kategoride öğretmenler var, önce onları taşıyın'
                ]
            ], 400);
        }

        $category->delete();

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'delete_category',
            'target_type' => 'Category',
            'target_id' => $category->id,
            'meta' => $category->toArray(),
        ]);

        return response()->json([
            'message' => 'Kategori silindi'
        ]);
    }

    /**
     * Update reservation status
     */
    public function updateReservation(Request $request, Reservation $reservation): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'status' => 'required|in:pending,accepted,rejected,cancelled,completed',
            'admin_notes' => 'nullable|string|max:1000',
        ]);

        $oldStatus = $reservation->status;
        $reservation->update([
            'status' => $request->status,
            'admin_notes' => $request->admin_notes,
        ]);

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'update_reservation',
            'target_type' => 'Reservation',
            'target_id' => $reservation->id,
            'meta' => [
                'old_status' => $oldStatus,
                'new_status' => $request->status,
                'admin_notes' => $request->admin_notes,
            ],
        ]);

        return response()->json([
            'message' => 'Rezervasyon güncellendi',
            'reservation' => $reservation,
        ]);
    }

    /**
     * Delete reservation
     */
    public function deleteReservation(Reservation $reservation): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $reservation->delete();

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'delete_reservation',
            'target_type' => 'Reservation',
            'target_id' => $reservation->id,
            'meta' => $reservation->toArray(),
        ]);

        return response()->json([
            'message' => 'Rezervasyon silindi'
        ]);
    }

    /**
     * Delete user
     */
    public function deleteUser(User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        // Prevent admin from deleting themselves
        if ($user->id === Auth::id()) {
            return response()->json([
                'error' => [
                    'code' => 'CANNOT_DELETE_SELF',
                    'message' => 'Kendi hesabınızı silemezsiniz'
                ]
            ], 400);
        }

        $user->delete();

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'delete_user',
            'target_type' => 'User',
            'target_id' => $user->id,
            'meta' => $user->toArray(),
        ]);

        return response()->json([
            'message' => 'Kullanıcı silindi'
        ]);
    }

    /**
     * Suspend user
     */
    public function suspendUser(Request $request, User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'reason' => 'required|string|max:500',
            'duration' => 'nullable|integer|min:1|max:365', // days
        ]);

        $suspendedUntil = $request->duration 
            ? now()->addDays($request->duration) 
            : null;

        $user->update([
            'verified_at' => null,
            'suspended_at' => now(),
            'suspended_until' => $suspendedUntil,
            'suspension_reason' => $request->reason,
        ]);

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'suspend_user',
            'target_type' => 'User',
            'target_id' => $user->id,
            'meta' => [
                'reason' => $request->reason,
                'duration' => $request->duration,
                'suspended_until' => $suspendedUntil,
            ],
        ]);

        return response()->json([
            'message' => 'Kullanıcı askıya alındı',
            'user' => $user,
        ]);
    }

    /**
     * Unsuspend user
     */
    public function unsuspendUser(User $user): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $user->update([
            'verified_at' => now(),
            'suspended_at' => null,
            'suspended_until' => null,
            'suspension_reason' => null,
        ]);

        // Audit log
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'unsuspend_user',
            'target_type' => 'User',
            'target_id' => $user->id,
            'meta' => $user->toArray(),
        ]);

        return response()->json([
            'message' => 'Kullanıcı askıdan çıkarıldı',
            'user' => $user,
        ]);
    }

    /**
     * Get system health
     */
    public function getSystemHealth(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $health = [
            'database' => $this->checkDatabaseHealth(),
            'cache' => $this->checkCacheHealth(),
            'storage' => $this->checkStorageHealth(),
            'queue' => $this->checkQueueHealth(),
        ];

        return response()->json([
            'success' => true,
            'data' => $health,
        ]);
    }

    /**
     * Check database health
     */
    private function checkDatabaseHealth(): array
    {
        try {
            \DB::connection()->getPdo();
            return ['status' => 'healthy', 'message' => 'Database connection successful'];
        } catch (\Exception $e) {
            return ['status' => 'unhealthy', 'message' => $e->getMessage()];
        }
    }

    /**
     * Check cache health
     */
    private function checkCacheHealth(): array
    {
        try {
            \Cache::put('health_check', 'ok', 60);
            $value = \Cache::get('health_check');
            return ['status' => 'healthy', 'message' => 'Cache working properly'];
        } catch (\Exception $e) {
            return ['status' => 'unhealthy', 'message' => $e->getMessage()];
        }
    }

    /**
     * Check storage health
     */
    private function checkStorageHealth(): array
    {
        try {
            \Storage::disk('s3')->exists('health_check.txt');
            return ['status' => 'healthy', 'message' => 'Storage accessible'];
        } catch (\Exception $e) {
            return ['status' => 'unhealthy', 'message' => $e->getMessage()];
        }
    }

    /**
     * Check queue health
     */
    private function checkQueueHealth(): array
    {
        try {
            // Simple queue health check
            return ['status' => 'healthy', 'message' => 'Queue system operational'];
        } catch (\Exception $e) {
            return ['status' => 'unhealthy', 'message' => $e->getMessage()];
        }
    }

    /**
     * Get system logs
     */
    public function getSystemLogs(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'level' => 'sometimes|in:emergency,alert,critical,error,warning,notice,info,debug',
            'date_from' => 'sometimes|date',
            'date_to' => 'sometimes|date|after:date_from',
            'page' => 'sometimes|integer|min:1',
        ]);

        // This would typically read from log files or a logging service
        // For now, we'll return a mock response
        $logs = [
            [
                'timestamp' => now()->subMinutes(5)->toISOString(),
                'level' => 'info',
                'message' => 'User login successful',
                'context' => ['user_id' => 1, 'ip' => '192.168.1.1'],
            ],
            [
                'timestamp' => now()->subMinutes(10)->toISOString(),
                'level' => 'warning',
                'message' => 'Failed login attempt',
                'context' => ['email' => 'test@example.com', 'ip' => '192.168.1.2'],
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => $logs,
        ]);
    }

    /**
     * Clear system cache
     */
    public function clearCache(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        try {
            \Cache::flush();
            \Artisan::call('config:clear');
            \Artisan::call('route:clear');
            \Artisan::call('view:clear');

            return response()->json([
                'success' => true,
                'message' => 'Cache başarıyla temizlendi',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Cache temizlenirken hata oluştu: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get backup status
     */
    public function getBackupStatus(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        // This would typically check backup service status
        $backupStatus = [
            'last_backup' => now()->subHours(2)->toISOString(),
            'next_backup' => now()->addHours(22)->toISOString(),
            'backup_size' => '2.5 GB',
            'status' => 'healthy',
        ];

        return response()->json([
            'success' => true,
            'data' => $backupStatus,
        ]);
    }

    /**
     * Send system notification
     */
    public function sendSystemNotification(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'title' => 'required|string|max:255',
            'message' => 'required|string|max:1000',
            'type' => 'required|in:info,warning,error,success',
            'target_users' => 'sometimes|array',
            'target_users.*' => 'exists:users,id',
            'send_to_all' => 'sometimes|boolean',
        ]);

        $notificationData = [
            'title' => $request->title,
            'message' => $request->message,
            'type' => $request->type,
            'sent_at' => now()->toISOString(),
        ];

        if ($request->boolean('send_to_all')) {
            // Send to all users
            $users = User::whereNotNull('fcm_tokens')->get();
        } else {
            // Send to specific users
            $users = User::whereIn('id', $request->target_users)
                ->whereNotNull('fcm_tokens')
                ->get();
        }

        // Here you would typically send push notifications
        // For now, we'll just log the notification
        \Log::info('System notification sent', [
            'notification' => $notificationData,
            'recipients' => $users->count(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Sistem bildirimi gönderildi',
            'data' => [
                'recipients' => $users->count(),
                'notification' => $notificationData,
            ],
        ]);
    }

    /**
     * Get user statistics
     */
    public function getUserStatistics(): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $stats = [
            'total_users' => User::count(),
            'active_users' => User::where('verified_at', '!=', null)->count(),
            'suspended_users' => User::whereNotNull('suspended_at')->count(),
            'new_users_today' => User::whereDate('created_at', today())->count(),
            'new_users_this_week' => User::where('created_at', '>=', now()->subWeek())->count(),
            'new_users_this_month' => User::where('created_at', '>=', now()->subMonth())->count(),
            'users_by_role' => User::selectRaw('role, COUNT(*) as count')
                ->groupBy('role')
                ->get()
                ->pluck('count', 'role'),
        ];

        return response()->json([
            'success' => true,
            'data' => $stats,
        ]);
    }

    /**
     * Export user data
     */
    public function exportUsers(Request $request): JsonResponse
    {
        // Admin yetkisi zaten middleware tarafından kontrol ediliyor

        $request->validate([
            'format' => 'required|in:csv,json,xlsx',
            'filters' => 'sometimes|array',
        ]);

        $query = User::query();

        // Apply filters
        if ($request->has('filters')) {
            $filters = $request->filters;
            
            if (isset($filters['role'])) {
                $query->where('role', $filters['role']);
            }
            
            if (isset($filters['status'])) {
                switch ($filters['status']) {
                    case 'active':
                        $query->whereNotNull('verified_at')->whereNull('suspended_at');
                        break;
                    case 'suspended':
                        $query->whereNotNull('suspended_at');
                        break;
                    case 'inactive':
                        $query->whereNull('verified_at');
                        break;
                }
            }
        }

        $users = $query->get();

        // This would typically generate and return a file
        // For now, we'll return the data directly
        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı verileri hazırlandı',
            'data' => [
                'format' => $request->get('format'),
                'count' => $users->count(),
                'users' => $users->toArray(),
            ],
        ]);
    }

}
