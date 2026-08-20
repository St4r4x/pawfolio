import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/data/breeds.dart';

void main() {
  test('breedsForSpecies returns dog breeds for dog', () {
    expect(breedsForSpecies('dog'), contains('Labrador'));
  });

  test('breedsForSpecies returns cat breeds for cat', () {
    expect(breedsForSpecies('cat'), contains('Siamois'));
  });

  test('breedsForSpecies returns an empty list for other', () {
    expect(breedsForSpecies('other'), isEmpty);
  });
}
