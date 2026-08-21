import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawfolio/providers/vet_search_providers.dart';
import 'package:pawfolio/screens/vets/vets_screen.dart';
import 'package:pawfolio/vets/geocoding_service.dart';
import 'package:pawfolio/vets/vet_search_service.dart';

void main() {
  testWidgets('shows an initial prompt before any search', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: VetsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cherche des vétérinaires près de chez toi.'), findsOneWidget);
  });

  testWidgets('typing an address and submitting shows the results list', (tester) async {
    final geocodingClient = MockClient(
      (request) async => http.Response('[{"lat":"48.8566","lon":"2.3522","display_name":"Paris"}]', 200),
    );
    final vetClient = MockClient(
      (request) async => http.Response(
        '{"elements":[{"type":"node","id":1,"lat":48.857,"lon":2.353,"tags":{"name":"Clinique du Parc"}}]}',
        200,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodingServiceProvider.overrideWithValue(GeocodingService(client: geocodingClient)),
          vetSearchServiceProvider.overrideWithValue(VetSearchService(client: vetClient)),
        ],
        child: const MaterialApp(home: VetsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '10 Rue de Rivoli, Paris');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Clinique du Parc'), findsOneWidget);
  });
}
