import 'package:equatable/equatable.dart';

class Assignment extends Equatable {
  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String difficulty;
  final String status;
  final String? grade;
  final String? feedback;
  final String? submissionNotes;
  final String? submissionFileName;
  final DateTime? submittedAt;
  final DateTime? gradedAt;
  final String teacherName;
  final String studentName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.difficulty,
    required this.status,
    this.grade,
    this.feedback,
    this.submissionNotes,
    this.submissionFileName,
    this.submittedAt,
    this.gradedAt,
    required this.teacherName,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      dueDate: DateTime.parse(json['due_date']),
      difficulty: json['difficulty'],
      status: json['status'],
      grade: json['grade'],
      feedback: json['feedback'],
      submissionNotes: json['submission_notes'],
      submissionFileName: json['submission_file_name'],
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at']) : null,
      gradedAt: json['graded_at'] != null ? DateTime.parse(json['graded_at']) : null,
      teacherName: json['teacher_name'],
      studentName: json['student_name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'difficulty': difficulty,
      'status': status,
      'grade': grade,
      'feedback': feedback,
      'submission_notes': submissionNotes,
      'submission_file_name': submissionFileName,
      'submitted_at': submittedAt?.toIso8601String(),
      'graded_at': gradedAt?.toIso8601String(),
      'teacher_name': teacherName,
      'student_name': studentName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get difficultyInTurkish {
    const difficulties = {
      'easy': 'Kolay',
      'medium': 'Orta',
      'hard': 'Zor',
    };
    return difficulties[difficulty] ?? difficulty;
  }

  String get statusInTurkish {
    const statuses = {
      'pending': 'Bekliyor',
      'submitted': 'Teslim Edildi',
      'graded': 'Değerlendirildi',
      'overdue': 'Gecikti',
    };
    return statuses[status] ?? status;
  }

  String get statusText => statusInTurkish;

  String get formattedDueDate {
    return '${dueDate.day}/${dueDate.month}/${dueDate.year} ${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';
  }

  bool get isOverdue {
    return status == 'pending' && dueDate.isBefore(DateTime.now());
  }

  bool get isSubmitted {
    return status == 'submitted' || status == 'graded';
  }

  bool get isGraded {
    return status == 'graded' && grade != null;
  }

  String get timeUntilDue {
    if (isSubmitted || isGraded) {
      return '';
    }

    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'Gecikti';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat kaldı';
    } else {
      return '${difference.inMinutes} dakika kaldı';
    }
  }

  String get gradeColor {
    if (grade == null) return 'grey';
    
    switch (grade) {
      case 'A+':
      case 'A':
        return 'green';
      case 'B+':
      case 'B':
        return 'lightgreen';
      case 'C+':
      case 'C':
        return 'orange';
      case 'D+':
      case 'D':
        return 'red';
      case 'F':
        return 'darkred';
      default:
        return 'grey';
    }
  }

  String get timeSinceCreated {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  String get timeSinceSubmitted {
    if (submittedAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(submittedAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  String get timeSinceGraded {
    if (gradedAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(gradedAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        dueDate,
        difficulty,
        status,
        grade,
        feedback,
        submissionNotes,
        submissionFileName,
        submittedAt,
        gradedAt,
        teacherName,
        studentName,
        createdAt,
        updatedAt,
      ];
}