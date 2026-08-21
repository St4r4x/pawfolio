import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/vet_visit.dart';

void main() {
  test('VetVisit.fromJson parses a full record', () {
    final visit = VetVisit.fromJson({
      'id': 'vv1',
      'pet_id': 'p1',
      'visit_date': '2024-04-10',
      'reason': 'Contrôle annuel',
      'notes': 'RAS',
    });
    expect(visit.reason, 'Contrôle annuel');
    expect(visit.visitDate, DateTime(2024, 4, 10));
  });

  test('toInsertJson omits null optional fields', () {
    final visit = VetVisit(id: '', petId: 'p1', visitDate: DateTime(2024, 4, 10), reason: 'Contrôle annuel');
    final json = visit.toInsertJson();
    expect(json.containsKey('notes'), isFalse);
  });
}
