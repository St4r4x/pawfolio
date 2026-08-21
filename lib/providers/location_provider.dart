// lib/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus { idle, loading, granted, denied, error }

class LocationState {
  const LocationState({this.status = LocationStatus.idle, this.position, this.errorMessage});

  final LocationStatus status;
  final LatLng? position;
  final String? errorMessage;
}

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  Future<void> useCurrentPosition() async {
    state = const LocationState(status: LocationStatus.loading);

    if (!await Geolocator.isLocationServiceEnabled()) {
      state = const LocationState(
        status: LocationStatus.denied,
        errorMessage: 'Active la localisation dans les réglages de ton appareil.',
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      state = const LocationState(
        status: LocationStatus.denied,
        errorMessage: 'Localisation refusée — entre une adresse à la place.',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      state = LocationState(
        status: LocationStatus.granted,
        position: LatLng(position.latitude, position.longitude),
      );
    } catch (_) {
      state = const LocationState(
        status: LocationStatus.error,
        errorMessage: 'Impossible d\'obtenir ta position.',
      );
    }
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);
