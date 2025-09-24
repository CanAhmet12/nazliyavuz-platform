<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\SharedFile;
use App\Models\User;
use App\Services\FileUploadService;

class FileSharingController extends Controller
{
    protected $fileUploadService;

    public function __construct(FileUploadService $fileUploadService)
    {
        $this->fileUploadService = $fileUploadService;
    }

    /**
     * Get shared files between users
     */
    public function getSharedFiles(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'other_user_id' => 'required|exists:users,id',
            'reservation_id' => 'sometimes|exists:reservations,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $otherUserId = $request->other_user_id;
            $reservationId = $request->reservation_id;

            $query = SharedFile::where(function ($q) use ($user, $otherUserId) {
                $q->where(function ($q2) use ($user, $otherUserId) {
                    $q2->where('uploaded_by_id', $user->id)->where('receiver_id', $otherUserId);
                })->orWhere(function ($q2) use ($user, $otherUserId) {
                    $q2->where('uploaded_by_id', $otherUserId)->where('receiver_id', $user->id);
                });
            });

            if ($reservationId) {
                $query->where('reservation_id', $reservationId);
            }

            $files = $query->with(['uploadedBy', 'receiver'])
                         ->orderBy('created_at', 'desc')
                         ->get();

            return response()->json([
                'success' => true,
                'files' => $files->map(function ($file) {
                    return [
                        'id' => $file->id,
                        'file_name' => $file->file_name,
                        'file_url' => $file->file_url,
                        'file_type' => $file->file_type,
                        'file_size' => $file->file_size,
                        'description' => $file->description,
                        'category' => $file->category,
                        'uploaded_by_name' => $file->uploadedBy->name,
                        'receiver_name' => $file->receiver->name,
                        'created_at' => $file->created_at->toISOString(),
                        'updated_at' => $file->updated_at->toISOString(),
                    ];
                }),
            ]);

        } catch (\Exception $e) {
            Log::error('Get shared files failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
                'other_user_id' => $request->other_user_id,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_FILES_ERROR',
                    'message' => 'Dosyalar alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Upload shared file
     */
    public function uploadSharedFile(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'file' => 'required|file|max:102400', // Max 100MB
            'receiver_id' => 'required|exists:users,id',
            'description' => 'sometimes|string|max:500',
            'category' => 'required|string|in:document,homework,notes,resource,other',
            'reservation_id' => 'sometimes|exists:reservations,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => $validator->errors()
                ]
            ], 400);
        }

        try {
            $user = Auth::user();
            $file = $request->file('file');
            $receiverId = $request->receiver_id;

            // Check if user can share with this receiver
            if (!$this->canShareWithUser($user->id, $receiverId)) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu kullanıcıyla dosya paylaşamazsınız'
                    ]
                ], 403);
            }

            // Upload file
            $uploadResult = $this->fileUploadService->uploadDocument(
                $file,
                $user->id,
                'shared_files'
            );

            if (!$uploadResult['success']) {
                return response()->json([
                    'error' => [
                        'code' => 'UPLOAD_FAILED',
                        'message' => $uploadResult['error']
                    ]
                ], 500);
            }

            // Create shared file record
            $sharedFile = SharedFile::create([
                'uploaded_by_id' => $user->id,
                'receiver_id' => $receiverId,
                'reservation_id' => $request->reservation_id,
                'file_name' => $file->getClientOriginalName(),
                'file_path' => $uploadResult['path'],
                'file_url' => $uploadResult['url'],
                'file_type' => $file->getClientMimeType(),
                'file_size' => $file->getSize(),
                'description' => $request->description ?? '',
                'category' => $request->category,
            ]);

            // Send notification to receiver
            $this->sendFileSharedNotification($sharedFile);

            Log::info('File shared successfully', [
                'file_id' => $sharedFile->id,
                'uploaded_by_id' => $user->id,
                'receiver_id' => $receiverId,
                'filename' => $file->getClientOriginalName(),
                'category' => $request->category,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Dosya başarıyla paylaşıldı',
                'file' => [
                    'id' => $sharedFile->id,
                    'file_name' => $sharedFile->file_name,
                    'file_url' => $sharedFile->file_url,
                    'file_type' => $sharedFile->file_type,
                    'file_size' => $sharedFile->file_size,
                    'category' => $sharedFile->category,
                    'created_at' => $sharedFile->created_at->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Upload shared file failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
                'receiver_id' => $request->receiver_id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'UPLOAD_FILE_ERROR',
                    'message' => 'Dosya yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Download shared file
     */
    public function downloadSharedFile(SharedFile $file): JsonResponse
    {
        try {
            $user = Auth::user();

            // Ensure only involved users can download
            if ($file->uploaded_by_id !== $user->id && $file->receiver_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dosyayı indirme yetkiniz yok'
                    ]
                ], 403);
            }

            // Generate temporary download URL
            $downloadUrl = $this->fileUploadService->getTemporaryUrl($file->file_path, 5); // 5 minutes

            Log::info('File download URL generated', [
                'file_id' => $file->id,
                'user_id' => $user->id,
                'filename' => $file->file_name,
            ]);

            return response()->json([
                'success' => true,
                'download_url' => $downloadUrl,
                'file_name' => $file->file_name,
                'message' => 'Dosya indirme bağlantısı oluşturuldu'
            ]);

        } catch (\Exception $e) {
            Log::error('Download shared file failed', [
                'error' => $e->getMessage(),
                'file_id' => $file->id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'DOWNLOAD_FILE_ERROR',
                    'message' => 'Dosya indirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Delete shared file
     */
    public function deleteSharedFile(SharedFile $file): JsonResponse
    {
        try {
            $user = Auth::user();

            // Only the uploader or receiver can delete
            if ($file->uploaded_by_id !== $user->id && $file->receiver_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu dosyayı silme yetkiniz yok'
                    ]
                ], 403);
            }

            // Delete file from storage
            $this->fileUploadService->deleteFile($file->file_path);

            // Delete database record
            $file->delete();

            Log::info('File deleted successfully', [
                'file_id' => $file->id,
                'user_id' => $user->id,
                'filename' => $file->file_name,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Dosya başarıyla silindi'
            ]);

        } catch (\Exception $e) {
            Log::error('Delete shared file failed', [
                'error' => $e->getMessage(),
                'file_id' => $file->id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'DELETE_FILE_ERROR',
                    'message' => 'Dosya silinirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Check if user can share with another user
     */
    private function canShareWithUser(int $uploaderId, int $receiverId): bool
    {
        // Users can share files if they have:
        // 1. Active reservations together
        // 2. Previous conversations
        // 3. Any relationship in the system

        $uploader = User::find($uploaderId);
        $receiver = User::find($receiverId);

        if (!$uploader || !$receiver) {
            return false;
        }

        // Check for active reservations
        $hasReservation = \DB::table('reservations')
            ->where(function ($query) use ($uploaderId, $receiverId) {
                $query->where('teacher_id', $uploaderId)->where('student_id', $receiverId)
                      ->orWhere('teacher_id', $receiverId)->where('student_id', $uploaderId);
            })
            ->whereIn('status', ['accepted', 'completed'])
            ->exists();

        if ($hasReservation) {
            return true;
        }

        // Check for conversations
        $hasConversation = \DB::table('chats')
            ->where(function ($query) use ($uploaderId, $receiverId) {
                $query->where('user1_id', $uploaderId)->where('user2_id', $receiverId)
                      ->orWhere('user1_id', $receiverId)->where('user2_id', $uploaderId);
            })
            ->exists();

        return $hasConversation;
    }

    /**
     * Send file shared notification
     */
    private function sendFileSharedNotification(SharedFile $file): void
    {
        try {
            $file->receiver->notifications()->create([
                'type' => 'file_shared',
                'title' => 'Yeni Dosya Paylaşıldı',
                'message' => "{$file->uploadedBy->name} size yeni bir dosya paylaştı: {$file->file_name}",
                'data' => [
                    'file_id' => $file->id,
                    'uploader_name' => $file->uploadedBy->name,
                    'file_name' => $file->file_name,
                    'category' => $file->category,
                ],
            ]);

            Log::info('File shared notification sent', [
                'file_id' => $file->id,
                'uploader_id' => $file->uploaded_by_id,
                'receiver_id' => $file->receiver_id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send file shared notification', [
                'error' => $e->getMessage(),
                'file_id' => $file->id,
            ]);
        }
    }
}