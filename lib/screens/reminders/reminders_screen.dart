import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../date_only.dart';
import '../../motion.dart';
import '../../providers/reminders_provider.dart';
import '../../reminders.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rappels')),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $error'),
              TextButton(
                onPressed: () => ref.invalidate(upcomingRemindersProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                illustration: SvgPicture.asset(
                  'assets/illustrations/no_reminders.svg',
                  colorFilter: const ColorFilter.mode(
                    AppColors.muted,
                    BlendMode.srcIn,
                  ),
                ),
                title: 'Aucun rappel à venir',
                subtitle: 'Les vaccins, traitements et visites à venir apparaîtront ici.',
              )
            : ListView(
                children: AnimateList(
                  interval: AppMotion.durationOrInstant(
                    context,
                    AppMotion.staggerStep,
                  ),
                  effects: [
                    FadeEffect(
                      duration: AppMotion.durationOrInstant(
                        context,
                        AppMotion.microDuration,
                      ),
                      curve: AppMotion.entranceCurve,
                    ),
                  ],
                  children: _sections(items).expand((s) => s).toList(),
                ),
              ),
      ),
    );
  }
}

List<List<Widget>> _sections(List<DueItem> items) {
  final byUrgency = <ReminderUrgency, List<DueItem>>{
    ReminderUrgency.today: [],
    ReminderUrgency.soon: [],
    ReminderUrgency.later: [],
  };
  for (final item in items) {
    byUrgency[reminderUrgency(item.dueDate)]!.add(item);
  }

  const labels = {
    ReminderUrgency.today: "Aujourd'hui",
    ReminderUrgency.soon: 'Cette semaine',
    ReminderUrgency.later: 'Plus tard',
  };

  return [
    for (final urgency in ReminderUrgency.values)
      if (byUrgency[urgency]!.isNotEmpty)
        [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              labels[urgency]!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final item in byUrgency[urgency]!)
            ListTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: urgencyColor(urgency),
              ),
              title: Text('${item.petName} · ${item.label}'),
              subtitle: Text(dateOnly(item.dueDate)),
            ),
        ],
  ];
}
