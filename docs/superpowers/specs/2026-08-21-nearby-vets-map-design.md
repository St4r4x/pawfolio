# Pawfolio — Nearby Veterinarians Map — Design

## Purpose

Roadmap Phase 3.1 (`docs/roadmap.md`): let a user find veterinary clinics near them,
without adding a paid API key or a new backend service. This is the last major item
in the roadmap's suggested ordering, and the first Pawfolio feature that talks to
location hardware and to external mapping data rather than to Supabase.

Scope for this spec is **3.1 only**: search + map + list. Phase 3.2 (favorite vets,
a `favorite_vets` Supabase table + a favorite button) is a separate, later spec — it
depends on this screen existing but adds its own data model and its own PR, matching
how every roadmap phase so far has shipped as one focused PR.

Out of scope for this PR (approved during brainstorming):
- Favoriting a vet (3.2).
- OSM `way`/`relation`-shaped clinics — only point `node`s are queried. Real-world
  vet clinics are overwhelmingly mapped as nodes; ways/relations would need a
  centroid computation for a vanishingly small gain.
- Auto-refreshing results as the user pans/zooms the map. Search is an explicit
  action (tap "use my location" or submit an address), not a live map query.
- Persisting the last search location across app restarts.

## Architecture approach

**Two new stateless HTTP services (Nominatim geocoding, Overpass POI search) behind
Riverpod providers, one new location-permission notifier, one new screen, one new
bottom-nav tab.** No new backend, no Supabase table, no new dependency on `main.dart`
startup.

This directly extends two patterns already established in this codebase (barcode
scanner PR, merged 2026-08-21):
- A fail-soft HTTP service class (`BarcodeLookupService`) that never throws — any
  network error, timeout, or empty result resolves to `null`/`[]` so the UI shows an
  explicit empty/error state instead of a crash. `GeocodingService` and
  `VetSearchService` follow the same shape, each with an injectable `http.Client`
  for testing via `package:http/testing.dart`.
- Riverpod `Provider`s for external-facing services (`barcodeLookupServiceProvider`),
  consumed via `ref.read(...)` from the widget, not constructed ad hoc. This is what
  makes the services swappable with fakes in widget tests without touching real
  network or GPS hardware.

Rejected: a single combined "LocationSearchService" merging geocoding + POI search —
the two calls hit unrelated external APIs (Nominatim vs. Overpass) with different
request/response shapes; keeping them as separate classes keeps each one small and
independently testable, matching this codebase's existing preference for narrow,
single-purpose service classes (`BarcodeLookupService`, `BarcodeNameCache`) over
multi-purpose ones.

## Navigation

A fourth `StatefulShellBranch` in `lib/app_router.dart`'s existing
`StatefulShellRoute.indexedStack`, alongside Mes animaux / Rappels / Profil:

| Tab | Route | Icon |
|---|---|---|
| Vétérinaires | `/vets` | `Icons.local_hospital` (already used for vet-visit records) |

No changes to the three existing branches. `AppShell`'s `NavigationDestination` list
gains one entry.

## Data model

`lib/models/vet_clinic.dart` — a plain immutable record of what a clinic needs to
render as a map marker and a list row:

```dart
class VetClinic {
  const VetClinic({required this.id, required this.name, required this.latitude, required this.longitude, this.address});
  final String id;       // OSM element id, e.g. "node/123456"
  final String name;      // falls back to "Vétérinaire" if OSM has no `name` tag
  final double latitude;
  final double longitude;
  final String? address;  // built from addr:housenumber/street/city tags when present
  double distanceMetersFrom(LatLng origin); // via latlong2's Distance (flutter_map's own dependency, no new package)
}
```

## Components

- **`lib/providers/location_provider.dart`** — a `Notifier` wrapping
  `Geolocator.getCurrentPosition()`, exposing a small sealed-ish state:
  `LocationState` = `idle | loading | granted(Position) | denied | error(String)`.
  Nothing calls this on screen load; it only runs when the user taps "Utiliser ma
  position", so the permission prompt is always a direct result of a user action.

- **`lib/services/geocoding_service.dart`** — `GeocodingService.geocode(String query)
  → Future<LatLng?>`. Calls Nominatim's `/search` endpoint
  (`https://nominatim.openstreetmap.org/search?q=...&format=json&limit=1`), a free
  public geocoder with no API key, subject to a 1 req/sec fair-use policy (a
  personal app with manual, user-triggered searches is far under that). Sets a
  descriptive `User-Agent` header identifying the app and its public repo, per
  Nominatim's usage policy. Returns `null` on no match, non-200, timeout, or
  malformed response — same never-throw contract as `BarcodeLookupService`.

