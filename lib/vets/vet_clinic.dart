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

  factory VetClinic.fromSireneEtablissement(Map<String, dynamic> etablissement, {required String fallbackName}) {
    final enseignes = (etablissement['liste_enseignes'] as List<dynamic>?)?.whereType<String>();
    final name =
        (enseignes?.isNotEmpty ?? false)
            ? enseignes!.first
            : etablissement['nom_commercial'] as String? ?? fallbackName;

    return VetClinic(
      id: 'siret/${etablissement['siret']}',
      name: name,
      latitude: double.parse(etablissement['latitude'] as String),
      longitude: double.parse(etablissement['longitude'] as String),
      address: etablissement['adresse'] as String?,
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
