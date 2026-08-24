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

  Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'json',
    });
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'Pawfolio/1.0 (+https://github.com/St4r4x/pawfolio)'})
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      return address?['postcode'] as String?;
    } catch (_) {
      return null;
    }
  }
}
