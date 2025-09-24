<?php

namespace App\Http\Controllers;

use App\Services\MailService;
use App\Models\EmailVerification;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Mail;
use Tymon\JWTAuth\Facades\JWTAuth;
use Tymon\JWTAuth\Exceptions\JWTException;

/**
 * @OA\Tag(
 *     name="Authentication",
 *     description="Kimlik doğrulama işlemleri"
 * )
 */
class AuthController extends Controller
{
    protected MailService $mailService;

    public function __construct(MailService $mailService)
    {
        $this->mailService = $mailService;
    }

    /**
     * @OA\Post(
     *     path="/auth/register",
     *     tags={"Authentication"},
     *     summary="Yeni kullanıcı kaydı",
     *     description="Sisteme yeni kullanıcı kaydı oluşturur",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"name","email","password","password_confirmation","role"},
     *             @OA\Property(property="name", type="string", example="Ahmet Yılmaz"),
     *             @OA\Property(property="email", type="string", format="email", example="ahmet@example.com"),
     *             @OA\Property(property="password", type="string", format="password", example="password123"),
     *             @OA\Property(property="password_confirmation", type="string", format="password", example="password123"),
     *             @OA\Property(property="role", type="string", enum={"student","teacher"}, example="student")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="Kullanıcı başarıyla oluşturuldu",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Kullanıcı başarıyla oluşturuldu"),
     *             @OA\Property(property="user", type="object"),
     *             @OA\Property(property="token", type="object")
     *         )
     *     ),
     *     @OA\Response(
     *         response=422,
     *         description="Validation hatası",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function register(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'role' => 'required|in:student,teacher',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role,
        ]);

        // E-posta doğrulama token'ı oluştur
        $verification = EmailVerification::createForUser($user);

        // Mail gönderim durumunu kontrol et
        $mailSent = $this->mailService->sendEmailVerification($user, $verification->token, $verification->verification_code);
        $mailConfigured = $this->mailService->isMailConfigured();

        // Hoş geldin e-postası gönder
        $this->mailService->sendWelcomeEmail($user);

        // Audit log
        AuditLog::createLog(
            userId: $user->id,
            action: 'create_user',
            targetType: 'User',
            targetId: $user->id,
            meta: [
                'role' => $request->role,
                'email' => $request->email,
            ],
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        $token = JWTAuth::fromUser($user);

        return response()->json([
            'message' => 'Kullanıcı başarıyla oluşturuldu',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'email_verified_at' => $user->email_verified_at,
            ],
            'token' => [
                'access_token' => $token,
                'token_type' => 'bearer',
                'expires_in' => config('jwt.ttl') * 60
            ],
            'email_verification' => [
                'required' => true,
                'mail_sent' => $mailSent,
                'mail_configured' => $mailConfigured,
                'verification_token' => $verification->token, // Development için
                'message' => $mailSent 
                    ? 'E-posta doğrulama maili gönderildi' 
                    : 'E-posta doğrulama maili gönderilemedi - lütfen mail ayarlarını kontrol edin'
            ]
        ], 201);
    }

    /**
     * Login user
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $credentials = $request->only('email', 'password');

        try {
            if (!$token = JWTAuth::attempt($credentials)) {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_CREDENTIALS',
                        'message' => 'E-posta veya şifre hatalı'
                    ]
                ], 401);
            }
        } catch (JWTException $e) {
            return response()->json([
                'error' => [
                    'code' => 'TOKEN_ERROR',
                    'message' => 'Token oluşturulamadı'
                ]
            ], 500);
        }

        $user = auth()->user();

        // E-posta doğrulama kontrolü
        if (!$user->email_verified_at) {
            // E-posta doğrulama token'ı oluştur ve gönder
            $verification = EmailVerification::createForUser($user);
            $mailSent = $this->mailService->sendEmailVerification($user, $verification->token, $verification->verification_code);
            
            return response()->json([
                'error' => [
                    'code' => 'EMAIL_NOT_VERIFIED',
                    'message' => 'E-posta adresinizi doğrulamanız gerekiyor',
                    'email_verification' => [
                        'required' => true,
                        'mail_sent' => $mailSent,
                        'verification_code' => $verification->verification_code, // Development için
                        'message' => $mailSent 
                            ? 'Doğrulama kodu e-posta adresinize gönderildi' 
                            : 'E-posta gönderilemedi - lütfen mail ayarlarını kontrol edin'
                    ]
                ]
            ], 403);
        }

        // Audit log
        AuditLog::createLog(
            userId: $user->id,
            action: 'login',
            targetType: 'User',
            targetId: $user->id,
            meta: [
                'email' => $request->email,
                'login_time' => now()->toISOString(),
            ],
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return response()->json([
            'token' => [
                'access_token' => $token,
                'token_type' => 'bearer',
                'expires_in' => config('jwt.ttl') * 60
            ],
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'profile_photo_url' => $user->profile_photo_url,
            ]
        ]);
    }

    /**
     * Refresh token
     */
    public function refresh(): JsonResponse
    {
        try {
            $token = JWTAuth::refresh(JWTAuth::getToken());
            
            return response()->json([
                'token' => [
                    'access_token' => $token,
                    'token_type' => 'bearer',
                    'expires_in' => config('jwt.ttl') * 60
                ]
            ]);
        } catch (JWTException $e) {
            return response()->json([
                'error' => [
                    'code' => 'TOKEN_ERROR',
                    'message' => 'Token yenilenemedi'
                ]
            ], 401);
        }
    }

