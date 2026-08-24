import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geocoding_service.dart';
import 'vet_clinic.dart';

/// Finds veterinary clinics near a point by combining OpenStreetMap's
/// Overpass API with France's official business registry (SIRENE, via
/// data.gouv.fr's "recherche d'entreprises" API, filtered to NAF code
/// 75.00Z). OSM coverage depends on volunteer mapping and misses many
/// clinics; SIRENE is the exhaustive official list but only supports
/// filtering by postcode, not by radius, so results are reverse-geocoded
/// and re-filtered client-side. Both sources are queried in parallel and
/// each never throws: any miss, error, or timeout resolves to an empty
/// list so a failure in one source never hides results from the other.
class VetSearchService {
  VetSearchService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client(),
        _geocodingService = GeocodingService(client: client);

  final http.Client _client;
  final GeocodingService _geocodingService;
  final Duration timeout;

  /// SIRENE establishments within this distance of an already-found clinic
  /// are assumed to be the same physical place and dropped.
  static const _duplicateRadiusMeters = 30;

  Future<List<VetClinic>> nearby(LatLng center, {double radiusMeters = 5000}) async {
    final sources = await Future.wait([_searchOverpass(center, radiusMeters), _searchSirene(center)]);
    final osmClinics = sources[0];
    // Overpass already bounds its results server-side via the `around:radiusMeters`
    // query; SIRENE is filtered by postcode instead, so it needs the same bound
    // applied client-side.
    final sireneClinics = sources[1].where((c) => c.distanceMetersFrom(center) <= radiusMeters);

    final merged = [...osmClinics];
    for (final clinic in sireneClinics) {
      final isDuplicate = osmClinics.any(
        (existing) => clinic.distanceMetersFrom(LatLng(existing.latitude, existing.longitude)) < _duplicateRadiusMeters,
      );
      if (!isDuplicate) merged.add(clinic);
    }

    final withDistance =
        merged.map((clinic) => (clinic: clinic, distance: clinic.distanceMetersFrom(center))).toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
    return [for (final entry in withDistance) entry.clinic];
  }

  Future<List<VetClinic>> _searchOverpass(LatLng center, double radiusMeters) async {
    final query =
        '[out:json][timeout:10];'
        '(node[amenity=veterinary](around:${radiusMeters.toInt()},${center.latitude},${center.longitude}););'
        'out;';
    final uri = Uri.https('overpass-api.de', '/api/interpreter', {'data': query});
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final elements = (jsonDecode(response.body) as Map<String, dynamic>)['elements'] as List<dynamic>?;
      if (elements == null) return const [];
      return [for (final e in elements) VetClinic.fromOverpassElement(e as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  Future<List<VetClinic>> _searchSirene(LatLng center) async {
    try {
      final postcode = await _geocodingService.reverseGeocode(center);
      if (postcode == null) return const [];
      final uri = Uri.https('recherche-entreprises.api.gouv.fr', '/search', {
        'code_postal': postcode,
        'activite_principale': '75.00Z',
        'etat_administratif': 'A',
        'per_page': '25',
        'limite_matching_etablissements': '25',
      });
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final results = (jsonDecode(response.body) as Map<String, dynamic>)['results'] as List<dynamic>?;
      if (results == null) return const [];

      final clinics = <VetClinic>[];
      for (final company in results.cast<Map<String, dynamic>>()) {
        final fallbackName = company['nom_complet'] as String? ?? 'Vétérinaire';
        final etablissements = company['matching_etablissements'] as List<dynamic>? ?? const [];
        for (final etab in etablissements.cast<Map<String, dynamic>>()) {
          if (etab['latitude'] == null || etab['longitude'] == null) continue;
          final activite = etab['activite_principale'] as String?;
          if (activite != null && activite != '75.00Z') continue;
          clinics.add(VetClinic.fromSireneEtablissement(etab, fallbackName: fallbackName));
        }
      }
      return clinics;
    } catch (_) {
      return const [];
    }
  }
}
