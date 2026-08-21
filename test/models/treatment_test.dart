import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/models/treatment.dart';

void main() {
  test('Treatment.fromJson parses a full record', () {
    final treatment = Treatment.fromJson({
      'id': 't1',
      'pet_id': 'p1',
      'type': 'dewormer',
      'name': 'Milbemax',
      'date_given': '2024-02-01',
      'next_due_date': '2024-05-01',
      'notes': null,
    });
    expect(treatment.type, 'dewormer');
    expect(treatment.name, 'Milbemax');
    expect(treatment.dateGiven, DateTime(2024, 2, 1));
    expect(treatment.nextDueDate, DateTime(2024, 5, 1));
  });

  test('toInsertJson omits null optional fields', () {
    final treatment = Treatment(
      id: '',
      petId: 'p1',
      type: 'antiparasitic',
      name: 'Frontline',
      dateGiven: DateTime(2024, 2, 1),
    );
    final json = treatment.toInsertJson();
    expect(json.containsKey('next_due_date'), isFalse);
    expect(json.containsKey('notes'), isFalse);
  });

  test('toInsertJson always sends reference, even null, so clearing it on update persists', () {
    final treatment = Treatment(
      id: '',
      petId: 'p1',
      type: 'antiparasitic',
      name: 'Frontline',
      dateGiven: DateTime(2024, 2, 1),
    );
    final json = treatment.toInsertJson();
    expect(json.containsKey('reference'), isTrue);
    expect(json['reference'], isNull);
  });

  test('Treatment.fromJson parses a barcode reference', () {
    final treatment = Treatment.fromJson({
      'id': 't1',
      'pet_id': 'p1',
      'type': 'dewormer',
      'name': 'Milbemax',
      'date_given': '2024-02-01',
      'next_due_date': null,
      'notes': null,
      'reference': '3401579999999',
    });
    expect(treatment.reference, '3401579999999');
  });

  test('toInsertJson includes a set reference', () {
    final treatment = Treatment(
      id: '',
      petId: 'p1',
      type: 'antiparasitic',
      name: 'Frontline',
      dateGiven: DateTime(2024, 2, 1),
      reference: '3401579999999',
    );
    final json = treatment.toInsertJson();
    expect(json['reference'], '3401579999999');
  });
}
