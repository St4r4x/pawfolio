import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawfolio/vets/geocoding_service.dart';

void main() {
  test('returns coordinates for a matched address', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['q'], '10 Rue de Rivoli, Paris');
      return http.Response('[{"lat":"48.8566","lon":"2.3522","display_name":"Paris"}]', 200);
    });
    final service = GeocodingService(client: client);

    final result = await service.geocode('10 Rue de Rivoli, Paris');

    expect(result?.latitude, 48.8566);
    expect(result?.longitude, 2.3522);
  });

  test('returns null when no address matches', () async {
    final client = MockClient((request) async => http.Response('[]', 200));
    final service = GeocodingService(client: client);

    expect(await service.geocode('nowhere'), isNull);
  });

  test('returns null on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('', 503));
    final service = GeocodingService(client: client);

    expect(await service.geocode('anything'), isNull);
  });

  test('returns null when the client throws', () async {
    final client = MockClient((request) async => throw Exception('offline'));
    final service = GeocodingService(client: client);

    expect(await service.geocode('anything'), isNull);
  });

  test('returns null on an unparseable response body', () async {
    final client = MockClient((request) async => http.Response('not json', 200));
    final service = GeocodingService(client: client);

    expect(await service.geocode('anything'), isNull);
  });
}
