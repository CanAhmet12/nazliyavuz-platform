<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Http\JsonResponse;

class AuthRateLimitMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Illuminate\Http\Response|\Illuminate\Http\JsonResponse)  $next
     * @return \Illuminate\Http\Response|\Illuminate\Http\JsonResponse
     */
    public function handle(Request $request, Closure $next)
    {
        $key = 'auth|' . $request->ip();
        $maxAttempts = 5; // 5 deneme hakkı
        $decayMinutes = 15; // 15 dakika bekleme

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            return $this->buildResponse($key, $maxAttempts);
        }

        RateLimiter::hit($key, $decayMinutes * 60);

        $response = $next($request);

        // Başarılı giriş durumunda rate limit'i temizle
        if ($response->getStatusCode() === 200 || $response->getStatusCode() === 201) {
            RateLimiter::clear($key);
        }

        return $this->addHeaders(
            $response,
            $maxAttempts,
            $this->calculateRemainingAttempts($key, $maxAttempts)
        );
    }

    /**
     * Create a too many attempts response.
     *
     * @param  string  $key
     * @param  int  $maxAttempts
     * @return \Illuminate\Http\JsonResponse
     */
    protected function buildResponse(string $key, int $maxAttempts): JsonResponse
    {
        $retryAfter = RateLimiter::availableIn($key);

        return response()->json([
            'error' => [
                'code' => 'AUTH_RATE_LIMIT_EXCEEDED',
                'message' => 'Çok fazla başarısız giriş denemesi. Lütfen ' . $retryAfter . ' saniye sonra tekrar deneyin.',
                'retry_after' => $retryAfter,
            ]
        ], 429);
    }

    /**
     * Add the limit header information to the given response.
     *
     * @param  \Illuminate\Http\Response|\Illuminate\Http\JsonResponse  $response
     * @param  int  $maxAttempts
     * @param  int  $remainingAttempts
     * @return \Illuminate\Http\Response|\Illuminate\Http\JsonResponse
     */
    protected function addHeaders($response, int $maxAttempts, int $remainingAttempts)
    {
        $response->headers->add([
            'X-RateLimit-Limit' => $maxAttempts,
            'X-RateLimit-Remaining' => $remainingAttempts,
        ]);

        return $response;
    }

    /**
     * Calculate the number of remaining attempts.
     *
     * @param  string  $key
     * @param  int  $maxAttempts
     * @return int
     */
    protected function calculateRemainingAttempts(string $key, int $maxAttempts): int
    {
        return max(0, $maxAttempts - RateLimiter::attempts($key));
    }
}
