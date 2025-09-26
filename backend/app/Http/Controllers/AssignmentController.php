<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use App\Models\Assignment;
use App\Models\User;
use App\Services\FileUploadService;

class AssignmentController extends Controller
{
    protected $fileUploadService;

    public function __construct(FileUploadService $fileUploadService)
    {
        $this->fileUploadService = $fileUploadService;
    }

    /**
     * Get teacher's all assignments
     */
    public function getTeacherAssignments(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $assignments = Assignment::where('teacher_id', $user->id)
                                   ->with(['student'])
                                   ->orderBy('created_at', 'desc')
                                   ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments->map(function ($assignment) {
                    return [
                        'id' => $assignment->id,
                        'title' => $assignment->title,
                        'description' => $assignment->description,
                        'due_date' => $assignment->due_date->toISOString(),
                        'difficulty' => $assignment->difficulty,
                        'status' => $assignment->status,
                        'grade' => $assignment->grade,
                        'feedback' => $assignment->feedback,
                        'submission_notes' => $assignment->submission_notes,
                        'submission_file_name' => $assignment->submission_file_name,
                        'submitted_at' => $assignment->submitted_at?->toISOString(),
                        'graded_at' => $assignment->graded_at?->toISOString(),
                        'student_name' => $assignment->student->name,
                        'created_at' => $assignment->created_at->toISOString(),
                        'updated_at' => $assignment->updated_at->toISOString(),
                    ];
                }),
            ]);

        } catch (\Exception $e) {
            Log::error('Get teacher assignments failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_TEACHER_ASSIGNMENTS_ERROR',
                    'message' => 'Ödevler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get student's all assignments
     */
    public function getStudentAssignments(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();

            if ($user->role !== 'student') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğrenciler bu endpoint\'i kullanabilir'
                    ]
                ], 403);
            }

            $assignments = Assignment::where('student_id', $user->id)
                                   ->with(['teacher'])
                                   ->orderBy('created_at', 'desc')
                                   ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments->map(function ($assignment) {
                    return [
                        'id' => $assignment->id,
                        'title' => $assignment->title,
                        'description' => $assignment->description,
                        'due_date' => $assignment->due_date->toISOString(),
                        'difficulty' => $assignment->difficulty,
                        'status' => $assignment->status,
                        'grade' => $assignment->grade,
                        'feedback' => $assignment->feedback,
                        'submission_notes' => $assignment->submission_notes,
                        'submission_file_name' => $assignment->submission_file_name,
                        'submitted_at' => $assignment->submitted_at?->toISOString(),
                        'graded_at' => $assignment->graded_at?->toISOString(),
                        'teacher_name' => $assignment->teacher->name,
                        'created_at' => $assignment->created_at->toISOString(),
                        'updated_at' => $assignment->updated_at->toISOString(),
                    ];
                }),
            ]);

        } catch (\Exception $e) {
            Log::error('Get student assignments failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_STUDENT_ASSIGNMENTS_ERROR',
                    'message' => 'Ödevler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get assignments for authenticated user
     */
    public function index(Request $request): JsonResponse
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

            // Get assignments given to current user
            $assignmentsQuery = Assignment::where(function ($query) use ($user, $otherUserId) {
                $query->where(function ($q) use ($user, $otherUserId) {
                    // Assignments given by current user to other user
                    $q->where('teacher_id', $user->id)
                      ->where('student_id', $otherUserId);
                })->orWhere(function ($q) use ($user, $otherUserId) {
                    // Assignments given by other user to current user
                    $q->where('teacher_id', $otherUserId)
                      ->where('student_id', $user->id);
                });
            });

            if ($reservationId) {
                $assignmentsQuery->where('reservation_id', $reservationId);
            }

            $assignments = $assignmentsQuery->with(['teacher', 'student'])
                                          ->orderBy('created_at', 'desc')
                                          ->get();

            // Get user's own assignments (given by current user)
            $myAssignmentsQuery = Assignment::where('teacher_id', $user->id);

            if ($reservationId) {
                $myAssignmentsQuery->where('reservation_id', $reservationId);
            }

            $myAssignments = $myAssignmentsQuery->with(['student'])
                                              ->orderBy('created_at', 'desc')
                                              ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments->map(function ($assignment) {
                    return [
                        'id' => $assignment->id,
                        'title' => $assignment->title,
                        'description' => $assignment->description,
                        'due_date' => $assignment->due_date->toISOString(),
                        'difficulty' => $assignment->difficulty,
                        'status' => $assignment->status,
                        'grade' => $assignment->grade,
                        'feedback' => $assignment->feedback,
                        'submission_notes' => $assignment->submission_notes,
                        'submission_file_name' => $assignment->submission_file_name,
                        'submitted_at' => $assignment->submitted_at?->toISOString(),
                        'graded_at' => $assignment->graded_at?->toISOString(),
                        'teacher_name' => $assignment->teacher->name,
                        'student_name' => $assignment->student->name,
                        'created_at' => $assignment->created_at->toISOString(),
                        'updated_at' => $assignment->updated_at->toISOString(),
                    ];
                }),
                'my_assignments' => $myAssignments->map(function ($assignment) {
                    return [
                        'id' => $assignment->id,
                        'title' => $assignment->title,
                        'description' => $assignment->description,
                        'due_date' => $assignment->due_date->toISOString(),
                        'difficulty' => $assignment->difficulty,
                        'status' => $assignment->status,
                        'grade' => $assignment->grade,
                        'feedback' => $assignment->feedback,
                        'submission_notes' => $assignment->submission_notes,
                        'submission_file_name' => $assignment->submission_file_name,
                        'submitted_at' => $assignment->submitted_at?->toISOString(),
                        'graded_at' => $assignment->graded_at?->toISOString(),
                        'student_name' => $assignment->student->name,
                        'created_at' => $assignment->created_at->toISOString(),
                        'updated_at' => $assignment->updated_at->toISOString(),
                    ];
                }),
            ]);

        } catch (\Exception $e) {
            Log::error('Get assignments failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
                'other_user_id' => $request->other_user_id,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GET_ASSIGNMENTS_ERROR',
                    'message' => 'Ödevler alınırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create new assignment
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'receiver_id' => 'required|exists:users,id',
            'title' => 'required|string|max:255',
            'description' => 'sometimes|string|max:1000',
            'due_date' => 'required|date|after:now',
            'difficulty' => 'sometimes|string|in:easy,medium,hard',
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
            $receiverId = $request->receiver_id;

            // Check if user can assign to this receiver
            if (!$this->canAssignToUser($user->id, $receiverId)) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu kullanıcıya ödev veremezsiniz'
                    ]
                ], 403);
            }

            // Create assignment
            $assignment = Assignment::create([
                'teacher_id' => $user->id,
                'student_id' => $receiverId,
                'reservation_id' => $request->reservation_id,
                'title' => $request->title,
                'description' => $request->description ?? '',
                'due_date' => $request->due_date,
                'difficulty' => $request->difficulty ?? 'medium',
                'status' => 'pending',
            ]);

            // Send notification to student
            $this->sendAssignmentNotification($assignment);

            Log::info('Assignment created successfully', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $user->id,
                'student_id' => $receiverId,
                'title' => $request->title,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla oluşturuldu',
                'assignment' => [
                    'id' => $assignment->id,
                    'title' => $assignment->title,
                    'description' => $assignment->description,
                    'due_date' => $assignment->due_date->toISOString(),
                    'difficulty' => $assignment->difficulty,
                    'status' => $assignment->status,
                    'created_at' => $assignment->created_at->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Create assignment failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id ?? null,
                'receiver_id' => $request->receiver_id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'CREATE_ASSIGNMENT_ERROR',
                    'message' => 'Ödev oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Submit assignment
     */
    public function submit(Request $request, Assignment $assignment): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'file' => 'required|file|max:102400', // Max 100MB
            'notes' => 'sometimes|string|max:1000',
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

            // Check if user is the student
            if ($assignment->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi sadece öğrenci teslim edebilir'
                    ]
                ], 403);
            }

            // Check if assignment is still pending
            if ($assignment->status !== 'pending') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu ödev zaten teslim edilmiş'
                    ]
                ], 400);
            }

            $file = $request->file('file');

            // Upload file
            $uploadResult = $this->fileUploadService->uploadDocument(
                $file,
                $user->id,
                'assignment_submission'
            );

            if (!$uploadResult['success']) {
                return response()->json([
                    'error' => [
                        'code' => 'UPLOAD_FAILED',
                        'message' => $uploadResult['error']
                    ]
                ], 500);
            }

            // Update assignment
            $assignment->update([
                'status' => 'submitted',
                'submission_notes' => $request->notes,
                'submission_file_path' => $uploadResult['path'],
                'submission_file_name' => $file->getClientOriginalName(),
                'submitted_at' => now(),
            ]);

            // Send notification to teacher
            $this->sendSubmissionNotification($assignment);

            Log::info('Assignment submitted successfully', [
                'assignment_id' => $assignment->id,
                'student_id' => $user->id,
                'filename' => $file->getClientOriginalName(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla teslim edildi',
                'assignment' => [
                    'id' => $assignment->id,
                    'status' => $assignment->status,
                    'submission_file_name' => $assignment->submission_file_name,
                    'submitted_at' => $assignment->submitted_at->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Submit assignment failed', [
                'error' => $e->getMessage(),
                'assignment_id' => $assignment->id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'SUBMIT_ASSIGNMENT_ERROR',
                    'message' => 'Ödev teslim edilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Grade assignment
     */
    public function grade(Request $request, Assignment $assignment): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'grade' => 'required|string|in:A+,A,B+,B,C+,C,D+,D,F',
            'feedback' => 'sometimes|string|max:1000',
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

            // Check if user is the teacher
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi sadece öğretmen değerlendirebilir'
                    ]
                ], 403);
            }

            // Check if assignment is submitted
            if ($assignment->status !== 'submitted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Bu ödev henüz teslim edilmemiş'
                    ]
                ], 400);
            }

            // Update assignment
            $assignment->update([
                'status' => 'graded',
                'grade' => $request->grade,
                'feedback' => $request->feedback,
                'graded_at' => now(),
            ]);

            // Send notification to student
            $this->sendGradeNotification($assignment);

            Log::info('Assignment graded successfully', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $user->id,
                'grade' => $request->grade,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla değerlendirildi',
                'assignment' => [
                    'id' => $assignment->id,
                    'status' => $assignment->status,
                    'grade' => $assignment->grade,
                    'feedback' => $assignment->feedback,
                    'graded_at' => $assignment->graded_at->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Grade assignment failed', [
                'error' => $e->getMessage(),
                'assignment_id' => $assignment->id,
                'user_id' => $user->id ?? null,
            ]);

            return response()->json([
                'error' => [
                    'code' => 'GRADE_ASSIGNMENT_ERROR',
                    'message' => 'Ödev değerlendirilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Check if user can assign to another user
     */
    private function canAssignToUser(int $teacherId, int $studentId): bool
    {
        // Users can assign if they have:
        // 1. Active reservations together
        // 2. Previous conversations
        // 3. Teacher-student relationship

        $teacher = User::find($teacherId);
        $student = User::find($studentId);

        if (!$teacher || !$student || $teacher->role !== 'teacher' || $student->role !== 'student') {
            return false;
        }

        // Check for active reservations
        $hasReservation = \DB::table('reservations')
            ->where('teacher_id', $teacherId)
            ->where('student_id', $studentId)
            ->whereIn('status', ['accepted', 'completed'])
            ->exists();

        if ($hasReservation) {
            return true;
        }

        // Check for conversations
        $hasConversation = \DB::table('chats')
            ->where(function ($query) use ($teacherId, $studentId) {
                $query->where('user1_id', $teacherId)->where('user2_id', $studentId)
                      ->orWhere('user1_id', $studentId)->where('user2_id', $teacherId);
            })
            ->exists();

        return $hasConversation;
    }

    /**
     * Send assignment notification
     */
    private function sendAssignmentNotification(Assignment $assignment): void
    {
        try {
            $assignment->student->notifications()->create([
                'type' => 'assignment_created',
                'title' => 'Yeni Ödev',
                'message' => "{$assignment->teacher->name} size yeni bir ödev verdi: {$assignment->title}",
                'data' => [
                    'assignment_id' => $assignment->id,
                    'teacher_name' => $assignment->teacher->name,
                    'title' => $assignment->title,
                    'due_date' => $assignment->due_date->toISOString(),
                ],
            ]);

            Log::info('Assignment notification sent', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $assignment->teacher_id,
                'student_id' => $assignment->student_id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send assignment notification', [
                'error' => $e->getMessage(),
                'assignment_id' => $assignment->id,
            ]);
        }
    }

    /**
     * Send submission notification
     */
    private function sendSubmissionNotification(Assignment $assignment): void
    {
        try {
            $assignment->teacher->notifications()->create([
                'type' => 'assignment_submitted',
                'title' => 'Ödev Teslim Edildi',
                'message' => "{$assignment->student->name} ödevi teslim etti: {$assignment->title}",
                'data' => [
                    'assignment_id' => $assignment->id,
                    'student_name' => $assignment->student->name,
                    'title' => $assignment->title,
                ],
            ]);

            Log::info('Assignment submission notification sent', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $assignment->teacher_id,
                'student_id' => $assignment->student_id,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send assignment submission notification', [
                'error' => $e->getMessage(),
                'assignment_id' => $assignment->id,
            ]);
        }
    }

    /**
     * Send grade notification
     */
    private function sendGradeNotification(Assignment $assignment): void
    {
        try {
            $assignment->student->notifications()->create([
                'type' => 'assignment_graded',
                'title' => 'Ödev Değerlendirildi',
                'message' => "{$assignment->teacher->name} ödevinizi değerlendirdi: {$assignment->title} - Not: {$assignment->grade}",
                'data' => [
                    'assignment_id' => $assignment->id,
                    'teacher_name' => $assignment->teacher->name,
                    'title' => $assignment->title,
                    'grade' => $assignment->grade,
                ],
            ]);

            Log::info('Assignment grade notification sent', [
                'assignment_id' => $assignment->id,
                'teacher_id' => $assignment->teacher_id,
                'student_id' => $assignment->student_id,
                'grade' => $assignment->grade,
            ]);

        } catch (\Exception $e) {
            Log::error('Failed to send assignment grade notification', [
                'error' => $e->getMessage(),
                'assignment_id' => $assignment->id,
            ]);
        }
    }
}