- **`lib/services/vet_search_service.dart`** — `VetSearchService.nearby(LatLng
  center, {double radiusMeters = 5000}) → Future<List<VetClinic>>`. Builds an
  Overpass QL query for `node[amenity=veterinary]` within `around:radius,lat,lon` of
  Overpass's public interpreter (`https://overpass-api.de/api/interpreter`), parses
  the `elements` array into `VetClinic`s, sorts by distance from `center`. Returns
  `[]` (not null) on any failure, so the screen can render one consistent empty
  state regardless of *why* there are no results.

- **`lib/providers/vet_search_providers.dart`** — `geocodingServiceProvider` and
  `vetSearchServiceProvider`, plain `Provider`s (matches
  `lib/providers/barcode_providers.dart`), so widget tests override them with fakes
  instead of hitting real network.

- **`lib/screens/vets/vets_screen.dart`** — the tab body:
  1. A search row: a `TextField` for a typed address (submits → `GeocodingService`)
     and an icon button "Utiliser ma position" (triggers `location_provider`).
  2. Below it, one of: an initial prompt state, a loading spinner, an error message
     (permission denied / geocoding failed / network error — each with distinct,
     actionable copy), an `EmptyState` (reusing the existing
     `lib/widgets/empty_state.dart`) if the resolved location has zero nearby
     clinics, or the results: a `FlutterMap` (OpenStreetMap raster tiles via
     `TileLayer` with `urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'`
     and a `userAgentPackageName`, per OSM's tile usage policy — no API key) showing
     a marker per clinic plus a "you are here" marker, with a scrollable `ListView`
     of clinics (name, address, distance) underneath. Tapping a list row calls
     `MapController.move` to center that clinic's marker; markers themselves stay
     non-interactive for V1 — the list is the single source of detail.

## Data flow

1. User taps "Utiliser ma position" **or** types an address and submits.
2. That resolves to a `LatLng` (from `Geolocator` or from `GeocodingService`).
3. `VetSearchService.nearby(latLng)` runs; the screen shows a loading state meanwhile.
4. Results (possibly empty) render as map + list. A failed geocode or a location
   permission denial shows its own explanatory state and does **not** call
   `VetSearchService` — there's no ambiguity about which step failed.

## Error handling

Every external failure path has a distinct, human-readable message (in French, matching
the rest of the app) rather than a generic "Erreur: $error":
- Location permission denied → "Localisation refusée — entre une adresse à la place."
  (keeps the manual-search path visible, doesn't dead-end the screen).
- Address not found → "Adresse introuvable."
- Network/timeout on either service → "Impossible de charger les vétérinaires,
  réessaie." with a retry action.
- Zero results for a valid location → the existing `EmptyState` widget, consistent
  with every other list screen in the app (Vaccins/Traitements/Rappels/etc.).

## Testing

- `VetClinic`: JSON-parsing test against a sample Overpass `elements` array
  (including a node with no `name`/`addr:*` tags, to confirm the fallbacks).
- `GeocodingService` / `VetSearchService`: unit tests via `MockClient`
  (`package:http/testing.dart`) covering success, empty/no-match, non-200, and
  thrown-exception cases — same shape as `barcode_lookup_service_test.dart`.
- Distance sort: a pure unit test with a handful of known coordinates.
- `VetsScreen` widget tests: override `vetSearchServiceProvider` /
  `geocodingServiceProvider` with fakes and drive the manual-address path
  end-to-end (type address → submit → results render); assert the permission-denied
  and empty-results states render their expected copy. The GPS path itself
  (`location_provider` actually calling `Geolocator`) isn't unit-testable
  meaningfully and isn't manually verifiable in this environment either — the
  sandboxed browser used for manual verification denies geolocation the same way
  it denied the camera for the barcode scanner. Manual verification instead
  exercises the address path against the **real** Nominatim and Overpass endpoints
  once, to confirm the actual integration (query shape, response parsing, tile
  loading) works end to end — a handful of requests, well inside fair use.

## Dependencies added

- `geolocator` (^14.x) — GPS position, web-supported (browser Geolocation API;
  requires a secure context, but `http://localhost`/`127.0.0.1` count as secure
  contexts for this purpose, so local dev works over plain HTTP).
- `flutter_map` (^8.x) — the map widget, web-supported, tile-source-agnostic (no
  API key required for the OSM raster tile server used here).
- `latlong2` — flutter_map's own coordinate/distance dependency; reused directly
  instead of hand-rolling haversine math.

No new Supabase migration, no new secret, no `--dart-define`.
