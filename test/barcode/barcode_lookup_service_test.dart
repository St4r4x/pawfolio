import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawfolio/barcode/barcode_lookup_service.dart';

void main() {
  test('returns the product title on a successful match', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['upc'], '3401579999999');
      return http.Response(
        '{"code":"OK","items":[{"title":"Milbemax chien","ean":"3401579999999"}]}',
        200,
      );
    });
    final service = BarcodeLookupService(client: client);

    expect(await service.lookupProductName('3401579999999'), 'Milbemax chien');
  });

  test('returns null when the barcode has no match', () async {
    final client = MockClient((request) async {
      return http.Response('{"code":"INVALID_UPC","items":[]}', 200);
    });
    final service = BarcodeLookupService(client: client);

    expect(await service.lookupProductName('0'), isNull);
  });

  test('returns null on a non-200 response (e.g. rate limited)', () async {
    final client = MockClient((request) async => http.Response('', 429));
    final service = BarcodeLookupService(client: client);

    expect(await service.lookupProductName('123'), isNull);
  });

  test('returns null when the client throws', () async {
    final client = MockClient((request) async => throw Exception('offline'));
    final service = BarcodeLookupService(client: client);

    expect(await service.lookupProductName('123'), isNull);
  });

  test('returns null when the request exceeds the timeout', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{"items":[{"title":"Too slow"}]}', 200);
    });
    final service = BarcodeLookupService(
      client: client,
      timeout: const Duration(milliseconds: 5),
    );

    expect(await service.lookupProductName('123'), isNull);
  });
}
