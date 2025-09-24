<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    /**
     * Get user's notifications
     */
    public function index(Request $request): JsonResponse
    {
        $user = auth()->user();
        
        $query = $user->notifications();

        // Okunmamış bildirimler
        if ($request->has('unread_only') && $request->unread_only) {
            $query->unread();
        }

        // Tip filtresi
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        $notifications = $query->orderBy('created_at', 'desc')->paginate(20);

        return response()->json([
            'data' => $notifications->items(),
            'meta' => [
                'current_page' => $notifications->currentPage(),
                'last_page' => $notifications->lastPage(),
                'per_page' => $notifications->perPage(),
                'total' => $notifications->total(),
            ]
        ]);
    }

    /**
     * Mark notification as read
     */
    public function markAsRead(Notification $notification): JsonResponse
    {
        $user = auth()->user();

        // Sadece bildirim sahibi okuyabilir
        if ($notification->user_id !== $user->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu bildirimi okuyamazsınız'
                ]
            ], 403);
        }

        $notification->markAsRead();

        return response()->json([
            'message' => 'Bildirim okundu olarak işaretlendi'
        ]);
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(): JsonResponse
    {
        $user = auth()->user();
        
        $user->notifications()->unread()->update(['read_at' => now()]);

        return response()->json([
            'message' => 'Tüm bildirimler okundu olarak işaretlendi'
        ]);
    }
}