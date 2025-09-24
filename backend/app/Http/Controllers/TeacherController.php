<?php

namespace App\Http\Controllers;

use App\Models\Teacher;
use App\Models\Category;
use App\Models\Reservation;
use App\Services\CacheService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Cache;
use App\Services\SmartCacheService;
use App\Services\DatabaseOptimizerService;
use App\Services\PerformanceMonitoringService;

class TeacherController extends Controller
{
    protected CacheService $cacheService;

    public function __construct(CacheService $cacheService)
    {
        $this->cacheService = $cacheService;
    }
    /**
     * Get all teachers with filters
     */
    public function index(Request $request): JsonResponse
    {
        // Create cache key based on request parameters
        $cacheKey = 'teachers:' . md5(serialize($request->all()));
        
        // Try to get from cache first
        $cachedResult = $this->cacheService->getCachedSearchResults($cacheKey, $request->all());
        if ($cachedResult) {
            return response()->json($cachedResult);
        }

        $query = Teacher::with(['user', 'categories'])
            ->whereHas('user', function ($q) {
                $q->where('role', 'teacher');
            });

        // Kategori filtresi
        if ($request->has('category')) {
            $query->whereHas('categories', function ($q) use ($request) {
                $q->where('slug', $request->category);
            });
        }

        // Seviye filtresi (gelecekte eklenebilir)
        if ($request->has('level')) {
            // Bu filtre için teacher tablosuna level alanı eklenebilir
        }

        // Fiyat filtresi
        if ($request->has('price_min')) {
            $query->where('price_hour', '>=', $request->price_min);
        }
        if ($request->has('price_max')) {
            $query->where('price_hour', '<=', $request->price_max);
        }

        // Dil filtresi
        if ($request->has('language')) {
            $query->whereJsonContains('languages', $request->language);
        }

        // Online müsaitlik filtresi
        if ($request->has('online_only') && $request->online_only) {
            $query->where('online_available', true);
        }

        // Rating filtresi
        if ($request->has('min_rating')) {
            $query->where('rating_avg', '>=', $request->min_rating);
        }

        // Deneyim filtresi (gelecekte eklenebilir)
        if ($request->has('experience_years')) {
            // Bu filtre için teacher tablosuna experience_years alanı eklenebilir
        }

        // Arama
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('bio', 'like', "%{$search}%")
                  ->orWhereHas('user', function ($userQuery) use ($search) {
                      $userQuery->where('name', 'like', "%{$search}%");
                  });
            });
        }

        // Sıralama
        $sortBy = $request->get('sort_by', 'rating_avg');
        $sortOrder = $request->get('sort_order', 'desc');
        
        if ($sortBy === 'price') {
            $query->orderBy('price_hour', $sortOrder);
        } elseif ($sortBy === 'rating') {
            $query->orderBy('rating_avg', $sortOrder);
        } else {
            $query->orderBy('created_at', $sortOrder);
        }

        // Sayfalama
        $perPage = $request->get('per_page', 20);
        $teachers = $query->paginate($perPage);

        \Log::info('🔄 Teachers API called - Found ' . $teachers->count() . ' teachers');
        \Log::info('📊 Teachers data: ' . json_encode($teachers->items()));

        $result = [
            'data' => $teachers->items(),
            'meta' => [
                'current_page' => $teachers->currentPage(),
                'last_page' => $teachers->lastPage(),
                'per_page' => $teachers->perPage(),
                'total' => $teachers->total(),
            ]
        ];

        // Cache the result
        $this->cacheService->cacheSearchResults($cacheKey, $request->all(), $result, CacheService::SHORT_TERM);

        return response()->json($result);
    }

    /**
     * Get single teacher
     */
    public function show(Teacher $teacher): JsonResponse
    {
        // Try to get from cache first
        $cachedTeacher = $this->cacheService->getCachedTeacher($teacher->id);
        if ($cachedTeacher) {
            return response()->json($cachedTeacher);
        }

        $teacher->load(['user', 'categories', 'reservations' => function ($query) {
            $query->where('status', 'completed')->limit(10);
        }]);

        $result = $teacher->toArray();
        
        // Cache the result
        $this->cacheService->cacheTeacher($teacher->id, $result, CacheService::MEDIUM_TERM);

        return response()->json($teacher);
    }

    /**
     * Create teacher profile
     */
    public function store(Request $request): JsonResponse
    {
        $user = auth()->user();

        if ($user->role !== 'teacher') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Sadece öğretmenler profil oluşturabilir'
                ]
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'bio' => 'required|string|max:1000',
            'specialization' => 'sometimes|string|max:255',
            'education' => 'sometimes|array',
            'education.*' => 'string|max:255',
            'certifications' => 'sometimes|array',
            'certifications.*' => 'string|max:255',
            'price_hour' => 'required|numeric|min:0',
            'languages' => 'sometimes|array',
            'languages.*' => 'string|max:50',
            'categories' => 'required|array|min:1',
            'categories.*' => 'exists:categories,id',
            'online_available' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        // Teacher profil oluştur
        $teacher = Teacher::create([
            'user_id' => $user->id,
            'bio' => $request->get('bio'),
            'education' => $request->get('education', []),
            'certifications' => $request->get('certifications', []),
            'price_hour' => $request->get('price_hour'),
            'languages' => $request->get('languages', []),
            'online_available' => $request->get('online_available', true),
            'is_approved' => false, // Admin onayı bekliyor
        ]);

        // Kategorileri ekle
        $teacher->categories()->attach($request->categories);

        // User'ın teacher_status'unu pending yap
        $user->update(['teacher_status' => 'pending']);

        $teacher->load(['user', 'categories']);

        return response()->json([
            'message' => 'Öğretmen profili başarıyla oluşturuldu. Admin onayı bekleniyor.',
            'teacher' => $teacher,
            'status' => 'pending'
        ], 201);
    }

    /**
     * Update teacher profile
     */
    public function update(Request $request): JsonResponse
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

        $validator = Validator::make($request->all(), [
            'bio' => 'sometimes|string|max:1000',
            'specialization' => 'sometimes|string|max:255',
            'education' => 'sometimes|array',
            'education.*' => 'string|max:255',
            'certifications' => 'sometimes|array',
            'certifications.*' => 'string|max:255',
            'price_hour' => 'sometimes|numeric|min:0',
            'languages' => 'sometimes|array',
            'languages.*' => 'string|max:50',
            'categories' => 'sometimes|array|min:1',
            'categories.*' => 'exists:categories,id',
            'online_available' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $teacher->update($request->only([
            'bio', 'education', 'certifications', 'price_hour', 'languages', 'online_available'
        ]));

        // Kategorileri güncelle
        if ($request->has('categories')) {
            $teacher->categories()->sync($request->categories);
        }

        $teacher->load(['user', 'categories']);

        return response()->json([
            'message' => 'Öğretmen profili başarıyla güncellendi',
            'teacher' => $teacher
        ]);
    }

    /**
     * Get teacher's reservations
     */
    public function reservations(Request $request): JsonResponse
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
     * Get student's favorite teachers
     */
    public function favorites(): JsonResponse
    {
        $user = auth()->user();
        $favorites = $user->favoriteTeachers()->with(['teacher'])->get();

        return response()->json($favorites);
    }

    /**
     * Add teacher to favorites
     */
    public function addToFavorites(Teacher $teacher): JsonResponse
    {
        $user = auth()->user();

        if ($user->role !== 'student') {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Sadece öğrenciler favorilere ekleyebilir'
                ]
            ], 403);
        }

        $user->favoriteTeachers()->syncWithoutDetaching([$teacher->user_id]);

        return response()->json([
            'message' => 'Öğretmen favorilere eklendi'
        ]);
    }

    /**
     * Remove teacher from favorites
     */
    public function removeFromFavorites(Teacher $teacher): JsonResponse
    {
        $user = auth()->user();
        $user->favoriteTeachers()->detach($teacher->user_id);

        return response()->json([
            'message' => 'Öğretmen favorilerden çıkarıldı'
        ]);
    }

    /**
     * Delete teacher profile
     */
    public function destroy(): JsonResponse
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

        // Soft delete teacher profile
        $teacher->delete();

        return response()->json([
            'message' => 'Öğretmen profili başarıyla silindi'
        ]);
    }

    /**
     * Get featured teachers
     */
    public function featured(): JsonResponse
    {
        $featuredTeachers = Teacher::with(['user', 'categories'])
            ->whereHas('user', function ($q) {
                $q->where('role', 'teacher');
            })
            ->where('rating_avg', '>=', 4.0)
            ->orderBy('rating_avg', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'data' => $featuredTeachers,
            'message' => 'Öne çıkan öğretmenler'
        ]);
    }

    /**
     * Get teacher statistics
     */
    public function statistics(): JsonResponse
    {
        $stats = [
            'total_teachers' => Teacher::whereHas('user', function ($q) {
                $q->where('role', 'teacher');
            })->count(),
            'online_teachers' => Teacher::where('online_available', true)
                ->whereHas('user', function ($q) {
                    $q->where('role', 'teacher');
                })->count(),
            'average_rating' => Teacher::whereHas('user', function ($q) {
                $q->where('role', 'teacher');
            })->avg('rating_avg'),
            'categories_count' => \App\Models\Category::count(),
        ];

        return response()->json([
            'data' => $stats,
            'message' => 'Öğretmen istatistikleri'
        ]);
    }

    /**
     * Get teacher reviews
     */
    public function reviews(Teacher $teacher): JsonResponse
    {
        $reviews = $teacher->ratings()
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(10);

        return response()->json([
            'data' => $reviews->items(),
            'meta' => [
                'current_page' => $reviews->currentPage(),
                'last_page' => $reviews->lastPage(),
                'per_page' => $reviews->perPage(),
                'total' => $reviews->total(),
            ]
        ]);
    }
}