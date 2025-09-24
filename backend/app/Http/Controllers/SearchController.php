<?php

namespace App\Http\Controllers;

use App\Models\Teacher;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;

class SearchController extends Controller
{
    /**
     * Search teachers
     */
    public function searchTeachers(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'query' => 'sometimes|string|max:255',
            'category_id' => 'sometimes|exists:categories,id',
            'min_price' => 'sometimes|numeric|min:0',
            'max_price' => 'sometimes|numeric|min:0|gte:min_price',
            'rating_min' => 'sometimes|numeric|min:0|max:5',
            'online_only' => 'sometimes|boolean',
            'sort_by' => 'sometimes|in:price_asc,price_desc,rating_desc,created_desc',
            'page' => 'sometimes|integer|min:1',
            'per_page' => 'sometimes|integer|min:1|max:50',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $query = Teacher::with(['user', 'categories'])
            ->where('is_approved', true);

        // Search by name or specialization
        if ($request->filled('query')) {
            $searchQuery = $request->input('query');
            $query->whereHas('user', function ($q) use ($searchQuery) {
                $q->where('name', 'LIKE', "%{$searchQuery}%");
            })->orWhere('bio', 'LIKE', "%{$searchQuery}%");
        }

        // Filter by category
        if ($request->filled('category_id')) {
            $query->whereHas('categories', function ($q) use ($request) {
                $q->where('categories.id', $request->category_id);
            });
        }

        // Filter by price range
        if ($request->filled('min_price')) {
            $query->where('price_hour', '>=', $request->min_price);
        }
        if ($request->filled('max_price')) {
            $query->where('price_hour', '<=', $request->max_price);
        }

        // Filter by rating
        if ($request->filled('rating_min')) {
            $query->where('rating_avg', '>=', $request->rating_min);
        }

        // Filter by online availability
        if ($request->filled('online_only') && $request->online_only) {
            $query->where('online_available', true);
        }

        // Sorting
        $sortBy = $request->get('sort_by', 'rating_desc');
        switch ($sortBy) {
            case 'price_asc':
                $query->orderBy('price_hour', 'asc');
                break;
            case 'price_desc':
                $query->orderBy('price_hour', 'desc');
                break;
            case 'rating_desc':
                $query->orderBy('rating_avg', 'desc');
                break;
            case 'created_desc':
                $query->orderBy('created_at', 'desc');
                break;
            default:
                $query->orderBy('rating_avg', 'desc');
        }

        // Pagination
        $perPage = $request->get('per_page', 20);
        $teachers = $query->paginate($perPage);

        // Format response
        $formattedTeachers = $teachers->map(function ($teacher) {
            return [
                'id' => $teacher->id,
                'user_id' => $teacher->user_id,
                'name' => $teacher->user->name,
                'email' => $teacher->user->email,
                'profile_photo_url' => $teacher->user->profile_photo_url,
                'bio' => $teacher->bio,
                'specialization' => $teacher->specialization,
                'education' => $teacher->education,
                'certifications' => $teacher->certifications,
                'price_hour' => $teacher->price_hour,
                'languages' => $teacher->languages,
                'rating_avg' => $teacher->rating_avg,
                'rating_count' => $teacher->rating_count,
                'online_available' => $teacher->online_available,
                'categories' => $teacher->categories->map(function ($category) {
                    return [
                        'id' => $category->id,
                        'name' => $category->name,
                        'slug' => $category->slug,
                        'description' => $category->description,
                    ];
                }),
                'created_at' => $teacher->created_at,
                'updated_at' => $teacher->updated_at,
            ];
        });

        return response()->json([
            'teachers' => $formattedTeachers,
            'meta' => [
                'current_page' => $teachers->currentPage(),
                'last_page' => $teachers->lastPage(),
                'per_page' => $teachers->perPage(),
                'total' => $teachers->total(),
                'filters_applied' => [
                    'query' => $request->query,
                    'category_id' => $request->category_id,
                    'min_price' => $request->min_price,
                    'max_price' => $request->max_price,
                    'rating_min' => $request->rating_min,
                    'online_only' => $request->online_only,
                    'sort_by' => $sortBy,
                ]
            ]
        ]);
    }

    /**
     * Get search suggestions
     */
    public function getSuggestions(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'query' => 'required|string|min:2|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $searchQuery = $request->input('query');
        $suggestions = [];

        // Teacher name suggestions
        $teacherNames = Teacher::whereHas('user', function ($q) use ($searchQuery) {
            $q->where('name', 'LIKE', "%{$searchQuery}%");
        })
        ->with('user')
        ->limit(5)
        ->get()
        ->map(function ($teacher) {
            return [
                'type' => 'teacher',
                'id' => $teacher->user_id,
                'name' => $teacher->user->name,
                'text' => $teacher->user->name,
            ];
        });

        $suggestions = array_merge($suggestions, $teacherNames->toArray());

        // Category suggestions
        $categoryNames = Category::where('name', 'LIKE', "%{$searchQuery}%")
            ->limit(5)
            ->get()
            ->map(function ($category) {
                return [
                    'type' => 'category',
                    'id' => $category->id,
                    'name' => $category->name,
                    'text' => $category->name,
                ];
            });

        $suggestions = array_merge($suggestions, $categoryNames->toArray());

        return response()->json([
            'suggestions' => $suggestions
        ]);
    }

    /**
     * Get popular searches
     */
    public function getPopularSearches(): JsonResponse
    {
        $popularCategories = Category::withCount('teachers')
            ->orderBy('teachers_count', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($category) {
                return [
                    'type' => 'category',
                    'id' => $category->id,
                    'name' => $category->name,
                    'teacher_count' => $category->teachers_count,
                ];
            });

        return response()->json([
            'popular_searches' => $popularCategories
        ]);
    }

    /**
     * Get search filters
     */
    public function getFilters(): JsonResponse
    {
        $categories = Category::where('is_active', true)
            ->orderBy('name')
            ->get()
            ->map(function ($category) {
                return [
                    'id' => $category->id,
                    'name' => $category->name,
                    'slug' => $category->slug,
                    'teacher_count' => $category->teachers()->count(),
                ];
            });

        $priceRange = Teacher::selectRaw('MIN(price_hour) as min_price, MAX(price_hour) as max_price')
            ->where('is_approved', true)
            ->first();

        return response()->json([
            'categories' => $categories,
            'price_range' => [
                'min' => $priceRange->min_price ?? 0,
                'max' => $priceRange->max_price ?? 1000,
            ],
            'sort_options' => [
                ['value' => 'rating_desc', 'label' => 'En Yüksek Puan'],
                ['value' => 'price_asc', 'label' => 'En Düşük Fiyat'],
                ['value' => 'price_desc', 'label' => 'En Yüksek Fiyat'],
                ['value' => 'created_desc', 'label' => 'En Yeni'],
            ]
        ]);
    }
}