<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Models\ContentPage;
use Illuminate\Support\Facades\Gate;

/**
 * @OA\Tag(
 *     name="Content Pages",
 *     description="İçerik sayfaları işlemleri"
 * )
 */
class ContentPageController extends Controller
{
    /**
     * @OA\Get(
     *     path="/content-pages",
     *     tags={"Content Pages"},
     *     summary="Tüm aktif içerik sayfalarını listele",
     *     description="Sistemdeki tüm aktif içerik sayfalarını listeler",
     *     @OA\Response(
     *         response=200,
     *         description="İçerik sayfaları başarıyla getirildi",
     *         @OA\JsonContent(
     *             type="array",
     *             @OA\Items(
     *                 @OA\Property(property="id", type="integer"),
     *                 @OA\Property(property="slug", type="string"),
     *                 @OA\Property(property="title", type="string"),
     *                 @OA\Property(property="content", type="string"),
     *                 @OA\Property(property="meta_title", type="string"),
     *                 @OA\Property(property="meta_description", type="string"),
     *                 @OA\Property(property="created_at", type="string", format="date-time"),
     *                 @OA\Property(property="updated_at", type="string", format="date-time")
     *             )
     *         )
     *     )
     * )
     */
    public function index(): JsonResponse
    {
        $pages = ContentPage::active()->ordered()->get();

        return response()->json([
            'data' => $pages
        ]);
    }

    /**
     * @OA\Get(
     *     path="/content-pages/{slug}",
     *     tags={"Content Pages"},
     *     summary="Belirli bir içerik sayfasını getir",
     *     description="Slug'a göre belirli bir içerik sayfasını getirir",
     *     @OA\Parameter(
     *         name="slug",
     *         in="path",
     *         required=true,
     *         description="Sayfa slug'ı",
     *         @OA\Schema(type="string")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="İçerik sayfası başarıyla getirildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="data", type="object")
     *         )
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="Sayfa bulunamadı",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function show(string $slug): JsonResponse
    {
        $page = ContentPage::getBySlug($slug);

        if (!$page) {
            return response()->json([
                'error' => [
                    'code' => 'PAGE_NOT_FOUND',
                    'message' => 'Sayfa bulunamadı'
                ]
            ], 404);
        }

        return response()->json([
            'data' => $page
        ]);
    }

    /**
     * @OA\Post(
     *     path="/admin/content-pages",
     *     tags={"Content Pages"},
     *     summary="Yeni içerik sayfası oluştur",
     *     description="Admin tarafından yeni içerik sayfası oluşturur",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"slug","title","content"},
     *             @OA\Property(property="slug", type="string", example="hakkimizda"),
     *             @OA\Property(property="title", type="string", example="Hakkımızda"),
     *             @OA\Property(property="content", type="string", example="Platform hakkında bilgiler..."),
     *             @OA\Property(property="meta_title", type="string", example="Hakkımızda - Nazliyavuz Platform"),
     *             @OA\Property(property="meta_description", type="string", example="Platform hakkında detaylı bilgiler"),
     *             @OA\Property(property="is_active", type="boolean", example=true),
     *             @OA\Property(property="sort_order", type="integer", example=1)
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="İçerik sayfası başarıyla oluşturuldu",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="İçerik sayfası oluşturuldu"),
     *             @OA\Property(property="data", type="object")
     *         )
     *     )
     * )
     */
    public function store(Request $request): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $request->validate([
            'slug' => 'required|string|max:255|unique:content_pages',
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'meta_title' => 'nullable|string|max:255',
            'meta_description' => 'nullable|string|max:500',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ]);

        $page = ContentPage::create($request->all());

