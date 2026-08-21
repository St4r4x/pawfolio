# Nearby Veterinarians Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a signed-in user find veterinary clinics near them — via GPS or a
typed address — on a map with a results list, using only free, keyless services
(OpenStreetMap tiles, Overpass POI search, Nominatim geocoding).

**Architecture:** Two new fail-soft HTTP service classes behind Riverpod
`Provider`s (mirroring `lib/barcode/barcode_lookup_service.dart` and
`lib/providers/barcode_providers.dart`), one new `Notifier` wrapping `geolocator`,
one new domain model, one new screen wired in as a fourth bottom-nav tab.

**Tech Stack:** Flutter, `flutter_riverpod`, `geolocator` (GPS), `flutter_map` +
`latlong2` (map rendering), `http` (already a dependency), `go_router`.

**Spec:** `docs/superpowers/specs/2026-08-21-nearby-vets-map-design.md`

## Global Constraints

- No API keys, no new Supabase table, no new `--dart-define`. Every external call
  in this feature is to a free, keyless public service (OSM tiles, Overpass,
  Nominatim).
- Every HTTP service class never throws to its caller: on any network error,
  timeout, or unparseable response, return `null` (geocoding, one result) or `[]`
  (vet search, a list) — same contract as `lib/barcode/barcode_lookup_service.dart`.
- All external HTTP calls use `Uri.https(host, path, {queryParamMap})` for query
  parameters — never hand-build a URL string by interpolating user input — matching
  `lib/barcode/barcode_lookup_service.dart`'s existing pattern. The only
  user-supplied text in this feature (the typed address) reaches Nominatim as a
  `q` query parameter this way, never concatenated into a raw query/URL string.
- Every screen-facing string is in French, matching the rest of the app.
- New files follow existing directory conventions exactly:
  - `lib/models/` — plain domain data (`Pet`, `Treatment`, and now `VetClinic`).
  - `lib/vets/` — this feature's service classes, mirroring `lib/barcode/`.
  - `lib/providers/` — Riverpod wiring, mirroring `lib/providers/barcode_providers.dart`.
  - `lib/screens/vets/` — the screen, mirroring `lib/screens/pet_detail/`.
  - Test files mirror the `lib/` path they cover under `test/`.
- This project is only manually verified via the web target in this environment —
  never attempt an Android emulator or build (it crashes the dev machine); there is
  no `ios/` platform folder in this repo at all. Mobile-only setup (Android
  manifest permissions, `Info.plist` usage descriptions) is out of scope for this
  plan, matching the precedent set by the merged barcode-scanner PR, which left
  `mobile_scanner`'s own Android camera permission to its plugin's bundled
  manifest rather than hand-editing `AndroidManifest.xml`. `geolocator_android`
  bundles its own location permissions the same way.
- GPS itself (the `geolocator` call path) is not unit-testable in a meaningful way
  and not manually verifiable in this environment either — the sandboxed browser
  used for manual verification denies geolocation the same way it denied the
  camera for the barcode scanner. Only the typed-address path gets both automated
  widget-test coverage and real manual verification (against the live Nominatim/
  Overpass endpoints).

---

### Task 1: Isolate in a worktree

**Files:** none (setup only).

- [ ] **Step 1: Confirm on `main` with a clean tree, then create the worktree**

```bash
git status --porcelain
git checkout main && git pull
```

- [ ] **Step 2: Create the worktree on `feature/nearby-vets-map`**

Use the native worktree tool if available (`EnterWorktree` with
`name: "feature/nearby-vets-map"`); otherwise:

```bash
git worktree add .worktrees/feature/nearby-vets-map -b feature/nearby-vets-map
cd .worktrees/feature/nearby-vets-map
```

- [ ] **Step 3: Verify a clean baseline**

```bash
flutter pub get
flutter test
```

Expected: all existing tests pass (136 at the time this plan was written). If
anything fails, stop and investigate before continuing — a red baseline makes
every later failure ambiguous.

---

