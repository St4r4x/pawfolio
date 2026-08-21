import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vets/geocoding_service.dart';
import '../vets/vet_search_service.dart';

final geocodingServiceProvider = Provider((ref) => GeocodingService());

final vetSearchServiceProvider = Provider((ref) => VetSearchService());