    /**
     * Logout user
     */
    public function logout(): JsonResponse
    {
        $user = auth()->user();
        
        // Audit log
        if ($user) {
            AuditLog::createLog(
                userId: $user->id,
                action: 'logout',
                targetType: 'User',
                targetId: $user->id,
                meta: [
                    'logout_time' => now()->toISOString(),
                ],
                ipAddress: request()->ip(),
                userAgent: request()->userAgent(),
            );
        }

        try {
            JWTAuth::invalidate(JWTAuth::getToken());
            
            return response()->json([
                'message' => 'Başarıyla çıkış yapıldı'
            ]);
        } catch (JWTException $e) {
            return response()->json([
                'error' => [
                    'code' => 'TOKEN_ERROR',
                    'message' => 'Çıkış yapılamadı'
                ]
            ], 500);
        }
    }

    /**
     * Get authenticated user
     */
    public function me(): JsonResponse
    {
        $user = auth()->user();
        
        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'profile_photo_url' => $user->profile_photo_url,
                'verified_at' => $user->verified_at,
            ]
        ]);
    }

    /**
     * @OA\Post(
     *     path="/auth/verify-email",
     *     tags={"Authentication"},
     *     summary="E-posta doğrulama",
     *     description="Kullanıcının e-posta adresini doğrular",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"token"},
     *             @OA\Property(property="token", type="string", example="abc123...")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="E-posta başarıyla doğrulandı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="E-posta başarıyla doğrulandı")
     *         )
     *     ),
     *     @OA\Response(
     *         response=400,
     *         description="Geçersiz veya süresi dolmuş token",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function verifyEmail(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $verification = EmailVerification::where('token', $request->token)->first();

        if (!$verification) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_TOKEN',
                    'message' => 'Geçersiz doğrulama token\'ı'
                ]
            ], 400);
        }

        if ($verification->isExpired()) {
            return response()->json([
                'error' => [
                    'code' => 'EXPIRED_TOKEN',
                    'message' => 'Doğrulama token\'ının süresi dolmuş'
                ]
            ], 400);
        }

        if ($verification->isVerified()) {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_VERIFIED',
                    'message' => 'E-posta adresi zaten doğrulanmış'
                ]
            ], 400);
        }

        $verification->verify();

        // Audit log
        AuditLog::createLog(
            userId: $verification->user_id,
            action: 'email_verified',
            targetType: 'User',
            targetId: $verification->user_id,
            meta: [
                'email' => $verification->user->email,
                'verification_time' => now()->toISOString(),
            ],
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return response()->json([
            'message' => 'E-posta başarıyla doğrulandı'
        ]);
    }

    /**
     * @OA\Post(
     *     path="/auth/resend-verification",
     *     tags={"Authentication"},
     *     summary="Doğrulama e-postası yeniden gönder",
     *     description="Kullanıcıya yeni doğrulama e-postası gönderir",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email"},
     *             @OA\Property(property="email", type="string", format="email", example="user@example.com")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Doğrulama e-postası gönderildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Doğrulama e-postası gönderildi")
     *         )
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="Kullanıcı bulunamadı",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function resendVerification(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'error' => [
                    'code' => 'USER_NOT_FOUND',
                    'message' => 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı'
                ]
            ], 404);
        }

        if ($user->email_verified_at) {
            return response()->json([
                'error' => [
                    'code' => 'ALREADY_VERIFIED',
                    'message' => 'E-posta adresi zaten doğrulanmış'
                ]
            ], 400);
        }

        // Yeni doğrulama token'ı oluştur
        $verification = EmailVerification::createForUser($user);

        // E-posta gönder
        $this->mailService->sendEmailVerification($user, $verification->token);

        return response()->json([
            'message' => 'Doğrulama e-postası gönderildi'
        ]);
    }

    /**
     * @OA\Post(
     *     path="/auth/forgot-password",
     *     tags={"Authentication"},
     *     summary="Şifre sıfırlama talebi",
     *     description="Kullanıcıya şifre sıfırlama e-postası gönderir",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email"},
     *             @OA\Property(property="email", type="string", format="email", example="user@example.com")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Şifre sıfırlama e-postası gönderildi",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Şifre sıfırlama e-postası gönderildi")
     *         )
     *     )
     * )
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $status = Password::sendResetLink($request->only('email'));

        return $status === Password::RESET_LINK_SENT
            ? response()->json(['message' => 'Şifre sıfırlama e-postası gönderildi'])
            : response()->json([
                'error' => [
                    'code' => 'RESET_LINK_FAILED',
                    'message' => 'Şifre sıfırlama e-postası gönderilemedi'
                ]
            ], 400);
    }

    /**
     * @OA\Post(
     *     path="/auth/reset-password",
     *     tags={"Authentication"},
     *     summary="Şifre sıfırlama",
     *     description="Token ile şifreyi sıfırlar",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"token","email","password","password_confirmation"},
     *             @OA\Property(property="token", type="string", example="abc123..."),
     *             @OA\Property(property="email", type="string", format="email", example="user@example.com"),
     *             @OA\Property(property="password", type="string", format="password", example="newpassword123"),
     *             @OA\Property(property="password_confirmation", type="string", format="password", example="newpassword123")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Şifre başarıyla sıfırlandı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Şifre başarıyla sıfırlandı")
     *         )
     *     ),
     *     @OA\Response(
     *         response=400,
     *         description="Geçersiz token veya validation hatası",
     *         @OA\JsonContent(
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required',
            'email' => 'required|email',
            'password' => 'required|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation hatası',
                    'details' => $validator->errors()
                ]
            ], 422);
        }

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user, $password) {
                $user->forceFill([
                    'password' => Hash::make($password)
                ])->save();

                // Audit log
                AuditLog::createLog(
                    userId: $user->id,
                    action: 'password_reset',
                    targetType: 'User',
                    targetId: $user->id,
                    meta: [
                        'email' => $user->email,
                        'reset_time' => now()->toISOString(),
                    ],
                    ipAddress: request()->ip(),
                    userAgent: request()->userAgent(),
                );
            }
        );

        return $status === Password::PASSWORD_RESET
            ? response()->json(['message' => 'Şifre başarıyla sıfırlandı'])
            : response()->json([
                'error' => [
                    'code' => 'RESET_FAILED',
                    'message' => 'Şifre sıfırlama başarısız'
                ]
            ], 400);
    }
    
    /**
     * @OA\Get(
     *     path="/auth/mail-status",
     *     tags={"Authentication"},
     *     summary="Mail sistem durumu",
     *     description="Mail sisteminin yapılandırma durumunu kontrol eder",
     *     @OA\Response(
     *         response=200,
     *         description="Mail sistem durumu",
     *         @OA\JsonContent(
     *             @OA\Property(property="configured", type="boolean"),
     *             @OA\Property(property="config", type="object"),
     *             @OA\Property(property="recommendations", type="array", @OA\Items(type="string"))
     *         )
     *     )
     * )
     */
    public function getMailStatus(): JsonResponse
    {
        $mailStatus = $this->mailService->testMailConfiguration();
        
        return response()->json([
            'message' => 'Mail sistem durumu',
            'status' => $mailStatus
        ]);
    }

    /**
     * @OA\Post(
     *     path="/auth/verify-email-code",
     *     tags={"Authentication"},
     *     summary="6 haneli kod ile e-posta doğrula",
     *     description="Kullanıcının e-posta adresini 6 haneli kod ile doğrular",
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"code"},
     *             @OA\Property(property="code", type="string", example="123456", description="6 haneli doğrulama kodu")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="E-posta başarıyla doğrulandı",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="E-posta adresiniz başarıyla doğrulandı"),
     *             @OA\Property(property="user", type="object")
     *         )
     *     ),
     *     @OA\Response(
     *         response=400,
     *         description="Geçersiz kod veya hata",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="error", type="object")
     *         )
     *     )
     * )
     */
    public function verifyEmailCode(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|size:6'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Doğrulama kodu geçersiz',
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        $code = $request->code;
        
        // Kodu bul
        $verification = EmailVerification::findByCode($code);
        
        if (!$verification) {
            return response()->json([
                'message' => 'Geçersiz veya süresi dolmuş doğrulama kodu',
                'error' => [
                    'code' => 'INVALID_CODE',
                    'message' => 'Lütfen geçerli bir 6 haneli kod girin'
                ]
            ], 400);
        }

        // Kodu doğrula
        if ($verification->verifyWithCode($code)) {
            // Audit log
            AuditLog::createLog(
                userId: $verification->user_id,
                action: 'verify_email',
                targetType: 'User',
                targetId: $verification->user_id,
                meta: [
                    'email' => $verification->user->email,
                    'verification_method' => '6_digit_code'
                ],
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return response()->json([
                'message' => 'E-posta adresiniz başarıyla doğrulandı',
                'user' => [
                    'id' => $verification->user->id,
                    'name' => $verification->user->name,
                    'email' => $verification->user->email,
                    'email_verified_at' => $verification->user->email_verified_at,
                    'role' => $verification->user->role
                ]
            ]);
        }

        return response()->json([
            'message' => 'Doğrulama kodu hatalı',
            'error' => [
                'code' => 'VERIFICATION_FAILED',
                'message' => 'Lütfen doğru kodu girin'
            ]
        ], 400);
    }
}