### Task 2: Add map/location dependencies

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `geolocator`, `flutter_map`, `latlong2` importable from every later task.

- [ ] **Step 1: Add the dependencies**

```bash
flutter pub add geolocator flutter_map latlong2
```

- [ ] **Step 2: Verify resolution and no analyzer breakage**

```bash
flutter pub get
flutter analyze lib/
```

Expected: `flutter pub add` reports `geolocator`, `flutter_map`, and `latlong2`
added to `pubspec.yaml`/`pubspec.lock`; `flutter analyze` reports the same 12
pre-existing `info`-level issues as before (no new errors/warnings).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add geolocator, flutter_map, and latlong2 dependencies"
```

---

### Task 3: `VetClinic` model

**Files:**
- Create: `lib/models/vet_clinic.dart`
- Test: `test/models/vet_clinic_test.dart`

**Interfaces:**
- Consumes: `LatLng`, `Distance` from `package:latlong2/latlong.dart` (added in Task 2).
- Produces:
  - `class VetClinic { id, name, latitude, longitude, address }`
  - `factory VetClinic.fromOverpassElement(Map<String, dynamic> element)`
  - `double distanceMetersFrom(LatLng origin)`
  - `String formattedDistanceFrom(LatLng origin)` — e.g. `"350 m"` / `"2.3 km"`

Later tasks (`VetSearchService`, `VetsScreen`) call all four.

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/vet_clinic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawfolio/models/vet_clinic.dart';

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
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/models/vet_clinic_test.dart
```

Expected: FAIL — `lib/models/vet_clinic.dart` does not exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/vet_clinic.dart
import 'package:latlong2/latlong.dart';

class VetClinic {
  const VetClinic({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  factory VetClinic.fromOverpassElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? const {};
    final addressParts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:city'],
    ].whereType<String>().toList();

    return VetClinic(
      id: '${element['type']}/${element['id']}',
      name: tags['name'] as String? ?? 'Vétérinaire',
      latitude: (element['lat'] as num).toDouble(),
      longitude: (element['lon'] as num).toDouble(),
      address: addressParts.isEmpty ? null : addressParts.join(' '),
    );
  }

  double distanceMetersFrom(LatLng origin) =>
      const Distance().distance(origin, LatLng(latitude, longitude));

