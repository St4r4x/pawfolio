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
        '(node[amenity=veterinary](around:${radiusMeters.toInt()},${center.latitude},${center.longitude}););'
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
