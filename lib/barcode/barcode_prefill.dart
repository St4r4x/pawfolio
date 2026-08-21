import 'package:flutter/widgets.dart';

import 'barcode_lookup_service.dart';
import 'barcode_name_cache.dart';

/// Fills [referenceController] with the scanned [code], and — only if
/// [nameController] is still empty — tries to prefill the product name from
/// the local cache first, then the barcode lookup service, remembering a
/// fresh lookup hit in the cache for next time.
Future<void> applyScannedBarcode({
  required String code,
  required TextEditingController nameController,
  required TextEditingController referenceController,
  required BarcodeNameCache cache,
  required BarcodeLookupService lookupService,
}) async {
  referenceController.text = code;
  if (nameController.text.trim().isNotEmpty) return;

  final cached = await cache.get(code);
  if (cached != null) {
    nameController.text = cached;
    return;
  }

  final looked = await lookupService.lookupProductName(code);
  if (looked != null) {
    nameController.text = looked;
    await cache.put(code, looked);
  }
}
