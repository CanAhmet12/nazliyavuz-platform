class Lesson {
  final int id;
  final int reservationId;
  final int teacherId;
  final int studentId;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String status;
  final String? notes;
  final int? rating;
  final String? feedback;
  final DateTime? ratedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related objects
  final Map<String, dynamic>? student;
  final Map<String, dynamic>? teacher;
  final Map<String, dynamic>? reservation;

  Lesson({
    required this.id,
    required this.reservationId,
    required this.teacherId,
    required this.studentId,
    required this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.durationMinutes,
    required this.status,
    this.notes,
    this.rating,
    this.feedback,
    this.ratedAt,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.teacher,
    this.reservation,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      reservationId: json['reservation_id'],
      teacherId: json['teacher_id'],
      studentId: json['student_id'],
      scheduledAt: DateTime.parse(json['scheduled_at']),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationMinutes: json['duration_minutes'],
      status: json['status'],
      notes: json['notes'],
      rating: json['rating'],
      feedback: json['feedback'],
      ratedAt: json['rated_at'] != null ? DateTime.parse(json['rated_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      student: json['student'],
      teacher: json['teacher'],
      reservation: json['reservation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reservation_id': reservationId,
      'teacher_id': teacherId,
      'student_id': studentId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'status': status,
      'notes': notes,
      'rating': rating,
      'feedback': feedback,
      'rated_at': ratedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'student': student,
      'teacher': teacher,
      'reservation': reservation,
    };
  }

  // Helper methods
  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRated => rating != null;
  
  String get statusText {
    switch (status) {
      case 'scheduled':
        return 'Planlandı';
      case 'in_progress':
        return 'Devam Ediyor';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return 'Bilinmiyor';
    }
  }

  String get studentName => student?['name'] ?? 'Bilinmiyor';
  String get teacherName => teacher?['name'] ?? 'Bilinmiyor';
  String get subject => reservation?['subject'] ?? 'Bilinmiyor';
}
