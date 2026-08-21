import 'package:shared_preferences/shared_preferences.dart';

const _keyPrefix = 'barcode_name_cache_';

class BarcodeNameCache {
  Future<String?> get(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix$barcode');
  }

  Future<void> put(String barcode, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$barcode', name);
  }
}
