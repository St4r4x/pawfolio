import '../date_only.dart';

class Treatment {
  const Treatment({
    required this.id,
    required this.petId,
    required this.type,
    required this.name,
    required this.dateGiven,
    this.nextDueDate,
    this.notes,
  });

  final String id;
  final String petId;
  final String type;
  final String name;
  final DateTime dateGiven;
  final DateTime? nextDueDate;
  final String? notes;

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        dateGiven: DateTime.parse(json['date_given'] as String),
        nextDueDate: json['next_due_date'] == null ? null : DateTime.parse(json['next_due_date'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'type': type,
        'name': name,
        'date_given': dateOnly(dateGiven),
        if (nextDueDate != null) 'next_due_date': dateOnly(nextDueDate!),
        if (notes != null) 'notes': notes,
      };
}
