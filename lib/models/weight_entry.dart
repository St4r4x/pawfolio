import '../date_only.dart';

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.petId,
    required this.weightKg,
    required this.recordedAt,
  });

  final String id;
  final String petId;
  final double weightKg;
  final DateTime recordedAt;

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        weightKg: num.parse(json['weight_kg'].toString()).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'pet_id': petId,
        'weight_kg': weightKg,
        'recorded_at': dateOnly(recordedAt),
      };
}
