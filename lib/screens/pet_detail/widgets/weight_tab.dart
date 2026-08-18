import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../date_only.dart';
import '../../../models/weight_entry.dart';
import '../../../providers/weight_entries_provider.dart' show weightEntriesRepositoryProvider, weightEntriesProvider;
import '../../../theme.dart';
import '../../../widgets/empty_state.dart';

class WeightTab extends ConsumerWidget {
  const WeightTab({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightEntriesProvider(petId));

    return Scaffold(
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(weightEntriesProvider(petId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? EmptyState(
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_weight_entries.svg',
                  colorFilter: const ColorFilter.mode(AppColors.muted, BlendMode.srcIn),
                ),
                title: 'Aucune pesée enregistrée',
                subtitle: 'Ajoute la première pesée avec le bouton + ci-dessous.',
              )
            : Column(
                children: [
                  if (entries.length >= 2) _WeightChart(entries: entries),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text('${entry.weightKg} kg'),
                          subtitle: Text(dateOnly(entry.recordedAt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddWeightSheet(context, ref, existing: entry),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWeightSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWeightSheet(BuildContext context, WidgetRef ref, {WeightEntry? existing}) {
    final weightController = TextEditingController(text: existing?.weightKg.toString() ?? '');
    DateTime recordedAt = existing?.recordedAt ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              ListTile(
                title: Text('Pesée le ${dateOnly(recordedAt)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: recordedAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => recordedAt = picked);
                },
              ),
              FilledButton(
                onPressed: () async {
                  final weight = double.tryParse(weightController.text.replaceAll(',', '.'));
                  if (weight == null) return;
                  try {
                    if (existing == null) {
                      await ref.read(weightEntriesRepositoryProvider).create(WeightEntry(
                            id: '',
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    } else {
                      await ref.read(weightEntriesRepositoryProvider).update(WeightEntry(
                            id: existing.id,
                            petId: petId,
                            weightKg: weight,
                            recordedAt: recordedAt,
                          ));
                    }
                    ref.invalidate(weightEntriesProvider(petId));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text('Erreur: $error')));
                    }
                  }
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final chronological = entries.reversed.toList();
    // num.clamp returns num, not double — SideTitles.interval needs an explicit toDouble().
    final labelInterval = (chronological.length / 4).ceil().clamp(1, chronological.length).toDouble();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: labelInterval,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= chronological.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dateOnly(chronological[index].recordedAt),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < chronological.length; i++)
                    FlSpot(i.toDouble(), chronological[i].weightKg),
                ],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData: const FlDotData(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
