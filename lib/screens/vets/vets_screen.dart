import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/vet_clinic.dart';
import '../../providers/location_provider.dart';
import '../../providers/vet_search_providers.dart';
import '../../widgets/empty_state.dart';

class VetsScreen extends ConsumerStatefulWidget {
  const VetsScreen({super.key});

  @override
  ConsumerState<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends ConsumerState<VetsScreen> {
  final _addressController = TextEditingController();
  final _mapController = MapController();
  bool _loading = false;
  String? _errorMessage;
  List<VetClinic>? _results;
  LatLng? _center;

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = null;
    });
    final coords = await ref.read(geocodingServiceProvider).geocode(address);
    if (coords == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Adresse introuvable.';
      });
      return;
    }
    await _searchNear(coords);
  }

  Future<void> _searchNear(LatLng center) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _center = center;
    });
    final clinics = await ref.read(vetSearchServiceProvider).nearby(center);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = clinics;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.status == LocationStatus.granted && next.position != null) {
        _searchNear(next.position!);
      } else if (next.status == LocationStatus.denied || next.status == LocationStatus.error) {
        setState(() {
          _loading = false;
          _errorMessage = next.errorMessage;
        });
      } else if (next.status == LocationStatus.loading) {
        setState(() {
          _loading = true;
          _errorMessage = null;
        });
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_results == null) {
      return const Center(child: Text('Cherche des vétérinaires près de chez toi.'));
    }
    if (_results!.isEmpty) {
      return const EmptyState(
        illustration: Icon(Icons.location_off_outlined, size: 64),
        title: 'Aucun vétérinaire trouvé à proximité',
      );
    }
    final center = _center!;
    return Column(
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
                  for (final clinic in _results!)
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
          child: ListView(
            children: [
              for (final clinic in _results!)
                ListTile(
                  title: Text(clinic.name),
                  subtitle: Text(
                    [if (clinic.address != null) clinic.address!, clinic.formattedDistanceFrom(center)].join(' · '),
                  ),
                  onTap: () => _mapController.move(LatLng(clinic.latitude, clinic.longitude), 15),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
