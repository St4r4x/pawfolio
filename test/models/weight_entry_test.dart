import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/weight_entry.dart';

void main() {
  test('WeightEntry.fromJson parses a record', () {
    final entry = WeightEntry.fromJson({
      'id': 'w1',
      'pet_id': 'p1',
      'weight_kg': '12.5',
      'recorded_at': '2024-03-01',
    });
    expect(entry.weightKg, 12.5);
    expect(entry.recordedAt, DateTime(2024, 3, 1));
  });

  test('toInsertJson serializes weight and date', () {
    final entry = WeightEntry(id: '', petId: 'p1', weightKg: 12.5, recordedAt: DateTime(2024, 3, 1));
    final json = entry.toInsertJson();
    expect(json['weight_kg'], 12.5);
    expect(json['recorded_at'], '2024-03-01');
  });
}
