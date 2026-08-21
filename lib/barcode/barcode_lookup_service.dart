import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a product name from a barcode via UPCitemdb's free trial
/// endpoint (no API key, shared rate limit). Never throws: any miss,
/// error, or timeout resolves to null so callers can fall back to manual
/// entry.
class BarcodeLookupService {
  BarcodeLookupService({http.Client? client, this.timeout = const Duration(seconds: 4)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<String?> lookupProductName(String barcode) async {
    final uri = Uri.https('api.upcitemdb.com', '/prod/trial/lookup', {'upc': barcode});
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;
      final items = (jsonDecode(response.body) as Map<String, dynamic>)['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;
      final title = (items.first as Map<String, dynamic>)['title'] as String?;
      return (title == null || title.isEmpty) ? null : title;
    } catch (_) {
      return null;
    }
  }
}
