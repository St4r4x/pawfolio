import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/barcode/barcode_name_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('get returns null for an unknown barcode', () async {
    final cache = BarcodeNameCache();
    expect(await cache.get('0000000000000'), isNull);
  });

  test('put then get round-trips a product name', () async {
    final cache = BarcodeNameCache();
    await cache.put('3401579999999', 'Milbemax');
    expect(await cache.get('3401579999999'), 'Milbemax');
  });

  test('stores multiple barcodes independently', () async {
    final cache = BarcodeNameCache();
    await cache.put('111', 'Frontline');
    await cache.put('222', 'Milbemax');
    expect(await cache.get('111'), 'Frontline');
    expect(await cache.get('222'), 'Milbemax');
  });
}
