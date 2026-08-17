import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vaccination.dart';

void main() {
  test('Vaccination.fromJson parses a full record', () {
    final vaccination = Vaccination.fromJson({
      'id': 'v1',
      'pet_id': 'p1',
      'name': 'Rage',
      'date_administered': '2024-01-15',
      'next_due_date': '2025-01-15',
      'notes': 'Bien toléré',
    });
    expect(vaccination.name, 'Rage');
    expect(vaccination.dateAdministered, DateTime(2024, 1, 15));
    expect(vaccination.nextDueDate, DateTime(2025, 1, 15));
    expect(vaccination.notes, 'Bien toléré');
  });

  test('toInsertJson omits null optional fields', () {
    final vaccination = Vaccination(
      id: '',
      petId: 'p1',
      name: 'Rage',
      dateAdministered: DateTime(2024, 1, 15),
    );
    final json = vaccination.toInsertJson();
    expect(json.containsKey('next_due_date'), isFalse);
    expect(json.containsKey('notes'), isFalse);
    expect(json['date_administered'], '2024-01-15');
  });
}
