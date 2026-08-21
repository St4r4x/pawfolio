import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawfolio/vets/vet_search_service.dart';

void main() {
  const origin = LatLng(48.8566, 2.3522);

  test('returns clinics sorted by distance from the search center', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'overpass-api.de');
      expect(request.url.queryParameters['data'], contains('amenity=veterinary'));
      expect(request.url.queryParameters['data'], contains('around:5000,48.8566,2.3522'));
      return http.Response(
        '{"elements":['
        '{"type":"node","id":1,"lat":48.87,"lon":2.36,"tags":{"name":"Far"}},'
        '{"type":"node","id":2,"lat":48.857,"lon":2.3525,"tags":{"name":"Near"}}'
        ']}',
        200,
      );
    });
    final service = VetSearchService(client: client);

    final results = await service.nearby(origin);

    expect(results.map((c) => c.name), ['Near', 'Far']);
  });

  test('returns an empty list when there are no elements', () async {
    final client = MockClient((request) async => http.Response('{"elements":[]}', 200));
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('', 504));
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list when the client throws', () async {
    final client = MockClient((request) async => throw Exception('offline'));
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });

  test('returns an empty list on an unparseable response body', () async {
    final client = MockClient((request) async => http.Response('not json', 200));
    final service = VetSearchService(client: client);

    expect(await service.nearby(origin), isEmpty);
  });
}
