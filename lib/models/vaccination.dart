import '../date_only.dart';

class Vaccination {
  const Vaccination({
    required this.id,
    required this.petId,
    required this.name,
    required this.dateAdministered,
    this.nextDueDate,
    this.notes,
  });

  final String id;
  final String petId;
  final String name;
  final DateTime dateAdministered;
  final DateTime? nextDueDate;
  final String? notes;

  factory Vaccination.fromJson(Map<String, dynamic> json) => Vaccination(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        name: json['name'] as String,
        dateAdministered: DateTime.parse(json['date_administered'] as String),
        nextDueDate: json['next_due_date'] == null ? null : DateTime.parse(json['next_due_date'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'name': name,
        'date_administered': dateOnly(dateAdministered),
        if (nextDueDate != null) 'next_due_date': dateOnly(nextDueDate!),
        if (notes != null) 'notes': notes,
      };
}