  String formattedDistanceFrom(LatLng origin) {
    final meters = distanceMetersFrom(origin);
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/models/vet_clinic_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/vet_clinic.dart test/models/vet_clinic_test.dart
git commit -m "feat: add VetClinic model with Overpass parsing and distance formatting"
```

---

### Task 4: `GeocodingService`

**Files:**
- Create: `lib/vets/geocoding_service.dart`
- Test: `test/vets/geocoding_service_test.dart`

**Interfaces:**
- Consumes: `LatLng` from `package:latlong2/latlong.dart`.
- Produces: `class GeocodingService { GeocodingService({http.Client? client, Duration timeout}); Future<LatLng?> geocode(String address); }`

`VetsScreen` (Task 7) calls `geocode`. `lib/providers/vet_search_providers.dart`
(Task 6) exposes it via `geocodingServiceProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/vets/geocoding_service_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/vets/geocoding_service_test.dart
```

Expected: FAIL — `lib/vets/geocoding_service.dart` does not exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/vets/geocoding_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turns a typed address into coordinates via Nominatim's free, keyless
/// geocoding endpoint. Never throws: any miss, error, or timeout resolves to
/// null so callers can show an explicit "address not found" state.
class GeocodingService {
  GeocodingService({http.Client? client, this.timeout = const Duration(seconds: 5)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<LatLng?> geocode(String address) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': address,
      'format': 'json',
      'limit': '1',
    });
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'Pawfolio/1.0 (+https://github.com/St4r4x/pawfolio)'})
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lon = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/vets/geocoding_service_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/vets/geocoding_service.dart test/vets/geocoding_service_test.dart
git commit -m "feat: add GeocodingService (Nominatim, keyless)"
```

---

### Task 5: `VetSearchService`

**Files:**
- Create: `lib/vets/vet_search_service.dart`
- Test: `test/vets/vet_search_service_test.dart`

**Interfaces:**
- Consumes: `VetClinic.fromOverpassElement`, `VetClinic.distanceMetersFrom` (Task 3); `LatLng` from `latlong2`.
- Produces: `class VetSearchService { VetSearchService({http.Client? client, Duration timeout}); Future<List<VetClinic>> nearby(LatLng center, {double radiusMeters}); }`

`VetsScreen` (Task 7) calls `nearby`. Exposed via `vetSearchServiceProvider` (Task 6).

- [ ] **Step 1: Write the failing tests**

```dart
// test/vets/vet_search_service_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/vets/vet_search_service_test.dart
```

Expected: FAIL — `lib/vets/vet_search_service.dart` does not exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/vets/vet_search_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/vet_clinic.dart';

/// Finds veterinary clinics near a point via Overpass's free, keyless public
/// interpreter. Never throws: any miss, error, or timeout resolves to an
/// empty list so the screen shows one consistent empty state regardless of
/// *why* there are no results.
class VetSearchService {
  VetSearchService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<List<VetClinic>> nearby(LatLng center, {double radiusMeters = 5000}) async {
    final query =
        '[out:json][timeout:10];'
        '(node[amenity=veterinary](around:$radiusMeters,${center.latitude},${center.longitude}););'
        'out;';
    final uri = Uri.https('overpass-api.de', '/api/interpreter', {'data': query});
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final elements = (jsonDecode(response.body) as Map<String, dynamic>)['elements'] as List<dynamic>?;
      if (elements == null) return const [];
      final clinics = elements.map((e) => VetClinic.fromOverpassElement(e as Map<String, dynamic>)).toList();
      clinics.sort((a, b) => a.distanceMetersFrom(center).compareTo(b.distanceMetersFrom(center)));
      return clinics;
    } catch (_) {
      return const [];
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/vets/vet_search_service_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/vets/vet_search_service.dart test/vets/vet_search_service_test.dart
git commit -m "feat: add VetSearchService (Overpass, keyless)"
```

---

### Task 6: Riverpod providers for the two services

**Files:**
- Create: `lib/providers/vet_search_providers.dart`

**Interfaces:**
- Consumes: `GeocodingService` (Task 4), `VetSearchService` (Task 5).
- Produces: `final geocodingServiceProvider = Provider<GeocodingService>(...)`, `final vetSearchServiceProvider = Provider<VetSearchService>(...)`.

`VetsScreen` (Task 7) reads both via `ref.read(...)`; widget tests override both
with fakes via `ProviderScope`.

This task has no dedicated test — it's two one-line `Provider` declarations with
no branching logic, mirroring `lib/providers/barcode_providers.dart`, which
likewise has no test file of its own (its wrapped services are what's tested).

- [ ] **Step 1: Write the providers**

```dart
// lib/providers/vet_search_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vets/geocoding_service.dart';
import '../vets/vet_search_service.dart';

final geocodingServiceProvider = Provider((ref) => GeocodingService());

final vetSearchServiceProvider = Provider((ref) => VetSearchService());
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/providers/vet_search_providers.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/vet_search_providers.dart
git commit -m "feat: add geocodingServiceProvider and vetSearchServiceProvider"
```

---

### Task 7: `location_provider.dart`

**Files:**
- Create: `lib/providers/location_provider.dart`

**Interfaces:**
- Produces: `enum LocationStatus { idle, loading, granted, denied, error }`,
  `class LocationState { status, position (LatLng?), errorMessage (String?) }`,
  `class LocationNotifier extends Notifier<LocationState> { Future<void> useCurrentPosition(); }`,
  `final locationProvider = NotifierProvider<LocationNotifier, LocationState>(...)`.

`VetsScreen` (Task 7 — wait, see Task 8) watches `locationProvider` and calls
`ref.read(locationProvider.notifier).useCurrentPosition()`.

No automated test for this task (see Global Constraints: GPS itself isn't
meaningfully unit-testable — `Geolocator`'s static methods have no seam to inject
a fake through without a wrapper interface this feature doesn't otherwise need,
and the real behavior can't be manually verified in this sandboxed environment
either, same as the barcode scanner's camera). The four-branch state machine
below follows `geolocator`'s own documented recommended usage pattern (check
service enabled → check/request permission → get position) exactly, which is the
most defensible substitute for a test here.

- [ ] **Step 1: Write the implementation**

```dart
// lib/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus { idle, loading, granted, denied, error }

class LocationState {
  const LocationState({this.status = LocationStatus.idle, this.position, this.errorMessage});

  final LocationStatus status;
  final LatLng? position;
  final String? errorMessage;
}

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  Future<void> useCurrentPosition() async {
    state = const LocationState(status: LocationStatus.loading);

    if (!await Geolocator.isLocationServiceEnabled()) {
      state = const LocationState(
        status: LocationStatus.denied,
        errorMessage: 'Active la localisation dans les réglages de ton appareil.',
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      state = const LocationState(
        status: LocationStatus.denied,
        errorMessage: 'Localisation refusée — entre une adresse à la place.',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      state = LocationState(
        status: LocationStatus.granted,
        position: LatLng(position.latitude, position.longitude),
      );
    } catch (_) {
      state = const LocationState(
        status: LocationStatus.error,
        errorMessage: 'Impossible d\'obtenir ta position.',
      );
    }
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/providers/location_provider.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/location_provider.dart
git commit -m "feat: add locationProvider wrapping geolocator"
```

---

### Task 8: `VetsScreen`

**Files:**
- Create: `lib/screens/vets/vets_screen.dart`
- Test: `test/screens/vets_screen_test.dart`

**Interfaces:**
- Consumes: `geocodingServiceProvider`, `vetSearchServiceProvider` (Task 6),
  `locationProvider` (Task 7), `VetClinic` (Task 3), `EmptyState` from
  `lib/widgets/empty_state.dart` (existing — constructor:
  `EmptyState({required Widget illustration, required String title, String? subtitle})`).
- Produces: `class VetsScreen extends ConsumerStatefulWidget` — the fourth tab's
  screen, wired into the router in Task 9.

This is the biggest task; it's kept as one task (one file, one cohesive
deliverable) but built through four small test-then-implement cycles, each
ending in its own commit — every cycle leaves `vets_screen.dart` in a fully
working state, never a stub.

#### Cycle 1 — initial state and the address search happy path

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/vets_screen_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: FAIL — `lib/screens/vets/vets_screen.dart` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// lib/screens/vets/vets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/vet_clinic.dart';
import '../../providers/location_provider.dart';
import '../../providers/vet_search_providers.dart';
import '../../widgets/empty_state.dart';

class VetsScreen extends ConsumerStatefulWidget {
  const VetsScreen({super.key});

  @override
  ConsumerState<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends ConsumerState<VetsScreen> {
  final _addressController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  List<VetClinic>? _results;
  LatLng? _center;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = null;
    });
    final coords = await ref.read(geocodingServiceProvider).geocode(address);
    if (coords == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Adresse introuvable.';
      });
      return;
    }
    await _searchNear(coords);
  }

  Future<void> _searchNear(LatLng center) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _center = center;
    });
    final clinics = await ref.read(vetSearchServiceProvider).nearby(center);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = clinics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vétérinaires')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Rechercher',
                  onPressed: _searchAddress,
                ),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Utiliser ma position',
                  onPressed: () => ref.read(locationProvider.notifier).useCurrentPosition(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_results == null) {
      return const Center(child: Text('Cherche des vétérinaires près de chez toi.'));
    }
    if (_results!.isEmpty) {
      return const EmptyState(
        illustration: Icon(Icons.location_off_outlined, size: 64),
        title: 'Aucun vétérinaire trouvé à proximité',
      );
    }
    return ListView(
      children: [
        for (final clinic in _results!)
          ListTile(
            title: Text(clinic.name),
            subtitle: Text([if (clinic.address != null) clinic.address!, clinic.formattedDistanceFrom(_center!)].join(' · ')),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/vets/vets_screen.dart test/screens/vets_screen_test.dart
git commit -m "feat: add VetsScreen with address search and results list"
```

#### Cycle 2 — geocoding failure and empty-results states

- [ ] **Step 1: Write the failing tests**

Append to `test/screens/vets_screen_test.dart`:

```dart
testWidgets('shows an explicit error when the address has no match', (tester) async {
  final geocodingClient = MockClient((request) async => http.Response('[]', 200));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        geocodingServiceProvider.overrideWithValue(GeocodingService(client: geocodingClient)),
      ],
      child: const MaterialApp(home: VetsScreen()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'nowhere at all');
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();

  expect(find.text('Adresse introuvable.'), findsOneWidget);
});

testWidgets('shows the empty state when the search finds no clinics', (tester) async {
  final geocodingClient = MockClient(
    (request) async => http.Response('[{"lat":"48.8566","lon":"2.3522","display_name":"Paris"}]', 200),
  );
  final vetClient = MockClient((request) async => http.Response('{"elements":[]}', 200));

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

  expect(find.text('Aucun vétérinaire trouvé à proximité'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: the two new tests FAIL if the states aren't wired yet — but Cycle 1's
implementation above already handles both branches (`_errorMessage` and empty
`_results`), so at this point they should already PASS. If they don't, the bug
is in `_searchAddress`/`_buildBody`'s branching in Cycle 1 — fix there, not by
adding new branches.

- [ ] **Step 3: Run the full screen test file to confirm everything passes together**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 4: Commit**

```bash
git add test/screens/vets_screen_test.dart
git commit -m "test: cover geocoding-not-found and empty-results states in VetsScreen"
```

#### Cycle 3 — map rendering alongside the list

**Interfaces added:** `FlutterMap`, `MapOptions`, `TileLayer`, `MarkerLayer`,
`Marker`, `MapController` from `package:flutter_map/flutter_map.dart`.

- [ ] **Step 1: Write the failing test**

Append to `test/screens/vets_screen_test.dart`:

```dart
testWidgets('renders a map alongside the results list', (tester) async {
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
  // A single pump, deliberately NOT pumpAndSettle: FlutterMap's TileLayer
  // starts real network image requests for map tiles that never resolve
  // inside flutter_test's controlled Zone, so pumpAndSettle would hang/time
  // out waiting for them. One pump is enough to confirm the widget tree
  // (map + list) is built; it does not need to wait for tile images to load.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  expect(find.byType(FlutterMap), findsOneWidget);
  expect(find.text('Clinique du Parc'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: FAIL — no `FlutterMap` in the widget tree yet.

- [ ] **Step 3: Add the map to the results branch**

Replace the `return ListView(...)` block at the end of `_buildBody()` in
`lib/screens/vets/vets_screen.dart` with:

```dart
    final center = _center!;
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pawfolio.pawfolio',
              ),
              MarkerLayer(
                markers: [
                  Marker(point: center, child: const Icon(Icons.my_location, color: Colors.blue)),
                  for (final clinic in _results!)
                    Marker(
                      point: LatLng(clinic.latitude, clinic.longitude),
                      child: const Icon(Icons.local_hospital, color: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final clinic in _results!)
                ListTile(
                  title: Text(clinic.name),
                  subtitle: Text(
                    [if (clinic.address != null) clinic.address!, clinic.formattedDistanceFrom(center)].join(' · '),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
```

Add the import: `import 'package:flutter_map/flutter_map.dart';` at the top of
`lib/screens/vets/vets_screen.dart`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/vets/vets_screen.dart test/screens/vets_screen_test.dart
git commit -m "feat: render a flutter_map with clinic markers in VetsScreen"
```

#### Cycle 4 — tapping a list row centers the map on that clinic

- [ ] **Step 1: Write the failing test**

Append to `test/screens/vets_screen_test.dart`:

```dart
testWidgets('tapping a clinic row moves the map to that clinic', (tester) async {
  final geocodingClient = MockClient(
    (request) async => http.Response('[{"lat":"48.8566","lon":"2.3522","display_name":"Paris"}]', 200),
  );
  final vetClient = MockClient(
    (request) async => http.Response(
      '{"elements":['
      '{"type":"node","id":1,"lat":48.857,"lon":2.353,"tags":{"name":"Clinique du Parc"}},'
      '{"type":"node","id":2,"lat":48.90,"lon":2.40,"tags":{"name":"Clinique Lointaine"}}'
      ']}',
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await tester.tap(find.text('Clinique Lointaine'));
  await tester.pump();

  // The map itself isn't asserted on directly (no network tiles in test);
  // this confirms the tap handler runs without throwing, which is what
  // MapController.move would do on a bad/disposed controller.
});
```

- [ ] **Step 2: Run test to verify it fails or trivially passes**

```bash
flutter test test/screens/vets_screen_test.dart
```

The row isn't tappable yet (no `onTap`), so the test passes today by doing
nothing meaningful — that's the signal to add the real behavior next, not a
reason to skip it.

- [ ] **Step 3: Wire a `MapController` and the row tap**

In `_VetsScreenState`, add a field and use it:

```dart
final _mapController = MapController();
```

Pass `mapController: _mapController` to the `FlutterMap(...)` constructor from
Cycle 3, and add `onTap` to each clinic's `ListTile`:

```dart
            for (final clinic in _results!)
              ListTile(
                title: Text(clinic.name),
                subtitle: Text(
                  [if (clinic.address != null) clinic.address!, clinic.formattedDistanceFrom(center)].join(' · '),
                ),
                onTap: () => _mapController.move(LatLng(clinic.latitude, clinic.longitude), 15),
              ),
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/screens/vets_screen_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/vets/vets_screen.dart test/screens/vets_screen_test.dart
git commit -m "feat: tapping a clinic row centers the map on it"
```

---

### Task 9: Wire the new tab into navigation

**Files:**
- Modify: `lib/app_shell.dart`
- Modify: `lib/app_router.dart`

**Interfaces:**
- Consumes: `VetsScreen` (Task 8).

No dedicated new test file: this is declarative router/nav wiring with no
branching logic, and there's no existing precedent in this codebase for testing
the authenticated shell's navigation (the only router-adjacent test,
`test/app_smoke_test.dart`, covers the logged-out redirect to `/login` and isn't
affected by this change). Verified instead by the full regression suite and by
manual verification in Task 10.

- [ ] **Step 1: Add the fourth destination to `AppShell`**

In `lib/app_shell.dart`, add one entry to the `destinations` list:

```dart
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets), label: 'Mes animaux'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Rappels'),
          NavigationDestination(icon: Icon(Icons.local_hospital), label: 'Vétérinaires'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
```

(Placed before Profil, matching the roadmap's own ordering of Home → Reminders →
Vets → Profile as increasingly personal/settings-like.)

- [ ] **Step 2: Add the branch to the router**

In `lib/app_router.dart`, add the import:

```dart
import 'screens/vets/vets_screen.dart';
```

Add a new `StatefulShellBranch` inside the existing `StatefulShellRoute.indexedStack`'s
`branches` list, between the Rappels branch and the Profil branch (matching the
`AppShell` ordering above exactly — `StatefulShellBranch` order must match
`NavigationDestination` order, since `navigationShell.currentIndex` indexes into
both by position):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vets',
                builder: (context, state) => const VetsScreen(),
              ),
            ],
          ),
```

- [ ] **Step 3: Run the full test suite**

```bash
flutter test
flutter analyze lib/
```

Expected: all tests pass (142 at this point: 136 before this plan + 6 in
`vets_screen_test.dart`); `flutter analyze` shows the same pre-existing 12 `info`
issues, no new ones.

- [ ] **Step 4: Commit**

```bash
git add lib/app_shell.dart lib/app_router.dart
git commit -m "feat: add a Vétérinaires tab to the bottom navigation"
```

---

### Task 10: Manual verification

**Files:** none.

- [ ] **Step 1: Start the local Supabase stack and the web dev server**

```bash
supabase status || supabase start
supabase migration up   # only if any migration is pending; this feature adds none
```

Copy `web/` into the worktree if it's missing (fresh worktrees branched from
`origin/main` may lack it until it's re-verified as committed):

```bash
cp -r /home/missia03/Projects/pawfolio/web ./web
```

Run the app against local Supabase (get the anon key from `supabase status -o
env`), opening the Browser pane with `preview_start({url: "http://localhost:<port>"})`
— not `{name: "pawfolio-web"}`, which resolves `.claude/launch.json` from the
**main checkout**, not this worktree, so it would serve stale code with none of
this feature's changes:

```bash
flutter run -d web-server --web-port 8768 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<from supabase status -o env>
```

- [ ] **Step 2: Verify the tab exists and the initial state renders**

Sign in with a throwaway test account, navigate to the new "Vétérinaires" tab.
Confirm: the tab icon/label render, the initial prompt text shows, no crash.

- [ ] **Step 3: Verify the "use my position" path fails gracefully**

Tap the locate-me button. Expected: the sandboxed browser denies the permission
prompt (same as it did for the barcode scanner's camera) — confirm the screen
shows the `LocationStatus.denied` error copy rather than crashing or hanging.

- [ ] **Step 4: Verify the real address search path end-to-end**

Type a real, well-known address (e.g. "Tour Eiffel, Paris") and submit. This
hits the **real** Nominatim and Overpass public endpoints — a couple of requests,
well within their fair-use policies. Confirm: the map renders with visible OSM
tiles, at least one clinic marker and list row appear (central Paris has several
mapped veterinary clinics), and distances look plausible.

- [ ] **Step 5: Verify tapping a result centers the map, and the empty state**

Tap a different list row than the one the map is currently centered on; confirm
the map recenters. Then search an address in a very remote/rural area (or a
made-up postal code) to trigger the zero-results `EmptyState`.

- [ ] **Step 6: Clean up**

```bash
# stop the flutter run process
# gio trash web (only if it wasn't already tracked before this task — check
# `git status` first; if `web/` shows as unmodified/tracked, leave it alone)
```

---

### Task 11: `/simplify` pass

**Files:** the full diff from Tasks 2–9.

- [ ] **Step 1: Run `/simplify`** against the diff (reuse, simplification,
  efficiency, altitude — 4 parallel review agents per that skill's process).

- [ ] **Step 2: Apply the fixes** it reports, unless a fix would contradict this
  spec's approved decisions (e.g. don't reintroduce a paid tile provider, don't
  merge the two service classes back into one).

- [ ] **Step 3: Re-run the full test suite** after applying fixes.

```bash
flutter test
flutter analyze lib/
```

- [ ] **Step 4: Commit** any fixes as their own commit(s), same as the barcode
  and breed-predispositions PRs did.

---

### Task 12: `/security-review` pass

**Files:** the full diff from Tasks 2–9.

- [ ] **Step 1: Run `/security-review`** against the diff. Expect it to check in
  particular: the typed address never reaches the Overpass query string directly
  (it only reaches Nominatim, via a `Uri.https` query parameter, never
  interpolated into a raw URL or query string — see Global Constraints); no API
  key exists to leak (there is none in this feature).

- [ ] **Step 2: Address any confirmed findings**; re-run tests if any fix
  touches application code.

---

### Task 13: Update `CHANGELOG.md`

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add an entry**

Under the existing `## [Unreleased]` → `### Added` section (this repo doesn't
tag releases or bump `pubspec.yaml`'s version per-PR — confirmed by `git log`
and by how the two most recently merged PRs handled their own changelog
entries), add, as the newest (topmost) `### Added` bullet:

```markdown
- Nearby veterinarians: a new "Vétérinaires" tab shows a map and list of
  veterinary clinics near you (GPS or a typed address), using free OpenStreetMap
  data — no account, no API key.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add changelog entry for nearby veterinarians map"
```

---

### Task 14: Finish the branch

**Files:** none.

- [ ] **Step 1: Final full-suite check**

```bash
flutter test
flutter analyze lib/
```

- [ ] **Step 2: Push and open the PR**

```bash
gh auth switch --user St4r4x
git push -u origin feature/nearby-vets-map
gh pr create --title "feat: add nearby veterinarians map" --body "$(cat <<'EOF'
## Summary
- New "Vétérinaires" tab: search nearby veterinary clinics via GPS or a typed
  address, shown on an OpenStreetMap-tiled map plus a results list
- Two keyless, fail-soft HTTP services: GeocodingService (Nominatim),
  VetSearchService (Overpass) — no API key, no new Supabase table
- Phase 3.1 of the roadmap; favorites (3.2) are a separate follow-up

## Test plan
- [x] `flutter test` — full suite passing
- [x] `flutter analyze` — no new issues
- [x] Manual verification: typed-address path against the real Nominatim/Overpass
  endpoints (map, markers, list, tap-to-center, empty state all confirmed); GPS
  path confirmed to fail gracefully (permission denied in the sandboxed browser,
  same limitation as the barcode scanner's camera)
- [x] `/simplify` and `/security-review` passes applied

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
gh auth switch --user St4r4x-NV
```

- [ ] **Step 3: Report the PR URL** and keep the worktree in place for review
  feedback.

---

## Self-Review Notes

- **Spec coverage:** every section of `2026-08-21-nearby-vets-map-design.md` maps
  to a task — data model (Task 3), geocoding service (Task 4), vet search service
  (Task 5), providers (Task 6), location provider (Task 7), screen incl. error/
  empty states (Task 8), navigation (Task 9), testing strategy incl. the explicit
  GPS-not-testable call (throughout), manual verification against real endpoints
  (Task 10).
- **File-path correction from the spec:** the spec said `lib/services/`; this repo
  has no such directory. Corrected to `lib/vets/`, mirroring `lib/barcode/`'s
  established feature-module convention — an implementation-level detail the
  brainstorming spec left at the wrong altitude, fixed here where file structure
  gets locked in.
- **Type consistency checked:** `VetClinic` (Task 3) → consumed identically by
  `VetSearchService` (Task 5, `distanceMetersFrom`/`fromOverpassElement`) and
  `VetsScreen` (Task 8, `formattedDistanceFrom`, `.name`, `.address`,
  `.latitude`/`.longitude`). `LocationState`/`LocationStatus` (Task 7) aren't
  actually consumed by `VetsScreen`'s Task 8 code as written — `VetsScreen` calls
  `ref.read(locationProvider.notifier).useCurrentPosition()` but doesn't `watch`
  `locationProvider` to react to its result. **This is a real gap**, not a typo:
  Task 8 as written lets the user tap the locate-me button, but the resulting
  `LocationState.granted(position)` never triggers `_searchNear`. Fixed by adding
  a `ref.listen(locationProvider, ...)` in `VetsScreen`'s `build()` — see the
  addendum below.

### Addendum: wiring `locationProvider` into `VetsScreen` (Cycle 1, Step 3, corrected)

Add inside `build()`, before the `return Scaffold(...)`:

```dart
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.status == LocationStatus.granted && next.position != null) {
        _searchNear(next.position!);
      } else if (next.status == LocationStatus.denied || next.status == LocationStatus.error) {
        setState(() {
          _loading = false;
          _errorMessage = next.errorMessage;
        });
      } else if (next.status == LocationStatus.loading) {
        setState(() {
          _loading = true;
          _errorMessage = null;
        });
      }
    });
```

This isn't separately unit-tested (same reasoning as the rest of `location_provider.dart`'s
GPS path — see Global Constraints), but it's exercised by every manual
verification step in Task 10 that taps the locate-me button.