        return response()->json([
            'message' => 'İçerik sayfası oluşturuldu',
            'data' => $page
        ], 201);
    }

    /**
     * @OA\Put(
     *     path="/admin/content-pages/{page}",
     *     tags={"Content Pages"},
     *     summary="İçerik sayfasını güncelle",
     *     description="Admin tarafından içerik sayfasını günceller",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="page",
     *         in="path",
     *         required=true,
     *         description="Sayfa ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             @OA\Property(property="slug", type="string", example="hakkimizda"),
     *             @OA\Property(property="title", type="string", example="Hakkımızda"),
     *             @OA\Property(property="content", type="string", example="Platform hakkında bilgiler..."),
     *             @OA\Property(property="meta_title", type="string", example="Hakkımızda - Nazliyavuz Platform"),
     *             @OA\Property(property="meta_description", type="string", example="Platform hakkında detaylı bilgiler"),
     *             @OA\Property(property="is_active", type="boolean", example=true),
     *             @OA\Property(property="sort_order", type="integer", example=1)
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="İçerik sayfası başarıyla güncellendi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="İçerik sayfası güncellendi"),
     *             @OA\Property(property="data", type="object")
     *         )
     *     )
     * )
     */
    public function update(Request $request, ContentPage $page): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $request->validate([
            'slug' => 'required|string|max:255|unique:content_pages,slug,' . $page->id,
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'meta_title' => 'nullable|string|max:255',
            'meta_description' => 'nullable|string|max:500',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ]);

        $page->update($request->all());

        return response()->json([
            'message' => 'İçerik sayfası güncellendi',
            'data' => $page
        ]);
    }

    /**
     * @OA\Delete(
     *     path="/admin/content-pages/{page}",
     *     tags={"Content Pages"},
     *     summary="İçerik sayfasını sil",
     *     description="Admin tarafından içerik sayfasını siler",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="page",
     *         in="path",
     *         required=true,
     *         description="Sayfa ID",
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="İçerik sayfası başarıyla silindi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="İçerik sayfası silindi")
     *         )
     *     )
     * )
     */
    public function destroy(ContentPage $page): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $page->delete();

        return response()->json([
            'message' => 'İçerik sayfası silindi'
        ]);
    }

    /**
     * Get all content pages for admin
     */
    public function adminIndex(Request $request): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $query = ContentPage::query();

        // Filter by active status
        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        // Search by title or content
        if ($request->has('search')) {
            $search = $request->get('search');
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('content', 'like', "%{$search}%")
                  ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $pages = $query->orderBy('sort_order')->paginate(20);

        return response()->json([
            'data' => $pages->items(),
            'meta' => [
                'current_page' => $pages->currentPage(),
                'last_page' => $pages->lastPage(),
                'per_page' => $pages->perPage(),
                'total' => $pages->total(),
            ]
        ]);
    }

    /**
     * Toggle page active status
     */
    public function toggleStatus(ContentPage $page): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $page->update(['is_active' => !$page->is_active]);

        return response()->json([
            'message' => 'Sayfa durumu güncellendi',
            'data' => $page
        ]);
    }

    /**
     * Update page sort order
     */
    public function updateSortOrder(Request $request): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $request->validate([
            'pages' => 'required|array',
            'pages.*.id' => 'required|exists:content_pages,id',
            'pages.*.sort_order' => 'required|integer',
        ]);

        foreach ($request->pages as $pageData) {
            ContentPage::where('id', $pageData['id'])
                ->update(['sort_order' => $pageData['sort_order']]);
        }

        return response()->json([
            'message' => 'Sıralama güncellendi'
        ]);
    }

    /**
     * Duplicate content page
     */
    public function duplicate(ContentPage $page): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $newPage = $page->replicate();
        $newPage->title = $page->title . ' (Kopya)';
        $newPage->slug = $page->slug . '-kopya-' . time();
        $newPage->is_active = false;
        $newPage->save();

        return response()->json([
            'message' => 'Sayfa kopyalandı',
            'data' => $newPage
        ], 201);
    }

    /**
     * Get page statistics
     */
    public function getStatistics(): JsonResponse
    {
        Gate::authorize('admin', \App\Models\User::class);

        $stats = [
            'total_pages' => ContentPage::count(),
            'active_pages' => ContentPage::where('is_active', true)->count(),
            'inactive_pages' => ContentPage::where('is_active', false)->count(),
            'recent_pages' => ContentPage::where('created_at', '>=', now()->subDays(30))->count(),
        ];

        return response()->json([
            'data' => $stats
        ]);
    }
}
