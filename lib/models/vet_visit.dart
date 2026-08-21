import '../date_only.dart';

class VetVisit {
  const VetVisit({
    required this.id,
    required this.petId,
    required this.visitDate,
    required this.reason,
    this.notes,
  });

  final String id;
  final String petId;
  final DateTime visitDate;
  final String reason;
  final String? notes;

  factory VetVisit.fromJson(Map<String, dynamic> json) => VetVisit(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        reason: json['reason'] as String,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'visit_date': dateOnly(visitDate),
        'reason': reason,
        if (notes != null) 'notes': notes,
      };
}
