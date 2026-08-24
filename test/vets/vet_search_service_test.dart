import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawfolio/vets/vet_search_service.dart';

/// A [http.Response] for a Nominatim reverse-geocode call that resolves to no postcode.
final _noPostcode = http.Response('{"address":{}}', 200);

void main() {
  const origin = LatLng(48.8566, 2.3522);

  test('returns clinics sorted by distance from the search center', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') {
        expect(request.url.queryParameters['data'], contains('amenity=veterinary'));
        expect(request.url.queryParameters['data'], contains('around:5000,48.8566,2.3522'));
        return http.Response(
          '{"elements":['
          '{"type":"node","id":1,"lat":48.87,"lon":2.36,"tags":{"name":"Far"}},'
          '{"type":"node","id":2,"lat":48.857,"lon":2.3525,"tags":{"name":"Near"}}'
          ']}',
          200,
        );
      }
      return _noPostcode;
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['Near', 'Far']);
  });

  test('returns an empty list when there are no elements', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') return http.Response('{"elements":[]}', 200);
      return _noPostcode;
    });
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list on a non-200 response', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') return http.Response('', 504);
      return _noPostcode;
    });
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list when the client throws', () async {
    final client = MockClient((request) async => throw Exception('offline'));
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list on an unparseable response body', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') return http.Response('not json', 200);
      return _noPostcode;
    });
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('adds a SIRENE result that is not near an existing OSM result', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') {
        return http.Response(
          '{"elements":[{"type":"node","id":1,"lat":48.8566,"lon":2.3522,"tags":{"name":"OSM Clinic"}}]}',
          200,
        );
      }
      if (request.url.path == '/reverse') {
        return http.Response('{"address":{"postcode":"75001"}}', 200);
      }
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') {
        expect(request.url.queryParameters['code_postal'], '75001');
        expect(request.url.queryParameters['activite_principale'], '75.00Z');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'nom_complet': 'FAMILYVETS',
                'matching_etablissements': [
                  {
                    'siret': '1',
                    'adresse': '1 Rue Sirene',
                    'latitude': '48.86',
                    'longitude': '2.35',
                    'liste_enseignes': ['Clinique Sirene'],
                    'activite_principale': '75.00Z',
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), containsAll(['OSM Clinic', 'Clinique Sirene']));
    expect(results, hasLength(2));
  });

  test('skips a SIRENE result that duplicates a nearby OSM result', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') {
        return http.Response(
          '{"elements":[{"type":"node","id":1,"lat":48.8566,"lon":2.3522,"tags":{"name":"OSM Clinic"}}]}',
          200,
        );
      }
      if (request.url.path == '/reverse') {
        return http.Response('{"address":{"postcode":"75001"}}', 200);
      }
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'nom_complet': 'FAMILYVETS',
                'matching_etablissements': [
                  {
                    'siret': '1',
                    'latitude': '48.8567', // ~11m from the OSM clinic above.
                    'longitude': '2.3522',
                    'liste_enseignes': ['Sirene Duplicate'],
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['OSM Clinic']);
  });

  test('excludes a SIRENE result outside the search radius', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') return http.Response('{"elements":[]}', 200);
      if (request.url.path == '/reverse') {
        return http.Response('{"address":{"postcode":"75001"}}', 200);
      }
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'nom_complet': 'FAMILYVETS',
                'matching_etablissements': [
                  {
                    'siret': '1',
                    'latitude': '49.0', // ~16km from origin, outside the default 5000m radius.
                    'longitude': '2.3522',
                    'liste_enseignes': ['Too Far'],
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('falls back to OSM-only results when reverse geocoding finds no postcode', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') {
        return http.Response(
          '{"elements":[{"type":"node","id":1,"lat":48.8566,"lon":2.3522,"tags":{"name":"OSM Clinic"}}]}',
          200,
        );
      }
      if (request.url.path == '/reverse') return _noPostcode;
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') {
        fail('SIRENE should not be queried without a postcode');
      }
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['OSM Clinic']);
  });

  test('falls back to OSM-only results when the SIRENE request fails', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') {
        return http.Response(
          '{"elements":[{"type":"node","id":1,"lat":48.8566,"lon":2.3522,"tags":{"name":"OSM Clinic"}}]}',
          200,
        );
      }
      if (request.url.path == '/reverse') {
        return http.Response('{"address":{"postcode":"75001"}}', 200);
      }
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') return http.Response('', 500);
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['OSM Clinic']);
  });

  test('ignores a matching establishment whose own activity code is not veterinary', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'overpass-api.de') return http.Response('{"elements":[]}', 200);
      if (request.url.path == '/reverse') {
        return http.Response('{"address":{"postcode":"75001"}}', 200);
      }
      if (request.url.host == 'recherche-entreprises.api.gouv.fr') {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'nom_complet': 'FAMILYVETS',
                'matching_etablissements': [
                  {
                    'siret': '1',
                    'latitude': '48.8566',
                    'longitude': '2.3522',
                    'liste_enseignes': ['Vet Branch'],
                    'activite_principale': '75.00Z',
                  },
                  {
                    'siret': '2',
                    'latitude': '48.8566',
                    'longitude': '2.3522',
                    'liste_enseignes': ['Head Office'],
                    'activite_principale': '47.19B',
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      throw StateError('unexpected host: ${request.url.host}');
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['Vet Branch']);
  });
}
