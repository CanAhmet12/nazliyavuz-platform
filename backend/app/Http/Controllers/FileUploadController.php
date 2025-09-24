<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Intervention\Image\Facades\Image;
use App\Services\FileUploadService;

class FileUploadController extends Controller
{
    protected FileUploadService $fileUploadService;

    public function __construct(FileUploadService $fileUploadService)
    {
        $this->fileUploadService = $fileUploadService;
    }
    public function uploadProfilePhoto(Request $request)
    {
        $request->validate([
            'photo' => 'required|image|mimes:jpeg,png,jpg,gif,webp|max:5120', // 5MB
        ]);

        try {
            $user = Auth::user();
            
            // Eski fotoğrafı sil
            if ($user->profile_photo_url) {
                $this->fileUploadService->deleteFile($this->extractPathFromUrl($user->profile_photo_url));
            }

            // Yeni fotoğrafı S3'e yükle
            $result = $this->fileUploadService->uploadProfilePhoto($request->file('photo'), $user->id);

            if (!$result['success']) {
                return response()->json([
                    'error' => [
                        'code' => 'UPLOAD_FAILED',
                        'message' => $result['error']
                    ]
                ], 500);
            }

            // Kullanıcı profilini güncelle
            $user->update(['profile_photo_url' => $result['url']]);

            return response()->json([
                'success' => true,
                'message' => 'Profil fotoğrafı başarıyla yüklendi',
                'photo_url' => $result['url']
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'UPLOAD_ERROR',
                    'message' => 'Fotoğraf yüklenirken bir hata oluştu: ' . $e->getMessage()
                ]
            ], 500);
        }
    }

    public function deleteProfilePhoto()
    {
        try {
            $user = Auth::user();

            if ($user->profile_photo_url) {
                // S3'ten dosyayı sil
                $this->fileUploadService->deleteFile($this->extractPathFromUrl($user->profile_photo_url));
                
                // Kullanıcı profilini güncelle
                $user->update(['profile_photo_url' => null]);

                return response()->json([
                    'success' => true,
                    'message' => 'Profil fotoğrafı başarıyla silindi'
                ]);
            }

            return response()->json([
                'error' => [
                    'code' => 'NOT_FOUND',
                    'message' => 'Silinecek bir profil fotoğrafı bulunamadı'
                ]
            ], 404);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'DELETE_ERROR',
                    'message' => 'Fotoğraf silinirken bir hata oluştu: ' . $e->getMessage()
                ]
            ], 500);
        }
    }

    /**
     * Upload document (certificates, diplomas, etc.)
     */
    public function uploadDocument(Request $request)
    {
        $request->validate([
            'document' => 'required|file|mimes:pdf,doc,docx,jpg,jpeg,png|max:10240', // 10MB
            'type' => 'required|string|in:certificate,diploma,portfolio,other'
        ]);

        try {
            $user = Auth::user();
            
            $result = $this->fileUploadService->uploadDocument(
                $request->file('document'),
                $user->id,
                $request->type
            );

            if (!$result['success']) {
                return response()->json([
                    'error' => [
                        'code' => 'UPLOAD_FAILED',
                        'message' => $result['error']
                    ]
                ], 500);
            }

            return response()->json([
                'success' => true,
                'message' => 'Doküman başarıyla yüklendi',
                'document_url' => $result['url'],
                'filename' => $result['filename']
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'UPLOAD_ERROR',
                    'message' => 'Doküman yüklenirken bir hata oluştu: ' . $e->getMessage()
                ]
            ], 500);
        }
    }

    /**
     * Generate presigned URL for direct upload
     */
    public function generatePresignedUrl(Request $request)
    {
        $request->validate([
            'filename' => 'required|string|max:255',
            'type' => 'required|string|in:profile-photo,document',
            'expiration_minutes' => 'sometimes|integer|min:1|max:1440' // Max 24 hours
        ]);

        try {
            $user = Auth::user();
            $expirationMinutes = $request->expiration_minutes ?? 60;
            
            $filename = $request->type . '_' . $user->id . '_' . time() . '_' . $request->filename;
            $path = $request->type . '/' . $filename;

            $result = $this->fileUploadService->generatePresignedUrl($filename, $request->type, $user->id);

            if (!$result['success']) {
                return response()->json([
                    'error' => [
                        'code' => 'PRESIGNED_URL_FAILED',
                        'message' => $result['error']
                    ]
                ], 500);
            }

            return response()->json([
                'success' => true,
                'presigned_url' => $result['presigned_url'],
                'path' => $path,
                'expires_in' => $result['expires_in']
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'error' => [
                    'code' => 'PRESIGNED_URL_ERROR',
                    'message' => 'Presigned URL oluşturulurken bir hata oluştu: ' . $e->getMessage()
                ]
            ], 500);
        }
    }

    /**
     * Extract path from S3 URL
     */
    private function extractPathFromUrl(string $url): string
    {
        $parsedUrl = parse_url($url);
        return ltrim($parsedUrl['path'] ?? '', '/');
    }
}
