import 'package:equatable/equatable.dart';

class Prescription extends Equatable {
  final String id;
  final String customerId;
  final String doctorName;
  final String? clinicName;
  final DateTime prescriptionDate;
  final String imageUrl;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const Prescription({
    required this.id,
    required this.customerId,
    required this.doctorName,
    this.clinicName,
    required this.prescriptionDate,
    required this.imageUrl,
    this.isSynced = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  @override
  List<Object?> get props => [
    id,
    customerId,
    doctorName,
    clinicName,
    prescriptionDate,
    imageUrl,
    isSynced,
    isDeleted,
    createdAt,
    updatedAt,
    createdBy,
  ];
}
