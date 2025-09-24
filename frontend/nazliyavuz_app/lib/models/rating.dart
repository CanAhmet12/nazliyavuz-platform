import 'package:equatable/equatable.dart';
import 'user.dart';
import 'teacher.dart';
import 'reservation.dart';

class Rating extends Equatable {
  final int id;
  final int studentId;
  final int teacherId;
  final int reservationId;
  final int rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? student;
  final Teacher? teacher;
  final Reservation? reservation;

  const Rating({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.reservationId,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.teacher,
    this.reservation,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'],
      studentId: json['student_id'],
      teacherId: json['teacher_id'],
      reservationId: json['reservation_id'],
      rating: json['rating'],
      review: json['review'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      student: json['student'] != null ? User.fromJson(json['student']) : null,
      teacher: json['teacher'] != null ? Teacher.fromJson(json['teacher']) : null,
      reservation: json['reservation'] != null ? Reservation.fromJson(json['reservation']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'reservation_id': reservationId,
      'rating': rating,
      'review': review,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'student': student?.toJson(),
      'teacher': teacher?.toJson(),
      'reservation': reservation?.toJson(),
    };
  }

  Rating copyWith({
    int? id,
    int? studentId,
    int? teacherId,
    int? reservationId,
    int? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? student,
    Teacher? teacher,
    Reservation? reservation,
  }) {
    return Rating(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      reservationId: reservationId ?? this.reservationId,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      student: student ?? this.student,
      teacher: teacher ?? this.teacher,
      reservation: reservation ?? this.reservation,
    );
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  List<Object?> get props => [
        id,
        studentId,
        teacherId,
        reservationId,
        rating,
        review,
        createdAt,
        updatedAt,
        student,
        teacher,
        reservation,
      ];
}
