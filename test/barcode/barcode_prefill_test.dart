import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawfolio/barcode/barcode_lookup_service.dart';
import 'package:pawfolio/barcode/barcode_name_cache.dart';
import 'package:pawfolio/barcode/barcode_prefill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BarcodeLookupService lookupServiceThatFails() =>
      BarcodeLookupService(client: MockClient((request) async => throw StateError('should not be called')));

  test('always fills the reference field with the scanned code', () async {
    final nameController = TextEditingController(text: 'Milbemax');
    final referenceController = TextEditingController();

    await applyScannedBarcode(
      code: '3401579999999',
      nameController: nameController,
      referenceController: referenceController,
      cache: BarcodeNameCache(),
      lookupService: lookupServiceThatFails(),
    );

    expect(referenceController.text, '3401579999999');
  });

  test('does not overwrite an already-typed name', () async {
    final nameController = TextEditingController(text: 'Milbemax');
    final referenceController = TextEditingController();

    await applyScannedBarcode(
      code: '3401579999999',
      nameController: nameController,
      referenceController: referenceController,
      cache: BarcodeNameCache(),
      lookupService: lookupServiceThatFails(),
    );

    expect(nameController.text, 'Milbemax');
  });

  test('fills the name from the local cache without calling the lookup service', () async {
    final cache = BarcodeNameCache();
    await cache.put('3401579999999', 'Milbemax (mémorisé)');
    final nameController = TextEditingController();
    final referenceController = TextEditingController();

    await applyScannedBarcode(
      code: '3401579999999',
      nameController: nameController,
      referenceController: referenceController,
      cache: cache,
      lookupService: lookupServiceThatFails(),
    );

    expect(nameController.text, 'Milbemax (mémorisé)');
  });

  test('falls back to the lookup service on a cache miss and remembers the result', () async {
    final cache = BarcodeNameCache();
    final lookupService = BarcodeLookupService(
      client: MockClient((request) async {
        return http.Response('{"items":[{"title":"Frontline Combo"}]}', 200);
      }),
    );
    final nameController = TextEditingController();
    final referenceController = TextEditingController();

    await applyScannedBarcode(
      code: '123',
      nameController: nameController,
      referenceController: referenceController,
      cache: cache,
      lookupService: lookupService,
    );

    expect(nameController.text, 'Frontline Combo');
    expect(await cache.get('123'), 'Frontline Combo');
  });

  test('leaves the name empty when neither the cache nor the lookup has a match', () async {
    final cache = BarcodeNameCache();
    final lookupService = BarcodeLookupService(
      client: MockClient((request) async => http.Response('{"items":[]}', 200)),
    );
    final nameController = TextEditingController();
    final referenceController = TextEditingController();

    await applyScannedBarcode(
      code: '123',
      nameController: nameController,
      referenceController: referenceController,
      cache: cache,
      lookupService: lookupService,
    );

    expect(nameController.text, isEmpty);
  });
}
