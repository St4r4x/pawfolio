import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../barcode/barcode_lookup_service.dart';
import '../barcode/barcode_name_cache.dart';

final barcodeNameCacheProvider = Provider((ref) => BarcodeNameCache());

final barcodeLookupServiceProvider = Provider((ref) => BarcodeLookupService());
