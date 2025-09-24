<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Services\PushNotificationService;

class PushNotificationController extends Controller
{
    protected PushNotificationService $pushNotificationService;

    public function __construct(PushNotificationService $pushNotificationService)
    {
        $this->pushNotificationService = $pushNotificationService;
    }

    /**
     * Register FCM token for the authenticated user
     */
    public function registerToken(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = Auth::user();
        $success = $this->pushNotificationService->registerFCMToken($user, $request->token);

        if ($success) {
            return response()->json([
                'success' => true,
                'message' => 'FCM token registered successfully'
            ]);
        }

        return response()->json([
            'error' => [
                'code' => 'REGISTRATION_FAILED',
                'message' => 'Failed to register FCM token'
            ]
        ], 500);
    }

    /**
     * Unregister FCM token for the authenticated user
     */
    public function unregisterToken(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = Auth::user();
        $success = $this->pushNotificationService->unregisterFCMToken($user, $request->token);

        if ($success) {
            return response()->json([
                'success' => true,
                'message' => 'FCM token unregistered successfully'
            ]);
        }

        return response()->json([
            'error' => [
                'code' => 'UNREGISTRATION_FAILED',
                'message' => 'Failed to unregister FCM token'
            ]
        ], 500);
    }

    /**
     * Send test notification (for development/testing)
     */
    public function sendTestNotification(Request $request): JsonResponse
    {
        if (!config('app.debug')) {
            return response()->json([
                'error' => [
                    'code' => 'NOT_ALLOWED',
                    'message' => 'Test notifications only available in debug mode'
                ]
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'body' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = Auth::user();
        $success = $this->pushNotificationService->sendToUser(
            $user,
            $request->title,
            $request->body,
            ['type' => 'test']
        );

        if ($success) {
            return response()->json([
                'success' => true,
                'message' => 'Test notification sent successfully'
            ]);
        }

        return response()->json([
            'error' => [
                'code' => 'SEND_FAILED',
                'message' => 'Failed to send test notification'
            ]
        ], 500);
    }

    /**
     * Get user's notification settings
     */
    public function getNotificationSettings(): JsonResponse
    {
        $user = Auth::user();
        
        $settings = [
            'push_notifications_enabled' => !empty($user->fcm_tokens),
            'reservation_notifications' => true, // Can be stored in user preferences
            'rating_notifications' => true,
            'message_notifications' => true,
            'promotional_notifications' => true,
            'system_notifications' => true,
        ];

        return response()->json([
            'success' => true,
            'data' => $settings
        ]);
    }

    /**
     * Update user's notification settings
     */
    public function updateNotificationSettings(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reservation_notifications' => 'boolean',
            'rating_notifications' => 'boolean',
            'message_notifications' => 'boolean',
            'promotional_notifications' => 'boolean',
            'system_notifications' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = Auth::user();
        
        // Here you would typically update user preferences in the database
        // For now, we'll just return success
        
        return response()->json([
            'success' => true,
            'message' => 'Notification settings updated successfully'
        ]);
    }
}