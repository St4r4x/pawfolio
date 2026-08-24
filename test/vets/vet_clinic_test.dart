import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawfolio/vets/vet_clinic.dart';

void main() {
  test('fromOverpassElement parses name, address, and coordinates', () {
    final clinic = VetClinic.fromOverpassElement({
      'type': 'node',
      'id': 123456789,
      'lat': 48.8566,
      'lon': 2.3522,
      'tags': {
        'amenity': 'veterinary',
        'name': 'Clinique Vétérinaire du Parc',
        'addr:housenumber': '12',
        'addr:street': 'Rue de la Paix',
        'addr:city': 'Paris',
      },
    });

    expect(clinic.id, 'node/123456789');
    expect(clinic.name, 'Clinique Vétérinaire du Parc');
    expect(clinic.latitude, 48.8566);
    expect(clinic.longitude, 2.3522);
    expect(clinic.address, '12 Rue de la Paix Paris');
  });

  test('fromOverpassElement falls back to a generic name and null address when tags are missing', () {
    final clinic = VetClinic.fromOverpassElement({
      'type': 'node',
      'id': 42,
      'lat': 1.0,
      'lon': 2.0,
      'tags': <String, dynamic>{},
    });

    expect(clinic.name, 'Vétérinaire');
    expect(clinic.address, isNull);
  });

  test('fromOverpassElement handles a missing tags key entirely', () {
    final clinic = VetClinic.fromOverpassElement({'type': 'node', 'id': 1, 'lat': 0.0, 'lon': 0.0});
    expect(clinic.name, 'Vétérinaire');
  });

  test('distanceMetersFrom computes the distance to a known point', () {
    // Eiffel Tower to Arc de Triomphe, ~3.2km apart.
    const clinic = VetClinic(id: 'node/1', name: 'Test', latitude: 48.8738, longitude: 2.2950);
    final distance = clinic.distanceMetersFrom(const LatLng(48.8584, 2.2945));
    expect(distance, greaterThan(1500));
    expect(distance, lessThan(1800));
  });

  test('formattedDistanceFrom shows meters under 1km and km with one decimal above', () {
    const near = VetClinic(id: 'node/1', name: 'Near', latitude: 48.8566, longitude: 2.3522);
    const far = VetClinic(id: 'node/2', name: 'Far', latitude: 48.8738, longitude: 2.2950);
    final origin = const LatLng(48.8566, 2.3522);

    expect(near.formattedDistanceFrom(origin), '0 m');
    expect(far.formattedDistanceFrom(origin), endsWith(' km'));
  });

  test('fromSireneEtablissement prefers the enseigne as the name', () {
    final clinic = VetClinic.fromSireneEtablissement({
      'siret': '48748185500012',
      'adresse': '15 RUE LA BOETIE 75008 PARIS',
      'latitude': '48.873989063',
      'longitude': '2.3176677422',
      'liste_enseignes': ['CLINIQUE VETERINAIRE LA BOETIE'],
      'nom_commercial': null,
    }, fallbackName: 'FAMILYVETS');

    expect(clinic.id, 'siret/48748185500012');
    expect(clinic.name, 'CLINIQUE VETERINAIRE LA BOETIE');
    expect(clinic.latitude, 48.873989063);
    expect(clinic.longitude, 2.3176677422);
    expect(clinic.address, '15 RUE LA BOETIE 75008 PARIS');
  });

  test('fromSireneEtablissement falls back to nom_commercial when there is no enseigne', () {
    final clinic = VetClinic.fromSireneEtablissement({
      'siret': '1',
      'adresse': null,
      'latitude': '1.0',
      'longitude': '2.0',
      'liste_enseignes': null,
      'nom_commercial': 'Clinique du Chat Botté',
    }, fallbackName: 'FAMILYVETS');

    expect(clinic.name, 'Clinique du Chat Botté');
    expect(clinic.address, isNull);
  });

  test('fromSireneEtablissement falls back to the legal-unit name when no enseigne or nom_commercial', () {
    final clinic = VetClinic.fromSireneEtablissement({
      'siret': '1',
      'latitude': '1.0',
      'longitude': '2.0',
    }, fallbackName: 'FAMILYVETS');

    expect(clinic.name, 'FAMILYVETS');
  });
}
