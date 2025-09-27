<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use App\Models\Assignment;
use App\Models\User;
use App\Models\Reservation;
use Carbon\Carbon;

class AssignmentController extends Controller
{
    /**
     * Get assignments for authenticated user
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $user = Auth::user();
            
            $query = Assignment::query();
            
            // Filter by user role
            if ($user->role === 'teacher') {
                $query->where('teacher_id', $user->id);
            } else {
                $query->where('student_id', $user->id);
            }
            
            // Apply status filter
            if ($request->has('status') && $request->status) {
                $query->where('status', $request->status);
            }
            
            // Apply date range filter
            if ($request->has('from_date') && $request->from_date) {
                $query->whereDate('due_date', '>=', $request->from_date);
            }
            
            if ($request->has('to_date') && $request->to_date) {
                $query->whereDate('due_date', '<=', $request->to_date);
            }
            
            // Load relationships
            $query->with([
                'teacher:id,name,email',
                'student:id,name,email',
                'reservation'
            ]);
            
            // Order by due date
            $query->orderBy('due_date', 'asc');
            
            $assignments = $query->paginate($request->get('per_page', 20));
            
            // Format assignments data
            $formattedAssignments = $assignments->getCollection()->map(function ($assignment) {
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
                    'teacher_name' => $assignment->teacher?->name,
                    'student_name' => $assignment->student?->name,
                    'created_at' => $assignment->created_at->toISOString(),
                    'updated_at' => $assignment->updated_at->toISOString(),
                ];
            });
            
            return response()->json([
                'success' => true,
                'assignments' => $formattedAssignments,
                'pagination' => [
                    'current_page' => $assignments->currentPage(),
                    'last_page' => $assignments->lastPage(),
                    'per_page' => $assignments->perPage(),
                    'total' => $assignments->total(),
                ]
            ]);
            
        } catch (\Exception $e) {
            Log::error('Error getting assignments: ' . $e->getMessage());
            
            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENTS_FETCH_ERROR',
                    'message' => 'Ödevler yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Create new assignment (teacher only)
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'student_id' => 'required|exists:users,id',
                'title' => 'required|string|max:255',
                'description' => 'required|string',
                'due_date' => 'required|date|after:now',
                'difficulty' => 'required|in:easy,medium,hard',
                'reservation_id' => 'nullable|exists:reservations,id',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check if user is a teacher
            if ($user->role !== 'teacher') {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Sadece öğretmenler ödev oluşturabilir'
                    ]
                ], 403);
            }

            // Check if student exists and is a student
            $student = User::where('id', $request->student_id)
                ->where('role', 'student')
                ->first();

            if (!$student) {
                return response()->json([
                    'error' => [
                        'code' => 'STUDENT_NOT_FOUND',
                        'message' => 'Öğrenci bulunamadı'
                    ]
                ], 404);
            }

            // Create assignment
            $assignment = Assignment::create([
                'teacher_id' => $user->id,
                'student_id' => $request->student_id,
                'reservation_id' => $request->reservation_id,
                'title' => $request->title,
                'description' => $request->description,
                'due_date' => $request->due_date,
                'difficulty' => $request->difficulty,
                'status' => 'pending',
            ]);

            // Load relationships for response
            $assignment->load(['teacher:id,name', 'student:id,name']);

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
                    'teacher_name' => $assignment->teacher?->name,
                    'student_name' => $assignment->student?->name,
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('Error creating assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_CREATE_ERROR',
                    'message' => 'Ödev oluşturulurken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Submit assignment (student only)
     */
    public function submit(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'submission_notes' => 'nullable|string|max:1000',
                'file' => 'nullable|file|max:10240', // 10MB max
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check if user is the student for this assignment
            if ($assignment->student_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi teslim etme yetkiniz yok'
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

            $submissionData = [
                'status' => 'submitted',
                'submission_notes' => $request->submission_notes,
                'submitted_at' => now(),
            ];

            // Handle file upload
            if ($request->hasFile('file')) {
                $file = $request->file('file');
                $fileName = time() . '_' . $file->getClientOriginalName();
                $filePath = $file->storeAs('assignments', $fileName, 'public');
                
                $submissionData['submission_file_path'] = $filePath;
                $submissionData['submission_file_name'] = $file->getClientOriginalName();
            }

            $assignment->update($submissionData);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla teslim edildi'
            ]);

        } catch (\Exception $e) {
            Log::error('Error submitting assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_SUBMIT_ERROR',
                    'message' => 'Ödev teslim edilirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Grade assignment (teacher only)
     */
    public function grade(Request $request, Assignment $assignment): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'grade' => 'required|string|max:10',
                'feedback' => 'nullable|string|max:1000',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'error' => [
                        'code' => 'VALIDATION_ERROR',
                        'message' => 'Geçersiz veri',
                        'details' => $validator->errors()
                    ]
                ], 422);
            }

            $user = Auth::user();

            // Check if user is the teacher for this assignment
            if ($assignment->teacher_id !== $user->id) {
                return response()->json([
                    'error' => [
                        'code' => 'FORBIDDEN',
                        'message' => 'Bu ödevi notlandırma yetkiniz yok'
                    ]
                ], 403);
            }

            // Check if assignment is submitted
            if ($assignment->status !== 'submitted') {
                return response()->json([
                    'error' => [
                        'code' => 'INVALID_STATUS',
                        'message' => 'Sadece teslim edilmiş ödevler notlandırılabilir'
                    ]
                ], 400);
            }

            $assignment->update([
                'status' => 'graded',
                'grade' => $request->grade,
                'feedback' => $request->feedback,
                'graded_at' => now(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Ödev başarıyla notlandırıldı'
            ]);

        } catch (\Exception $e) {
            Log::error('Error grading assignment: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'ASSIGNMENT_GRADE_ERROR',
                    'message' => 'Ödev notlandırılırken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get student assignments (for teachers)
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
                ->with(['teacher:id,name', 'reservation'])
                ->orderBy('due_date', 'asc')
                ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting student assignments: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'STUDENT_ASSIGNMENTS_ERROR',
                    'message' => 'Öğrenci ödevleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }

    /**
     * Get teacher assignments
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
                ->with(['student:id,name', 'reservation'])
                ->orderBy('due_date', 'asc')
                ->get();

            return response()->json([
                'success' => true,
                'assignments' => $assignments
            ]);

        } catch (\Exception $e) {
            Log::error('Error getting teacher assignments: ' . $e->getMessage());

            return response()->json([
                'error' => [
                    'code' => 'TEACHER_ASSIGNMENTS_ERROR',
                    'message' => 'Öğretmen ödevleri yüklenirken bir hata oluştu'
                ]
            ], 500);
        }
    }
}