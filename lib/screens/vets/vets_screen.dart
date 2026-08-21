import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/location_provider.dart';
import '../../providers/vet_search_providers.dart';
import '../../vets/vet_clinic.dart';
import '../../widgets/empty_state.dart';

sealed class _VetsSearchState {
  const _VetsSearchState();
}

class _Idle extends _VetsSearchState {
  const _Idle();
}

class _Loading extends _VetsSearchState {
  const _Loading();
}

class _Failure extends _VetsSearchState {
  const _Failure(this.message);
  final String message;
}

class _Success extends _VetsSearchState {
  const _Success({required this.center, required this.clinics});
  final LatLng center;
  final List<VetClinic> clinics;
}

class VetsScreen extends ConsumerStatefulWidget {
  const VetsScreen({super.key});

  @override
  ConsumerState<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends ConsumerState<VetsScreen> {
  final _addressController = TextEditingController();
  final _mapController = MapController();
  _VetsSearchState _state = const _Idle();

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    setState(() => _state = const _Loading());
    final coords = await ref.read(geocodingServiceProvider).geocode(address);
    if (coords == null) {
      setState(() => _state = const _Failure('Adresse introuvable.'));
      return;
    }
    await _searchNear(coords);
  }

  Future<void> _searchNear(LatLng center) async {
    setState(() => _state = const _Loading());
    final clinics = await ref.read(vetSearchServiceProvider).nearby(center);
    if (!mounted) return;
    setState(() => _state = _Success(center: center, clinics: clinics));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(locationProvider, (previous, next) {
      switch (next.status) {
        case LocationStatus.granted:
          if (next.position != null) _searchNear(next.position!);
        case LocationStatus.denied:
        case LocationStatus.error:
          setState(() => _state = _Failure(next.errorMessage ?? 'Erreur de localisation.'));
        case LocationStatus.loading:
          setState(() => _state = const _Loading());
        case LocationStatus.idle:
          break;
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Vétérinaires')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Rechercher',
                  onPressed: _searchAddress,
                ),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Utiliser ma position',
                  onPressed: () => ref.read(locationProvider.notifier).useCurrentPosition(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() => switch (_state) {
    _Idle() => const Center(child: Text('Cherche des vétérinaires près de chez toi.')),
    _Loading() => const Center(child: CircularProgressIndicator()),
    _Failure(:final message) => Center(child: Text(message)),
    _Success(:final clinics) when clinics.isEmpty => const EmptyState(
      illustration: Icon(Icons.location_off_outlined, size: 64),
      title: 'Aucun vétérinaire trouvé à proximité',
    ),
    _Success(:final center, :final clinics) => Column(
      children: [
        SizedBox(
          height: 240,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pawfolio.pawfolio',
              ),
              MarkerLayer(
                markers: [
                  Marker(point: center, child: const Icon(Icons.my_location, color: Colors.blue)),
                  for (final clinic in clinics)
                    Marker(
                      point: LatLng(clinic.latitude, clinic.longitude),
                      child: const Icon(Icons.local_hospital, color: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: clinics.length,
            itemBuilder: (context, index) {
              final clinic = clinics[index];
              return ListTile(
                title: Text(clinic.name),
                subtitle: Text(
                  [if (clinic.address != null) clinic.address!, clinic.formattedDistanceFrom(center)].join(' · '),
                ),
                onTap: () => _mapController.move(LatLng(clinic.latitude, clinic.longitude), 15),
              );
            },
          ),
        ),
      ],
    ),
  };
}
