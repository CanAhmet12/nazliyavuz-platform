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

    public function __construct()
    {
        // Cache service temporarily disabled for deployment
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
            'active_categories' => Category::where('is_active', true)->count(),
        ];

        $recentActivities = AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'success' => true,
            'stats' => $stats,
            'recent_activities' => $recentActivities,
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/analytics",
     *     tags={"Admin"},
     *     summary="Detaylı analitik veriler",
     *     description="Admin paneli için detaylı analitik verileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Analitik veriler başarıyla getirildi"
     *     )
     * )
     */
    public function getAnalytics(): JsonResponse
    {
        $analytics = [
            'user_growth' => $this->getUserGrowthData(),
            'reservation_trends' => $this->getReservationTrends(),
            'category_popularity' => $this->getCategoryPopularity(),
            'teacher_performance' => $this->getTeacherPerformance(),
        ];

        return response()->json([
            'success' => true,
            'analytics' => $analytics,
        ]);
    }

    /**
     * @OA\Put(
     *     path="/admin/users/{user}/status",
     *     tags={"Admin"},
     *     summary="Kullanıcı durumunu güncelle",
     *     description="Kullanıcının aktif/pasif durumunu günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="user",
     *         in="path",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="status", type="string", enum={"active", "suspended"}),
     *             @OA\Property(property="reason", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Kullanıcı durumu başarıyla güncellendi"
     *     )
     * )
     */
    public function updateUserStatus(Request $request, User $user): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:active,suspended',
            'reason' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $status = $request->status;
        $reason = $request->reason;

        if ($status === 'suspended') {
            $user->update([
                'suspended_at' => now(),
                'suspension_reason' => $reason,
            ]);
        } else {
            $user->update([
                'suspended_at' => null,
                'suspended_until' => null,
                'suspension_reason' => null,
            ]);
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_status_updated',
            'description' => "User {$user->name} status updated to {$status}",
            'metadata' => [
                'target_user_id' => $user->id,
                'status' => $status,
                'reason' => $reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı durumu başarıyla güncellendi',
            'user' => $user->fresh(),
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/reservations",
     *     tags={"Admin"},
     *     summary="Tüm rezervasyonları listele",
     *     description="Admin paneli için tüm rezervasyonları getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Rezervasyonlar başarıyla getirildi"
     *     )
     * )
     */
    public function getReservations(Request $request): JsonResponse
    {
        $query = Reservation::with(['student', 'teacher.user', 'category']);

        if ($request->has('status') && $request->status) {
            $query->where('status', $request->status);
        }

        $reservations = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'reservations' => $reservations->items(),
            'pagination' => [
                'current_page' => $reservations->currentPage(),
                'last_page' => $reservations->lastPage(),
                'per_page' => $reservations->perPage(),
                'total' => $reservations->total(),
            ],
        ]);
    }

    /**
     * @OA\Get(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Kategorileri listele",
     *     description="Admin paneli için kategorileri getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="Kategoriler başarıyla getirildi"
     *     )
     * )
     */
    public function getCategories(): JsonResponse
    {
        $categories = Category::with('children')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'success' => true,
            'categories' => $categories,
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/categories",
     *     tags={"Admin"},
     *     summary="Yeni kategori oluştur",
     *     description="Admin paneli için yeni kategori oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="name", type="string"),
     *             @OA\Property(property="description", type="string"),
     *             @OA\Property(property="parent_id", type="integer"),
     *             @OA\Property(property="icon", type="string"),
     *             @OA\Property(property="sort_order", type="integer")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Kategori başarıyla oluşturuldu"
     *     )
     * )
     */
    public function createCategory(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'parent_id' => 'nullable|exists:categories,id',
            'icon' => 'nullable|string|max:255',
            'sort_order' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $category = Category::create([
            'name' => $request->name,
            'description' => $request->description,
            'parent_id' => $request->parent_id,
            'icon' => $request->icon,
            'sort_order' => $request->sort_order ?? 0,
            'slug' => \Str::slug($request->name),
        ]);

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'category_created',
            'description' => "Category '{$category->name}' created",
            'metadata' => [
                'category_id' => $category->id,
                'category_name' => $category->name,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kategori başarıyla oluşturuldu',
            'category' => $category,
        ], 201);
    }

    /**
     * @OA\Get(
     *     path="/admin/audit-logs",
     *     tags={"Admin"},
     *     summary="Audit loglarını listele",
     *     description="Admin paneli için audit loglarını getirir",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="action",
     *         in="query",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Parameter(
     *         name="user_id",
     *         in="query",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Audit logları başarıyla getirildi"
     *     )
     * )
     */
    public function getAuditLogs(Request $request): JsonResponse
    {
        $query = AuditLog::with('user');

        if ($request->has('action') && $request->action) {
            $query->where('action', $request->action);
        }

        if ($request->has('user_id') && $request->user_id) {
            $query->where('user_id', $request->user_id);
        }

        $logs = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'logs' => $logs->items(),
            'pagination' => [
                'current_page' => $logs->currentPage(),
                'last_page' => $logs->lastPage(),
                'per_page' => $logs->perPage(),
                'total' => $logs->total(),
            ],
        ]);
    }

    // User management methods
    public function listUsers(Request $request): JsonResponse
    {
        $query = User::query();

        if ($request->has('role') && $request->role) {
            $query->where('role', $request->role);
        }

        if ($request->has('status') && $request->status) {
            if ($request->status === 'active') {
                $query->whereNull('suspended_at');
            } elseif ($request->status === 'suspended') {
                $query->whereNotNull('suspended_at');
            }
        }

        $users = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'success' => true,
            'users' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    public function searchUsers(Request $request): JsonResponse
    {
        $query = $request->get('q', '');
        
        if (strlen($query) < 2) {
            return response()->json([
                'success' => true,
                'users' => [],
            ]);
        }

        $users = User::where('name', 'like', "%{$query}%")
            ->orWhere('email', 'like', "%{$query}%")
            ->limit(20)
            ->get();

        return response()->json([
            'success' => true,
            'users' => $users,
        ]);
    }

    public function deleteUser(int $id): JsonResponse
    {
        $user = User::findOrFail($id);
        
        // Prevent admin from deleting themselves
        if ($user->id === Auth::id()) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Kendi hesabınızı silemezsiniz'
                ]
            ], 403);
        }

        $userName = $user->name;
        $user->delete();

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'user_deleted',
            'description' => "User '{$userName}' deleted",
            'metadata' => [
                'deleted_user_id' => $id,
                'deleted_user_name' => $userName,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Kullanıcı başarıyla silindi',
        ]);
    }

    public function deleteMultipleUsers(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'integer|exists:users,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $userIds = $request->user_ids;
        $deletedCount = 0;

        foreach ($userIds as $userId) {
            if ($userId !== Auth::id()) {
                $user = User::find($userId);
                if ($user) {
                    $user->delete();
                    $deletedCount++;
                }
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'multiple_users_deleted',
            'description' => "{$deletedCount} users deleted",
            'metadata' => [
                'deleted_user_ids' => $userIds,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "{$deletedCount} kullanıcı başarıyla silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    public function deleteUsersByName(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|min:2',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $name = $request->name;
        $users = User::where('name', 'like', "%{$name}%")->get();
        $deletedCount = 0;

        foreach ($users as $user) {
            if ($user->id !== Auth::id()) {
                $user->delete();
                $deletedCount++;
            }
        }

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'users_deleted_by_name',
            'description' => "Users with name '{$name}' deleted",
            'metadata' => [
                'search_name' => $name,
                'deleted_count' => $deletedCount,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => "İsimde '{$name}' geçen {$deletedCount} kullanıcı silindi",
            'deleted_count' => $deletedCount,
        ]);
    }

    // Teacher approval methods
    public function getPendingTeachers(): JsonResponse
    {
        $teachers = User::where('role', 'teacher')
            ->where('teacher_status', 'pending')
            ->with('teacher')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'teachers' => $teachers,
        ]);
    }

    public function approveTeacher(User $user): JsonResponse
    {
        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı öğretmen değil'
                ]
            ], 400);
        }

        $user->update([
            'teacher_status' => 'approved',
            'approved_by' => Auth::id(),
            'approved_at' => now(),
        ]);

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'teacher_approved',
            'description' => "Teacher '{$user->name}' approved",
            'metadata' => [
                'approved_teacher_id' => $user->id,
                'approved_teacher_name' => $user->name,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başarıyla onaylandı',
            'teacher' => $user->fresh(),
        ]);
    }

    public function rejectTeacher(Request $request, User $user): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_USER',
                    'message' => 'Bu kullanıcı öğretmen değil'
                ]
            ], 400);
        }

        $user->update([
            'teacher_status' => 'rejected',
            'rejection_reason' => $request->reason,
        ]);

        // Log the action
        AuditLog::create([
            'user_id' => Auth::id(),
            'action' => 'teacher_rejected',
            'description' => "Teacher '{$user->name}' rejected",
            'metadata' => [
                'rejected_teacher_id' => $user->id,
                'rejected_teacher_name' => $user->name,
                'rejection_reason' => $request->reason,
            ],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Öğretmen başarıyla reddedildi',
            'teacher' => $user->fresh(),
        ]);
    }

    // Helper methods for analytics
    private function getUserGrowthData(): array
    {
        $data = [];
        for ($i = 11; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $count = User::whereYear('created_at', $date->year)
                ->whereMonth('created_at', $date->month)
                ->count();
            $data[] = [
                'month' => $date->format('Y-m'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getReservationTrends(): array
    {
        $data = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $count = Reservation::whereDate('created_at', $date)->count();
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getCategoryPopularity(): array
    {
        return Category::withCount('reservations')
            ->orderBy('reservations_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($category) {
                return [
                    'name' => $category->name,
                    'count' => $category->reservations_count,
                ];
            })
            ->toArray();
    }

    private function getTeacherPerformance(): array
    {
        return Teacher::with('user')
            ->withCount('reservations')
            ->orderBy('reservations_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($teacher) {
                return [
                    'name' => $teacher->user->name,
                    'reservations_count' => $teacher->reservations_count,
                    'average_rating' => $teacher->average_rating,
                ];
            })
            ->toArray();
    }
}
