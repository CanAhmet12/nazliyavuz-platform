<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\TeacherController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\ReservationController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\RatingController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\ContentPageController;
use App\Http\Controllers\AvailabilityController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\PushNotificationController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\SearchController;
use App\Http\Controllers\PerformanceDashboardController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

Route::prefix('v1')->group(function () {
    
    // Public routes
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('auth_rate_limit');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('auth_rate_limit');
    Route::post('/auth/refresh', [AuthController::class, 'refresh']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    
    // Email verification and password reset (public)
    Route::post('/auth/verify-email', [AuthController::class, 'verifyEmail'])->middleware('auth_rate_limit');
    Route::post('/auth/verify-email-code', [AuthController::class, 'verifyEmailCode'])->middleware('auth_rate_limit');
    Route::post('/auth/resend-verification', [AuthController::class, 'resendVerification'])->middleware('auth_rate_limit');
    Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('auth_rate_limit');
    Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('auth_rate_limit');
    
    // Social Authentication (public) - Disabled for now
    // Route::post('/auth/social/google', [SocialAuthController::class, 'googleAuth'])->middleware('auth_rate_limit');
    // Route::post('/auth/social/facebook', [SocialAuthController::class, 'facebookAuth'])->middleware('auth_rate_limit');
    // Route::post('/auth/social/apple', [SocialAuthController::class, 'appleAuth'])->middleware('auth_rate_limit');
    
    // Mail status check (public)
    Route::get('/auth/mail-status', [AuthController::class, 'getMailStatus']);
    
    // Categories (public)
    Route::get('/categories', [CategoryController::class, 'index']);
    Route::get('/categories/{category}', [CategoryController::class, 'show']);
    Route::get('/categories/fallback/{slug}', [CategoryController::class, 'showWithFallback']);
    
    // Search
    Route::get('/search/teachers', [SearchController::class, 'searchTeachers']);
    Route::get('/search/suggestions', [SearchController::class, 'getSuggestions']);
    Route::get('/search/popular', [SearchController::class, 'getPopularSearches']);
    Route::get('/search/filters', [SearchController::class, 'getFilters']);
    
    // Teachers (public)
    Route::get('/teachers', [TeacherController::class, 'index']);
    Route::get('/teachers/featured', [TeacherController::class, 'featured']);
    Route::get('/teachers/statistics', [TeacherController::class, 'statistics']);
    Route::get('/teachers/{teacher}', [TeacherController::class, 'show']);
    Route::get('/teachers/{teacher}/reviews', [TeacherController::class, 'reviews']);
    
    // Ratings (public)
    Route::get('/teachers/{teacher}/ratings', [RatingController::class, 'getTeacherRatings']);
    
    // Content pages (public)
    Route::get('/content-pages', [ContentPageController::class, 'index']);
    Route::get('/content-pages/{slug}', [ContentPageController::class, 'show']);
    
    // Payment callback (public)
    Route::post('/payments/callback', [PaymentController::class, 'handleCallback']);
    
    // Protected routes
    Route::middleware(['auth:api', 'rate_limit:api,60,1'])->group(function () {
        
        // User profile
        Route::get('/user', [UserController::class, 'profile']);
        Route::put('/user', [UserController::class, 'update']);
        Route::post('/user/change-password', [UserController::class, 'changePassword']);
        Route::get('/user/statistics', [UserController::class, 'getStatistics']);
        Route::get('/user/activity-history', [UserController::class, 'getActivityHistory']);
        Route::delete('/user/account', [UserController::class, 'deleteAccount']);
        Route::get('/user/export-data', [UserController::class, 'exportData']);
        Route::get('/user/notification-preferences', [UserController::class, 'getNotificationPreferences']);
        Route::put('/user/notification-preferences', [UserController::class, 'updateNotificationPreferences']);
        
        // Social account linking - Disabled for now
        // Route::post('/auth/social/link', [SocialAuthController::class, 'linkSocialAccount']);
        // Route::get('/auth/social/accounts', [SocialAuthController::class, 'getLinkedAccounts']);
        // Route::delete('/auth/social/unlink/{provider}', [SocialAuthController::class, 'unlinkSocialAccount']);
        
        // Teacher profile management
        Route::middleware('role:teacher')->group(function () {
            Route::post('/teacher/profile', [TeacherController::class, 'store']);
            Route::put('/teacher/profile', [TeacherController::class, 'update']);
            Route::get('/teacher/students', [TeacherController::class, 'getStudents']);
            Route::get('/teacher/lessons', [TeacherController::class, 'getLessons']);
            Route::get('/teacher/statistics', [TeacherController::class, 'getStatistics']);
            Route::get('/teacher/reservations', [ReservationController::class, 'teacherReservations']);
            Route::put('/reservations/{reservation}/status', [ReservationController::class, 'updateStatus']);
        });
        
        // Reservations (accessible by both students and teachers)
        Route::get('/reservations', [ReservationController::class, 'index']);
        Route::get('/reservations/statistics', [ReservationController::class, 'getStatistics']);
        Route::post('/reservations', [ReservationController::class, 'store']);
        Route::put('/reservations/{reservation}/status', [ReservationController::class, 'updateStatus']);
        Route::delete('/reservations/{reservation}', [ReservationController::class, 'destroy']);
        
        // Lessons (accessible by both students and teachers)
        Route::get('/lessons/{lesson}', [LessonController::class, 'show']);
        Route::put('/lessons/notes', [LessonController::class, 'updateNotes']);
        Route::post('/lessons/rate', [LessonController::class, 'rateLesson']);
        
        // Student routes
        Route::middleware('role:student')->group(function () {
            
            // Favorites
            Route::get('/favorites', [TeacherController::class, 'favorites']);
            Route::post('/favorites/{teacher}', [TeacherController::class, 'addToFavorites']);
            Route::delete('/favorites/{teacher}', [TeacherController::class, 'removeFromFavorites']);
        });
        
        // Notifications
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::put('/notifications/{notification}/read', [NotificationController::class, 'markAsRead']);
        Route::put('/notifications/read-all', [NotificationController::class, 'markAllAsRead']);
        
        // Payments
        Route::post('/payments/create', [PaymentController::class, 'createPayment']);
        Route::post('/payments/confirm', [PaymentController::class, 'confirmPayment']);
        Route::get('/payments/history', [PaymentController::class, 'getPaymentHistory']);
        
        // File sharing
        Route::get('/files/shared', [App\Http\Controllers\FileSharingController::class, 'getSharedFiles']);
        Route::post('/files/upload-shared', [App\Http\Controllers\FileSharingController::class, 'uploadSharedFile']);
        Route::get('/files/download/{file}', [App\Http\Controllers\FileSharingController::class, 'downloadSharedFile']);
        
        // Lessons
        Route::get('/lessons', [App\Http\Controllers\LessonController::class, 'getUserLessons']);
        Route::get('/lessons/statistics', [App\Http\Controllers\LessonController::class, 'getLessonStatistics']);
        Route::get('/lessons/upcoming', [App\Http\Controllers\LessonController::class, 'getUpcomingLessons']);
        Route::post('/lessons/start', [App\Http\Controllers\LessonController::class, 'startLesson']);
        Route::post('/lessons/end', [App\Http\Controllers\LessonController::class, 'endLesson']);
        Route::put('/lessons/notes', [App\Http\Controllers\LessonController::class, 'updateLessonNotes']);
        Route::post('/lessons/rate', [App\Http\Controllers\LessonController::class, 'rateLesson']);
        Route::get('/lessons/status/{reservation}', [App\Http\Controllers\LessonController::class, 'getLessonStatus']);
        Route::delete('/files/{file}', [App\Http\Controllers\FileSharingController::class, 'deleteSharedFile']);
        
        // Assignments
        Route::get('/assignments', [App\Http\Controllers\AssignmentController::class, 'index']);
        Route::get('/assignments/student', [App\Http\Controllers\AssignmentController::class, 'getStudentAssignments']);
        Route::get('/assignments/teacher', [App\Http\Controllers\AssignmentController::class, 'getTeacherAssignments']);
        Route::post('/assignments', [App\Http\Controllers\AssignmentController::class, 'store']);
        Route::post('/assignments/{assignment}/submit', [App\Http\Controllers\AssignmentController::class, 'submit']);
        Route::post('/assignments/{assignment}/grade', [App\Http\Controllers\AssignmentController::class, 'grade']);
        
        // Video call signaling
        Route::post('/chat/signaling', [ChatController::class, 'sendSignalingMessage']);
        
        
        // File upload
        Route::post('/upload/profile-photo', [App\Http\Controllers\FileUploadController::class, 'uploadProfilePhoto']);
        Route::delete('/upload/profile-photo', [App\Http\Controllers\FileUploadController::class, 'deleteProfilePhoto']);
        Route::post('/upload/document', [App\Http\Controllers\FileUploadController::class, 'uploadDocument']);
        Route::post('/upload/presigned-url', [App\Http\Controllers\FileUploadController::class, 'generatePresignedUrl']);
        
        // Teacher availability management
        Route::post('/teacher/availabilities', [AvailabilityController::class, 'store']);
        Route::put('/teacher/availabilities/{availability}', [AvailabilityController::class, 'update']);
        Route::delete('/teacher/availabilities/{availability}', [AvailabilityController::class, 'destroy']);
        
            // Push notification routes
            Route::post('/notifications/register-token', [PushNotificationController::class, 'registerToken']);
            Route::post('/notifications/unregister-token', [PushNotificationController::class, 'unregisterToken']);
            Route::post('/notifications/test', [PushNotificationController::class, 'sendTestNotification']);
            Route::get('/notifications/settings', [PushNotificationController::class, 'getNotificationSettings']);
            Route::put('/notifications/settings', [PushNotificationController::class, 'updateNotificationSettings']);
            
            // Chat routes
            Route::get('/chats', [ChatController::class, 'index']);
            Route::post('/chats/get-or-create', [ChatController::class, 'getOrCreateChat']);
            Route::post('/chats/messages', [ChatController::class, 'sendMessage']);
            Route::put('/chats/mark-read', [ChatController::class, 'markAsRead']);
            Route::get('/chats/{chatId}/messages', [ChatController::class, 'getMessages']);
            
            // Advanced chat features
            Route::post('/chat/typing', [ChatController::class, 'sendTypingIndicator']);
            Route::post('/chat/messages/{messageId}/reaction', [ChatController::class, 'sendMessageReaction']);
            Route::get('/chat/messages/{messageId}/reactions', [ChatController::class, 'getMessageReactions']);
            Route::post('/chat/voice-message', [ChatController::class, 'sendVoiceMessage']);
            Route::post('/chat/video-call', [ChatController::class, 'sendVideoCallInvitation']);
            Route::post('/chat/video-call-response', [ChatController::class, 'respondToVideoCall']);
        
        // Admin routes
        Route::middleware('role:admin')->group(function () {
            Route::get('/admin/dashboard', [AdminController::class, 'dashboard']);
            Route::get('/admin/analytics', [AdminController::class, 'getAnalytics']);
            Route::put('/admin/users/{user}/status', [AdminController::class, 'updateUserStatus']);
            Route::get('/admin/reservations', [AdminController::class, 'getReservations']);
            Route::get('/admin/categories', [AdminController::class, 'getCategories']);
            Route::post('/admin/categories', [AdminController::class, 'createCategory']);
            Route::get('/admin/audit-logs', [AdminController::class, 'getAuditLogs']);
            
            // User management routes (new endpoints)
            Route::get('/admin/users', [AdminController::class, 'listUsers']);
            Route::get('/admin/users/search', [AdminController::class, 'searchUsers']);
            Route::delete('/admin/users/{id}', [AdminController::class, 'deleteUser']);
            Route::delete('/admin/users', [AdminController::class, 'deleteMultipleUsers']);
            Route::delete('/admin/users/by-name', [AdminController::class, 'deleteUsersByName']);
            
            // Teacher approval routes
            Route::get('/admin/teachers/pending', [AdminController::class, 'getPendingTeachers']);
            Route::post('/admin/teachers/{user}/approve', [AdminController::class, 'approveTeacher']);
            Route::post('/admin/teachers/{user}/reject', [AdminController::class, 'rejectTeacher']);
            Route::put('/admin/categories/{category}', [CategoryController::class, 'update']);
            Route::delete('/admin/categories/{category}', [CategoryController::class, 'destroy']);
            
            // Content pages management
            Route::get('/admin/content-pages', [ContentPageController::class, 'index']);
            Route::post('/admin/content-pages', [ContentPageController::class, 'store']);
            Route::put('/admin/content-pages/{page}', [ContentPageController::class, 'update']);
            Route::delete('/admin/content-pages/{page}', [ContentPageController::class, 'destroy']);
            
            // Performance Dashboard routes
            Route::get('/performance/dashboard', [PerformanceDashboardController::class, 'dashboard']);
            Route::get('/performance/trends', [PerformanceDashboardController::class, 'trends']);
            Route::get('/performance/recommendations', [PerformanceDashboardController::class, 'recommendations']);
            Route::get('/performance/export', [PerformanceDashboardController::class, 'export']);
        });
    });
});

// Public routes (no authentication required)
Route::middleware('cache_response:600')->group(function () {
    Route::get('/teachers/{teacher}/availabilities', [AvailabilityController::class, 'index']);
    Route::get('/teachers/{teacher}/available-slots', [AvailabilityController::class, 'getAvailableSlots']);
    
    // Search routes
    Route::get('/search', [SearchController::class, 'search']);
    Route::get('/search/suggestions', [SearchController::class, 'suggestions']);
    Route::get('/search/popular', [SearchController::class, 'popularSearches']);
    Route::get('/search/filters', [SearchController::class, 'filters']);
    Route::get('/search/trending', [SearchController::class, 'trending']);
});

// PayTR callback (public route - outside auth middleware)
Route::post('/payments/callback', [PaymentController::class, 'handleCallback']);
