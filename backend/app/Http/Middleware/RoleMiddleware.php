<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next, string $role): Response
    {
        if (!auth()->check()) {
            return response()->json([
                'error' => [
                    'code' => 'UNAUTHORIZED',
                    'message' => 'Giriş yapmanız gerekiyor'
                ]
            ], 401);
        }

        $user = auth()->user();
        
        // Kullanıcının rolünü veritabanından yeniden yükle
        $user = \App\Models\User::find($user->id);
        
        if (!$user || $user->role !== $role) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Bu işlem için yetkiniz bulunmuyor'
                ]
            ], 403);
        }

        return $next($request);
    }
}