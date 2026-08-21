import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/data/breed_predispositions.dart';
import 'package:pawfolio/data/breeds.dart';

void main() {
  test('every curated breed name exists in the canonical dog/cat breed lists', () {
    final canonicalBreeds = {...dogBreeds, ...catBreeds};
    for (final breed in breedPredispositions.keys) {
      expect(canonicalBreeds, contains(breed), reason: '"$breed" is not in dogBreeds/catBreeds — typo or renamed breed?');
    }
  });

  test('returns known predispositions for a common dog breed', () {
    final result = predispositionsForBreed('Berger Allemand');
    expect(result, isNotEmpty);
    expect(result.any((p) => p.condition.contains('Dysplasie')), isTrue);
  });

  test('returns known predispositions for a common cat breed', () {
    final result = predispositionsForBreed('Persan');
    expect(result, isNotEmpty);
  });

  test('returns an empty list for a breed with no curated entry', () {
    expect(predispositionsForBreed('Chien de traîneau inventé'), isEmpty);
  });

  test('lookup is case-insensitive', () {
    expect(predispositionsForBreed('berger allemand'), isNotEmpty);
  });

  test('every entry has a non-empty condition and note', () {
    for (final entries in breedPredispositions.values) {
      for (final entry in entries) {
        expect(entry.condition, isNotEmpty);
        expect(entry.note, isNotEmpty);
      }
    }
  });
}
